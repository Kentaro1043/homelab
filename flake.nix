{
  description = "My NixOS HomeLab Configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    deploy-rs.url = "github:serokell/deploy-rs";
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs = {
        nixpkgs.follows = "";
        home-manager.follows = "";
      };
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs = {
    self,
    nixpkgs,
    deploy-rs,
    sops-nix,
    impermanence,
    disko,
    ...
  } @ inputs: let
    systems = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        packages = [
          pkgs.fluxcd
          deploy-rs.packages.${system}.deploy-rs
        ];
      };
    });

    nixosConfigurations = {
      kentaro-homelab = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./nixos/kentaro-homelab/configuration.nix
          sops-nix.nixosModules.sops
          impermanence.nixosModules.impermanence
          disko.nixosModules.disko
        ];
      };
    };

    deploy.nodes.kentaro-homelab = {
      hostname = "kentaro-homelab";
      profiles.system = {
        sshUser = "kentaro";
        user = "root";
        path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.kentaro-homelab;
      };
    };
  };
}
