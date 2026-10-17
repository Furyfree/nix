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
   keys for Windows and firmware, then turn Secure Boot back on. `sbctl
   status` should show Setup Mode disabled and Secure Boot enabled. On the HP
   laptop, confirm the code that disables Sure Start Secure Boot Keys
   Protection, which otherwise restores HP's keys; HP then turns Secure Boot
   on by itself. Set a firmware administrator password afterwards.
2. `tailscale up` to join the tailnet.
3. `mise install` for the language runtimes and agent CLIs.
4. Dictation: `voxtype setup --download --model large-v3-turbo` on the desktop,
   `--model small` elsewhere, then `systemctl --user start voxtype`.
5. 1Password: sign in, then in Settings → Developer turn on the SSH agent and
   the CLI integration. Git signs commits with your SSH key from 1Password; set
   which one in a file outside the repo:
   `git config --file ~/.config/git/local user.signingkey "key::ssh-ed25519 ..."`
6. `op document get 3223bqk2tzqdut7gdhiqjyqj34 --out-file ~/.ssh/local.conf`
   for the homelab SSH hosts, and `gh auth login`. Switch this checkout to
   SSH, since the installer cloned it over HTTPS:
   `git -C ~/Projects/nix remote set-url origin git@github.com:Furyfree/nix.git`
7. `git clone git@github.com:Furyfree/wallpapers.git ~/Projects/wallpapers`,
   then `sudo systemctl restart home-manager-$USER.service` to link it into
   `~/Pictures/Wallpapers`; `nswitch` skips that when nothing else changed.
8. `git clone git@github.com:Furyfree/ai-workflow.git ~/Projects/ai-workflow`,
   then in it `nix develop -c just install` for agent rules and skills.
9. `dtu-eduroam <1Password item>` for DTU Wi-Fi; laptop: `fprintd-enroll`.

## Accounts and apps

Noctalia writes theme files when an app's config folder exists; after an app's
first start, run `noctalia msg templates-apply` once so its theme appears.

### Browser and web apps

- Brave: from the Chrome Web Store, install 1Password, Dark Reader,
  BookmarkHub and Unhook, and sign in to 1Password. In Settings: Use GTK and
  the system title bar, vertical tabs (expanded), a blank new-tab page, Ctrl+Tab
  through recently used tabs, no saving passwords, no history suggestions in
  the address bar, Do Not Track, no usage reports, no background apps, no
  graphics acceleration, and languages and spellcheck in English (UK) and
  Danish.
- ChatGPT, FotMob and Google Maps: open each web app once and sign in.

### AI

- Log in to `claude`, `codex`, `grok` and `agy`. In Claude Code and Codex,
  pick the Noctalia theme.
- OpenCode: `opencode auth login` for each AI provider. Pi: `/login` inside
  `pi` for each provider.
- Claude Desktop: sign in. T3 Code: add your providers in its settings.

### Everyday apps

- Signal: link it to your phone. Sign in to Spotify, Zed and Fastmail (your
  own account and the family one).
- Obsidian: open the vault and check its Noctalia snippet is enabled.
- LibreOffice: on Writer's first start, turn on "Enable application theming"
  in the welcome dialog.
- Vesktop: sign in, then Settings → Vencord → Themes → Local Themes → enable
  Noctalia Midnight.
- VSCodium: `codium-extensions` installs the extensions, including Noctalia's
  theme; then `noctalia msg templates-apply` and Developer: Reload Window. Zed
  and Zathura: restart after the first palette.
- Fastmail calendar, in Noctalia's settings: a CalDAV account with ID
  `fastmail`, your login and `https://caldav.fastmail.com/dav/`, and a
  calendar-only app password saved through its keyring option.
- Printer: the Epson ET-5800 shows up in print dialogs by itself. To keep it,
  add it at <http://localhost:631> → Administration → Add Printer with IPP
  Everywhere. Scan with Simple Scan.

### JetBrains

- Toolbox: sign in, install Rider (later GoLand, PyCharm, RustRover or CLion
  as needed). In Toolbox settings, under Tools turn off "Keep previous versions
  of tools to enable instant rollback", and under Plugins turn on plugin
  auto-update, which covers every IDE.
- In each IDE: sign in and turn on Settings Sync with your synced profile.

### Gaming (desktop)

- Steam: sign in. Settings → Interface: Start Up Location Library, and turn
  off "Notify me about additions or changes to my games". Steam has no
  Noctalia theme.
- ProtonPlus: Tools → Proton → Proton-CachyOS → install Latest. Then Steam
  Settings → Compatibility: make it the default, and restart Steam.
- Heroic: sign in. Settings → General → Custom Themes Path (the field under
  Select Theme, not Default Installation Path): `~/.config/heroic/themes`.
  Restart Heroic, then Select Theme → `matugen`.
- Lutris: add Battle.net (+ → search Lutris for Battle.net → install), sign
  in and install World of Warcraft; WowUp manages its addons.

### Projects and homelab

- Clone the repositories you work on into `~/Projects` (`gh repo list` shows
  them); `pull-projects` keeps them updated. Then run
  `noctalia msg templates-apply` again so Obsidian vaults among them get the
  Noctalia snippet.
- In each project, follow its README (`mise install`, `nix develop`,
  `uv sync` or similar) and run its checks.
- `ssh` to each host from `~/.ssh/local.conf` and check access and services.

## Check

- Suspend, hibernate (`systemctl hibernate`) and resume, then the boot menu.
- Monitors, workspaces and brightness (ddcutil on the desktop).
- Wi-Fi after boot, eduroam at DTU, AirPods with LibrePods.
- Printing and scanning on the Epson ET-5800.
- Desktop: Windows boots from the menu and its anti-cheat games run.
