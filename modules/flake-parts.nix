{ inputs, lib, ... }:
let
  # Packages whose unfree license we accept. Keep this list tight — the
  # previous `_ : true` whitelisted every unfree package.
  # (keep in sync with modules/base.nix's nixpkgs.config.allowUnfreePredicate)
  allowUnfreePredicate = pkg:
    lib.lists.any
      (n: lib.getName pkg == n)
      [
        "qq"        # Tencent QQ (lib.licenses.unfree)
        "helium"    # Helium browser (appimageTools wrapper defaults to unfree)
      ]
    || lib.hasPrefix "nvidia" (lib.getName pkg); # NVIDIA driver/settings/persistenced;
in
{
  imports = [ inputs.flake-parts.flakeModules.modules ];

  perSystem = { system, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfreePredicate = allowUnfreePredicate;
    };
  };
}
