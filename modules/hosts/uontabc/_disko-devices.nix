{
  # Single source of truth for this machine's disko layout. Consumed by:
  # - the NixOS system: modules/hosts/uontabc/disko.nix points
  #   `flake.modules.nixos.uontabc` at this file, so `disko.devices` (and the
  #   generated fileSystems) are configured on the host;
  # - the flake output: modules/disko.nix imports it for
  #   `diskoConfigurations.uontabc` so the disko CLI works directly.
  #
  # Partitions are created manually once (see INSTALL.md 3.4). The regular
  # format,mount flow preserves existing filesystem contents; the explicit
  # destroy,format,mount flow wipes/reformats these two partitions. Devices
  # are plain paths (/dev/nvme0n1p1 etc.) — adjust to your disk; the btrfs
  # device must also match `hosts/uontabc/default.nix` (rollback service).
  # This machine: p1 = 200M vfat ESP, p6 = 601G btrfs; p2-p5 (Windows /
  # Fedora /boot) are left untouched.
  disko.devices.disk = {
    nixos-esp = {
      type = "disk";
      device = "/dev/nvme0n1p1";
      destroy = true;
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
        mountOptions = [ "umask=0077" "defaults" ];
      };
    };
    nixos-btrfs = {
      type = "disk";
      device = "/dev/nvme0n1p6";
      destroy = true;
      content = {
        type = "btrfs";
        extraArgs = [ "-L" "nixos" ];
        subvolumes = {
          "root" = {
            mountpoint = "/";
            mountOptions = [ "compress=zstd" "noatime" "ssd" ];
          };
          "nix" = {
            mountpoint = "/nix";
            mountOptions = [ "compress=zstd" "noatime" "ssd" ];
          };
          "persist" = {
            mountpoint = "/persist";
            mountOptions = [ "compress=zstd" "noatime" "ssd" ];
          };
        };
      };
    };
  };
}