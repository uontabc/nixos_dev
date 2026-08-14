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
          description = "onyx";
          extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
          initialPassword = "changeme";
          packages = config.my.packages;
        };

        security.sudo.enable = true;
      };
    };
}