{
  # Named after the host: the host factory in lib/nixos.nix auto-attaches
  # `flake.modules.nixos.<hostname>` to the matching host via
  # `optional (nixos ? ${name}) nixos.${name}`.
  #
  # The actual partition layout lives in ./_disko-devices.nix (single source
  # of truth, shared with the diskoConfigurations.vps flake output). The file
  # is underscore-prefixed so import-tree does NOT import it as a
  # flake-parts module (`disko.*` is not a flake-parts option).
  flake.modules.nixos.vps = ./_disko-devices.nix;
}
