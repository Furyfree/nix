#!/usr/bin/env bash
# Debloat a fresh Ubuntu 26.04 Desktop, Default selection, once. bootstrap.sh
# runs it as the user from a terminal in the GNOME session, and the reboot
# after the setup finishes it. It removes only what ubuntu-desktop-minimal
# recommends, never what it depends on, and stops if a removal would take a
# base metapackage with it. It keeps what IT may use: sssd for company sign-in,
# and kdump, whose kernel options IT owns.
set -euo pipefail

log() { printf '\n== %s\n' "$*"; }
apt_get() { sudo env DEBIAN_FRONTEND=noninteractive apt-get -q "$@"; }

purge=(
  # Telemetry and crash reporting
  ubuntu-insights ubuntu-report whoopsie apport apport-gtk
  # Only used at install time
  cloud-init gnome-initial-setup memtest86+
  # Unused services
  gnome-remote-desktop wsdd gamemode sysprof sysstat evolution-data-server modemmanager cups-browsed
  # Screen reader
  orca brltty speech-dispatcher
  # VPN plugins; WireGuard is built into NetworkManager
  openvpn network-manager-openvpn network-manager-openvpn-gnome network-manager-pptp network-manager-pptp-gnome
  # GNOME apps
  baobab gnome-clocks gnome-characters gnome-font-viewer gnome-logs
)
base='^Purg (ubuntu-desktop-minimal|ubuntu-standard|ubuntu-minimal) '

# A disk the TPM unlocks needs snapd, which unlocks it, and the pc-kernel snap,
# which is its kernel; there every snap stays.
if snap list pc-kernel >/dev/null 2>&1; then
  remove_snaps=false
else
  remove_snaps=true
  # snapd and the Firefox package that only installs the snap
  purge+=(snapd firefox)
fi

sudo -v
apt_get update

if $remove_snaps; then
  log 'Snaps: apps first, then runtimes, then bases; apt purges snapd itself'
  for snap in firefox snap-store firmware-updater desktop-security-center prompting-client \
    snapd-desktop-integration hwctl gnome-46-2404 mesa-2404 gtk-common-themes core24 bare; do
    if snap list "$snap" >/dev/null 2>&1; then
      sudo snap remove --purge "$snap"
    fi
  done
else
  log 'The TPM unlocks this disk through snapd: snapd and the snaps stay'
fi

log 'Simulate first: no base metapackage may go'
if LANG=C apt-get -s purge "${purge[@]}" | grep -E "$base"; then
  echo 'debloat.sh: this would remove a base metapackage; stopping' >&2
  exit 1
fi
apt_get purge -y "${purge[@]}"

if $remove_snaps; then
  rm -rf -- "$HOME/snap"
  log "Keep snapd out: nothing may install it again"
  printf '%s\n' '# Keep snapd off; nothing may pull it back in.' 'Package: snapd' 'Pin: release a=*' 'Pin-Priority: -1' |
    sudo tee /etc/apt/preferences.d/no-snapd >/dev/null
fi

log 'Ubuntu Pro adverts in apt off'
sudo pro config set apt_news=false

log 'GNOME file indexing off for this user'
gsettings set org.freedesktop.Tracker3.Miner.Files index-recursive-directories '[]'
gsettings set org.freedesktop.Tracker3.Miner.Files index-single-directories '[]'
localsearch reset --filesystem || true

log 'Autoremove'
# The dry run on its own line, so its failure stops here instead of reading as
# nothing to remove.
removals=$(LANG=C apt-get -s autoremove --purge)
if grep -E "$base" <<<"$removals"; then
  echo 'debloat.sh: autoremove would remove a base metapackage; stopping' >&2
  exit 1
fi
apt_get autoremove --purge -y
sudo dpkg --audit

log 'Done'
