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
            nixfmt
            statix
            deadnix
            util-linux
            openssh
          ];
        };

      nixosConfigurations.nixos-test = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/nixos-test/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
        ];
      };

      nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit self; };
        modules = [ ./hosts/installer/configuration.nix ];
      };
    };
}
