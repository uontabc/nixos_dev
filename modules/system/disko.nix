{
  inputs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;

  # ── disko layout factories (codeberg nix-config style) ──────────────────────
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
in
{
  imports = [ inputs.disko.flakeModules.disko ];

  flake = {
    modules.nixos.disko.imports = [
      inputs.disko.nixosModules.default
    ];

    # Expose the factories so hosts can build their layout inline (codeberg
    # style): e.g. modules/hosts/uontabc/configuration.nix passes
    #   extraImports = [ (config.flake.lib.mkPartitionConfig { esp = ...; root = ...; }) ];
    lib = {
      inherit mkDiskConfig mkPartitionConfig;
    };

    # Expose the uontabc layout as `diskoConfigurations.uontabc` so the disko
    # CLI / disko-install work directly. (The host itself gets the same
    # layout via extraImports in configuration.nix.)
    diskoConfigurations.uontabc = {
      disko.devices =
        (mkPartitionConfig {
          esp = "/dev/nvme0n1p3";
          root = "/dev/nvme0n1p4";
        }).disko.devices;
    };
  };

  # `nix run .#disko -- --flake .#uontabc --mode format,mount` — uses the
  # lockfile-pinned disko, no GitHub fetch (avoids "Connection error" in CN).
  # Also available as `disko` in the devshell (modules/devshell.nix).
  perSystem =
    { inputs', ... }:
    {
      apps.disko = {
        type = "app";
        program = inputs'.disko.packages.disko;
      };
    };
}
