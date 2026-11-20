#!/usr/bin/env bash
# Set up the Ubuntu work laptop from this repository: install Git, clone this
# repository, debloat Ubuntu once, install Nix, write ubuntu/local/user.nix,
# switch Home Manager and install the apps. Each step checks first, so running
# it again carries on where it stopped. On a fresh Ubuntu, which has wget but
# not curl, in GNOME's terminal:
#   wget -qO- https://raw.githubusercontent.com/Furyfree/nix/main/ubuntu/bootstrap.sh | bash
# To try a branch before it is merged, fetch it from that branch and name it:
#   wget -qO- https://raw.githubusercontent.com/Furyfree/nix/BRANCH/ubuntu/bootstrap.sh | bash -s -- BRANCH
set -euo pipefail

branch=${1:-main}
repo=$HOME/Projects/nix
user_file=$repo/ubuntu/local/user.nix
nix_bin=/nix/var/nix/profiles/default/bin
debloated=${XDG_STATE_HOME:-$HOME/.local/state}/nix-workstation/debloated

say() { printf '\n==> %s\n' "$*"; }
die() {
  printf 'bootstrap: %s\n' "$*" >&2
  exit 1
}

check() {
  # shellcheck source=/dev/null
  . /etc/os-release
  # apps.sh installs from this release's repositories.
  [[ ${ID-} == ubuntu && ${VERSION_CODENAME-} == resolute ]] || die 'this needs Ubuntu 26.04'
  ((EUID != 0)) || die 'run this as your own account, not as root'
  # sudo asks on the terminal, since wget feeds this script on stdin.
  sudo -v
}

# Over HTTPS: the SSH keys arrive later through 1Password. curl is for the Nix
# installer.
clone() {
  if ! command -v git >/dev/null || ! command -v curl >/dev/null; then
    say 'Installing Git and curl'
    sudo apt-get update -q </dev/null
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -qy git curl </dev/null
  fi
  [[ ! -e $repo ]] || return 0
  say "Cloning this repository's $branch to $repo"
  git clone --branch "$branch" https://github.com/Furyfree/nix.git "$repo"
}

# Until it has finished once; a run cut short repeats it, which is safe.
debloat() {
  [[ ! -e $debloated ]] || return 0
  say 'Debloating Ubuntu'
  "$repo/ubuntu/debloat.sh" </dev/null
  mkdir -p "${debloated%/*}"
  touch "$debloated"
}

install_nix() {
  if [[ ! -x $nix_bin/nix ]]; then
    say 'Installing Nix'
    curl -fsSL -o "$tmp/nix.sh" https://nixos.org/nix/install
    sh "$tmp/nix.sh" --daemon --yes --no-channel-add </dev/null
  fi
  if ! grep -qs '^experimental-features = nix-command flakes$' /etc/nix/nix.conf; then
    echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf >/dev/null
    sudo systemctl restart nix-daemon
  fi
}

write_user() {
  [[ ! -e $user_file ]] || return 0
  mkdir -p "${user_file%/*}"
  printf '{ home.username = "%s"; home.homeDirectory = "%s"; }\n' "$(id -un)" "$HOME" >"$user_file"
  say "Wrote $user_file"
}

first_switch() {
  if [[ -e ${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager ]]; then
    say 'Home Manager runs already; use nswitch from here on'
    return
  fi
  say 'Switching Home Manager'
  # nh as pinned in flake.lock. Files Ubuntu made where a link goes are kept
  # as *.before-home-manager.
  PATH=$nix_bin:$PATH nix run --inputs-from "path:$repo" nixpkgs#nh -- \
    home switch --configuration ubuntu --backup-extension before-home-manager "path:$repo" </dev/null
}

main() {
  tmp=$(mktemp -d)
  trap 'rm -rf -- "$tmp"' EXIT

  check
  clone
  debloat
  install_nix
  write_user
  first_switch
  say 'Installing the apps, which takes a while'
  PATH=$HOME/.nix-profile/bin:$nix_bin:$PATH "$repo/ubuntu/apps.sh" </dev/null
  say 'Done. Reboot, then follow ~/Projects/nix/ubuntu/README.md'
}

# Last, so a download cut short runs nothing.
main
