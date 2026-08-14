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
        swapDevices = [ ];

        # disko takes over fileSystems for us — it injects fileSystems.* for the
        # nixos-esp (vfat) + nixos-btrfs subvolumes (root/persist/nix), all
        # referenced by the stable by-partlabel paths created during manual
        # `parted` partitioning (see README "Same-disk dual-boot installation").
        # Run `disko --mode format,mount --flake .#uontabc` once after manual
        # parted; disko is idempotent (skips mkfs when blkid sees an existing
        # filesystem, skips btrfs subvolume create when one already exists).
        # destroy = false on every disk block — we never want disko to wipe
        # partitions, even if someone accidentally runs `--mode destroy,...`.
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

        # btrfs subvolume rollback — mount toplevel (subvolid=5), then either
        # seed @root-blank (first boot) or roll root back to @root-blank.
        # Still keyed on the same by-partlabel disko uses, so no surprises.
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