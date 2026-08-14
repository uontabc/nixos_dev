{ inputs, config, withSystem, lib, self, ... }:
let
  inherit (inputs.nixpkgs.lib) mapAttrs nixosSystem optional;
in
{
  options.hosts = lib.mkOption {
    type = lib.types.lazyAttrsOf (lib.types.submodule {
      options = {
        system = lib.mkOption { type = lib.types.str; };
        stateVersion = lib.mkOption { type = lib.types.str; };
        module = lib.mkOption { type = lib.types.deferredModule; };
      };
    });
    default = { };
  };

  config.flake.nixosConfigurations = mapAttrs (
    name: host:
    withSystem host.system (
      { pkgs, ... }:
      nixosSystem {
        inherit pkgs;
        # Required by the vaultix NixOS module (locates the re-encrypted
        # secret cache under the flake source).
        specialArgs = { inherit self; };
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
    )
  ) config.hosts;
}