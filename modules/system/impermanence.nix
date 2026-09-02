{ inputs, lib, ... }: {
  flake.modules.nixos.impermanence =
    { config, pkgs, ... }:
    let
      user = config.my.name;
    in
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];

      # btrfs toplevel device that holds the `root` subvolume, e.g.
      # "/dev/nvme0n1p4". Set per-host in modules/hosts/<name>/configuration.nix
      # (codeberg style: the host only declares the device, the rollback
      # machinery lives here). When set, stage-1 rolls `root` back to the
      # @root-blank snapshot at every boot.
      options.impermanence.rollbackDevice = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          btrfs toplevel device (subvolid=5) that holds the `root` subvolume.
          When set, stage-1 rolls `root` back to the @root-blank snapshot at
          every boot (impermanence).
        '';
      };

      config = lib.mkMerge [
        (lib.mkIf (config.impermanence.rollbackDevice != null) {
          # btrfs subvolume rollback in systemd stage-1 (systemd initrd is
          # now the default, so boot.initrd.postDeviceCommands is
          # unsupported). Mount the toplevel (subvolid=5), then either seed
          # @root-blank (first boot) or roll root back to @root-blank — runs
          # before /sysroot is mounted.
          boot.initrd.systemd = {
            services.impermanence-rollback =
              let
                device = config.impermanence.rollbackDevice;
                # /dev/nvme0n1p4 -> dev-nvme0n1p4 (systemd device unit name).
                # replaceStrings on the whole path would keep a leading dash
                # (dev--dev-nvme0n1p4) — strip the /dev/ prefix first.
                unit = "dev-${lib.removePrefix "/dev/" device}";
              in
              {
                description = "Impermanence: roll back root btrfs subvolume";
                wantedBy = [ "initrd.target" ];
                before = [ "sysroot.mount" ];
                # Wait for the btrfs device to appear — the disk may not be
                # probed yet at initrd startup.
                after = [ "${unit}.device" ];
                requires = [ "${unit}.device" ];
                unitConfig.DefaultDependencies = "no";
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                };
                script = ''
                  mkdir -p /btrfs-tl
                  mount -t btrfs -o subvolid=5 ${device} /btrfs-tl

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
        })

        # What survives a reboot under /persist (same for every host that
        # enables impermanence).
        {
          environment.persistence."/persist" = {
            enable = true;
            hideMounts = true;

            directories = [
              "/var/lib/nixos"
              "/var/lib/systemd"
              "/var/lib/NetworkManager"
              "/var/lib/bluetooth"
              "/var/lib/hjem"
              "/var/log"
              "/etc/NetworkManager/system-connections"
              "/etc/daed"
            ];

            files = [
              "/etc/machine-id"
              "/etc/ssh/ssh_host_ed25519_key"
              "/etc/ssh/ssh_host_ed25519_key.pub"
              "/etc/ssh/ssh_host_rsa_key"
              "/etc/ssh/ssh_host_rsa_key.pub"
            ];

            users.${user} = {
              directories = [
                "Documents"
                "Downloads"
                "Pictures"
                "Music"
                "Videos"
                "Projects"
                # The flake repo itself — wiped root subvolume would delete it.
                "nixos_dev"
                # Development workspace.
                "dev"
                {
                  directory = ".ssh";
                  mode = "0700";
                }
                ".local/share"
                ".local/state"
                {
                  directory = ".gnupg";
                  mode = "0700";
                }
                # pi coding agent: settings/auth/sessions under ~/.pi.
                {
                  directory = ".pi";
                  mode = "0700";
                }
              ];

              # fish history lives under ~/.local/share/fish/fish_history —
              # covered by the persisted ".local/share" directory above.
            };
          };
        }
      ];
    };
}
