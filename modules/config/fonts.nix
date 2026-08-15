{
  flake.modules.nixos.fonts =
    { pkgs, ... }: {
      fonts.packages = with pkgs; [
        noto-fonts
        noto-fonts-color-emoji
        # Nerd Font patched Fantasque Sans Mono — required for the icons used
        # by nvim web-devicons/lualine/nvim-tree and kitty.
        nerd-fonts.fantasque-sans-mono
        # LXGW WenKai — the CJK (Chinese) UI/sans font.
        lxgw-wenkai
      ];

      fonts.fontconfig = {
        defaultFonts = {
          # English/Latin text uses Fantasque Sans Mono (Nerd Font), Chinese
          # falls back to LXGW WenKai. Fontconfig matches by charset, so each
          # script picks its own face from the list.
          monospace = [ "FantasqueSansM Nerd Font Mono" "LXGW WenKai" ];
          sansSerif = [ "FantasqueSansM Nerd Font Mono" "LXGW WenKai" ];
          serif = [ "FantasqueSansM Nerd Font Mono" "LXGW WenKai" ];
        };
      };
    };
}
