{ config, inputs, ... }: {
  flake.modules.nixos.desktop = { pkgs, ... }: {
    imports = with config.flake.modules.nixos; [
      audio
      display
      portal
      noctalia
      xwayland
      niri
      kitty
      qt
      fcitx5
      fonts
      printing
    ];

    my.packages = with pkgs; [
      yazi
      superfile
      satty
      wl-clipboard
      networkmanagerapplet
      brightnessctl
      polkit_gnome
      qq
      inetutils
      inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
