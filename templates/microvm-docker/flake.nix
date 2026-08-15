{
  description = "MicroVM with docker for isolated development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
    }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.docker-dev = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          microvm.nixosModules.microvm
          (
            { lib, ... }:
            {
              system.stateVersion = "26.05";
              networking.hostName = "docker-dev";

              microvm = {
                hypervisor = "qemu";
                # Not exactly 2048MiB: QEMU hangs with exactly 2GB guest memory.
                mem = 2560;
                vcpu = 2;
                shares = [
                  {
                    tag = "ro-store";
                    source = "/nix/store";
                    mountPoint = "/nix/.ro-store";
                    proto = "9p";
                  }
                ];
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
              };

              virtualisation.docker.enable = true;

              services.getty.autologinUser = "root";

              services.openssh = {
                enable = true;
                settings.PermitRootLogin = "yes";
              };
              networking.firewall.allowedTCPPorts = [ 22 ];
            }
          )
        ];
      };

      apps.${system}.default = {
        type = "app";
        program = "${self.nixosConfigurations.docker-dev.config.microvm.declaredRunner}/bin/microvm-run";
      };
    };
}
