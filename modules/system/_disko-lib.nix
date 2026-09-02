{ lib }:
{
  # Disko layout factories, in the style of the old codeberg nix-config repo
  # (flake.lib.mkDiskConfig). Two variants:
  #
  # - mkPartitionConfig: manage existing partitions by device path — used for
  #   dual-boot disks where Windows owns partitions that must not be touched
  #   (uontabc: Windows on nvme0n1p1/p2, NixOS on nvme0n1p3/p4).
  # - mkDiskConfig: whole-disk GPT (ESP + btrfs) for dedicated disks.
  #
  # Subvolume names (root/nix/persist) are shared with the @root-blank
  # rollback service in modules/hosts/uontabc/configuration.nix.

  # NixOS-only partitions on a shared (dual-boot) disk, addressed by device
  # path. `destroy = true` only wipes the NixOS partitions; the Windows
  # partitions are never part of this definition.
  mkPartitionConfig =
    {
      esp,
      root,
      swapSize ? null,
    }:
    {
      disko.devices.disk = {
        nixos-esp = {
          type = "disk";
          device = esp;
          destroy = true;
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [
              "umask=0077"
              "defaults"
            ];
          };
        };
        nixos-btrfs = {
          type = "disk";
          device = root;
          destroy = true;
          content = {
            type = "btrfs";
            extraArgs = [
              "-L"
              "nixos"
            ];
            subvolumes = {
              "root" = {
                mountpoint = "/";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                  "ssd"
                ];
              };
              "nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                  "ssd"
                ];
              };
              "persist" = {
                mountpoint = "/persist";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                  "ssd"
                ];
              };
            }
            // lib.optionalAttrs (swapSize != null) {
              "swap" = {
                mountpoint = "/swap";
                swap.swapfile.size = swapSize;
              };
            };
          };
        };
      };

      # disko does not set neededForBoot on generated mounts; stage-1 needs
      # /persist (impermanence bind-mounts from it in the initrd).
      fileSystems."/persist".neededForBoot = true;
    };

  # Whole-disk layout for a dedicated NixOS disk: GPT with ESP + btrfs root
  # (plus swapfile subvolume). Wipes the entire disk.
  mkDiskConfig =
    {
      device,
      swapSize ? "8G",
      espSize ? "512M",
    }:
    {
      disko.devices.disk.main = {
        type = "disk";
        inherit device;
        content = {
          type = "gpt";
          partitions = {
            esp = {
              size = espSize;
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "umask=0077"
                  "defaults"
                ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                    ];
                  };
                  "nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                    ];
                  };
                  "persist" = {
                    mountpoint = "/persist";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                    ];
                  };
                  "swap" = {
                    mountpoint = "/swap";
                    swap.swapfile.size = swapSize;
                  };
                };
              };
            };
          };
        };
      };

      fileSystems."/persist".neededForBoot = true;
    };
}
