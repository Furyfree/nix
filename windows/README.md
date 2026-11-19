# Windows

Each Windows machine runs one profile from `profiles/`, and keeps its name in
the ignored `local/profile`: `basic`, apps
and settings for anyone with Ubuntu in WSL; `vm`, my apps and configs for a VM
on Linux, which has no WSL2; or `desktop`, vm with games and the hardware
settings. Every profile clones this repository to `~\Projects\nix`.

## Set up Windows

`apply.ps1` renames each file it replaces to `*.before-nix-workstation`, and
stops if that backup already exists. It removes a link it made once the profile
no longer has it. Before it first imports a registry key,
it saves the old values to `%LOCALAPPDATA%\nix-workstation\backup\`; restore
one with `reg import FILE`.

1. Install Windows, from the Win11 Creator ISO when you have it; without it,
   the bootstrap runs WinUtil's Standard tweaks. On the desktop, unplug the
   NixOS disk while Windows installs; otherwise Setup puts Windows' boot files
   on the NixOS EFI partition instead of making its own. Then update Windows
   and name the PC (System → About) before the bootstrap; the BitLocker key
   file in step 4 carries the name.
2. In Windows PowerShell, as yourself:

   ```powershell
   irm https://raw.githubusercontent.com/Furyfree/nix/main/windows/bootstrap.ps1 | iex
   ```

   It asks for the profile and for administrator twice: for sudo, Git and
   PowerShell 7, then for the apps, settings and WSL. After an error, run it
   again; it carries on. When it installed WSL, restart Windows and run
   `~\Projects\nix\windows\apply.ps1` in PowerShell 7. The desktop's taskbar
   pins appear at the next sign-in.
3. vm and desktop: sign in to 1Password, then in Settings → Developer turn on
   the SSH agent, and in Settings → Security unlock with Windows Hello, so
   `op`, SSH and Git signing ask for the Windows PIN instead of the account
   password; Windows Hello needs a PIN from Settings → Accounts → Sign-in
   options. In PowerShell 7, fetch the SSH files into `~\.ssh` as in
   [SSH keys](../README.md#ssh-keys), run `gh auth login` and switch the
   checkout to SSH.
4. Desktop: store the BitLocker recovery key from
   `~\bitlocker-recovery-<computer>.txt` in 1Password from another device.

## By hand

- Desktop: the Riot Client, which has no winget package, from a game's
  installer at <https://www.riotgames.com/>; it then installs League of
  Legends and VALORANT itself.
- Desktop: point each game launcher's install folder at the games disk before
  its first game.
- Desktop: after World of Warcraft's first login, clone
  `git@github.com:Furyfree/wow-ui.git` to `~\Projects\wow-ui` and set it up as
  its README says, so addon settings and keybindings follow you between
  computers; WowUp installs the addons.
- Sign-ins: Microsoft 365 and Brave Origin's licence; on the desktop also Steam,
  Battle.net, Ubisoft Connect, Epic, Riot, Discord and the NVIDIA App.
- Settings, which Windows keeps out of reach of a `.reg` file: the PC's
  nearby-sharing name (System → Nearby sharing); Brave Origin as the default
  browser and PDF reader (Apps → Default apps); on the desktop, the monitor at
  its highest refresh rate (System → Display → Advanced display).
- The wallpaper: put `charcoal-amber-mountain-horizon.jpg` in
  `~\Pictures\Wallpapers`; the next `nswitch` sets it for the desktop and the
  lock screen.
