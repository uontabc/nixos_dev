{
  config,
  ...
}:
let
  inherit (config.flake.lib) mkHostConfiguration;
  inherit (config.flake.lib.hostProfiles) desktop;
in
{
  flake.nixosConfigurations.uontabc = mkHostConfiguration {
    hostName = "uontabc";
    inherit (desktop) nixosModules;

    # NixOS-only partitions on the dual-boot disk (Windows keeps p1/p2):
    # ESP on p3, btrfs on p4 — built by the codeberg-style factory in
    # modules/system/disko.nix (same call as diskoConfigurations.uontabc).
    extraImports = [
      (config.flake.lib.mkPartitionConfig {
        esp = "/dev/nvme0n1p3";
        root = "/dev/nvme0n1p4";
      })
    ];

    extraConfig =
      { ... }:
      {
        # Rollback machinery (initrd service + btrfs in stage-1) lives in
        # modules/system/impermanence.nix; the host only declares the btrfs
        # toplevel device that holds the `root` subvolume.
        impermanence.rollbackDevice = "/dev/nvme0n1p4";

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
