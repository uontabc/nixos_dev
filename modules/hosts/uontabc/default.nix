{ config, ... }: {
  hosts.uontabc = {
    system = "x86_64-linux";
    stateVersion = "26.05";
    module =
      { lib, pkgs, ... }: {
        imports = with config.flake.modules.nixos; [
          boot
          network
          hardware
          desktop
          microvm
          impermanence
          disko
        ];

        boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];
        swapDevices = [ ];

        # disko does not set neededForBoot on generated mounts; stage-1 needs
        # /persist (impermanence bind-mounts from it in the initrd).
        fileSystems."/persist".neededForBoot = true;

        # btrfs subvolume rollback in systemd stage-1 (systemd initrd is now the
        # default, so boot.initrd.postDeviceCommands is unsupported). Mount the
        # toplevel (subvolid=5), then either seed @root-blank (first boot) or
        # roll root back to @root-blank — runs before /sysroot is mounted.
        boot.initrd.systemd.services.impermanence-rollback = {
          description = "Impermanence: roll back root btrfs subvolume";
          wantedBy = [ "initrd.target" ];
          before = [ "sysroot.mount" ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
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

        # btrfs-progs must be reachable from the systemd initrd environment.
        boot.initrd.systemd.storePaths = [ "${pkgs.btrfs-progs}/bin" ];
      };
  };
}