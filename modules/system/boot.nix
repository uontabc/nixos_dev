{ inputs, ... }: {
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
        # Tokyo Night GRUB theme (input is a plain repo: flake = false).
        theme = "${inputs.tokyo-night-grub}/tokyo-night";
      };
    };

    boot.supportedFilesystems = [ "btrfs" "ntfs" ];
    boot.initrd.supportedFilesystems = [ "btrfs" ];
    boot.tmp.useTmpfs = true;
  };
}