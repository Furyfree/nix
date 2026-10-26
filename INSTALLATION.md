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
   the CLI integration.
6. SSH keys stay in 1Password; these public halves only tell SSH which key a
   host gets (GitHub, homelab or personal for everything else), and the
   document lists the homelab hosts:

   ```bash
   op item get n6imsp5vfs5nmlt5rmxgs6zdci --fields "label=public key" >~/.ssh/github.pub
   op item get 3ppqekfxnmjtg2iapnr5d7gewi --fields "label=public key" >~/.ssh/homelab.pub
   op item get 3psgdyql5u5zlpamsfc4xr7cbu --fields "label=public key" >~/.ssh/personal.pub
   op document get 3223bqk2tzqdut7gdhiqjyqj34 --out-file ~/.ssh/local.conf
   git config --file ~/.config/git/local user.signingkey ~/.ssh/github.pub
   ```

   Then `gh auth login`, and switch this checkout to SSH, since the installer
   cloned it over HTTPS:
   `git -C ~/Projects/nix remote set-url origin git@github.com:Furyfree/nix.git`
7. `git clone git@github.com:Furyfree/wallpapers.git ~/Projects/wallpapers`,
   then `sudo systemctl restart home-manager-$USER.service` to link it into
   `~/Pictures/Wallpapers`; `nswitch` skips that when nothing else changed.
8. `git clone git@github.com:Furyfree/ai-workflow.git ~/Projects/ai-workflow`,
   then in it `nix develop -c just install` for agent rules and skills.
9. `dtu-eduroam <1Password item>` for DTU Wi-Fi; laptop: `fprintd-enroll`.
10. Local models download on first use; fetch them now instead, one at a
    time, and follow `journalctl -fu llama-cpp` until each has loaded:
    `curl -d '{"model":"glm-4.7-flash"}' http://127.0.0.1:8080/models/load`,
    then `gpt-oss-20b` and `gemma-4-e4b`.

## Accounts and apps

Noctalia writes theme files when an app's config folder exists; after an app's
first start, run `noctalia msg templates-apply` once so its theme appears.
Noctalia downloads its plugins and theme templates only when it starts; if it
started before the network was up, bar plugins and app themes such as
Obsidian's are missing. Run `systemctl --user restart noctalia`, then
`noctalia msg templates-apply`.

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
  `pi` for each provider, and `/login llama.cpp` with the default URL for
  local models; `/llama` shows them.
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
- AirPods: pair them in Noctalia's Bluetooth panel. If LibrePods shows their
  battery but they are missing from the audio outputs, only the battery link
  is up. `bluetoothctl devices Connected` shows their address; then
  `bluetoothctl trust <address>` and `bluetoothctl connect <address>`. If that
  fails, `bluetoothctl remove <address>`, open the case, hold its button until
  the light flashes white, and pair them again.
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
