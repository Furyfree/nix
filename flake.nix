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
      # A host builds only from its ignored local/ data, which the installer
      # writes; without it, the host has no output.
      mkHost =
        name:
        let
          host = ./hosts + "/${name}";
          localHardware = host + "/local/hardware-configuration.nix";
          localInstallation = host + "/local/installation.nix";
          installation =
            if builtins.pathExists localHardware && builtins.pathExists localInstallation then
              localInstallation
            else
              throw "Incomplete hosts/${name}/local: hardware-configuration.nix and installation.nix are both required.";
        in
        nixpkgs.lib.optionalAttrs
          (builtins.pathExists localHardware || builtins.pathExists localInstallation)
          {
            ${name} = builtins.seq installation (
              nixpkgs.lib.nixosSystem {
                modules = [
                  (host + "/configuration.nix")
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
      // mkHost "desktop"
      // mkHost "laptop"
      // mkHost "nixos-test";

      # Standalone Home Manager on an Apple silicon Mac. Like the NixOS hosts, it
      # builds only once the ignored local/user.nix names the account.
      homeConfigurations = nixpkgs.lib.optionalAttrs (builtins.pathExists ./hosts/macos/local/user.nix) {
        macos = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          modules = [
            ./hosts/macos/home.nix
            ./hosts/macos/local/user.nix
          ];
        };
      };
    };
}
