{
  config,
  ...
}:
let
  inherit (config.flake.lib) mkHostConfiguration;
in
{
  flake.nixosConfigurations.wsl = mkHostConfiguration {
    hostName = "wsl";
    inherit (config.flake.lib.hostProfiles.wsl) nixosModules;
  };
}
