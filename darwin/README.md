# macOS

Every Mac uses the nix-darwin host `macos`. Its ignored `darwin/local/user.nix`
names the account and imports the Mac's profile, `personal.nix` or `work.nix`:

```nix
{ imports = [ ../personal.nix ]; system.primaryUser = "alice"; }
```

## Set up a Mac

The switch renames each file it replaces to `*.before-home-manager`, and
stops if that backup already exists.

1. In Setup Assistant, create your administrator account and turn on
   FileVault; store its recovery key in 1Password from another device. Then
   update macOS.
2. In Terminal:

   ```sh
   curl -fsSL \
     https://raw.githubusercontent.com/Furyfree/nix/main/darwin/bootstrap.sh | bash
   ```

   It installs what the Mac needs, asks which Mac this is and switches. It
   saves the settings it changes to
   `~/.local/state/nix-workstation/macos-before/`; restore one with
   `defaults import DOMAIN FILE`. After an error, run it again; it carries on.
3. Log out and back in, for the settings that wait for it.
4. 1Password, the SSH keys and `gh`, as in [SSH keys](../README.md#ssh-keys).
5. In a new terminal, `mise install`.
6. `git clone git@github.com:Furyfree/ai-workflow.git ~/Projects/ai-workflow`,
   then install it as its README says, with `python3 install.py`: its
   development shell is Linux-only.

## By hand

Every Mac:

- Battery: System Settings → Battery, ⓘ beside Charging: charge limit 80 %,
  Optimized Battery Charging off.
- App Management for Terminal.app only, for `brew upgrade`.
- Sign-ins: Microsoft 365, Spotify, Signal, ChatGPT, Claude, JetBrains and
  Brave Origin's licence.
- Permissions: Accessibility and Menu Bar Layout Access for Thaw,
  Accessibility for Tinycast, Screen Recording for OBS and Calendars for
  Itsycal.
- Tinycast: start at login, then Settings → Backup → Settings File: turn on
  **Sync settings file**. When asked **Import the existing settings file?**,
  choose **Import** to apply `~/.config/tinycast/settings.json`, which `nswitch`
  merges the repository's settings into.
  **Replace** overwrites that file with Tinycast's current settings.
- Spaces: in Mission Control (Hyper+M), add desktops until each display has
  five, for Hyper+1–5.
- Thaw: start at login; show Wi-Fi, battery, Itsycal and Control Center, and
  hide the other icons and the clock.
- Vorssaint and Itsycal: quit and reopen them after a switch to load their
  settings. Choose the calendars Itsycal shows and enable its launch at login.
- JetBrains Toolbox autostart off, Spotify's login item off, Brave Origin as
  the default browser, and Finder's sidebar favourites.

Personal Mac: Discord's sign-in, Screen Recording and keyboard access for
push-to-talk; Tailscale's network extension, VPN configuration and sign-in.
CodexBar: quit and reopen after a switch; its Keychain prompts, OpenRouter
key and launch at login are configured by hand.

Work Mac: work apps from your own notes, the work Git identity in
`~/.config/git/local`, and the work accounts.
