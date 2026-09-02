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

        # HTTP(S) proxy for the pi coding agent (settings.json httpProxy,
        # applied as HTTP_PROXY/HTTPS_PROXY). Needed when api.deepseek.com is
        # unreachable directly and pi fails with "Error: Connection error." —
        # point it at your local proxy, e.g. "http://127.0.0.1:7890".
        piHttpProxy = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
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
          packages = config.my.packages;
        };

        security.sudo.enable = true;
      };
    };
}
