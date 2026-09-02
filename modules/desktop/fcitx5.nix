{
  flake.modules.nixos.fcitx5 =
    { pkgs, config, ... }:
    let
      # The active theme. Ori is not packaged in nixpkgs — fetch from upstream
      # and drop into the themes dir.
      fcitx5-ori = pkgs.stdenv.mkDerivation {
        pname = "fcitx5-theme-ori";
        version = "2026-08-16";
        src = pkgs.fetchFromGitHub {
          owner = "Reverier-Xu";
          repo = "Ori-fcitx5";
          rev = "d2cf5df38f11e4e14dcf9436af5b9f8fa0087c55";
          sha256 = "104hj2a9vj3s1sv43pgfdqdq28fa5badpsr6c1j3b1k94k0bz8z3";
        };
        installPhase = ''
          runHook preInstall
          mkdir -p $out/share/fcitx5/themes
          cp -r OriDark OriLight $out/share/fcitx5/themes/
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
          # The only theme we use (OriDark); switch to OriLight or use
          # fcitx5-configtool at runtime.
          fcitx5-ori
        ];

        # Select the active theme (classicui). Use fcitx5-configtool to switch
        # at runtime. Font bumped to 14pt — the default 10pt renders tiny on
        # the 1.5x scaled display (QQ/Electron in particular).
        fcitx5.settings.addons.classicui.globalSection = {
          Theme = "OriDark";
          Font = "Sans 12";
          MenuFont = "Sans 12";
          TrayFont = "Sans Bold 12";
        };
      };

      # Rime schema activated via ~/.local/share/fcitx5/rime — managed by hjem
      # (modules/hjem.nix). The rime dir itself is created by the linker; only
      # the .custom.yaml is declared (fcitx5 writes its own files alongside).
      hjem.users.${config.my.name}.xdg.data.files."fcitx5/rime/default.custom.yaml" = {
        source = defaultCustom;
        clobber = true;
      };
    };
}
