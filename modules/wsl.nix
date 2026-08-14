{ inputs, ... }: {
  flake.modules.nixos.wsl =
    { config, ... }: {
      imports = [ inputs.nixos-wsl.nixosModules.wsl ];

      wsl = {
        enable = true;
        # Match the primary user from modules/users.nix.
        defaultUser = config.my.name;
        # Use the Windows host's OpenGL/Vulkan driver (WSLg).
        useWindowsDriver = true;
        startMenuLaunchers = true;
      };

      # WSL distro is a terminal environment: no bootloader, no kernel —
      # handled by the WSL module itself.
      system.stateVersion = "26.05";
    };
}