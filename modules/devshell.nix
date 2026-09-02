{ ... }: {
  perSystem =
    { pkgs, inputs', ... }:
    let
      starshipConfig = (import ./_starship-theme.nix { inherit pkgs; }).devshell;
    in
    {
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.lix
          pkgs.nh
          pkgs.nixfmt
          pkgs.statix
          pkgs.git
          pkgs.fish
          # Lockfile-pinned disko CLI: `disko --flake .#uontabc --mode format,mount`
          # (avoids `nix run github:...` which fails with Connection error in CN).
          inputs'.disko.packages.disko
        ];
        IN_NIX_SHELL = "impure";
        STARSHIP_CONFIG = starshipConfig;
        shellHook = ''
          if [ -n "$PS1" ]; then
            export SHELL=${pkgs.fish}/bin/fish
            exec ${pkgs.fish}/bin/fish
          fi
        '';
      };
    };
}
