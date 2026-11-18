#!/usr/bin/env bash
# Investigation (#28): debloat a fresh Ubuntu 26.04 Desktop, Default selection.
# Run it as the user from a terminal in the GNOME session, then reboot. It
# removes only what ubuntu-desktop-minimal recommends, never what it depends
# on, and stops if a removal would take a base metapackage with it.
set -euo pipefail

log() { printf '\n== %s\n' "$*"; }
apt_get() { sudo env DEBIAN_FRONTEND=noninteractive apt-get -q "$@"; }

purge=(
  # Telemetry and crash reporting
  ubuntu-insights ubuntu-report whoopsie apport apport-gtk
  # Only used at install time
  cloud-init gnome-initial-setup memtest86+
  # Reserves RAM for crash dumps
  kdump-tools
  # Unused services
  gnome-remote-desktop wsdd gamemode sysprof sysstat evolution-data-server modemmanager cups-browsed
  # Screen reader
  orca brltty speech-dispatcher
  # Active Directory and smart-card login
  sssd sssd-tools libpam-sss
  # VPN plugins; WireGuard is built into NetworkManager
  openvpn network-manager-openvpn network-manager-openvpn-gnome network-manager-pptp network-manager-pptp-gnome
  # GNOME apps
  baobab gnome-clocks gnome-characters gnome-font-viewer gnome-logs
  # snapd and the Firefox package that only installs the snap
  snapd firefox
)
base='^Purg (ubuntu-desktop-minimal|ubuntu-standard|ubuntu-minimal) '

sudo -v
apt_get update

log 'Snaps: apps first, then runtimes, then bases; apt purges snapd itself'
for snap in firefox snap-store firmware-updater desktop-security-center prompting-client \
  snapd-desktop-integration hwctl gnome-46-2404 mesa-2404 gtk-common-themes core24 bare; do
  if snap list "$snap" >/dev/null 2>&1; then
    sudo snap remove --purge "$snap"
  fi
done

log 'Simulate first: no base metapackage may go'
if LANG=C apt-get -s purge "${purge[@]}" | grep -E "$base"; then
  echo 'debloat.sh: this would remove a base metapackage; stopping' >&2
  exit 1
fi
apt_get purge -y "${purge[@]}"
rm -rf -- "$HOME/snap"

log "Keep snapd out: nothing may install it again"
printf '%s\n' '# Keep snapd off; nothing may pull it back in.' 'Package: snapd' 'Pin: release a=*' 'Pin-Priority: -1' |
  sudo tee /etc/apt/preferences.d/no-snapd >/dev/null

log "kdump's crashkernel= stays in grub.cfg until GRUB is regenerated"
sudo update-grub

log 'Ubuntu Pro adverts in apt off'
sudo pro config set apt_news=false

log 'GNOME file indexing off for this user'
gsettings set org.freedesktop.Tracker3.Miner.Files index-recursive-directories '[]'
gsettings set org.freedesktop.Tracker3.Miner.Files index-single-directories '[]'
localsearch reset --filesystem || true

log 'Autoremove, keeping the password-strength check that sssd pulled in'
sudo apt-mark manual libpam-pwquality >/dev/null
if LANG=C apt-get -s autoremove | grep -E "$base"; then
  echo 'debloat.sh: autoremove would remove a base metapackage; stopping' >&2
  exit 1
fi
apt_get autoremove --purge -y
sudo dpkg --audit

log 'Done; reboot now'
