# Ubuntu work laptop

Ubuntu LTS with Home Manager for the terminal and app configs, and `apps.sh`
for the apps. The rest is the checklist below. IT owns the kernel and its own
agents; nothing here touches them.

## Install

1. Ubuntu Desktop 26.04, Default selection. In GNOME's terminal:

   ```bash
   wget -qO- https://raw.githubusercontent.com/Furyfree/nix/main/ubuntu/bootstrap.sh | bash
   ```

   It installs Git and curl, clones this repository over HTTPS to
   `~/Projects/nix`, runs `debloat.sh` once, installs Nix with flakes, writes
   the ignored `ubuntu/local/user.nix` with your account, switches Home Manager
   and runs `apps.sh`. `debloat.sh` removes the snaps, telemetry and unused
   services, and stops before removing one of Ubuntu's base packages. After an
   error, run it again; it carries on. To try a branch before it is merged:

   ```bash
   wget -qO- https://raw.githubusercontent.com/Furyfree/nix/BRANCH/ubuntu/bootstrap.sh | bash -s -- BRANCH
   ```
2. Reboot, for the debloat, zsh and the `windows-vm` and `kvm` groups. Then
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
