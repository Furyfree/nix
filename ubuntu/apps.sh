#!/usr/bin/env bash
# The work laptop's apps from apt, Flatpak and the makers' downloads. nswitch
# runs it after Home Manager. It installs only what is missing and never
# upgrades or removes anything; Ubuntu's updates and the apps' own updaters do
# that. Must-haves come first and stop it on failure; a nice-to-have that fails
# is reported and skipped. Keys are checked by fingerprint, downloads by their
# published hash.
set -euo pipefail

claude_key=$(dirname -- "$(realpath -- "$0")")/../nixos/pins/claude-desktop.asc
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
refreshed=false
failed=()

log() { printf '== %s\n' "$*"; }
# sudo-rs ignores -E, so the variable goes through env.
apt_get() { sudo env DEBIAN_FRONTEND=noninteractive apt-get -q "$@"; }
has_source() { grep -rqs -- "$1" /etc/apt/sources.list.d/; }

# Install the packages that are not installed yet; options such as
# --no-install-recommends go first.
apt_install() {
  local options=() missing=() package
  while [[ ${1-} == -* ]]; do
    options+=("$1")
    shift
  done
  for package; do
    [[ $(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null) == installed ]] ||
      missing+=("$package")
  done
  ((${#missing[@]})) || return 0
  if ! $refreshed; then
    apt_get update
    refreshed=true
  fi
  log "apt: ${missing[*]}"
  apt_get install -y "${options[@]}" "${missing[@]}"
}

# Fetch a signing key, refuse it unless its primary fingerprints match, and
# store it as a binary keyring for Signed-By.
key() {
  local name=$1 url=$2 got want home=$tmp/gnupg-$1
  shift 2
  mkdir -m 700 "$home"
  curl -fsSL "$url" -o "$home/key"
  got=$(gpg --homedir "$home" --show-keys --with-colons "$home/key" |
    awk -F: '/^pub/ { p = 1; next } /^fpr/ && p { print $10; p = 0 }' | sort | xargs)
  want=$(printf '%s\n' "$@" | sort | xargs)
  [[ $got == "$want" ]] || {
    echo "key $name: got [$got], want [$want]" >&2
    return 1
  }
  gpg --homedir "$home" --quiet --import "$home/key"
  gpg --homedir "$home" --export | sudo tee "/usr/share/keyrings/$name.gpg" >/dev/null
}

# A deb822 source file; apt's lists are refreshed before the next install.
source_file() {
  local name=$1
  shift
  printf '%s\n' "$@" | sudo tee "/etc/apt/sources.list.d/$name.sources" >/dev/null
  refreshed=false
}

# Run a nice-to-have step; a failure is reported at the end, not fatal.
nice_to_have() {
  local status
  set +e
  (
    set -e
    "$2"
  )
  status=$?
  set -e
  ((status == 0)) || failed+=("$1")
}

# --- Must-haves -------------------------------------------------------------

# curl first: Ubuntu Desktop has wget but not curl.
apt_install curl gpg

if ! has_source brave-browser-apt-release; then
  key brave-browser-archive-keyring https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
    DBF1A116C220B8C7164F98230686B78420038257 47D32A74E9A9E013A4B4926C68D513D36A73CD96 B2A3DCA350E67256740DF904DE4EC67BE4B0DCA0
  source_file brave-browser-release 'Types: deb' 'URIs: https://brave-browser-apt-release.s3.brave.com' 'Suites: stable' \
    'Components: main' 'Architectures: amd64' 'Signed-By: /usr/share/keyrings/brave-browser-archive-keyring.gpg'
fi

if ! has_source downloads.1password.com; then
  key 1password-archive-keyring https://downloads.1password.com/linux/keys/1password.asc 3FEF9748469ADBE15DA7CA80AC2D62742012EA22
  source_file 1password 'Types: deb' 'URIs: https://downloads.1password.com/linux/debian/amd64' 'Suites: stable' \
    'Components: main' 'Architectures: amd64' 'Signed-By: /usr/share/keyrings/1password-archive-keyring.gpg'
fi

if ! has_source download.docker.com; then
  key docker-archive-keyring https://download.docker.com/linux/ubuntu/gpg 9DC858229FC7DD38854AE2D88D81803C0EBFCD88
  source_file docker 'Types: deb' 'URIs: https://download.docker.com/linux/ubuntu' 'Suites: resolute' \
    'Components: stable' 'Architectures: amd64' 'Signed-By: /usr/share/keyrings/docker-archive-keyring.gpg'
fi

# The Dux PPA, which Niri's docs point to, for Ghostty, since Ubuntu's stays at
# an older release, and for Niri below; nothing else may come from it. The pin
# goes in first, and again whenever it changes.
dux_pin=$(printf '%s\n' \
  '# Take only Ghostty, Niri and xwayland-satellite from the Dux PPA.' \
  'Package: ghostty niri xwayland-satellite' 'Pin: release o=LP-PPA-duxlabs-dux-repo' 'Pin-Priority: 500' '' \
  'Package: *' 'Pin: release o=LP-PPA-duxlabs-dux-repo' 'Pin-Priority: -1')
if [[ $(cat /etc/apt/preferences.d/duxlabs-dux-repo 2>/dev/null) != "$dux_pin" ]]; then
  printf '%s\n' "$dux_pin" | sudo tee /etc/apt/preferences.d/duxlabs-dux-repo >/dev/null
fi
if ! has_source duxlabs/dux-repo; then
  sudo add-apt-repository -y ppa:duxlabs/dux-repo >/dev/null
  refreshed=false
fi

apt_install zsh git git-lfs build-essential ghostty brave-origin 1password 1password-cli \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras uidmap \
  qemu-system-x86 ovmf swtpm swtpm-tools wireguard-tools

if [[ ! -x $HOME/.local/bin/zed ]]; then
  log "Zed: its own install script (~/.local/zed.app, updates itself)"
  curl -fsSL https://zed.dev/install.sh -o "$tmp/zed.sh"
  sh "$tmp/zed.sh" </dev/null
fi

if [[ $(getent passwd "$USER" | cut -d: -f7) != /usr/bin/zsh ]]; then
  log 'zsh as the login shell'
  sudo chsh -s /usr/bin/zsh "$USER"
fi

# The Windows VM's service and polkit rule, which Home Manager builds
# (ubuntu/home.nix); a changed one replaces the old.
vm=${XDG_DATA_HOME:-$HOME/.local/share}/windows-vm
if [[ -e $vm/docker-windows.service ]] && ! cmp -s "$vm/docker-windows.service" /etc/systemd/system/docker-windows.service; then
  log 'Windows VM service'
  sudo install -m 0644 "$vm/docker-windows.service" /etc/systemd/system/docker-windows.service
  sudo systemctl daemon-reload
fi
# Users cannot read polkit's rules folder, so a stamp with the rule's store
# path tells whether it changed.
stamp=${XDG_STATE_HOME:-$HOME/.local/state}/windows-vm-rules
if [[ -e $vm/windows-vm.rules && $(readlink -f "$vm/windows-vm.rules") != "$(cat "$stamp" 2>/dev/null)" ]]; then
  log 'Windows VM polkit rule'
  sudo install -m 0644 "$vm/windows-vm.rules" /etc/polkit-1/rules.d/50-windows-vm.rules
  mkdir -p "$(dirname "$stamp")"
  readlink -f "$vm/windows-vm.rules" >"$stamp"
fi

# windows-vm reads the VM's settings and may start it; kvm runs the VMs
# without root.
getent group windows-vm >/dev/null || sudo groupadd --system windows-vm
for group in windows-vm kvm; do
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx "$group"; then
    log "group $group; it applies at the next login"
    sudo usermod -aG "$group" "$USER"
  fi
done

# This account's own Docker runs rootless, without root rights, and its
# "rootless" CLI context makes it the default; `sudo docker` reaches the system
# one, which runs the Windows VM. Ubuntu's AppArmor profile lets rootlesskit
# create its user namespace.
if [[ ! -e ${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/docker.service ]]; then
  log 'rootless Docker for this account'
  dockerd-rootless-setuptool.sh install
fi

# --- Nice-to-haves ----------------------------------------------------------

install_vscode() {
  command -v code >/dev/null && return
  # Microsoft's own names for the key and source; code's package finds them and
  # adds no second source.
  if ! has_source packages.microsoft.com/repos/code; then
    key microsoft https://packages.microsoft.com/keys/microsoft.asc BC528686B50D79E339D3721CEB3E94ADBE1229CF
    source_file vscode 'Types: deb' 'URIs: https://packages.microsoft.com/repos/code' 'Suites: stable' \
      'Components: main' 'Architectures: amd64' 'Signed-By: /usr/share/keyrings/microsoft.gpg'
  fi
  # No /usr/bin/copilot, since the shared settings turn Copilot off.
  echo 'code code/add-copilot-command boolean false' | sudo debconf-set-selections
  apt_install code
}

install_t3code() {
  command -v t3code >/dev/null && return
  log 'T3 Code: the maker .deb, checked against its update manifest'
  local tag version base want got
  tag=$(curl -fsSL https://api.github.com/repos/pingdotgg/t3code/releases/latest |
    python3 -I -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')
  version=${tag#v}
  base=https://github.com/pingdotgg/t3code/releases/download/$tag
  curl -fsSL "$base/T3-Code-$version-amd64.deb" -o "$tmp/t3code.deb"
  curl -fsSL "$base/latest-linux.yml" -o "$tmp/latest-linux.yml"
  want=$(awk -v f="T3-Code-$version-amd64.deb" '$0 ~ "url: " f { getline; print $2 }' "$tmp/latest-linux.yml")
  got=$(openssl dgst -sha512 -binary "$tmp/t3code.deb" | base64 -w0)
  [[ -n $want && $want == "$got" ]] || {
    echo 'T3 Code: sha512 mismatch' >&2
    return 1
  }
  apt_get install -y "$tmp/t3code.deb"
}

install_toolbox() {
  # Toolbox runs from where it is unpacked and points its menu and autostart
  # entries there, so it goes beside its data, where it updates itself.
  local dir=$HOME/.local/share/JetBrains/Toolbox/bin link sum
  if [[ ! -x $dir/jetbrains-toolbox ]]; then
    log 'JetBrains Toolbox: the tarball, checked against its sha256'
    read -r link sum < <(curl -fsSL 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release' |
      python3 -I -c 'import json,sys; d=json.load(sys.stdin)["TBA"][0]["downloads"]["linux"]; print(d["link"], d["checksumLink"])')
    curl -fsSL "$link" -o "$tmp/toolbox.tar.gz"
    [[ $(curl -fsSL "$sum" | cut -d' ' -f1) == $(sha256sum "$tmp/toolbox.tar.gz" | cut -d' ' -f1) ]] || {
      echo 'Toolbox: sha256 mismatch' >&2
      return 1
    }
    mkdir -p "${dir%/bin}"
    tar -xzf "$tmp/toolbox.tar.gz" -C "${dir%/bin}" --strip-components=1
  fi
  # Its first start adds the menu entry; start it once where there is a
  # desktop to show it on.
  if [[ -n ${WAYLAND_DISPLAY-}${DISPLAY-} ]] &&
    ! grep -qs "$dir/jetbrains-toolbox" "$HOME/.local/share/applications/jetbrains-toolbox.desktop"; then
    log 'JetBrains Toolbox: its first start, which adds its menu entry'
    setsid -f "$dir/jetbrains-toolbox" >/dev/null 2>&1
  fi
}

install_daily_apps() {
  if ! has_source downloads.claude.ai; then
    key claude-desktop-archive-keyring "file://$(realpath "$claude_key")" 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
    source_file claude-desktop 'Types: deb' 'URIs: https://downloads.claude.ai/claude-desktop/apt/stable' 'Suites: stable' \
      'Components: main' 'Architectures: amd64' 'Signed-By: /usr/share/keyrings/claude-desktop-archive-keyring.gpg'
  fi
  if ! has_source repository.spotify.com; then
    key spotify-archive-keyring https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc \
      E1096BCBFF6D418796DE78515384CE82BA52C83A
    source_file spotify 'Types: deb' 'URIs: https://repository.spotify.com' 'Suites: stable' \
      'Components: non-free' 'Architectures: amd64' 'Signed-By: /usr/share/keyrings/spotify-archive-keyring.gpg'
    # An empty spotify.list stops the package from adding the same source.
    sudo touch /etc/apt/sources.list.d/spotify.list
  fi
  apt_install claude-desktop spotify-client
}

install_flatpaks() {
  apt_install flatpak
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  local app missing=()
  # Verified by their makers on Flathub
  for app in org.libreoffice.LibreOffice io.github.celluloid_player.Celluloid md.obsidian.Obsidian \
    com.github.PintaProject.Pinta com.obsproject.Studio; do
    flatpak info --user "$app" >/dev/null 2>&1 || missing+=("$app")
  done
  ((${#missing[@]})) || return 0
  log "Flatpak: ${missing[*]}"
  flatpak install --user --noninteractive -y flathub "${missing[@]}"
}

install_desktop() {
  # Noctalia ships its key only in a keyring package; take the key alone, so
  # nothing else in the package runs as root.
  if ! has_source pkg.noctalia.dev; then
    curl -fsSL https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb -o "$tmp/nickh.deb"
    dpkg-deb -x "$tmp/nickh.deb" "$tmp/nickh"
    key nickh-archive-keyring "file://$tmp/nickh/usr/share/keyrings/nickh-archive-keyring.gpg" \
      C2A7E07FB3D746BDF2A245CD683B67D7BC99A9B7
    source_file noctalia 'Types: deb' 'URIs: https://pkg.noctalia.dev/deb/' 'Suites: resolute/ resolute-backports/' \
      'Architectures: amd64' 'Signed-By: /usr/share/keyrings/nickh-archive-keyring.gpg'
  fi
  # Niri from the Dux PPA, without its recommends: no Alacritty or fuzzel.
  apt_install --no-install-recommends niri xwayland-satellite gnome-keyring xdg-desktop-portal-gnome xdg-desktop-portal-gtk
  # Noctalia, its plugins' helpers, the removable-drive mounter and the theme
  apt_install noctalia udiskie grim slurp tesseract-ocr tesseract-ocr-eng qrencode sqlite3 socat ddcutil \
    bibata-cursor-theme papirus-icon-theme qt5ct qt6ct fonts-inter fonts-jetbrains-mono
}

nice_to_have 'VS Code' install_vscode
nice_to_have 'T3 Code' install_t3code
nice_to_have 'JetBrains Toolbox' install_toolbox
nice_to_have 'Claude Desktop and Spotify' install_daily_apps
nice_to_have 'Flatpaks' install_flatpaks
nice_to_have 'the Niri desktop' install_desktop

if ((${#failed[@]})); then
  printf 'apps.sh: not installed, nice to have: %s\n' "${failed[@]}" >&2
fi
