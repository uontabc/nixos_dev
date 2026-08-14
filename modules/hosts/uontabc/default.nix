{ self, ... }: {
  hosts.uontabc = {
    system = "x86_64-linux";
    stateVersion = "26.05";
    module =
      { lib, ... }: {
        imports = with self.modules.nixos; [
          boot
          network
          hardware
          desktop
          impermanence
        ];

        boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];

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
      };
  };
}