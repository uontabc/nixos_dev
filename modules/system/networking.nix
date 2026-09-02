{ config, ... }: {
  flake.modules.nixos.network = {
    imports = with config.flake.modules.nixos; [
      daed
    ];

    networking.networkmanager.enable = true;
    networking.firewall.enable = true;

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };
}