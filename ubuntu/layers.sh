#!/usr/bin/env bash
# Investigation (#28): the desktop, apt, Flatpak and download layers for the
# Ubuntu 26.04 work laptop. Run it as the user after debloat.sh and a reboot.
# Every key is checked by fingerprint and every download by its published hash.
set -euo pipefail

claude_key=$(dirname -- "$(realpath -- "$0")")/../pins/claude-desktop.asc
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

log() { printf '\n== %s\n' "$*"; }
# sudo-rs ignores -E, so the variable goes through env.
apt_get() { sudo env DEBIAN_FRONTEND=noninteractive apt-get -q "$@"; }

sudo -v

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
  [[ $got == "$want" ]] || { echo "key $name: got [$got], want [$want]" >&2; exit 1; }
  gpg --homedir "$home" --quiet --import "$home/key"
  gpg --homedir "$home" --export | sudo tee "/usr/share/keyrings/$name.gpg" >/dev/null
}

# A deb822 source file.
source_file() {
  local name=$1
  shift
  printf '%s\n' "$@" | sudo tee "/etc/apt/sources.list.d/$name.sources" >/dev/null
}

log 'curl first: Ubuntu Desktop has wget but not curl'
apt_get update
apt_get install -y curl

log 'Repositories'
# Niri: the Dux PPA, which Niri's docs point to; only niri and
# xwayland-satellite may come from it.
sudo add-apt-repository -y ppa:duxlabs/dux-repo >/dev/null
printf '%s\n' \
  '# Take only Niri and xwayland-satellite from the Dux PPA.' \
  'Package: niri xwayland-satellite' 'Pin: release o=LP-PPA-duxlabs-dux-repo' 'Pin-Priority: 500' '' \
  'Package: *' 'Pin: release o=LP-PPA-duxlabs-dux-repo' 'Pin-Priority: -1' |
  sudo tee /etc/apt/preferences.d/duxlabs-dux-repo >/dev/null

# OBS: the OBS Project's PPA (it carries only obs-studio).
sudo add-apt-repository -y ppa:obsproject/obs-studio >/dev/null

# Noctalia: its keyring package, checked by the key inside it.
curl -fsSL https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb -o "$tmp/nickh.deb"
dpkg-deb -x "$tmp/nickh.deb" "$tmp/nickh"
mkdir -m 700 "$tmp/gnupg-nickh"
gpg --homedir "$tmp/gnupg-nickh" --show-keys --with-colons "$tmp/nickh/usr/share/keyrings/nickh-archive-keyring.gpg" |
  grep -q '^fpr:::::::::C2A7E07FB3D746BDF2A245CD683B67D7BC99A9B7:' || { echo 'noctalia key changed' >&2; exit 1; }
sudo dpkg -i "$tmp/nickh.deb" >/dev/null
source_file noctalia 'Types: deb' 'URIs: https://pkg.noctalia.dev/deb/' 'Suites: resolute/ resolute-backports/' \
  'Architectures: amd64' 'Signed-By: /usr/share/keyrings/nickh-archive-keyring.gpg'

key brave-browser-archive-keyring https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
  DBF1A116C220B8C7164F98230686B78420038257 47D32A74E9A9E013A4B4926C68D513D36A73CD96 B2A3DCA350E67256740DF904DE4EC67BE4B0DCA0
source_file brave-browser-release 'Types: deb' 'URIs: https://brave-browser-apt-release.s3.brave.com' 'Suites: stable' \
  'Components: main' 'Architectures: amd64' 'Signed-By: /usr/share/keyrings/brave-browser-archive-keyring.gpg'

key 1password-archive-keyring https://downloads.1password.com/linux/keys/1password.asc 3FEF9748469ADBE15DA7CA80AC2D62742012EA22
source_file 1password 'Types: deb' 'URIs: https://downloads.1password.com/linux/debian/amd64' 'Suites: stable' \
  'Components: main' 'Architectures: amd64' 'Signed-By: /usr/share/keyrings/1password-archive-keyring.gpg'
# 1Password also signs its .debs; debsig-verify checks them with this policy.
sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22 /usr/share/debsig/keyrings/AC2D62742012EA22
curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol |
  sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol >/dev/null
sudo cp /usr/share/keyrings/1password-archive-keyring.gpg /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

key vscodium-archive-keyring https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
  1302DE60231889FE1EBACADC54678CF75A278D9C
source_file vscodium 'Types: deb' 'URIs: https://download.vscodium.com/debs' 'Suites: vscodium' \
  'Components: main' 'Architectures: amd64' 'Signed-By: /usr/share/keyrings/vscodium-archive-keyring.gpg'

key claude-desktop-archive-keyring "file://$(realpath "$claude_key")" 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
source_file claude-desktop 'Types: deb' 'URIs: https://downloads.claude.ai/claude-desktop/apt/stable' 'Suites: stable' \
  'Components: main' 'Architectures: amd64' 'Signed-By: /usr/share/keyrings/claude-desktop-archive-keyring.gpg'

key spotify-archive-keyring https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc \
  E1096BCBFF6D418796DE78515384CE82BA52C83A
source_file spotify 'Types: deb' 'URIs: https://repository.spotify.com' 'Suites: stable' \
  'Components: non-free' 'Architectures: amd64' 'Signed-By: /usr/share/keyrings/spotify-archive-keyring.gpg'

key docker-archive-keyring https://download.docker.com/linux/ubuntu/gpg 9DC858229FC7DD38854AE2D88D81803C0EBFCD88
source_file docker 'Types: deb' 'URIs: https://download.docker.com/linux/ubuntu' 'Suites: resolute' \
  'Components: stable' 'Architectures: amd64' 'Signed-By: /usr/share/keyrings/docker-archive-keyring.gpg'

apt_get update

log 'Niri without its recommends (no Alacritty or fuzzel)'
apt_get install -y --no-install-recommends niri xwayland-satellite gnome-keyring xdg-desktop-portal-gnome xdg-desktop-portal-gtk

log 'Apps and tools from apt'
apt_get install -y \
  noctalia brave-origin ghostty 1password 1password-cli codium claude-desktop spotify-client obs-studio \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  mpv zsh git git-lfs build-essential udiskie \
  wl-clipboard grim slurp tesseract-ocr tesseract-ocr-eng qrencode sqlite3 socat ddcutil wireguard-tools \
  bibata-cursor-theme papirus-icon-theme qt5ct qt6ct fonts-inter fonts-jetbrains-mono \
  qemu-system-x86 ovmf swtpm swtpm-tools flatpak

log 'Hold Niri and Noctalia: upgraded on purpose only'
sudo apt-mark hold niri noctalia noctalia-data

log 'T3 Code: the maker .deb, checked against its update manifest'
tag=$(curl -fsSL https://api.github.com/repos/pingdotgg/t3code/releases/latest | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')
version=${tag#v}
base=https://github.com/pingdotgg/t3code/releases/download/$tag
curl -fsSL "$base/T3-Code-$version-amd64.deb" -o "$tmp/t3code.deb"
curl -fsSL "$base/latest-linux.yml" -o "$tmp/latest-linux.yml"
want=$(awk -v f="T3-Code-$version-amd64.deb" '$0 ~ "url: " f { getline; print $2 }' "$tmp/latest-linux.yml")
got=$(openssl dgst -sha512 -binary "$tmp/t3code.deb" | base64 -w0)
[[ -n $want && $want == "$got" ]] || { echo 'T3 Code: sha512 mismatch' >&2; exit 1; }
apt_get install -y "$tmp/t3code.deb"

log 'Flatpaks verified by their makers'
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user --noninteractive -y flathub \
  org.libreoffice.LibreOffice io.github.celluloid_player.Celluloid md.obsidian.Obsidian com.github.PintaProject.Pinta

log "Zed: its own install script (~/.local/zed.app, updates itself)"
curl -fsSL https://zed.dev/install.sh -o "$tmp/zed.sh"
sh "$tmp/zed.sh" </dev/null

log 'JetBrains Toolbox: the tarball, checked against its sha256; its first run installs it'
read -r link sum < <(curl -fsSL 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release' |
  python3 -I -c 'import json,sys; d=json.load(sys.stdin)["TBA"][0]["downloads"]["linux"]; print(d["link"], d["checksumLink"])')
curl -fsSL "$link" -o "$tmp/toolbox.tar.gz"
[[ $(curl -fsSL "$sum" | cut -d' ' -f1) == $(sha256sum "$tmp/toolbox.tar.gz" | cut -d' ' -f1) ]] ||
  { echo 'Toolbox: sha256 mismatch' >&2; exit 1; }
mkdir -p "$HOME/Downloads/jetbrains-toolbox"
tar -xzf "$tmp/toolbox.tar.gz" -C "$HOME/Downloads/jetbrains-toolbox" --strip-components=1

log 'Groups: docker (root-equivalent) and kvm'
sudo usermod -aG docker,kvm "$USER"

log 'Done'
