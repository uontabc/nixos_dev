{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (inputs.nixpkgs.lib) mapAttrs nixosSystem optional;
in
{
  options.hosts = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          system = lib.mkOption { type = lib.types.str; };
          stateVersion = lib.mkOption { type = lib.types.str; };
          module = lib.mkOption { type = lib.types.deferredModule; };
        };
      }
    );
    default = { };
  };

  config.flake.nixosConfigurations = mapAttrs (
    name: host:
    nixosSystem {
      modules =
        let
          nixos = config.flake.modules.nixos;
        in
        [
          inputs.nixvim.nixosModules.nixvim
          host.module
          nixos.base
          { system.stateVersion = host.stateVersion; }
          {
            networking.hostName = name;
            nixpkgs.hostPlatform = host.system;
          }
        ]
        ++ optional (nixos ? ${name}) nixos.${name};
    }
  ) config.hosts;
}
