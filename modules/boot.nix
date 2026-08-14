{
  flake.modules.nixos.boot = {
    boot.loader = {
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot";
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = true;
        configurationLimit = 10;
      };
    };

    boot.supportedFilesystems = [ "btrfs" "ntfs" ];
    boot.initrd.supportedFilesystems = [ "btrfs" ];
    boot.tmp.useTmpfs = true;
  };
}