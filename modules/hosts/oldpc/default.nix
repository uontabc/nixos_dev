{
  config,
  lib,
  ...
}:
{
  # Older single-disk Intel machine (iGPU, no discrete GPU). Uses
  # systemd-boot instead of GRUB. Ported from the old nix-config repo
  # (codeberg.org/uontabc/nix-config).
  hosts.oldpc = {
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
          hardware
          desktop
          overlays
          impermanence
          disko
          cpu-intel
        ];

        # btrfs toplevel device this host rolls back from @root-blank every
        # boot (see modules/impermanence.nix for the initrd service).
        impermanence.rollbackDevice = "/dev/sda2";

        boot = {
          # modules/boot.nix defaults to GRUB (uontabc needs it); this
          # machine boots systemd-boot instead.
          loader = {
            systemd-boot.enable = true;
            grub.enable = lib.mkForce false;
          };

          initrd.availableKernelModules = [
            "xhci_pci"
            "ahci"
            "usb_storage"
            "sd_mod"
          ];
        };
      };
  };
}
