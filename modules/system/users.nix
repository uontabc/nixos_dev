{ lib, ... }: {
  flake.modules.nixos.users =
    { config, ... }:
    {
      options = {
        my.name = lib.mkOption {
          type = lib.types.str;
          default = "onyx";
        };

        my.packages = lib.mkOption {
          type = with lib.types; listOf package;
          default = [ ];
        };
      };

      config = {
        users.users.${config.my.name} = {
          isNormalUser = true;
          description = config.my.name;
          extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
          hashedPassword = "$6$D3UXt2pOU5LcOQtI$oY/oIdXkwUVNn8DPgAvWuVEb1Ywmx4fG/yl2pad46OT/UOCNY8yulNgwcIrmzt4fHdQC2AQI3.2xguP956f3C0";
          packages = config.my.packages;
        };

        security.sudo.enable = true;
      };
    };
}
