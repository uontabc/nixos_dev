{
  flake.modules.nixos.fonts =
    { pkgs, ... }: {
      fonts.packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-emoji
      ];

      fonts.fontconfig.defaultLocale = "zh_CN";
    };
}