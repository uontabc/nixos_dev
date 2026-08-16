{
  flake.modules.nixos.display = { pkgs, config, ... }: {
    services.greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session = {
        # --remember restores the last username; --user-menu lists all
        # /etc/passwd users, so it's omitted to avoid system users in the list.
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
        user = config.my.name;
      };
    };
  };
}

