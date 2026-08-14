{
  flake.modules.nixos.fonts =
    { pkgs, ... }: {
      fonts.packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        # Nerd Font patched JetBrains Mono — required for the icons used by
        # nvim web-devicons/lualine/nvim-tree and kitty.
        nerd-fonts.jetbrains-mono
      ];

      fonts.fontconfig = {
        defaultFonts = {
          monospace = [ "JetBrainsMono Nerd Font" ];
        };
      };
    };
}