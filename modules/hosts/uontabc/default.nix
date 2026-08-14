{ config, ... }: {
  hosts.uontabc = {
    system = "x86_64-linux";
    stateVersion = "26.05";
    module =
      { lib, ... }: {
        imports = with config.flake.modules.nixos; [
          boot
          network
          hardware
          desktop
          impermanence
          disko
        ];

        boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];
        swapDevices = [ ];

        # disko does not set neededForBoot on generated mounts; stage-1 needs
        # /persist (impermanence bind-mounts from it in the initrd).
        fileSystems."/persist".neededForBoot = true;

        # btrfs subvolume rollback — mount toplevel (subvolid=5), then either
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
      };
  };
}