{
  flake.modules.nixos.fonts =
    { pkgs, ... }: {
      fonts.packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        # Nerd Font patched Fantasque Sans Mono — required for the icons used
        # by nvim web-devicons/lualine/nvim-tree and kitty.
        nerd-fonts.fantasque-sans-mono
      ];

      fonts.fontconfig = {
        defaultFonts = {
          monospace = [ "FantasqueSansM Nerd Font Mono" ];
        };
      };
    };
}