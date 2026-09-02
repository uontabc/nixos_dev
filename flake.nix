{
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  # Mirrors first (fast in China), official cache as fallback — same setup as
  # modules/config/nix.nix, but applied as soon as this flake is trusted
  # (nix.settings.accept-flake-config), so fresh machines get the mirrors
  # during `nixos-install` / `nix develop` too.
  nixConfig = {
    extra-substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://mirror.sjtu.edu.cn/nix-channels/store"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
    helium = {
      url = "github:J0schu/helium.nix";
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
    # Re-exported as flake templates: `nix flake init -t .#<lang>`.
    dev-templates = {
      url = "github:the-nix-way/dev-templates";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Tokyo Night GRUB theme (plain repo, not a flake).
    tokyo-night-grub = {
      url = "github:mino29/tokyo-night-grub";
      flake = false;
    };
  };
}
