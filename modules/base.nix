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
      pi
      zsh
    ];

    hardware.enableRedistributableFirmware = true;

    # Only qq, helium and the NVIDIA driver need unfree; permit exactly those
    # (keep in sync with modules/flake-parts.nix's allowUnfreePredicate).
    nixpkgs.config.allowUnfreePredicate =
      pkg:
      lib.lists.any (n: lib.getName pkg == n) [
        "qq" # Tencent QQ
        "helium" # Helium browser (AppImage wrapper defaults to unfree)
      ]
      || lib.hasPrefix "nvidia" (lib.getName pkg); # NVIDIA driver/settings/persistenced

    environment.systemPackages = with pkgs; [
      wget
      curl
      htop
      man-pages
    ];
  };
}
