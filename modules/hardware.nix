{ config, ... }: {
  flake.modules.nixos.hardware =
    { ... }: {
      imports = with config.flake.modules.nixos; [
        cpu-amd
        nvidia
        graphics
        bluetooth
        input
      ];
    };
}