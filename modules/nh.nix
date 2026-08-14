{
  flake.modules.nixos.nh =
    { config, lib, ... }:
    let
      home = "/home/${config.my.name}";
    in
    {
      programs.nh = {
        enable = true;
        # Sets NH_FLAKE so `nh os switch` works without arguments.
        # Repo lives at ~/nixos_dev (matches the GitHub repo name).
        flake = lib.mkDefault "${home}/nixos_dev";
        clean = {
          enable = true;
          dates = "weekly";
          extraArgs = "--keep 5 --keep-since 7d";
        };
      };
    };
}
