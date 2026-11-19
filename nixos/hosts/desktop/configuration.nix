# MSI Z690 desktop: Intel integrated graphics plus an NVIDIA RTX 3080, which
# drives the monitor. The installer writes ./local with the detected
# hardware and the chosen account; nswitch adds Windows to the boot menu.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../../default.nix
    ../../gaming.nix
    ../../local-ai.nix
    ../../dtu-eduroam.nix
    ../../secure-boot.nix
    # SSH server: uncomment while this host needs remote access.
    # ../../ssh.nix
    ./local/hardware-configuration.nix
  ];

  networking.hostName = "desktop";

  hardware = {
    # Intel integrated graphics: VA-API video encoding and decoding.
    graphics.extraPackages = [ pkgs.intel-media-driver ];
    # NVIDIA graphics with the open kernel modules, which NVIDIA recommends
    # from the RTX 20 series on. The module also adds the VA-API video driver.
    nvidia = {
      open = true;
      modesetting.enable = true;
      # Keep video memory across suspend and hibernation.
      powerManagement.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      # Its X11 settings app does little on Wayland.
      nvidiaSettings = false;
    };
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  nixpkgs = {
    # btop finds the driver's GPU library only when built with CUDA support.
    overlays = [ (_: prev: { btop = prev.btop.override { cudaSupport = true; }; }) ];
    config = {
      # The driver, and the CUDA parts btop and llama.cpp build on.
      allowUnfreePackages = [
        "nvidia-x11"
        "cccl"
        "cuda_crt"
        "cuda_cudart"
        "cuda_nvcc"
        "cuda_nvrtc"
        "libcublas"
        "libnvvm"
      ];
      # Local models on CUDA. Building for the RTX 3080 alone keeps the local
      # CUDA build short.
      cudaCapabilities = [ "8.6" ];
    };
  };

  # The RTX 3080 runs Whisper's recommended large model; others keep small.
  systemd.user.services.voxtype.scriptArgs = "large-v3-turbo";

  services.llama-cpp.package = pkgs.llama-cpp-cuda;

  # The monitor hangs on the NVIDIA card. With an Intel driver in the early
  # boot image, Plymouth binds the unused iGPU and the unlock prompt is
  # invisible; without one it draws on the firmware framebuffer. i915 and xe
  # still load after unlock.
  assertions = [
    {
      assertion =
        !lib.any (
          m:
          lib.elem m [
            "i915"
            "xe"
          ]
        ) (config.boot.initrd.kernelModules ++ config.boot.initrd.availableKernelModules);
      message = "desktop: keep i915 and xe out of the initrd so the unlock prompt shows on the NVIDIA monitor.";
    }
  ];

  system.stateVersion = "26.11";
}
