{ ... }: {
  perSystem =
    { pkgs, inputs', ... }:
    let
      starshipConfig = (import ../starship-theme.nix { inherit pkgs; }).devshell;
    in
    {
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.lix
          pkgs.nh
          pkgs.nixfmt
          pkgs.statix
          pkgs.git
          pkgs.zsh
          # Lockfile-pinned disko CLI: `disko --flake .#uontabc --mode format,mount`
          # (avoids `nix run github:...` which fails with Connection error in CN).
          inputs'.disko.packages.disko
        ];
        IN_NIX_SHELL = "impure";
        STARSHIP_CONFIG = starshipConfig;
        shellHook = ''
          if [ -n "$PS1" ]; then
            export SHELL=${pkgs.zsh}/bin/zsh
            exec ${pkgs.zsh}/bin/zsh
          fi
        '';
      };
    };
}
