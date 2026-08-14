{
  hosts.wsl = {
    system = "x86_64-linux";
    stateVersion = "26.05";
    module =
      { ... }: {
        # base is auto-attached by the host factory (lib/nixos.nix adds
        # nixos.base to every host) — importing it here again would
        # double-declare options (e.g. my.name from users.nix).
        #
        # `wsl` (modules/wsl.nix) is auto-attached the same way, because the
        # module name matches this hostname (optional (nixos ? ${name}) ...).
        # So this module only holds host-specific overrides — none needed.
      };
  };
}