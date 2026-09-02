{ inputs, ... }: {
  flake.modules.nixos.noctalia =
    { pkgs, config, ... }:
    let
      # The config lives in the Nix store, so inotify hot-reload won't trigger;
      # after switching, reload the shell explicitly through IPC instead.
      noctaliaConfig = pkgs.writeText "noctalia-config.toml" ''
        # Declarative Noctalia shell config — managed from modules/desktop/noctalia.nix.
        # Changes hot-reload via inotify; startup-only settings are noted inline.

        [accessibility]
        ui_scale = 1.0

        [shell]
        font_family  = "FantasqueSansM Nerd Font Mono"
        time_format  = "{:%H:%M:%S}"
        date_format  = "%A, %x"
        polkit_agent = true
        lang        = "zh-Hans"
        external_ip_enabled                   = true
        niri_overview_type_to_launch_enabled  = true

        [shell.panel]
        transparency_mode = "solid"

        [shell.launcher]
        show_icons    = true
        sort_by_usage = true

        [theme]
        mode    = "dark"
        source  = "builtin"
        builtin = "Tokyo-Night"

        [plugins]
        enabled     = ["noctalia/screen_recorder", "kenn/keybind-cheatsheet"]
        auto_update = false

        # The built-in official/community git sources can't be cloned reliably on
        # this network, so disable them and ship the plugins we use through a
        # declarative path source instead (files fetched at build time; see the
        # `pluginsDir` derivation below).
        [[plugins.source]]
        name     = "official"
        kind     = "git"
        location = "https://github.com/noctalia-dev/official-plugins"
        enabled  = false

        [[plugins.source]]
        name     = "community"
        kind     = "git"
        location = "https://github.com/noctalia-dev/community-plugins"
        enabled  = false

        [[plugins.source]]
        name     = "nix"
        kind     = "path"
        location = "${pluginsDir}"
        enabled  = true

        [notification]
        enable_daemon = true

        [osd]
        position = "top_right"

        [backdrop]
        enabled        = true
        # Defaults blur/tint the wallpaper; zero them out for a sharp look.
        blur_intensity = 0.5
        tint_intensity = 0.3

        [wallpaper]
        directory  = "${home}/Pictures/Wallpapers"
        fill_mode  = "crop"

        [lockscreen]
        enabled         = true
        blurred_desktop = true
        blur_intensity  = 0.5
        tint_intensity  = 0.3

        [system.monitor]
        enabled = true

        [brightness]
        enable_ddcutil = true

        [idle.behavior.lock]
        timeout = 600
        action  = "lock"
        enabled = true

        [idle.behavior.screen-off]
        timeout = 660
        action  = "screen_off"
        enabled = true

        [bar.main]
        position      = "top"
        thickness     = 34
        radius        = 12
        margin_ends   = 180
        margin_edge   = 10
        padding       = 14
        reserve_space = true

        start  = ["workspaces"]
        center = ["clock"]
        end    = ["notifications", "network", "volume", "brightness", "battery", "tray", "noctalia/screen_recorder:recorder", "kenn/keybind-cheatsheet:keybinds", "session"]

        [widget.notifications]
        hide_when_no_unread = true

        [widget.clock]
        format = "{:%H:%M:%S}"
      '';
      # GTK icon theme selection so noctalia's icon resolver searches Papirus.
      # Font also pinned here so GTK apps match the global fontconfig defaults
      # (see modules/config/fonts.nix) instead of their per-theme default.
      gtkSettings = pkgs.writeText "gtk-settings.ini" ''
        [Settings]
        gtk-icon-theme-name=Papirus
        gtk-font-name=FantasqueSansM Nerd Font Mono 12
      '';
      # Plugins for noctalia, shipped through a `path` source (see [plugins] above).
      # Files come from the upstream repos' raw.githubusercontent (reliable CDN)
      # instead of git cloning, which times out on this network.
      pluginFile =
        repo: path: hash:
        pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/noctalia-dev/${repo}/main/${path}";
          sha256 = hash;
        };
      sr = name: hash: pluginFile "official-plugins" "screen_recorder/${name}" hash;
      kc = name: hash: pluginFile "community-plugins" "keybind-cheatsheet/${name}" hash;
      pluginsDir = pkgs.runCommand "noctalia-plugins" { } ''
        mkdir -p $out/screen_recorder/translations
        mkdir -p $out/keybind-cheatsheet/translations
        cp ${sr "plugin.toml" "sha256-GoxyQ3JbCMgv7IAGVKsykzlIjAKmEQ5uEvsxDC62Pm8="} $out/screen_recorder/plugin.toml
        cp ${sr "recorder.luau" "sha256-DVn0dCnQBCqkNU/7j3f8GoHrFd7v/JQS3YqM/A7xXto="} $out/screen_recorder/recorder.luau
        cp ${sr "recorder_service.luau" "sha256-nHkLLwWHUzvLVz5S0IHZeuI1TOv9udiTAzraLrL9jSI="} $out/screen_recorder/recorder_service.luau
        cp ${sr "shortcut.luau" "sha256-v5wgW2EmxHwOPUPjqcSIXn54hHmlDB/pQYoafZs672k="} $out/screen_recorder/shortcut.luau
        cp ${sr "translations/en.json" "sha256-1gom+FlRbBR0is+k1rpbxbrKxKDdMfYh9Lqf7kcAZCE="} $out/screen_recorder/translations/en.json
        cp ${sr "translations/zh-Hans.json" "sha256-Ku6F1oYKgcI1qafv5mI4ijJv/t+TURC7LJa3j7v3pAo="} $out/screen_recorder/translations/zh-Hans.json
        cp ${kc "plugin.toml" "sha256-rYyyIEUAePz5nT+t8P6zD7mY4EmEk3RtQC3eMG1Hz2c="} $out/keybind-cheatsheet/plugin.toml
        cp ${kc "service.luau" "sha256-oC4J2xawvmBlbVmPqFRDioCPlovwlkaMIW6xGirahqU="} $out/keybind-cheatsheet/service.luau
        cp ${kc "panel.luau" "sha256-LvSoHY8iaefPBZpK0v2o5ZlbG5gm7q/oO4RVmmvLkhw="} $out/keybind-cheatsheet/panel.luau
        cp ${kc "widget.luau" "sha256-QWDjdX9gn42nu7N9VLxKUvMQ0UOMH8Dqj/yCrJvKS/I="} $out/keybind-cheatsheet/widget.luau
        cp ${kc "translations/en.json" "sha256-OA4ygCTEBhzSw59na41b1NTKlMJPyxXv6MANl4Cu8bM="} $out/keybind-cheatsheet/translations/en.json
      '';
      home = "/home/${config.my.name}";
    in
    {
      imports = [ inputs.noctalia.nixosModules.default ];

      programs.noctalia = {
        enable = true;
        systemd.enable = true;
        # Pulls in NetworkManager, Bluetooth, UPower and power-profiles-daemon
        # (all mkDefault, so the explicit modules elsewhere still win).
        recommendedServices.enable = true;
      };

      security.polkit.enable = true;
      services.gnome.gnome-keyring.enable = true;
      # gnome-keyring's own module only wires PAM for `login`; this machine
      # logs in via greetd/tuigreet (PAM service `greetd`), so unlock it there.
      security.pam.services.greetd.enableGnomeKeyring = true;

      # Noctalia resolves tray/appindicator icons by name against the active
      # GTK icon theme (GSettings org.gnome.desktop.interface, then
      # ~/.config/gtk-{3,4}.0/settings.ini). NixOS ships only the empty hicolor
      # fallback, so named icons like nm-applet's `nm-signal-50` fail to resolve
      # and noctalia draws its "three-bars" menu-2 fallback glyph. Papirus
      # carries those status icons; the settings.ini below selects it.
      environment.systemPackages = [
        pkgs.ddcutil
        pkgs.papirus-icon-theme
        # System dependency of the screen_recorder plugin (GPU Screen Recorder).
        pkgs.gpu-screen-recorder
      ];

      # User config files managed by hjem (modules/hjem.nix). Noctalia
      # resolves tray icons against settings.ini, so the gtk dirs must be
      # user-owned — the hjem linker creates them as the user, which avoids
      # the unsafe-path-transition issue the old tmpfiles rules had.
      hjem.users.${config.my.name} = {
        xdg.config.files = {
          "noctalia/config.toml" = {
            source = noctaliaConfig;
            clobber = true;
          };
          "gtk-3.0/settings.ini" = {
            source = gtkSettings;
            clobber = true;
          };
          "gtk-4.0/settings.ini" = {
            source = gtkSettings;
            clobber = true;
          };
        };
        # Runtime state noctalia writes on first start (settings, state,
        # clipboard history, community cache). Ensure it exists even on the
        # very first boot before impermanence has seeded it.
        xdg.state.files."noctalia" = {
          type = "directory";
          permissions = "0755";
        };
      };
    };
}
