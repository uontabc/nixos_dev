{
  inputs,
  config,
  ...
}: {
  imports = [ inputs.disko.flakeModules.disko ];

  flake.modules.nixos.disko.imports = [
    inputs.disko.nixosModules.default
  ];

  # Expose the uontabc disko layout as `diskoConfigurations.uontabc` so the
  # disko CLI / disko-install work directly:
  #   nix run github:nix-community/disko -- --flake .#uontabc --mode format,mount
  # (the devices definition lives in modules/hosts/uontabc/disko.nix and is
  # reused both by the NixOS module and this flake output).
  flake.diskoConfigurations.uontabc = {
    disko.devices = config.flake.modules.nixos.uontabc.disko.devices;
  };
}
