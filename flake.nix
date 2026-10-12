{
  description = "NixOS and Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      host = ./hosts/nixos-test;
      localHardware = host + "/local/hardware-configuration.nix";
      localInstallation = host + "/local/installation.nix";
      hasLocal = builtins.pathExists localHardware || builtins.pathExists localInstallation;
      installation =
        if builtins.pathExists localHardware && builtins.pathExists localInstallation then
          localInstallation
        else
          throw "Incomplete hosts/nixos-test/local: hardware-configuration.nix and installation.nix are both required.";
    in
    {
      devShells.x86_64-linux.default =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.mkShellNoCC {
          UV_PYTHON = "${pkgs.python3}/bin/python3";
          UV_PYTHON_DOWNLOADS = "never";
          packages = with pkgs; [
            python3
            uv
            just
            basedpyright
            lua5_5
            hyprland
            nixfmt
            statix
            deadnix
            caligula
            util-linux
            openssh
          ];
        };

      nixosConfigurations = {
        installer = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit self; };
          modules = [ ./hosts/installer/configuration.nix ];
        };
      }
      // nixpkgs.lib.optionalAttrs hasLocal {
        nixos-test = builtins.seq installation (
          nixpkgs.lib.nixosSystem {
            modules = [
              ./hosts/nixos-test/configuration.nix
              home-manager.nixosModules.home-manager
              installation
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
              }
            ];
          }
        );
      };
    };
}
