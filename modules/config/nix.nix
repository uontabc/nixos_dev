{ inputs, ... }: {
  flake.modules.nixos.nix = {
    nix.registry.nixpkgs.flake = inputs.nixpkgs;

    nix.extraOptions = ''
      experimental-features = nix-command flakes
    '';

    nix.settings = {
      warn-dirty = false;
      auto-optimise-store = true;
    };
  };
}