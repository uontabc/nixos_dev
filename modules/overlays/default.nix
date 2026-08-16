{
  flake.modules.nixos.overlays = _: {
    # QQ's bundled Chromium ignores `--ozone-platform-hint=auto` (the
    # wrapper's default) and falls back to XWayland; force the Wayland
    # backend explicitly.
    nixpkgs.overlays = [
      (_final: _prev: {
        qq = _prev.qq.override {
          commandLineArgs = [
            "--enable-features=UseOzonePlatform"
            "--ozone-platform=wayland"
            "--ozone-platform-hint=auto"
            "--enable-wayland-ime"
            "--wayland-text-input-version=3"
          ];
        };
      })
    ];
  };
}
