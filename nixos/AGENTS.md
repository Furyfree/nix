# NixOS

The desktop and the laptop, whole: system, desktop and apps. The root
`AGENTS.md` holds the rules that must not break.

## Map

- `default.nix`: what every NixOS machine imports; a new topic module goes
  here.
- `*.nix` beside it: one topic each, or a purpose some hosts import
  (`gaming`, `local-ai`, `dtu-eduroam`, `secure-boot`, `ssh`). Hyprland's
  module holds its Home Manager half; Niri's is `../home-manager/niri.nix`,
  which Ubuntu shares. `limine-windows.nix` comes in when
  `nswitch` finds Windows in the firmware.
- `home.nix`: Home Manager only NixOS has, on top of `../home-manager/`'s
  `common.nix` and `linux.nix`.
- `hosts/<host>/`: each machine's own lines. The installer writes its ignored
  `local/` with the detected hardware, the account and swap; an optional
  `local/desktop.nix` picks the compositor, and an empty `local/limine-windows`
  adds Windows to the boot menu.
- `installer/`: the ISO (`configuration.nix`), the launcher `install.py`, its
  `nixos_setup/` modules and their tests, one file per module. It clones
  `main` from GitHub, so a layout change installs only once it is merged.
- `pins/`: apps from outside nixpkgs; `nvfetcher.toml` says where each comes
  from, and nvfetcher writes `_sources/`, which the modules read.

## Verify

`just check` from the root, and `nh os build` for a host, never activated.
Installation, login, sleep/resume and rollback need the machine.
