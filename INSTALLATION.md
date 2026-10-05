# NixOS installation

Install a disposable test machine with encrypted Btrfs and manual passphrase
entry at boot. This machine has no TPM. Follow the
[NixOS manual installation process](https://nixos.org/manual/nixos/stable/#sec-installation-manual).

## 1. Boot the installer

1. Download the NixOS Minimal ISO image.
2. Flash the ISO to the USB using `caligula burn [TARGET]`.
3. Boot from the USB. On this ISO, choose the **second option, not the LTS
   option**: `NixOS 26.05 … Installer (Linux 7.2.8)`.
4. Connect to the installer over SSH:

```sh
ssh nixos@192.0.2.10
```

Run the remaining installation commands in this SSH session. Run each command
separately and stop on any error.

## 2. Identify the target disk

```sh
lsblk -e 7 -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
```

The target is `/dev/nvme0n1`, the 476.9 GiB Samsung internal SSD. The installer
USB is `/dev/sda`, the 114.6 GiB SanDisk; leave it alone. The commands below erase
the entire internal SSD. Check these device names before reusing this guide.

The SSD previously contained Proxmox's `pve` volume group. Deactivate it before
wiping, so Linux releases its mapped volumes:

```sh
sudo /run/current-system/sw/bin/vgchange -an pve
lsblk -e 7 -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
```

Continue after the `pve-root` and `pve-swap` devices disappear. Skip this step on
a disk without that volume group.

## 3. Wipe and partition the SSD

Remove the signatures from the old three partitions and the disk:

```sh
sudo /run/current-system/sw/bin/wipefs --all \
  /dev/nvme0n1p1 /dev/nvme0n1p2 /dev/nvme0n1p3 /dev/nvme0n1
```

Create a GPT partition table, a 1 GiB EFI partition and an encrypted-system
partition using the remaining space:

```sh
sudo /run/current-system/sw/bin/parted --script /dev/nvme0n1 \
  mklabel gpt \
  mkpart ESP fat32 1MiB 1025MiB \
  set 1 esp on \
  mkpart cryptroot 1025MiB 100%

lsblk -e 7 -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL,MOUNTPOINTS
```

Check for `nvme0n1p1` labelled `ESP` and `nvme0n1p2` labelled `cryptroot`.

## 4. Format and encrypt

```sh
sudo /run/current-system/sw/bin/mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1

sudo /run/current-system/sw/bin/cryptsetup luksFormat --type luks2 /dev/nvme0n1p2
```

Type `YES` at the confirmation and enter the disk passphrase twice. Keep it
outside this repository.

```sh
sudo /run/current-system/sw/bin/cryptsetup open /dev/nvme0n1p2 cryptroot

sudo /run/current-system/sw/bin/mkfs.btrfs -L nixos /dev/mapper/cryptroot

lsblk -e 7 -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS
```

Check for FAT32 `BOOT` on partition 1, LUKS on partition 2, and Btrfs `nixos`
inside `/dev/mapper/cryptroot`.

## 5. Create Btrfs subvolumes

Mount the top-level Btrfs filesystem:

```sh
sudo /run/current-system/sw/bin/mkdir -p /mnt

sudo /run/wrappers/bin/mount -o subvolid=5 /dev/mapper/cryptroot /mnt

sudo /run/current-system/sw/bin/btrfs subvolume create \
  /mnt/root /mnt/home /mnt/snapshots \
  /mnt/log /mnt/cache /mnt/swapfile \
  /mnt/flatpak /mnt/docker /mnt/containerd

sudo /run/current-system/sw/bin/chmod 0700 /mnt/snapshots

sudo /run/current-system/sw/bin/btrfs subvolume list /mnt
```

Check for all nine subvolumes. This follows the separation in `fedora-iso`.
Keep `/nix` inside `root`, so root snapshots include the Nix store and its
database. Leave `/var/swap` empty until swap is needed. Choose Windows VM
storage when configuring that optional profile.

## 6. Mount the installation layout

```sh
sudo /run/wrappers/bin/umount /mnt

sudo /run/wrappers/bin/mount -o subvol=root,compress=zstd /dev/mapper/cryptroot /mnt

sudo /run/current-system/sw/bin/mkdir -p \
  /mnt/boot /mnt/home /mnt/.snapshots \
  /mnt/var/log /mnt/var/cache /mnt/var/swap \
  /mnt/var/lib/flatpak /mnt/var/lib/docker /mnt/var/lib/containerd

sudo /run/wrappers/bin/mount -o subvol=home,compress=zstd /dev/mapper/cryptroot /mnt/home

sudo /run/wrappers/bin/mount -o subvol=snapshots,compress=zstd /dev/mapper/cryptroot /mnt/.snapshots

sudo /run/wrappers/bin/mount -o subvol=log,compress=zstd /dev/mapper/cryptroot /mnt/var/log

sudo /run/wrappers/bin/mount -o subvol=cache,compress=zstd /dev/mapper/cryptroot /mnt/var/cache

sudo /run/wrappers/bin/mount -o subvol=swapfile,compress=zstd /dev/mapper/cryptroot /mnt/var/swap

sudo /run/wrappers/bin/mount -o subvol=flatpak,compress=zstd /dev/mapper/cryptroot /mnt/var/lib/flatpak

sudo /run/wrappers/bin/mount -o subvol=docker,compress=zstd /dev/mapper/cryptroot /mnt/var/lib/docker

sudo /run/wrappers/bin/mount -o subvol=containerd,compress=zstd /dev/mapper/cryptroot /mnt/var/lib/containerd

sudo /run/wrappers/bin/mount -o umask=077 /dev/nvme0n1p1 /mnt/boot

findmnt -R /mnt -o TARGET,SOURCE,FSTYPE,OPTIONS
```

Check that each Btrfs mount uses its intended subvolume and `compress=zstd:3`.
The EFI partition belongs at `/mnt/boot`.

## 7. Generate and edit the configuration

```sh
sudo /run/current-system/sw/bin/nixos-generate-config --root /mnt

cat /mnt/etc/nixos/hardware-configuration.nix
cat /mnt/etc/nixos/configuration.nix
```

Check that the hardware configuration contains all mounts and
`boot.initrd.luks.devices."cryptroot".device`, pointing to partition 2's UUID.
Keep the generated hardware configuration.

Read the installer's authorized public keys, then edit the system configuration:

```sh
cat /home/nixos/.ssh/authorized_keys
sudo nano /mnt/etc/nixos/configuration.nix
```

Make the active configuration match the following. Replace the key placeholder
with the complete public key line; use one quoted line per key if there are
several. The existing template comments can stay.

```nix
{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos-test";
  networking.networkmanager.enable = true;

  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      "PASTE THE COMPLETE PUBLIC KEY LINE HERE"
    ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  fileSystems."/".options = [ "compress=zstd" ];

  system.stateVersion = "26.05";
}
```

Keep each setting once. Save with **Ctrl+O**, **Enter**, then exit with
**Ctrl+X**. Review the file:

```sh
cat /mnt/etc/nixos/configuration.nix
```

The generator omitted compression from the hardware configuration. The root
mount setting above preserves it after reboot. Btrfs applies compression across
this filesystem.

## 8. Install NixOS

```sh
sudo /run/current-system/sw/bin/nixos-install
```

Set the root password when prompted. Wait for `installation finished!`.

## 9. Set the user password and reboot

Set `user`'s password for local login and `sudo`:

```sh
sudo /run/current-system/sw/bin/nixos-enter --root /mnt -c 'passwd user'
```

After the password update succeeds:

```sh
sudo /run/current-system/sw/bin/reboot
```

Remove the USB while restarting. Enter the disk passphrase at the machine when
prompted. There is no automatic unlock.

## 10. Reconnect and check the first boot

From your own computer:

```sh
ssh user@192.0.2.10
```

On the installed system:

```sh
whoami
hostname
uname -r
findmnt -t btrfs,vfat -o TARGET,SOURCE,FSTYPE
findmnt -no OPTIONS /
systemctl --failed
```

Check for user `user`, hostname `nixos-test`, the nine Btrfs mounts with Zstd
compression, and the EFI partition at `/boot`.

## 11. Configure and test Snapper

Edit `/etc/nixos/configuration.nix` and add Nimbus's root snapshot policy inside
the outer braces:

```sh
sudo nano /etc/nixos/configuration.nix
```

```nix
services.snapper.configs.root = {
  SUBVOLUME = "/";
  FSTYPE = "btrfs";
  SYNC_ACL = false;
  BACKGROUND_COMPARISON = false;
  NUMBER_CLEANUP = true;
  NUMBER_MIN_AGE = 0;
  NUMBER_LIMIT = 6;
  NUMBER_LIMIT_IMPORTANT = 0;
  TIMELINE_CREATE = false;
  TIMELINE_CLEANUP = false;
  EMPTY_PRE_POST_CLEANUP = false;
};
```

Save and apply:

```sh
sudo nixos-rebuild switch
sudo snapper -c root get-config
```

The [NixOS Snapper module](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/services/misc/snapper.nix)
supplies Snapper and a daily cleanup timer. Cleanup retains up to six numbered
snapshots. NixOS omits default-valued fields from the generated config; hourly
snapshot creation remains disabled even though the timeline timer runs.

Create a baseline snapshot:

```sh
sudo snapper -c root create \
  --description "Initial NixOS baseline" \
  --cleanup-algorithm number \
  --print-number

sudo snapper -c root list
systemctl list-timers 'snapper-*' --no-pager
```

Use [Snapper's built-in command](https://snapper.io/manpages/snapper.html) to take
snapshots before and after a rebuild:

```sh
sudo snapper -c root create \
  --description "nixos-rebuild switch" \
  --cleanup-algorithm number \
  --command "nixos-rebuild switch"

sudo snapper -c root list
```

Check for a `pre` snapshot and a `post` snapshot whose `Pre #` points to it.
Both should use the `number` cleanup algorithm.

Check that the post snapshot contains the running NixOS system and its Nix
database. Replace `3` with the post snapshot's number if different:

```sh
sudo ls -ld "/.snapshots/3/snapshot$(readlink -f /run/current-system)"
sudo ls -l /.snapshots/3/snapshot/nix/var/nix/db/db.sqlite
```

Test restoration before relying on snapshots for recovery. `/boot`, `/home`,
and the other mounted sibling subvolumes have their own state outside root
snapshots.

## 12. Build the repo configuration

The flake pins `nixos-unstable` and integrated Home Manager in `flake.lock`.
It keeps both state-version settings at `26.05`. The disk UUIDs and public SSH
key in `hosts/nixos-test/` belong to this machine.

From the repo on your own computer, generate or verify the input lock and check
the flake without building the system:

```sh
cd ~/Projects/nix
nix --extra-experimental-features 'nix-command flakes' flake lock path:/home/user/Projects/nix
nix --extra-experimental-features 'nix-command flakes' flake check --no-build --no-write-lock-file path:/home/user/Projects/nix
```

From the repo on your own computer, copy the configuration to the test machine:

```sh
cd ~/Projects/nix
ssh user@192.0.2.10 'mkdir -p /home/user/Projects/nix'
scp -r flake.nix flake.lock system.nix home.nix hosts components configs user@192.0.2.10:/home/user/Projects/nix/
```

In the SSH session on the test machine, build without activating:

```sh
cd ~/Projects/nix
sudo nixos-rebuild build --flake path:/home/user/Projects/nix#nixos-test
```

## 13. Activate the repo configuration

Continue only after the build succeeds. For the first upgrade from 26.05, use
`--no-reexec` to keep the installed rebuild tool. The newer tool requests
`systemd-run --output=cat`, which the old systemd does not support.

Activate with pre/post root snapshots:

```sh
sudo snapper -c root create \
  --description "nixos-test flake rebuild" \
  --cleanup-algorithm number \
  --command "nixos-rebuild switch --no-reexec --flake path:/home/user/Projects/nix#nixos-test"
```

For later rebuilds, omit `--no-reexec` and keep the explicit `--flake` path.
A plain `nixos-rebuild switch` still reads the bootstrap configuration in
`/etc/nixos`. The explicit `path:` also includes new files that Git does not
track yet.

After activation:

```sh
nixos-version
sudo snapper -c root list
systemctl status home-manager-user.service --no-pager
systemctl --failed
```

Reboot, unlock the disk at the machine, reconnect as `user`, and repeat the
first-boot checks.

## 14. Roll back a generation and return to the flake

List the generations and identify the previous configuration:

```sh
sudo nix-env --list-generations -p /nix/var/nix/profiles/system
readlink -f /nix/var/nix/profiles/system-2-link
```

For this installation, generation 2 contains `26.05.11006.4feb8eb8bf30` with
Snapper. Generation 3 contains the flake system `26.11.20261001.c59305b`.

Select the previous generation for the next boot:

```sh
sudo nixos-rebuild boot --rollback --no-reexec
sudo reboot
```

Unlock LUKS at the console, reconnect as `user`, and check:

```sh
nixos-version
findmnt -no OPTIONS /
systemctl --failed
```

We booted into 26.05 with `compress=zstd:3` and no failed units.

Return to the flake with pre/post snapshots:

```sh
sudo snapper -c root create \
  --description "Return to nixos-test flake" \
  --cleanup-algorithm number \
  --command "nixos-rebuild switch --no-reexec --flake path:/home/user/Projects/nix#nixos-test"

sudo reboot
```

After unlocking and reconnecting:

```sh
nixos-version
systemctl is-active home-manager-user.service
systemctl --failed
```

We booted back into 26.11 with Home Manager active and no failed units.
Generation rollback restores the system configuration; it does not restore
mutable files from a Btrfs snapshot.

## 15. Deferred snapshot restoration

We prepared a file recovery test:

```sh
printf 'before restore\n' | sudo tee /etc/btrfs-restore-test
printf 'before restore\n' > /home/user/btrfs-restore-test

sudo snapper -c root create \
  --description "Btrfs restore test baseline" \
  --print-number
```

Snapper returned snapshot 10. We assigned no cleanup algorithm to this
snapshot, so automatic cleanup does not remove it.

We changed both files and checked the snapshot:

```sh
printf 'after restore\n' | sudo tee /etc/btrfs-restore-test
printf 'after restore\n' > /home/user/btrfs-restore-test

sudo cat /.snapshots/10/snapshot/etc/btrfs-restore-test
cat /etc/btrfs-restore-test /home/user/btrfs-restore-test
```

The snapshot contained `before restore`; both current files contained
`after restore`. We deferred restoration at this point and continued with
system configuration.

To resume file recovery later, delete only the test file and copy it back:

```sh
sudo rm /etc/btrfs-restore-test
sudo cp -a \
  /.snapshots/10/snapshot/etc/btrfs-restore-test \
  /etc/btrfs-restore-test

cat /etc/btrfs-restore-test /home/user/btrfs-restore-test
```

Expect `before restore` for `/etc` and `after restore` for `/home/user`.
We have not run these recovery commands. Restoring the entire root also
remains deferred: boot the installer USB as a recovery system, preserve the
current `root`, create a writable copy of the chosen snapshot named `root`,
and update the boot menu from the restored installation before rebooting.
The USB recovery process does not require reinstalling or formatting.
