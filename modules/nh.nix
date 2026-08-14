{
  flake.modules.nixos.nh =
    { config, ... }:
    let
      home = "/home/${config.my.name}";
    in
    {
      programs.nh = {
        enable = true;
        flake = "${home}/nixos_dev";
        clean = {
          enable = true;
          dates = "weekly";
          extraArgs = "--keep 5 --keep-since 7d";
        };
      };
    };
}