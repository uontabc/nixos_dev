{ config, ... }: {
  # Generic hardware support shared by every desktop/bare-metal host.
  # CPU (cpu-amd / cpu-intel) and GPU (nvidia) modules are host-specific and
  # imported per-host — see modules/hosts/uontabc and modules/hosts/laptop.
  flake.modules.nixos.hardware = { ... }: {
    imports = with config.flake.modules.nixos; [
      graphics
      bluetooth
      input
      zram
    ];
  };
}
