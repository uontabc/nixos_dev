# DANGER: disko --mode destroy wipes the disk. If Windows lives on the same
# physical disk, this destroys Windows. Either use a separate disk or
# partition manually and drop the `disko.devices` block.
{ lib, ... }:

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # Replace with your disk's stable by-id path.
        device = lib.mkDefault "/dev/disk/by-id/REPLACE_WITH_YOUR_DISK_ID";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00"; # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" "defaults" ];
              };
            };

            btrfs = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" "-L" "nixos" ];
                subvolumes = {
                  "root" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" "ssd" ];
                  };
                  "persist" = {
                    mountpoint = "/persist";
                    mountOptions = [ "compress=zstd" "noatime" "ssd" ];
                  };
                  "nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" "ssd" ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  fileSystems."/persist".neededForBoot = true;

  # `disk-main-btrfs` is disko's auto-generated partition label.
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir -p /btrfs-tl
    mount -t btrfs -o subvolid=5 /dev/disk/by-partlabel/disk-main-btrfs /btrfs-tl

    if [ -d /btrfs-tl/@root-blank ]; then
      echo "[impermanence] rolling back root subvolume from @root-blank"
      btrfs subvolume delete /btrfs-tl/root
      btrfs subvolume snapshot /btrfs-tl/@root-blank /btrfs-tl/root
    else
      echo "[impermanence] first boot: seeding @root-blank from root"
      btrfs subvolume snapshot /btrfs-tl/root /btrfs-tl/@root-blank
    fi

    umount /btrfs-tl
    rmdir /btrfs-tl
  '';
}