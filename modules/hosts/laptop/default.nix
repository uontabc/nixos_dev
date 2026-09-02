{
  config,
  lib,
  ...
}:
let
  # The NixOS system config (`module`'s `config` arg) shadows the outer
  # flake-parts config, so capture it here for `flake.modules.nixos` access.
  flakeCfg = config;
in
{
  # Intel + NVIDIA laptop, NixOS on /dev/nvme1n1, Windows stays on
  # /dev/nvme0n1 (dual-boot via GRUB + os-prober from modules/boot.nix).
  # Ported from the old nix-config repo (codeberg.org/uontabc/nix-config).
  hosts.laptop = {
    system = "x86_64-linux";
    stateVersion = "26.05";
    module =
      { pkgs, config, ... }:
      {
        imports = with flakeCfg.flake.modules.nixos; [
          boot
          network
          hardware
          desktop
          overlays
          impermanence
          disko
          # Intel CPU + NVIDIA GPU specifics (the generic `hardware` module
          # no longer bundles CPU/GPU modules).
          cpu-intel
          nvidia
        ];

        # btrfs toplevel device this host rolls back from @root-blank every
        # boot (see modules/impermanence.nix for the initrd service).
        impermanence.rollbackDevice = "/dev/nvme1n1p2";

        boot = {
          initrd.availableKernelModules = [
            "xhci_pci"
            "ahci"
            "nvme"
            "usb_storage"
            "sd_mod"
          ];
          supportedFilesystems = [ "ntfs" ];
        };

        # This GPU needs the proprietary (non-open) driver on the beta
        # channel — override the shared module's open/stable defaults.
        hardware.nvidia.open = lib.mkForce false;
        hardware.nvidia.package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.beta;

        # NTFS read/write for the Windows partition.
        environment.systemPackages = [ pkgs.ntfs3g ];
      };
  };
}
