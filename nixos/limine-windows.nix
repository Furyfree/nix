# Windows in Limine's menu. flake.nix adds this to a host once its firmware
# lists Windows Boot Manager, which nix-workstation switch marks with an empty
# nixos/hosts/<host>/local/limine-windows. Picking the entry restarts into that
# firmware entry instead of starting Windows from Limine: BitLocker then sees
# its usual boot chain and asks for no recovery key, and no disk ID is needed.
{
  boot.loader.limine.extraEntries = ''
    /Windows
      protocol: efi_boot_entry
      entry: Windows Boot Manager
  '';
}
