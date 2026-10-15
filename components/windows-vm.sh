# Install, launch, stop, inspect or remove the Windows VM, after Omarchy's
# omarchy-windows-vm. Nix declares the Dockur container; this script owns the
# per-machine settings, disk and launcher entry. Nix sets WINDOWS_ROOT and
# WINDOWS_SERVICE.
settings=$WINDOWS_ROOT/settings.env
storage=$WINDOWS_ROOT/storage
shared=$WINDOWS_ROOT/shared
entry=${XDG_DATA_HOME:-$HOME/.local/share}/applications/windows-vm.desktop

die() {
  gum log --level error "$*"
  exit 1
}

usage() {
  echo "usage: windows-vm install | launch [--keep-alive] | stop | status | remove"
  exit 2
}

setting() {
  local key value
  while IFS='=' read -r key value; do
    if [[ $key == "$1" ]]; then
      printf '%s' "$value"
      return
    fi
  done <"$settings"
}

# Ask for a whole number between min and max, starting at a default.
number() {
  local header=$1 min=$2 max=$3 default=$4 value
  ((min <= max)) || die "Not enough resources for $header (needs $min)."
  value=$(gum input --header "$header ($min-$max)" --value "$((default < max ? default : max))" --char-limit 4) || exit 1
  if [[ ! $value =~ ^[0-9]+$ ]] || ((value < min || value > max)); then
    die "Choose $header between $min and $max."
  fi
  echo "$value"
}

cmd_install() {
  [[ -e /dev/kvm ]] || die "KVM is not available; enable virtualization in the firmware."
  [[ ! -e $settings ]] || die "The Windows VM is installed; run windows-vm remove first."

  local total_ram total_cores free ram cores disk username password iso
  total_ram=$(awk '/MemTotal/ { print int($2 / 1048576) }' /proc/meminfo)
  total_cores=$(nproc)
  free=$(df --output=avail -BG / | awk 'NR == 2 { print int($1) }')
  echo "Host: ${total_ram} GB RAM, ${total_cores} cores, ${free} GB free"

  # Leave the host some RAM, and disk space for the Windows download.
  ram=$(number "RAM in GB" 4 "$((total_ram - 2))" 8)
  cores=$(number "CPU cores" 1 "$total_cores" 4)
  disk=$(number "Disk in GB" 64 "$((free - 20))" 128)
  username=$(gum input --header "Windows username" --placeholder "letters, digits, - or _") || exit 1
  [[ $username =~ ^[A-Za-z0-9_-]{1,20}$ ]] || die "Use 1-20 letters, digits, - or _."
  password=$(gum input --header "Windows password (only for this VM)" --password) || exit 1
  [[ $password =~ ^[[:print:]]{1,64}$ ]] || die "Use 1-64 printable characters."
  iso=$(gum input --header "Custom ISO (empty downloads Windows 11)" --placeholder "$HOME/Downloads/Win11.iso") || exit 1
  iso=${iso/#\~/$HOME}
  [[ -z $iso || -f $iso ]] || die "No ISO at $iso."

  gum style --border normal --padding "1 2" "Windows VM" "" \
    "RAM:       $ram GB" "CPU:       $cores cores" "Disk:      $disk GB" \
    "Username:  $username" "ISO:       ${iso:-Windows 11 download}"
  gum confirm "Install? Root access is requested once." || exit 1

  printf 'RAM_SIZE=%sG\nCPU_CORES=%s\nDISK_SIZE=%sG\nUSERNAME=%s\nPASSWORD=%s\nTZ=%s\n' \
    "$ram" "$cores" "$disk" "$username" "$password" "$(timedatectl show -p Timezone --value)" |
    sudo "$0" root-prepare "$iso"

  mkdir -p "$(dirname "$entry")"
  cat >"$entry" <<EOF
[Desktop Entry]
Type=Application
Name=Windows
Comment=Start the Windows VM and connect with RDP
Exec=uwsm-app -- windows-vm launch
Icon=windows
Terminal=false
Categories=System;Virtualization;
EOF
  [[ -e $HOME/Windows ]] || ln -s "$shared" "$HOME/Windows"

  systemctl start "$WINDOWS_SERVICE"
  echo "Windows is installing. Follow it at http://127.0.0.1:8006 with your Windows username and password."
  echo "Afterwards, open Windows from the launcher or run: windows-vm launch"
}

# Root step: create and mount the subvolume, turn off copy-on-write for the
# disk, store the settings from stdin and link an optional ISO.
root_prepare() {
  local source top iso answer
  if ! findmnt -n "$WINDOWS_ROOT" >/dev/null; then
    source=$(findmnt -n -o SOURCE -T /)
    top=$(mktemp -d)
    mount -o subvolid=5 "${source%%[*}" "$top"
    [[ -d $top/windows ]] || btrfs subvolume create "$top/windows"
    umount "$top"
    rmdir "$top"
    systemctl start "$(systemd-escape --path --suffix mount "$WINDOWS_ROOT")"
  fi
  install -d -m 0700 "$storage"
  chattr +C "$storage"
  install -d -m 2775 -g docker "$shared"
  (umask 0027 && cat >"$settings")
  chgrp docker "$settings"
  if [[ -n ${1-} ]]; then
    cp --reflink=auto -- "$1" "$storage/custom.iso"
    # Dockur replaces an ISO's answer file with its own, which skips the
    # ISO's setup scripts; as storage/custom.xml it is used instead.
    iso=$(mktemp -d)
    mount -o loop,ro -- "$storage/custom.iso" "$iso"
    answer=$(find "$iso" -maxdepth 1 -iname autounattend.xml -print -quit)
    if [[ -n $answer ]]; then
      complete_answer "$answer" >"$storage/custom.xml"
      echo "Using the ISO's own setup, with the disk, account and Remote Desktop added."
    fi
    umount "$iso"
    rmdir "$iso"
  fi
}

# Add what the VM needs to an ISO's answer file, using Dockur's own blocks
# (assets/win11x64.xml): the install disk, the account from settings.env and
# Remote Desktop. Settings the answer file already has are kept.
complete_answer() {
  local account
  account=$(mktemp -p "$storage")
  printf '<account><user>%s</user><password>%s</password></account>\n' \
    "$(setting USERNAME | xmlstarlet esc)" "$(setting PASSWORD | xmlstarlet esc)" >"$account"
  xmlstarlet tr <(answer_stylesheet) -s account="$account" "$1"
  rm -f -- "$account"
}

answer_stylesheet() {
  cat <<'EOF'
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="urn:schemas-microsoft-com:unattend" xmlns:u="urn:schemas-microsoft-com:unattend"
  xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" exclude-result-prefixes="u">
  <xsl:param name="account"/>
  <xsl:variable name="user" select="document($account)/account/user"/>
  <xsl:variable name="password" select="document($account)/account/password"/>

  <xsl:template match="@*|node()">
    <xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy>
  </xsl:template>

  <xsl:template match="u:settings[@pass='windowsPE']/u:component[@name='Microsoft-Windows-Setup'][not(u:DiskConfiguration)]">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <DiskConfiguration>
        <Disk wcm:action="add">
          <DiskID>1</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add"><Order>1</Order><Type>EFI</Type><Size>128</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>2</Order><Type>MSR</Type><Size>128</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>3</Order><Type>Primary</Type><Extend>true</Extend></CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add"><Order>1</Order><PartitionID>1</PartitionID><Label>System</Label><Format>FAT32</Format></ModifyPartition>
            <ModifyPartition wcm:action="add"><Order>2</Order><PartitionID>2</PartitionID></ModifyPartition>
            <ModifyPartition wcm:action="add"><Order>3</Order><PartitionID>3</PartitionID><Label>Windows</Label><Letter>C</Letter><Format>NTFS</Format></ModifyPartition>
          </ModifyPartitions>
        </Disk>
      </DiskConfiguration>
    </xsl:copy>
  </xsl:template>

  <!-- Install onto the Windows partition above, only when the disk layout is ours. -->
  <xsl:template match="u:settings[@pass='windowsPE']/u:component[@name='Microsoft-Windows-Setup'][not(u:DiskConfiguration)]//u:OSImage[not(u:InstallTo)]">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <InstallTo><DiskID>1</DiskID><PartitionID>3</PartitionID></InstallTo>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="u:settings[@pass='specialize'][not(u:component[@name='Microsoft-Windows-TerminalServices-LocalSessionManager'])]">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
        <fDenyTSConnections>false</fDenyTSConnections>
      </component>
      <component name="Microsoft-Windows-TerminalServices-RDP-WinStationExtensions" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
        <UserAuthentication>0</UserAuthentication>
      </component>
      <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
        <FirewallGroups>
          <FirewallGroup wcm:action="add" wcm:keyValue="RemoteDesktop">
            <Active>true</Active>
            <Profile>all</Profile>
            <Group>@FirewallAPI.dll,-28752</Group>
          </FirewallGroup>
        </FirewallGroups>
      </component>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="u:settings[@pass='oobeSystem']/u:component[@name='Microsoft-Windows-Shell-Setup'][not(u:UserAccounts)]">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name><xsl:value-of select="$user"/></Name>
            <Group>Administrators</Group>
            <Password><Value><xsl:value-of select="$password"/></Value><PlainText>true</PlainText></Password>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="u:settings[@pass='oobeSystem']/u:component[@name='Microsoft-Windows-Shell-Setup'][not(u:UserAccounts)]/u:OOBE[not(u:HideLocalAccountScreen)]">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <HideLocalAccountScreen>true</HideLocalAccountScreen>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
EOF
}

cmd_launch() {
  [[ -r $settings ]] || die "The Windows VM is not installed; run windows-vm install."
  local keep_alive=false scale username password started attempt status
  [[ ${1-} == --keep-alive ]] && keep_alive=true
  username=$(setting USERNAME)
  password=$(setting PASSWORD)

  # FreeRDP tries Kerberos first and hangs offline; the VM uses a local account.
  export KRB5_CONFIG=$XDG_RUNTIME_DIR/windows-vm-krb5.conf
  printf '[libdefaults]\n  dns_lookup_kdc = false\n  dns_lookup_realm = false\n' >"$KRB5_CONFIG"

  # Arguments go in on stdin, so the password never appears in the process list.
  rdp() {
    printf '%s\n' "/u:$username" "/p:$password" /v:127.0.0.1:3389 /cert:ignore "$@" |
      xfreerdp /args-from:stdin
  }

  systemctl start "$WINDOWS_SERVICE"
  if ! $keep_alive; then
    trap 'systemctl stop "$WINDOWS_SERVICE"' EXIT
  fi
  # Wait for Dockur's boot message from this start, as Omarchy does; FreeRDP's
  # /auth-only probe can crash while Windows is still starting.
  started=$(docker inspect --format '{{.State.StartedAt}}' windows)
  until docker logs --since "$started" windows 2>&1 | grep -qi "windows started successfully"; do
    systemctl is-active --quiet "$WINDOWS_SERVICE" || die "The Windows VM stopped."
    sleep 2
  done

  scale=$(hyprctl monitors -j | jq -r '.[] | select(.focused).scale * 100 | floor')
  local args=(-grab-keyboard /sound /microphone /clipboard /dynamic-resolution
    /gfx:AVC444 "/title:Windows VM" "/floatbar:sticky:off,default:visible,show:fullscreen" /f)
  if ((scale >= 170)); then
    args+=(/scale:180)
  elif ((scale >= 130)); then
    args+=(/scale:140)
  fi
  # Booted is not yet ready for Remote Desktop: retry while FreeRDP cannot
  # connect, but not after a closed window or a rejected login.
  for attempt in {1..30}; do
    status=0
    rdp "${args[@]}" || status=$?
    case $status in
      131 | 133 | 137 | 141 | 143) ;;
      *) return "$status" ;;
    esac
    systemctl is-active --quiet "$WINDOWS_SERVICE" || die "The Windows VM stopped."
    echo "Windows is not ready for Remote Desktop yet (attempt $attempt of 30)."
    sleep 10
  done
  die "Windows did not accept Remote Desktop; check http://127.0.0.1:8006."
}

cmd_status() {
  [[ -e $settings ]] || die "The Windows VM is not installed; run windows-vm install."
  if systemctl is-active --quiet "$WINDOWS_SERVICE"; then
    gum style --border normal --padding "1 2" "Windows VM: running" "" \
      "Web console: http://127.0.0.1:8006" "Connect:     windows-vm launch" \
      "Stop:        windows-vm stop"
  else
    echo "Windows VM: stopped. Start it with: windows-vm launch"
  fi
}

cmd_remove() {
  gum confirm --default=false "Delete the Windows VM disk and settings? ~/Windows is kept." || exit 1
  systemctl stop "$WINDOWS_SERVICE"
  sudo "$0" root-remove
  rm -f "$entry"
  [[ -L $HOME/Windows ]] && rm "$HOME/Windows"
  echo "Windows VM removed; shared files remain in $shared."
}

root_remove() {
  rm -rf -- "$storage"
  rm -f -- "$settings"
}

case ${1-} in
  install) cmd_install ;;
  launch) cmd_launch "${2-}" ;;
  stop) systemctl stop "$WINDOWS_SERVICE" ;;
  status) cmd_status ;;
  remove) cmd_remove ;;
  root-prepare) root_prepare "${2-}" ;;
  root-remove) root_remove ;;
  *) usage ;;
esac
