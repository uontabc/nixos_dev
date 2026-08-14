{ inputs, self, ... }: {
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

        # Bake the flake source (self.outPath — already a store path, no
        # cleanSource copy of the repo root which would recurse) into the
        # tarball's /etc/nixos. After `wsl --import`, the full configuration
        # is present — run `nixos-rebuild switch --flake /etc/nixos#wsl`.
        tarball.configPath = self.outPath;
      };

      system.stateVersion = "26.05";
    };
}