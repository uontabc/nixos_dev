{ inputs, ... }: {
  flake.modules.nixos.nix = {
      nix.registry.nixpkgs.flake = inputs.nixpkgs;

      nix.settings = {
        experimental-features = [ "nix-command" "flakes" ];
        warn-dirty = false;
        auto-optimise-store = true;

        # Mirrors first (fast in China), official cache as fallback.
        # USTC and SJTU both mirror cache.nixos.org and sign with the same key.
        substituters = [
          "https://mirrors.ustc.edu.cn/nix-channels/store"
          "https://mirror.sjtu.edu.cn/nix-channels/store"
          "https://cache.nixos.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        ];

        # Trust our own flake's nixConfig (the mirror setup in flake.nix),
        # so `nh os switch` stops warning about "untrusted flake config".
        accept-flake-config = true;
      };
    };
}