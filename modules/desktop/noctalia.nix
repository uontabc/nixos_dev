{ inputs, ... }: {
  flake.modules.nixos.noctalia =
    { pkgs, ... }: {
      imports = [ inputs.noctalia.nixosModules.default ];

      programs.noctalia = {
        enable = true;
        systemd.enable = true;
      };

      security.polkit.enable = true;
      services.gnome.gnome-keyring.enable = true;
      services.upower.enable = true;
      services.power-profiles-daemon.enable = true;

      environment.systemPackages = [ pkgs.ddcutil ];
    };
}