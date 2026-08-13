{ inputs, lib, ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../modules/nixos
  ];

  networking.hostName = "uontabc";

  nixpkgs.overlays = [
    (final: prev: {
      noctalia = inputs.noctalia.packages.${prev.system}.default;
    })
  ];

  home-manager.users.onyx.imports = [
    ../../modules/home
  ];

  system.stateVersion = "26.05";
}