#!/usr/bin/env bash
# Set up a Mac from this repository, or move one from mac-setup: report its
# security settings, install the Command Line Tools, Rosetta, Homebrew and Nix,
# clone this repository, write the Mac's local/user.nix, save the settings it
# changes and switch to nix-darwin. Each step checks first, so running it again
# carries on where it stopped. On a new Mac, in Terminal:
#   curl -fsSL https://raw.githubusercontent.com/Furyfree/nix/main/darwin/bootstrap.sh | bash
# Written for macOS's own bash 3.2, which runs it there.
set -euo pipefail

repo=$HOME/Projects/nix
user_file=$repo/hosts/macos/local/user.nix
saved=${XDG_STATE_HOME:-$HOME/.local/state}/nix-workstation/macos-before
nix_bin=/nix/var/nix/profiles/default/bin

say() { printf '\n==> %s\n' "$*"; }
die() {
  printf 'bootstrap: %s\n' "$*" >&2
  exit 1
}

# Reports only; nothing here changes the Mac.
check() {
  local owner
  [[ $(uname -s) == Darwin && $(uname -m) == arm64 ]] || die 'this needs an Apple silicon Mac'
  ((EUID != 0)) || die 'run this as your own account, not as root'
  [[ " $(id -Gn) " == *" admin "* ]] || die 'your account must be an administrator'

  say 'This Mac, unchanged'
  printf 'FileVault:   %s\n' "$(fdesetup status | head -n 1)"
  printf 'SIP:         %s\n' "$(csrutil status)"
  printf 'Gatekeeper:  %s\n' "$(spctl --status 2>&1)"
  printf 'Firewall:    %s\n' "$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate)"
  printf 'Management:  %s\n' "$(profiles status -type enrollment 2>&1 | paste -sd ' ' -)"

  # nix-darwin runs Homebrew as this account.
  if [[ -e /opt/homebrew ]]; then
    owner=$(stat -f %Su /opt/homebrew)
    [[ $owner == "$(id -un)" ]] ||
      die "/opt/homebrew belongs to $owner; make this account its owner first"
  fi
}

# Official installers, downloaded first so a failed download stops here.
install_tools() {
  if ! xcode-select -p >/dev/null 2>&1; then
    say 'Installing the Command Line Tools; finish the window macOS opens'
    xcode-select --install || true
    until xcode-select -p >/dev/null 2>&1; do sleep 5; done
  fi

  if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
    say 'Installing Rosetta, for Intel apps'
    sudo softwareupdate --install-rosetta --agree-to-license
  fi

  if [[ ! -x /opt/homebrew/bin/brew ]]; then
    say 'Installing Homebrew'
    curl -fsSL -o "$tmp/homebrew.sh" https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
    # It asks for nothing when not interactive, so sudo must be fresh.
    sudo -v
    NONINTERACTIVE=1 /bin/bash "$tmp/homebrew.sh" </dev/null
  fi

  if [[ ! -x $nix_bin/nix ]]; then
    say 'Installing Nix'
    curl -fsSL -o "$tmp/nix.sh" https://nixos.org/nix/install
    sh "$tmp/nix.sh" --daemon --yes --no-channel-add </dev/null
  fi
}

# Over HTTPS: the SSH keys arrive later through 1Password.
clone() {
  [[ ! -e $repo ]] || return 0
  say "Cloning this repository to $repo"
  git clone https://github.com/Furyfree/nix.git "$repo"
}

write_user() {
  local profile='' profiles='^(personal|work)$'
  [[ ! -e $user_file ]] || return 0
  # Answers come from the terminal, since curl feeds this script on stdin.
  until [[ $profile =~ $profiles ]]; do
    read -rp 'Which Mac is this: personal or work? ' profile </dev/tty
  done
  mkdir -p "${user_file%/*}"
  printf '{\n  imports = [ ../../../darwin/%s.nix ];\n  system.primaryUser = "%s";\n}\n' \
    "$profile" "$(id -un)" >"$user_file"
  say "Wrote $user_file"
}

# Once, before the first switch; `defaults import DOMAIN FILE` restores one.
save_settings() {
  local domain
  [[ ! -d $saved ]] || return 0
  say "Saving the settings this repository changes to $saved"
  mkdir -p "$saved"
  # The domains darwin/settings.nix and shortcuts.nix write.
  for domain in NSGlobalDomain com.apple.finder com.apple.dock com.apple.spaces \
    com.apple.WindowManager com.apple.AppleMultitouchTrackpad \
    com.apple.driver.AppleBluetoothMultitouch.trackpad com.apple.desktopservices \
    com.apple.symbolichotkeys; do
    defaults export "$domain" "$saved/$domain.plist" 2>/dev/null ||
      printf '%s has no settings yet\n' "$domain"
  done
}

first_switch() {
  local file
  # nix-darwin replaces these with its own. It renames stock copies itself but
  # stops on those the Nix installer changed, so rename them as it would.
  for file in /etc/bashrc /etc/zshrc /etc/zshenv /etc/zprofile /etc/nix/nix.conf; do
    if [[ -f $file && ! -L $file ]]; then
      [[ ! -e $file.before-nix-darwin ]] ||
        die "$file.before-nix-darwin exists already; check it, remove it and run this again"
      say "Renaming $file to $file.before-nix-darwin"
      sudo mv -- "$file" "$file.before-nix-darwin"
    fi
  done

  say 'Switching to nix-darwin; Homebrew installs the apps, which takes a while'
  # nix-darwin as pinned in flake.lock.
  sudo -H env PATH="$nix_bin:$PATH" nix --extra-experimental-features 'nix-command flakes' \
    run --inputs-from "path:$repo" nix-darwin#darwin-rebuild -- switch --flake "path:$repo#macos"
}

main() {
  tmp=$(mktemp -d)
  trap 'rm -rf -- "$tmp"' EXIT

  check
  install_tools
  clone
  write_user
  save_settings
  if [[ -x /run/current-system/sw/bin/darwin-rebuild ]]; then
    say 'This Mac already runs nix-darwin; use nswitch from here on'
  else
    first_switch
  fi
  say 'Done. Log out and back in, then follow the macOS steps in ~/Projects/nix/INSTALLATION.md'
}

# Last, so a download cut short runs nothing.
main
