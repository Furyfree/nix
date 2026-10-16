# NVIDIA graphics with the open kernel modules, which NVIDIA recommends from
# the RTX 20 series on. The module also adds the VA-API video driver.
{ config, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    # Keep video memory across suspend and hibernation.
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # Its X11 settings app does little on Wayland; Fedora hid it too.
    nvidiaSettings = false;
  };
}
