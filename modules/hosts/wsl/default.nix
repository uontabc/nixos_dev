{
  hosts.wsl = {
    system = "x86_64-linux";
    stateVersion = "26.05";
    module =
      { config, ... }: {
        # `wsl` (modules/wsl.nix) is auto-attached by the host factory via
        # `optional (nixos ? ${name}) nixos.${name}` — the module name matches
        # this hostname. No need to import it here.
        imports = with config.flake.modules.nixos; [
          base
        ];

        # No boot/network/hardware/desktop/impermanence: WSL provides its own
        # kernel, network and display (WSLg). This is a terminal-only distro.
      };
  };
}