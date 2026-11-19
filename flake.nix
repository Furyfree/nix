{
  description = "NixOS, nix-darwin and Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Built against our nixpkgs, so it loads the desktop's own GLib modules
    # (gvfs, dconf).
    strata = {
      url = "github:lgse/strata";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      ...
    }:
    let
      # A host builds only from its ignored local/ data, which the installer
      # writes; without it, the host has no output. An optional
      # local/desktop.nix picks the compositor, and an empty
      # local/limine-windows adds Windows to Limine's menu.
      mkHost =
        name:
        let
          host = ./nixos/hosts + "/${name}";
          localHardware = host + "/local/hardware-configuration.nix";
          localInstallation = host + "/local/installation.nix";
          localDesktop = host + "/local/desktop.nix";
          localWindows = host + "/local/limine-windows";
          installation =
            if builtins.pathExists localHardware && builtins.pathExists localInstallation then
              localInstallation
            else
              throw "Incomplete nixos/hosts/${name}/local: hardware-configuration.nix and installation.nix are both required.";
        in
        nixpkgs.lib.optionalAttrs
          (builtins.pathExists localHardware || builtins.pathExists localInstallation)
          {
            ${name} = builtins.seq installation (
              nixpkgs.lib.nixosSystem {
                specialArgs = { inherit inputs; };
                modules = [
                  (host + "/configuration.nix")
                  home-manager.nixosModules.home-manager
                  installation
                  {
                    home-manager.useGlobalPkgs = true;
                    home-manager.useUserPackages = true;
                  }
                ]
                ++ nixpkgs.lib.optional (builtins.pathExists localDesktop) localDesktop
                ++ nixpkgs.lib.optional (builtins.pathExists localWindows) ./nixos/limine-windows.nix;
              }
            );
          };

      # Every Apple silicon Mac runs one nix-darwin host. Like the NixOS hosts, it
      # builds only once its ignored local/user.nix names the account and this
      # Mac's profile.
      macUser = ./darwin/local/user.nix;

      # The Ubuntu work laptop runs Home Manager on its own; it builds once its
      # ignored local/user.nix names the account.
      ubuntuUser = ./ubuntu/local/user.nix;

      # NixOS in WSL on the Windows desktop profile; it builds once
      # windows/apply.ps1 has written the ignored local/user.nix.
      wslUser = ./nixos/hosts/wsl/local/user.nix;
    in
    {
      devShells.x86_64-linux.default =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.mkShellNoCC {
          UV_PYTHON = "${pkgs.python3}/bin/python3";
          UV_PYTHON_DOWNLOADS = "never";
          # pwsh reports usage on start unless this is set.
          POWERSHELL_TELEMETRY_OPTOUT = "1";
          packages = with pkgs; [
            python3
            uv
            just
            basedpyright
            lua5_5
            hyprland
            niri
            nixfmt
            statix
            deadnix
            caligula
            util-linux
            openssh
            powershell
            # nix-workstation pin: nvfetcher, and gpgv for Claude Desktop's index
            nvfetcher
            gnupg
          ];
        };

      nixosConfigurations = {
        installer = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit self; };
          modules = [ ./nixos/installer/configuration.nix ];
        };
      }
      // mkHost "desktop"
      // mkHost "laptop"
      // mkHost "nixos-test"
      // nixpkgs.lib.optionalAttrs (builtins.pathExists wslUser) {
        wsl = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./nixos/hosts/wsl/configuration.nix
            home-manager.nixosModules.home-manager
            wslUser
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
            }
          ];
        };
      };

      homeConfigurations = nixpkgs.lib.optionalAttrs (builtins.pathExists ubuntuUser) {
        ubuntu = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [
            ./ubuntu/home.nix
            ubuntuUser
          ];
        };
      };

      darwinConfigurations = nixpkgs.lib.optionalAttrs (builtins.pathExists macUser) {
        macos = nix-darwin.lib.darwinSystem {
          modules = [
            ./darwin
            home-manager.darwinModules.home-manager
            macUser
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
            }
          ];
        };
      };
    };
}
