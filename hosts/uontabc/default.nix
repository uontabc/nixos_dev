{ ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/nixos
  ];

  networking.hostName = "uontabc";

  system.stateVersion = "26.05";
}