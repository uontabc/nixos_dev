{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption;
  inherit (lib.lists) singleton;
  # flake-parts' lib is the trimmed nixpkgs-lib (no nixosSystem); the full
  # one comes from the nixpkgs input.
  inherit (inputs.nixpkgs.lib) nixosSystem;

  # Every host pulls a profile: a list of module names
  # (flake.modules.nixos.<name>) that kind of machine needs. `base` is
  # always included (users/nix/i18n/env/nh/git/neovim/pi/zsh).
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
          imports = (map (name: mod.${name}) nixosModules) ++ extraImports;

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
  # flake-parts treats undeclared `flake.*` attrs as freeform+unique (cannot
  # be defined twice). Declare `flake.lib` as a mergeable attrset so this
  # module (hostProfiles/mkHostConfiguration) and modules/system/disko.nix
  # (mkDiskConfig/mkPartitionConfig) can both contribute to it.
  options.flake.lib = mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
  };

  config.flake.lib = {
    inherit hostProfiles mkHostConfiguration;
  };
}
