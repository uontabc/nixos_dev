{
  config,
  lib,
  ...
}:
{
  # Headless VPS: no desktop, no hardware-GPU/bluetooth/input modules, no
  # greetd. GRUB installs as a removable EFI app so the provider's firmware
  # picks it up. Ported from the old nix-config repo
  # (codeberg.org/uontabc/nix-config), where it was deployed via deploy-rs.
  hosts.vps = {
    system = "x86_64-linux";
    stateVersion = "26.05";
    # Note: do NOT destructure `config` here — the `imports` below rely on
    # `config` closing over the flake-parts config (same trick as uontabc).
    module =
      { ... }:
      {
        imports = with config.flake.modules.nixos; [
          boot
          network
          overlays
          impermanence
          disko
        ];

        # btrfs toplevel device this host rolls back from @root-blank every
        # boot (see modules/impermanence.nix for the initrd service).
        impermanence.rollbackDevice = "/dev/vda2";

        boot = {
          # EFI firmware on cloud providers usually does not keep persistent
          # NVRAM entries — install GRUB to the ESP fallback path instead of
          # touching EFI variables.
          loader = {
            grub.efiInstallAsRemovable = true;
            efi.canTouchEfiVariables = lib.mkForce false;
          };

          initrd.availableKernelModules = [
            "virtio_pci"
            "virtio_blk"
            "virtio_scsi"
            "virtio_net"
          ];
        };

        # SSH is enabled by modules/network.nix with password auth off, so
        # the box is only reachable with these keys. Put your real public
        # keys here before first deploy.
        my.sshAuthorizedKeys = [
          # "ssh-ed25519 AAAA... user@vps"
        ];
      };
  };
}
