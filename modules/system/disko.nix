{
  inputs,
  config,
  ...
}:
{
  imports = [ inputs.disko.flakeModules.disko ];

  flake.modules.nixos.disko.imports = [
    inputs.disko.nixosModules.default
  ];

  # Expose each host's disko layout as `diskoConfigurations.<name>` so the
  # disko CLI / disko-install work directly:
  #   nix run github:nix-community/disko -- --flake .#uontabc --mode format,mount
  # (the devices definitions live in modules/hosts/<name>/_disko-devices.nix
  # and are reused both by the NixOS module and this flake output. Note:
  # `config.flake.modules.nixos.uontabc` cannot be used here — flake-parts
  # wraps those modules as functions, so attribute access fails.)
  flake.diskoConfigurations.uontabc = {
    disko.devices =
      (import ../hosts/uontabc/_disko-devices.nix {
        lib = inputs.nixpkgs.lib;
      }).disko.devices;
  };
}
