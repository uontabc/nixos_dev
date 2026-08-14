# Declares the nixosConfigurations output via flake-parts.
#
# flake-parts expects flake attributes to live under the `flake` option.
# See: https://flake.parts/options/flake-parts.html
{ inputs, ... }:

{
  flake.nixosConfigurations.uontabc = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };

    modules = [
      ./../hosts/uontabc
      inputs.impermanence.nixosModules.impermanence
      inputs.noctalia.nixosModules.default
    ];
  };
}