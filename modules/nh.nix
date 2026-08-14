{
  flake.modules.nixos.nh = {
    programs.nh = {
      enable = true;
      flake = "/home/onyx/nixos";
      clean = {
        enable = true;
        dates = "weekly";
        extraArgs = "--keep 5 --keep-since 7d";
      };
    };
  };
}