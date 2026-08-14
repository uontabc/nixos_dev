{
  flake.modules.nixos.display =
    { pkgs, config, ... }: {
      services.greetd = {
        enable = true;
        settings.default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri";
          user = config.my.name;
        };
      };
    };
}