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
      ];

      hardware.enableRedistributableFirmware = true;

      environment.systemPackages = with pkgs; [
        vim
        wget
        curl
        htop
        man-pages
      ];
    };
}