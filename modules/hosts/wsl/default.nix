{ config, ... }: {
  hosts.wsl = {
    system = "x86_64-linux";
    stateVersion = "26.05";
    module =
      { ... }: {
        # `base` is injected unconditionally by the host factory
        # (lib/nixos.nix), and `wsl` (modules/wsl.nix) is auto-attached via
        # `optional (nixos ? ${name}) nixos.${name}` — neither needs an
        # explicit import here, and importing base again would double-declare
        # every option inside it.
        #
        # No boot/network/hardware/desktop/impermanence: WSL provides its own
        # kernel, network and display (WSLg). This is a terminal-only distro.

        vaultix.settings = {
          # sshd is disabled on this host, so host keys are never generated —
          # vaultix decrypts secrets with this dedicated key instead.
          hostKeys = [
            {
              path = "/etc/ssh/ssh_host_ed25519_key";
              type = "ed25519";
            }
          ];
          hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZ2ZTdB7qpgtPQW2hg2yog8nKaK8bRL7qYzK/EoKkrN root@wsl";
        };

        vaultix.secrets.example = { };
      };
  };
}