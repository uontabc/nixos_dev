{ config, ... }: {
  hosts.uontabc = {
    system = "x86_64-linux";
    stateVersion = "26.05";
    module = { lib, pkgs, ... }: {
      imports = with config.flake.modules.nixos; [
        boot
        network
        hardware
        desktop
        overlays
        impermanence
        disko
        # AMD CPU + NVIDIA GPU specifics (moved out of the generic
        # `hardware` module so Intel hosts can reuse it).
        cpu-amd
        nvidia
      ];

      # btrfs toplevel device this host rolls back from @root-blank every
      # boot (see modules/impermanence.nix for the initrd service).
      impermanence.rollbackDevice = "/dev/nvme0n1p6";

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "nvme"
        "usb_storage"
        "sd_mod"
      ];
      swapDevices = [ ];
    };
  };
}
