# Pairs with the root rollback in hosts/uontabc/disko.nix.
{ lib, ... }:

{
  environment.persistence."/persist" = {
    enable = true;
    hideMounts = true;

    directories = [
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/NetworkManager"
      "/var/lib/bluetooth"
      "/var/log"
      "/etc/NetworkManager/system-connections"
    ];

    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];

    users.onyx = {
      directories = [
        "Documents"
        "Downloads"
        "Pictures"
        "Music"
        "Videos"
        "Projects"
        ".ssh"
        ".local/share"
        ".gnupg"
        # ~/.config is NOT persisted: niri/kitty configs are bind-symlinked from the
# nix store by systemd.tmpfiles (modules/nixos/desktop/*). Add subdirs here
# only for apps whose config you tweak by hand (and want to survive reboot).
      ];
      allowOther = true;
    };
  };
}