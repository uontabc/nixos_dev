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
        # mkDefault so a host can override (e.g. if the repo lives elsewhere).
        # Also overridable at runtime with NH_OS_FLAKE=/path/to/repo.
        flake = lib.mkDefault "${home}/nixos";
        clean = {
          enable = true;
          dates = "weekly";
          extraArgs = "--keep 5 --keep-since 7d";
        };
      };
    };
}