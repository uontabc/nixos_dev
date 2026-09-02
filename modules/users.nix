{ lib, ... }: {
  flake.modules.nixos.users =
    { config, ... }:
    {
      options.my = {
        name = lib.mkOption {
          type = lib.types.str;
          default = "onyx";
        };

        packages = lib.mkOption {
          type = with lib.types; listOf package;
          default = [ ];
        };

        # SSH public keys for the primary user (empty by default). The
        # headless hosts (e.g. vps) set this — PasswordAuthentication is off
        # (modules/network.nix), so without keys you cannot SSH in.
        sshAuthorizedKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
      };

      config = {
        users.users.${config.my.name} = {
          isNormalUser = true;
          description = config.my.name;
          extraGroups = [
            "wheel"
            "networkmanager"
            "video"
            "audio"
            "input"
          ];
          hashedPassword = "$6$D3UXt2pOU5LcOQtI$oY/oIdXkwUVNn8DPgAvWuVEb1Ywmx4fG/yl2pad46OT/UOCNY8yulNgwcIrmzt4fHdQC2AQI3.2xguP956f3C0";
          openssh.authorizedKeys.keys = config.my.sshAuthorizedKeys;
          packages = config.my.packages;
        };

        security.sudo.enable = true;
      };
    };
}
