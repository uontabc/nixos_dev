{
  # Named after the host: the host factory in lib/nixos.nix auto-attaches
  # `flake.modules.nixos.<hostname>` to the matching host via
  # `optional (nixos ? ${name}) nixos.${name}`.
  flake.modules.nixos.uontabc.disko.devices.disk = {
    nixos-esp = {
      type = "disk";
      device = "/dev/disk/by-partlabel/nixos-esp";
      destroy = false;
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
        mountOptions = [ "umask=0077" "defaults" ];
      };
    };
    nixos-btrfs = {
      type = "disk";
      device = "/dev/disk/by-partlabel/nixos-btrfs";
      destroy = false;
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