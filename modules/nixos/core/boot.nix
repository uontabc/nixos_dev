# GRUB (EFI) + os-prober for Windows dual-boot detection.
{ lib, ... }:

{
  boot.loader = {
    efi.canTouchEfiVariables = true;
    efi.efiSysMountPoint = "/boot";

    grub = {
      enable = true;
      device = "nodev"; # install to the ESP, not a raw disk
      efiSupport = true;
      useOSProber = true;
      configurationLimit = 10;
    };
  };

  boot.supportedFilesystems = [ "btrfs" "ntfs" ];
  boot.initrd.supportedFilesystems = [ "btrfs" ];

  boot.tmp.useTmpfs = true;
}