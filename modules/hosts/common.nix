{
  inputs,
  config,
  ...
}:
let
  inherit (inputs.nixpkgs.lib) nixosSystem;
  inherit (inputs.nixpkgs.lib.lists) singleton;

  # Every host pulls a profile: a list of module names
  # (flake.modules.nixos.<name>) that kind of machine needs. `base` is
  # always included (users/nix/i18n/env/nh/git/neovim/pi/zsh) and the
  # nixvim NixOS module is injected by mkHostConfiguration below.
  hostProfiles = {
    # Bare-metal desktop: AMD + NVIDIA, niri Wayland, btrfs + impermanence,
    # GRUB. Imports mirror the old uontabc host definition.
    desktop = {
      nixosModules = [
        "base"
        "boot"
        "network"
        "hardware"
        "desktop"
        "overlays"
        "impermanence"
        "disko"
      ];
    };

    # Headless NixOS-WSL guest: no boot/network/hardware/desktop/
    # impermanence — WSL provides its own kernel, network and display.
    wsl = {
      nixosModules = [
        "base"
        "wsl"
      ];
    };
  };

  # Build a host NixOS configuration from a profile plus host-specific
  # extras (modules/hosts/<name>/configuration.nix).
  mkHostConfiguration =
    {
      hostName,
      system ? "x86_64-linux",
      stateVersion ? "26.05",
      nixosModules,
      extraImports ? [ ],
      extraConfig ? (_: { }),
    }:
    let
      mod = config.flake.modules.nixos;
    in
    nixosSystem {
      modules = singleton (
        # Destructure the standard module args explicitly: NixOS only injects
        # `pkgs`/`lib`/`config` into modules whose *formals* declare them
        # (functionArgs-driven `_module.args` fallback), so a bare `args:`
        # lambda would receive a set without `pkgs` and extraConfig would
        # fail with "called without required argument 'pkgs'".
        {
          config,
          lib,
          pkgs,
          ...
        }@args:
        {
          imports =
            (map (name: mod.${name}) nixosModules)
            ++ [
              inputs.nixvim.nixosModules.nixvim
            ]
            ++ extraImports;

          _module.args = { inherit hostName; };

          nixpkgs.hostPlatform = system;
          system.stateVersion = stateVersion;
          networking.hostName = hostName;
        }
        // extraConfig args
      );
    };
in
{
  # Re-export the disko layout factories (codeberg nix-config style):
  #   lib.mkPartitionConfig { esp = ...; root = ...; }  (dual-boot, uontabc)
  #   lib.mkDiskConfig { device = ...; swapSize = ...; } (whole disk)
  flake.lib =
    let
      inherit (import ../system/_disko-lib.nix { lib = inputs.nixpkgs.lib; })
        mkDiskConfig
        mkPartitionConfig
        ;
    in
    {
      inherit
        hostProfiles
        mkHostConfiguration
        mkDiskConfig
        mkPartitionConfig
        ;
    };
}
