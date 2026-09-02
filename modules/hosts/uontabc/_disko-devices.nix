{
  # NixOS-only partitions on the dual-boot disk: Windows owns nvme0n1p1/p2
  # (untouched), NixOS gets p3 (ESP) + p4 (btrfs). Consumed by:
  # - the NixOS system: modules/hosts/uontabc/configuration.nix passes
  #   flake.modules.nixos.uontabc (modules/hosts/uontabc/disko.nix) via
  #   extraImports, so disko.devices (and the generated fileSystems) are
  #   configured on the host;
  # - the flake output: modules/system/disko.nix imports it for
  #   diskoConfigurations.uontabc so the disko CLI works directly.
  #
  # Partitions are created manually once (see INSTALL.md 3.4). The regular
  # format,mount flow preserves existing filesystem contents; the explicit
  # destroy,format,mount flow wipes/reformats these two partitions. Devices
  # are plain paths (/dev/nvme0n1p3 etc.) — adjust to your disk; the btrfs
  # device must also match `configuration.nix` (rollback service).
  lib,
  ...
}:
let
  inherit (import ../../system/_disko-lib.nix { inherit lib; }) mkPartitionConfig;
in
mkPartitionConfig {
  esp = "/dev/nvme0n1p3";
  root = "/dev/nvme0n1p4";
}
