{
  description = "Niri + Noctalia NixOS configuration (no home-manager)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    flake-parts.url = "github:hercules-ci/flake-parts";

    impermanence.url = "github:nix-community/impermanence";

    # Tracks upstream (nixos-unstable); if it breaks vs 26.05, drop `follows`.
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ ./flake-modules/nixos.nix ];

      systems = [ "x86_64-linux" ];
    };
}