{ config, ... }: {
  hosts.wsl = {
    system = "x86_64-linux";
    stateVersion = "26.05";
    module =
      { pkgs, ... }: {
        # `base` is injected unconditionally by the host factory
        # (lib/nixos.nix), and `wsl` (modules/wsl.nix) is auto-attached via
        # `optional (nixos ? ${name}) nixos.${name}` — neither needs an
        # explicit import here, and importing base again would double-declare
        # every option inside it.
        #
        # No boot/network/hardware/desktop/impermanence: WSL provides its own
        # kernel, network and display (WSLg). This is a terminal-only distro.

        vaultix.settings = {
          # sshd is disabled on this host, so OpenSSH would never generate a
          # host key. Vaultix decrypts the per-host re-encrypted cache with
          # this dedicated ed25519 key instead (see vaultix-hostkey.service
          # below, which creates it if missing).
          hostKeys = [
            {
              path = "/etc/ssh/ssh_host_ed25519_key";
              type = "ed25519";
            }
          ];
          # Must match the private key at /etc/ssh/ssh_host_ed25519_key.
          # The committed cache (secrets/cache/wsl/) was re-encrypted to THIS
          # pubkey, so a different key means age decryption fails at boot —
          # vaultix-hostkey.service verifies this and tells you how to fix.
          hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZ2ZTdB7qpgtPQW2hg2yog8nKaK8bRL7qYzK/EoKkrN root@wsl";
        };

        vaultix.secrets.example = { };

        # vaultix-activate runs at sysinit.target; make sure the decryption
        # key always exists before it, and that it actually matches the
        # configured hostPubkey. A fresh WSL import regenerates a random key
        # which would silently invalidate every age secret — detect and report
        # that instead of failing cryptically.
        systemd.services.vaultix-hostkey = {
          description = "Provision and verify vaultix ed25519 host key";
          wantedBy = [ "sysinit.target" ];
          before = [ "vaultix-activate.service" ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = ''
            set -e
            key=/etc/ssh/ssh_host_ed25519_key
            mkdir -p /etc/ssh
            chmod 0755 /etc/ssh

            if [ ! -s "$key" ]; then
              echo "[vaultix] generating missing host key $key"
              ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -f "$key" -N "" -C root@wsl
            fi

            actual="$(${pkgs.openssh}/bin/ssh-keygen -y -f "$key" | ${pkgs.coreutils}/bin/cut -d' ' -f1-2)"
            expected="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZ2ZTdB7qpgtPQW2hg2yog8nKaK8bRL7qYzK/EoKkrN"
            if [ "$actual" != "$expected" ]; then
              echo "[vaultix] FATAL: host key does not match the configured hostPubkey." >&2
              echo "  actual:   $actual" >&2
              echo "  expected: $expected" >&2
              echo "  Fix: update vaultix.settings.hostPubkey in modules/hosts/wsl/default.nix" >&2
              echo "       to the actual pubkey, then run on a machine with the identity:" >&2
              echo "         nix run .#vaultix.app.x86_64-linux.renc" >&2
              echo "         git add secrets/cache && git commit" >&2
              exit 1
            fi
          '';
        };
      };
  };
}