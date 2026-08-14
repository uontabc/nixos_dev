{ inputs, ... }: {
  # microvm.nix host: declaratively run MicroVMs as systemd services.
  flake.modules.nixos.microvm =
    { config, lib, ... }:
    let
      user = config.my.name;
      home = "/home/${user}";
    in
    {
      imports = [ inputs.microvm.nixosModules.host ];

      microvm.vms.docker-dev = {
        # Start manually via `systemctl start microvm@docker-dev.service`.
        autostart = false;
        config = {
          system.stateVersion = "26.05";
          networking.hostName = "docker-dev";

          microvm = {
            hypervisor = "qemu";
            mem = 2048;
            vcpu = 2;
            # Share the host nix store read-only, plus a writable dev tree.
            shares = [
              {
                tag = "ro-store";
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
                proto = "9p";
              }
              {
                tag = "dev";
                source = "${home}/dev";
                mountPoint = "/workspace";
                proto = "9p";
              }
            ];
            # SLiRP user networking: no host setup required.
            interfaces = [
              {
                type = "user";
                id = "qemu";
                mac = "02:00:00:01:01:01";
              }
            ];
            forwardPorts = [
              {
                host.port = 2222;
                guest.port = 22;
              }
            ];
            # Persistent docker data (docker on tmpfs would lose images).
            volumes = [
              {
                image = "docker-data.img";
                mountPoint = "/var/lib/docker";
                size = 8192;
              }
            ];
          };

          virtualisation.docker.enable = true;

          services.getty.autologinUser = "root";

          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };
          networking.firewall.allowedTCPPorts = [ 22 ];
          users.users.root.initialPassword = "toor";
        };
      };
    };
}
