# MSI Z690 desktop: Intel integrated graphics plus an NVIDIA RTX 3080, which
# drives both monitors. The installer writes ./local with the detected
# hardware, the chosen account and the Windows boot entry.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../../system.nix
    ../../components/intel-graphics.nix
    ../../components/nvidia.nix
    ../../components/craft-suite.nix
    ../../components/gaming.nix
    ../../components/dtu-eduroam.nix
    ../../components/secure-boot.nix
    ./local/hardware-configuration.nix
  ];

  networking.hostName = "desktop";

  environment.systemPackages = [ pkgs.gimp ];

  # The RTX 3080 runs Whisper's recommended large model; others keep small.
  systemd.user.services.voxtype.scriptArgs = "large-v3-turbo";

  # Both monitors hang on the NVIDIA card. With an Intel driver in the early
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
