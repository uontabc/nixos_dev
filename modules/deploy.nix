{
  # deploy-rs nodes for the remote hosts, ported from the old nix-config repo
  # (codeberg.org/uontabc/nix-config):
  #   nix run .#deploy-rs -- .#vps
  #   nix run .#deploy-rs -- .        # all nodes
  # (the `deploy` CLI ships in the devshell too, see modules/devshell.nix)
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (lib.options) mkOption;
  inherit (lib.types) submodule lazyAttrsOf anything;

  system = "x86_64-linux";
  inherit (inputs.deploy-rs.lib.${system}) activate;

  mkNode = name: {
    hostname = name;
    profiles.system = {
      user = "root";
      sshUser = "root";
      path = activate.nixos config.flake.nixosConfigurations.${name};
    };
  };
in
{
  options.flake.deploy = mkOption {
    default = { };
    type = submodule {
      options.nodes = mkOption {
        default = { };
        type = lazyAttrsOf anything;
      };
    };
  };

  config.flake.deploy.nodes = {
    laptop = mkNode "laptop";
    oldpc = mkNode "oldpc";
    vps = mkNode "vps";
  };
}
