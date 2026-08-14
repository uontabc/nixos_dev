{ inputs, ... }: {
  flake.modules.nixos.nix = {
    nix.registry.nixpkgs.flake = inputs.nixpkgs;

    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
      auto-optimise-store = true;
    };
  };
}