{
  hosts.uontabc = {
    system = "x86_64-linux";
    stateVersion = "26.05";
    module =
      { lib, config, ... }: {
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

        # disko auto-injects fileSystems.* from the device declarations below.
        # It only touches /dev/disk/by-partlabel/nixos-* (Windows partitions
        # untouched), is idempotent (blkid / btrfs subvolume show guards), and
        # every block has destroy = false so even --mode destroy refuses to
        # wipe them. Run `disko --mode format,mount` after manual parted.
        disko.devices.disk = {
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