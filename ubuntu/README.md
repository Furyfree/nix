# Ubuntu work laptop

Ubuntu LTS with Home Manager for the terminal and app configs, and `apps.sh`
for the apps. The rest is the checklist below. IT owns the kernel and its own
agents; nothing here touches them.

## Install

1. Ubuntu Desktop 26.04, Default selection. In GNOME's terminal:
   `sudo apt install git curl`, then clone this repository over HTTPS to
   `~/Projects/nix`.
2. `ubuntu/debloat.sh` once, then reboot. It removes the snaps, telemetry and
   unused services, and stops before removing one of Ubuntu's base packages.
3. Nix, with flakes:

   ```bash
   curl -fsSL -o /tmp/nix.sh https://nixos.org/nix/install
   sh /tmp/nix.sh --daemon --yes --no-channel-add </dev/null
   echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf
   sudo systemctl restart nix-daemon
   ```

4. The account, in the ignored `ubuntu/local/user.nix`:

   ```nix
   { home.username = "alice"; home.homeDirectory = "/home/alice"; }
   ```

5. In a new terminal, Home Manager, then the apps:

   ```bash
   nix run nixpkgs#nh -- home switch --configuration ubuntu \
     --backup-extension before-home-manager path:$HOME/Projects/nix
   ~/Projects/nix/ubuntu/apps.sh
   ```

6. Log out and in again, for zsh and the `docker` and `kvm` groups. Then
   `mise install`, and 1Password, the work machine's SSH keys and `gh` as in
   [SSH keys](../README.md#ssh-keys).

After that, `git pull`, then `nswitch`: Home Manager first, then `apps.sh`
installs what is missing. NixOS updates `flake.lock`; apt updates the rest.

## By hand

- Updates: Ubuntu's own updater, as IT has set it.
- Auto-login, if wanted: Settings → System → Users.
- The Niri desktop: pick Niri at the login screen; GNOME stays there as the
  fallback. Its config is linked as on NixOS, with Ubuntu's differences in
  `configs/niri/hosts/ubuntu.kdl`.
