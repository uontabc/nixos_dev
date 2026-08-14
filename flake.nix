{
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    impermanence.url = "github:nix-community/impermanence";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # NOTE: nixvim deliberately does NOT follow our nixpkgs — they test against
    # their own pinned nixos-26.05 revision. Following can cause
    # `vimPlugins.<name> attribute not found` errors.
    nixvim.url = "github:nix-community/nixvim/nixos-26.05";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # NOTE: vaultix keeps its own pinned nixpkgs (nixos-unstable) on purpose,
    # matching its CI/tested revision.
    vaultix.url = "github:milieuim/vaultix";
  };
}
