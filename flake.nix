{
  description = "NixOS and Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.nixos-test = nixpkgs.lib.nixosSystem {
      modules = [
        ./hosts/nixos-test/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.user = ./hosts/nixos-test/home.nix;
        }
      ];
    };

    nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit self; };
      modules = [ ./hosts/installer/configuration.nix ];
    };
  };
}
