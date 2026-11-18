# Ubuntu work laptop (investigation)

Investigation scripts for the Ubuntu 26.04 work laptop in
[#28](https://github.com/Furyfree/nix/issues/28). They record what was tested
in a VM and will become `ubuntu/bootstrap.sh`; they are not a supported setup
yet, and they don't set up Nix or Home Manager.

On a fresh Ubuntu 26.04 Desktop installed with the Default selection, clone
this repository (`sudo apt install git`), then run from a terminal in the
GNOME session:

1. `ubuntu/debloat.sh`, then reboot.
2. `ubuntu/layers.sh`.

- `debloat.sh` removes the snaps and snapd, telemetry, install-time packages
  and unused services, keeps snapd out with an apt pin, and stops if a removal
  would take Ubuntu's base metapackages with it. Its steps were tested one by
  one; it hasn't run as one script yet.
- `layers.sh` adds the makers' apt repos and the Niri and OBS PPAs with
  fingerprint-checked keys and pins, installs the apps, the Flatpaks and the
  T3 Code, JetBrains Toolbox and Zed downloads, holds Niri and Noctalia, and
  adds you to the `docker` and `kvm` groups. It ran end to end in the VM.
