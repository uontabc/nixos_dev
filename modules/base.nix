{ config, ... }: {
  flake.modules.nixos.base = { pkgs, lib, ... }: {
    imports = with config.flake.modules.nixos; [
      users
      nix
      i18n
      env
      nh
      git
      neovim
      opencode
      fastfetch
      zsh
    ];

    hardware.enableRedistributableFirmware = true;

    # Only qq and helium need unfree; permit exactly those (keep in sync with
    # modules/flake-parts.nix's allowUnfreePredicate).
    nixpkgs.config.allowUnfreePredicate = pkg:
      lib.lists.any
        (n: lib.getName pkg == n)
        [
          "qq"      # Tencent QQ
          "helium"  # Helium browser (AppImage wrapper defaults to unfree)
        ];

    environment.systemPackages = with pkgs; [
      vim
      wget
      curl
      htop
      man-pages
    ];
  };
}
