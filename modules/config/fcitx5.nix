{
  flake.modules.nixos.fcitx5 =
    { pkgs, config, ... }:
    let
      home = "/home/${config.my.name}";
      rimeDir = "${home}/.local/share/fcitx5/rime";

      # fcitx5 macOS-style theme (macos12-dark / macos12-light), not packaged
      # in nixpkgs — fetch from upstream and drop into the themes dir.
      fcitx5-macos12 = pkgs.stdenv.mkDerivation {
        pname = "fcitx5-theme-macos12";
        version = "2024-11-17";
        src = pkgs.fetchFromGitHub {
          owner = "witt-bit";
          repo = "fcitx5-theme-macos12";
          rev = "ff92fdedb320a52c23b6eb8c20f1c012f9c313fe";
          sha256 = "0lw9ipw462k71yw6chp23c4gngiplmwbyqf6vpxs3w49z7xzfi8z";
        };
        installPhase = ''
          runHook preInstall
          mkdir -p $out/share/fcitx5/themes
          cp -r macos12-dark macos12-light $out/share/fcitx5/themes/
          runHook postInstall
        '';
      };

      # Activate the rime-ice schema and the upstream default settings
      # (scheme list, switches, etc.). rime-ice ships the upstream
      # default.yaml as rime_ice_suggestion.yaml; see rime-ice.meta.longDescription.
      defaultCustom = pkgs.writeText "fcitx5-rime-default.custom.yaml" ''
        patch:
          __include: rime_ice_suggestion:/
      '';
    in
    {
      i18n.inputMethod = {
        enable = true;
        type = "fcitx5";
        fcitx5.addons = [
          # Ship rime-ice instead of the default rime-data as the shared
          # rime dictionary data.
          (pkgs.fcitx5-rime.override { rimeDataPkgs = [ pkgs.rime-ice ]; })
          pkgs.fcitx5-gtk
          pkgs.qt6Packages.fcitx5-qt
          pkgs.qt6Packages.fcitx5-configtool
          # UI themes. Available variants:
          #   macOS:       macos12-dark (active), macos12-light
          #   Nord:        Nord-Dark, Nord-Light
          #   Material:    Material-Color-{black, blue, brown, deepPurple,
          #                indigo, orange, pink, red, sakuraPink, teal}
          fcitx5-macos12
          pkgs.fcitx5-nord
          pkgs.fcitx5-material-color
        ];

        # Select the active theme (classicui). Switch the `Theme` value below
        # to any variant above, or use `fcitx5-configtool` at runtime.
        fcitx5.settings.addons.classicui.globalSection = {
          Theme = "macos12-dark";
        };
      };

      systemd.tmpfiles.rules = [
        "d ${home}/.local/share/fcitx5 0755 ${config.my.name} users -"
        "d ${rimeDir} 0755 ${config.my.name} users -"
        "L+ ${rimeDir}/default.custom.yaml - - - - ${defaultCustom}"
      ];
    };
}
