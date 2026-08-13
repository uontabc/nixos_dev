# Same-disk dual-boot partition layout (Windows + NixOS).
#
# Assumed final GPT on /dev/nvme0n1:
#   p1  Windows ESP          (existing, fat32, 100 MB)
#   p2  Windows Reserved     (existing, 16 MB)
#   p3  Windows NTFS C:      (existing, shrunk by you to free 512 GB)
#   p4  NixOS ESP             (1 GB,   type EF00, partlabel "nixos-esp")
#   p5  NixOS btrfs           (511 GB,         partlabel "nixos-btrfs")
#
# You build p4/p5 manually with parted before installing — see README
# "Same-disk dual-boot installation". This file only declares the mounts
# and the rollback script for p5's btrfs subvolumes.
{ lib, ... }:

{
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-partlabel/nixos-btrfs";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" "noatime" "ssd" ];
      neededForBoot = true;
    };

    "/boot" = {
      device = "/dev/disk/by-partlabel/nixos-esp";
      fsType = "vfat";
      options = [ "umask=0077" "defaults" ];
    };

    "/nix" = {
      device = "/dev/disk/by-partlabel/nixos-btrfs";
      fsType = "btrfs";
      options = [ "subvol=nix" "compress=zstd" "noatime" "ssd" ];
      neededForBoot = true;
    };

    "/persist" = {
      device = "/dev/disk/by-partlabel/nixos-btrfs";
      fsType = "btrfs";
      options = [ "subvol=persist" "compress=zstd" "noatime" "ssd" ];
      neededForBoot = true;
    };
  };

  swapDevices = [ ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" ];

  # btrfs subvolume rollback — mount the toplevel (subvolid=5), then either
  # seed @root-blank (first boot) or roll root back to @root-blank.
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir -p /btrfs-tl
    mount -t btrfs -o subvolid=5 /dev/disk/by-partlabel/nixos-btrfs /btrfs-tl

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