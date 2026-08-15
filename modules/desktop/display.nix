{
  flake.modules.nixos.display = { pkgs, config, ... }: {
    services.greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session = {
        # --remember restores the last username; --user-menu lets the user pick.
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --user-menu --cmd niri-session";
        user = config.my.name;
      };
    };
  };
}

