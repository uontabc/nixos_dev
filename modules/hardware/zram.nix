{ lib, ... }: {
  flake.modules.nixos.zram = {
    # Compressed RAM swap: helps avoid OOM under memory pressure (e.g. while
    # building nix derivations). Uses CPU instead of disk.
    zramSwap = {
      enable = true;
      memoryPercent = 50;
      algorithm = "zstd";
      swapDevices = 1;
    };
  };
}
