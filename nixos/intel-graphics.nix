# Intel integrated graphics: VA-API video encoding and decoding (Broadwell and newer).
{ pkgs, ... }:

{
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
}
