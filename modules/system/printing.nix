{
  # CUPS printing + Avahi discovery, ported from the old nix-config repo
  # (codeberg.org/uontabc/nix-config). Desktop hosts import it via
  # modules/desktop/default.nix.
  flake.modules.nixos.printing =
    { pkgs, ... }:
    {
      services = {
        avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
        };

        printing = {
          enable = true;

          drivers = [
            pkgs.cups-browsed
            pkgs.cups-filters
          ];
        };
      };
    };
}
