{
  description = "Niri + Noctalia NixOS configuration (no home-manager)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    impermanence.url = "github:nix-community/impermanence";

    # Tracks upstream (nixos-unstable); if it breaks vs 26.05, drop `follows`.
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    {
      nixosConfigurations.uontabc = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };

        modules = [
          ./hosts/uontabc
          inputs.impermanence.nixosModules.impermanence
          inputs.noctalia.nixosModules.default
        ];
      };
    };
}