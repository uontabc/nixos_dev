{
  # File manager, ported from the old codeberg nix-config repo (NixOS-only
  # half; the home-manager part is dropped since this repo has no
  # home-manager). Imports are all system-level (gvfs/tumbler services +
  # programs.thunar), so nothing user-level is lost.
  flake.modules.nixos.thunar =
    { pkgs, ... }:
    {
      services = {
        gvfs.enable = true;
        tumbler.enable = true;
      };

      programs.thunar = {
        enable = true;
        plugins = with pkgs; [
          thunar-archive-plugin
          thunar-media-tags-plugin
          thunar-volman
        ];
      };
    };
}
