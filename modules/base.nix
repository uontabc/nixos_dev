{ config, ... }: {
  flake.modules.nixos.base =
    { pkgs, ... }: {
      imports = with config.flake.modules.nixos; [
        users
        nix
        i18n
        env
        nh
        git
        opencode
        neovim
        fonts
      ];

      hardware.enableRedistributableFirmware = true;

      environment.systemPackages = with pkgs; [
        wget
        curl
        htop
        man-pages
      ];
    };
}