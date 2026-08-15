{ inputs, ... }: {
  flake.modules.nixos.impermanence =
    { config, ... }: {
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
          "/etc/daed"
        ];

        files = [
          "/etc/machine-id"
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];

        users.${config.my.name} = {
          directories = [
            "Documents"
            "Downloads"
            "Pictures"
            "Music"
            "Videos"
            "Projects"
            # Writable tree shared into the docker-dev microvm at /workspace.
            "dev"
            ".ssh"
            ".local/share"
            ".local/state"
            ".gnupg"
          ];

          files = [
            ".zsh_history"
          ];
        };
      };
    };
}