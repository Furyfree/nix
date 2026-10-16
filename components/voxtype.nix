# Local dictation for Super+D: Whisper on the GPU through Vulkan, as on Fedora.
# Download the host's model once with
#   voxtype setup --download --model <model>
{ lib, pkgs, ... }:

let
  voxtype = pkgs.voxtype.override { vulkanSupport = true; };
in
{
  # Its wrapper brings wtype and wl-clipboard for typing the text.
  environment.systemPackages = [ voxtype ];

  systemd.user.services.voxtype = {
    description = "Voxtype dictation daemon";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    # The daemon fails and retries without a model; wait until one exists.
    unitConfig.ConditionPathExistsGlob = "%h/.local/share/voxtype/models/*";
    # Hosts with a stronger GPU choose a larger model.
    scriptArgs = lib.mkDefault "small";
    script = ''exec ${lib.getExe voxtype} --model "$1" daemon'';
    serviceConfig.Restart = "on-failure";
  };
}
