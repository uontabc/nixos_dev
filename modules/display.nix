{
  flake.modules.nixos.display =
    { pkgs, config, ... }: {
      services.greetd = {
        enable = true;
        vt = 1;
        settings.default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd niri";
          user = config.my.name;
        };
      };
    };
}