{ ... }: {
  perSystem =
    { pkgs, ... }:
    let
      starshipConfig = (import ./config/_starship-theme.nix { inherit pkgs; }).devshell;
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
