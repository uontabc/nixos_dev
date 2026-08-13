{ ... }:

{
  programs.nh = {
    enable = true;
    # Absolute path to the flake root. Adjust if you clone elsewhere.
    # `nh os switch` reads NH_FLAKE (set here) to auto-detect the system.
    flake = "/home/onyx/nixos";
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 5 --keep-since 7d";
    };
  };
}