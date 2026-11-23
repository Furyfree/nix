# Windows

One PowerShell profile per machine, `vm` or `desktop`, through
winget, Mise and `.reg` files. The root `AGENTS.md` holds the rules that must
not break.

## Map

- `bootstrap.ps1`: prepares a fresh Windows, clones the checkout and writes the
  ignored `local/profile` with the profile's name.
- `apply.ps1`: `nswitch`; applies the profile's layers from `profiles/`, whose
  keys `common.psd1` lists, with the settings in `registry/`.
- `profiles/`: `desktop` takes `vm` and `gaming` and adds the apps I use every
  day and NixOS in WSL (`../nixos/hosts/wsl/`). An app or setting goes in the
  layer that needs it.
- `../configs/windows/`: the PowerShell, Terminal, WSL, VS Code, fastfetch,
  Office and taskbar files.

## Verify

`just check-powershell` parses the scripts and profiles. Windows changes need
Windows: the VM from `windows-vm`, which has no WSL2, or the desktop.
