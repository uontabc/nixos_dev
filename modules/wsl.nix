{ inputs, ... }: {
  flake.modules.nixos.wsl =
    { config, lib, ... }: {
      imports = [ inputs.nixos-wsl.nixosModules.wsl ];

      wsl = {
        enable = true;
        # Match the primary user from modules/users.nix.
        defaultUser = config.my.name;
        # Use the Windows host's OpenGL/Vulkan driver (WSLg).
        useWindowsDriver = true;
        startMenuLaunchers = true;

        # Bake this entire flake (this file is modules/wsl.nix, so ../. is the
        # repository root) into the tarball's /etc/nixos. After `wsl --import`,
        # the full configuration is already present — just run
        # `nixos-rebuild switch --flake /etc/nixos#wsl` (or clone elsewhere and
        # use nh) to activate. Without this, the tarball only contains a
        # minimal NixOS-WSL config and you would have to clone the repo inside
        # the distro manually.
        tarball.configPath = lib.cleanSource ../.;
      };

      system.stateVersion = "26.05";
    };
}