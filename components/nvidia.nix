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
    # Its X11 settings app does little on Wayland.
    nvidiaSettings = false;
  };

  # btop finds the driver's GPU library only when built with CUDA support.
  nixpkgs.overlays = [ (_: prev: { btop = prev.btop.override { cudaSupport = true; }; }) ];

  # The driver, and the CUDA parts btop and the desktop's llama.cpp build on.
  nixpkgs.config.allowUnfreePackages = [
    "nvidia-x11"
    "cccl"
    "cuda_crt"
    "cuda_cudart"
    "cuda_nvcc"
    "cuda_nvrtc"
    "libcublas"
    "libnvvm"
  ];
}
