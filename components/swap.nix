{ sizeGiB }:
{ ... }:

{
  swapDevices = [
    {
      device = "/var/swap/swapfile";
      size = sizeGiB * 1024;
    }
  ];

  # Set boot.resumeDevice and resume_offset in the host after creating the file.
  # Get the offset with: btrfs inspect-internal map-swapfile -r /var/swap/swapfile
}
