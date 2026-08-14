{ inputs, ... }: {
  flake.modules.nixos.impermanence =
    { ... }: {
      imports = [ inputs.impermanence.nixosModules.impermanence ];

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
          ];
          allowOther = true;
        };
      };
    };
}