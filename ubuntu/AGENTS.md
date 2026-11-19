# Ubuntu

The work laptop: Home Manager for the terminal and app configs, apt and Flatpak
for the apps, and a checklist for the rest. The root `AGENTS.md` holds the
rules that must not break.

## Map

- `home.nix`: Home Manager on its own (`homeConfigurations.ubuntu`), on top of
  `../home-manager/`'s `common.nix`, `linux.nix` and `niri.nix`; the ignored
  `local/user.nix` names the account. Ubuntu's Niri differences, such as apt's
  command names, go in `../configs/niri/hosts/ubuntu.kdl`.
- `apps.sh`: the app list, which `nswitch` runs after Home Manager. It installs
  only what is missing, must-haves first; a nice-to-have that fails is
  reported and skipped. A new app goes in the part its setup needs.
- `debloat.sh`: run once on a fresh install.

## Verify

`just eval-local` evaluates the Home Manager output, and `shellcheck` the
scripts. Run them in a disposable Ubuntu VM, never on a Linux machine of mine.
