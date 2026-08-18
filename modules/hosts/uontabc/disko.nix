{
  # Named after the host: the host factory in lib/nixos.nix auto-attaches
  # `flake.modules.nixos.<hostname>` to the matching host via
  # `optional (nixos ? ${name}) nixos.${name}`.
  #
  # Partitions are created manually once (see INSTALL.md 3.4). The regular
  # format,mount flow preserves existing filesystem contents; the explicit
  # destroy,format,mount flow wipes/reformats these two partitions. Devices
  # are plain paths (/dev/nvme0n1p1 etc.) — adjust to your disk; the btrfs
  # device must also match `hosts/uontabc/default.nix` (rollback service).
  flake.modules.nixos.uontabc.disko.devices.disk = {
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
      device = "/dev/nvme0n1p2";
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
