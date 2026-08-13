{
  imports = [
    ./core/boot.nix
    ./core/networking.nix
    ./core/locale.nix
    ./core/users.nix
    ./core/packages.nix
    ./core/env.nix

    ./hardware/cpu-amd.nix
    ./hardware/nvidia.nix
    ./hardware/graphics.nix
    ./hardware/bluetooth.nix
    ./hardware/input.nix

    ./desktop/display.nix
    ./desktop/portal.nix
    ./desktop/audio.nix
    ./desktop/fonts.nix
    ./desktop/niri.nix
    ./desktop/noctalia.nix

    ./persistence/impermanence.nix
  ];
}