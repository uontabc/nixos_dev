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
  #   nix run github:nix-community/disko -- --flake .#<name> --mode format,mount
  # (the devices definitions live in modules/hosts/<name>/_disko-devices.nix
  # and are reused both by the NixOS module and this flake output. Note:
  # `config.flake.modules.nixos.<name>` cannot be used here — flake-parts
  # wraps those modules as functions, so attribute access fails.)
  flake.diskoConfigurations = {
    uontabc.disko.devices = (import ./hosts/uontabc/_disko-devices.nix).disko.devices;
    laptop.disko.devices = (import ./hosts/laptop/_disko-devices.nix).disko.devices;
    oldpc.disko.devices = (import ./hosts/oldpc/_disko-devices.nix).disko.devices;
    vps.disko.devices = (import ./hosts/vps/_disko-devices.nix).disko.devices;
  };
}
