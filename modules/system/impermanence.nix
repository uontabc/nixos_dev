{ inputs, ... }: {
  flake.modules.nixos.impermanence = { config, ... }: {
    imports = [ inputs.impermanence.nixosModules.impermanence ];

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

      users.${config.my.name} = {
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

        files = [ ".zsh_history" ];
      };
    };
  };
}
