# Installation

The installer erases the whole disk you choose. On the desktop, Windows stays
on its own disk and gets an entry in the boot menu.

## Before you start

1. Back up anything that is not in Git or the cloud.
2. Desktop only: in Windows, suspend BitLocker so it does not ask for the
   recovery key when Secure Boot changes. In an admin terminal:
   `manage-bde -protectors -disable C: -RebootCount 3`
3. Build and write the USB stick from a checkout of this repository:
   `just build-iso`, then `just burn`.

## Install

1. In the firmware settings, turn Secure Boot off; the installer is not signed.
2. Boot the USB stick. The installer starts on the screen by itself and needs
   the internet. On Wi-Fi, press Ctrl+C, run `systemctl start wpa_supplicant`,
   connect with `wpa_cli` (`add_network`, `set_network 0 ssid "name"`,
   `set_network 0 psk "password"`, `enable_network 0`), then run `nixos-setup`.
3. Choose the machine, the disk and your username. The review shows the swap
   size and, on the desktop, the Windows partition it found.
4. Enter one password for disk encryption, root and your user, type the disk's
   full path to confirm, and wait. Reboot when it finishes.

## First boot

1. Secure Boot: in the firmware settings, clear the Secure Boot keys (Setup
   Mode). In NixOS run `sudo sbctl enroll-keys -m`, which keeps Microsoft's
   keys for Windows and firmware. Turn Secure Boot back on.
2. `mise install` for the language runtimes and agent CLIs.
3. Dictation: `voxtype setup --download --model large-v3-turbo` on the desktop,
   `--model small` elsewhere, then `systemctl --user start voxtype`.
4. 1Password: sign in, then in Settings → Developer turn on the SSH agent and
   the CLI integration.
5. `op document get 3223bqk2tzqdut7gdhiqjyqj34 --out-file ~/.ssh/local.conf`
   for the homelab SSH hosts, and `gh auth login`.
6. `git clone git@github.com:Furyfree/wallpapers.git ~/Projects/wallpapers`,
   then `nswitch` to link it into `~/Pictures/Wallpapers`.
7. `git clone git@github.com:Furyfree/ai-workflow.git ~/Projects/ai-workflow`,
   then in it `nix develop -c just install` for agent rules and skills.
8. `dtu-eduroam <1Password item>` for DTU Wi-Fi; laptop: `fprintd-enroll`.
9. Desktop: install Battle.net in Lutris.

## Check

- Suspend, hibernate (`systemctl hibernate`) and resume, then the boot menu.
- Monitors, workspaces and brightness (ddcutil on the desktop).
- Wi-Fi after boot, eduroam at DTU, AirPods with LibrePods.
- Printing and scanning on the Epson ET-5800.
- Desktop: Windows boots from the menu and its anti-cheat games run.
