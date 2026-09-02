{
  config,
  ...
}:
let
  inherit (config.flake.lib) mkHostConfiguration;
  inherit (config.flake.lib.hostProfiles) desktop;
in
{
  flake.nixosConfigurations.uontabc = mkHostConfiguration {
    hostName = "uontabc";
    inherit (desktop) nixosModules;

    # disko devices for this machine (modules/hosts/uontabc/disko.nix points
    # flake.modules.nixos.uontabc at ./_disko-devices.nix).
    extraImports = [ config.flake.modules.nixos.uontabc ];

    extraConfig =
      { pkgs, ... }:
      {
        boot.initrd = {
          availableKernelModules = [
            "xhci_pci"
            "nvme"
            "usb_storage"
            "sd_mod"
          ];

          systemd = {
            # btrfs subvolume rollback in systemd stage-1 (systemd initrd is
            # now the default, so boot.initrd.postDeviceCommands is
            # unsupported). Mount the toplevel (subvolid=5), then either
            # seed @root-blank (first boot) or roll root back to
            # @root-blank — runs before /sysroot is mounted.
            services.impermanence-rollback = {
              description = "Impermanence: roll back root btrfs subvolume";
              wantedBy = [ "initrd.target" ];
              before = [ "sysroot.mount" ];
              # Wait for the btrfs device to appear — the disk may not be
              # probed yet at initrd startup.
              after = [ "dev-nvme0n1p4.device" ];
              requires = [ "dev-nvme0n1p4.device" ];
              unitConfig.DefaultDependencies = "no";
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = ''
                mkdir -p /btrfs-tl
                mount -t btrfs -o subvolid=5 /dev/nvme0n1p4 /btrfs-tl

                if [ -d /btrfs-tl/@root-blank ]; then
                  echo "[impermanence] rolling back root subvolume from @root-blank"
                  # -R: root contains nested subvolumes (systemd-tmpfiles
                  # creates /tmp, /var/tmp, /srv, /var/lib/machines,
                  # /var/lib/portables as btrfs subvolumes). A plain delete
                  # fails with ENOTEMPTY, so every rollback silently failed
                  # since this machine was set up.
                  btrfs subvolume delete -R /btrfs-tl/root
                  btrfs subvolume snapshot /btrfs-tl/@root-blank /btrfs-tl/root
                else
                  echo "[impermanence] first boot: seeding @root-blank from root"
                  btrfs subvolume snapshot /btrfs-tl/root /btrfs-tl/@root-blank
                fi

                umount /btrfs-tl
                rmdir /btrfs-tl
              '';
            };

            # btrfs-progs must be reachable from the systemd initrd
            # environment. `boot.initrd.systemd.storePaths` only copies the
            # files into the initrd but does NOT put `btrfs` on PATH (initrd
            # PATH is fixed to /bin:/sbin). Symlinking it into /bin via
            # `extraBin` is what makes the bare `btrfs` call in the rollback
            # script resolve — without this the rollback/seed silently never
            # ran ("btrfs: command not found").
            extraBin.btrfs = "${pkgs.btrfs-progs}/bin/btrfs";
            storePaths = [ "${pkgs.btrfs-progs}/bin" ];
          };
        };

        swapDevices = [ ];
      };
  };
}
