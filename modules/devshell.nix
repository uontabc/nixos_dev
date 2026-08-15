{ ... }: {
  perSystem = { pkgs, ... }: {
    devShells.default = pkgs.mkShell {
      packages = [
        pkgs.lix
        pkgs.nh
        pkgs.nixfmt
        pkgs.statix
        pkgs.git
      ];
    };
  };
}
