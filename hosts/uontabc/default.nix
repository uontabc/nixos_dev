{ ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../modules/nixos
  ];

  networking.hostName = "uontabc";

  system.stateVersion = "26.05";
}