{
  flake.modules.nixos.niri =
    { pkgs, config, ... }:
    let
      niriConfig = pkgs.writeText "niri-config.kdl" ''
        // Ask clients to omit their decorations so niri draws consistent
        // frames that follow the window corner radius below.
        prefer-no-csd

        // Four permanent workspaces, always present in the bar.
        workspace "1"
        workspace "2"
        workspace "3"
        workspace "4"

        input {
            keyboard {
                xkb {
                    layout "us"
                }
                numlock
                repeat-rate 25
                repeat-delay 600
            }

            touchpad {
                tap
                dwt
                drag-lock
            }

            mouse {
                accel-profile "flat"
            }
        }

        environment {
            QT_QPA_PLATFORMTHEME "qt6ct"
            QT_QPA_PLATFORM "wayland;xcb"
            XDG_CURRENT_DESKTOP "niri"
            XDG_SESSION_TYPE "wayland"
            XDG_SESSION_DESKTOP "niri"
            XKB_DEFAULT_LAYOUT "us"
        }

        spawn-at-startup "fcitx5" "-d"
        // Open a terminal on login; always-center-single-column below makes it
        // fill a single centered column (margins on both sides).
        spawn-at-startup "kitty"

        binds {
            Mod+Shift+E { quit; }
            Mod+Q { close-window; }

            Mod+D  { spawn "noctalia" "msg" "panel-toggle" "launcher"; }
            Mod+S      { spawn "noctalia" "msg" "panel-toggle" "control-center"; }
            Mod+Comma  { spawn "noctalia" "msg" "settings-toggle"; }

            Mod+Return { spawn "kitty"; }
            Mod+E      { spawn "kitty" "-e" "yazi"; }
            // Mod+Shift+E { spawn "kitty" "-e" "spf"; }

            XF86AudioRaiseVolume  { spawn "noctalia" "msg" "volume-up"; }
            XF86AudioLowerVolume  { spawn "noctalia" "msg" "volume-down"; }
            XF86AudioMute         { spawn "noctalia" "msg" "volume-mute"; }
            XF86MonBrightnessUp   { spawn "noctalia" "msg" "brightness-up"; }
            XF86MonBrightnessDown { spawn "noctalia" "msg" "brightness-down"; }

            Mod+H { focus-column-left; }
            Mod+L { focus-column-right; }
            Mod+K { focus-window-up; }
            Mod+J { focus-window-down; }
            Mod+Left  { focus-column-left; }
            Mod+Right { focus-column-right; }
            Mod+Up    { focus-window-up; }
            Mod+Down  { focus-window-down; }
            Mod+Tab   { focus-window-down; }

            Mod+Shift+H { move-column-left; }
            Mod+Shift+L { move-column-right; }
            Mod+Shift+K { move-window-up; }
            Mod+Shift+J { move-window-down; }

            Mod+1 { focus-workspace 1; }
            Mod+2 { focus-workspace 2; }
            Mod+3 { focus-workspace 3; }
            Mod+4 { focus-workspace 4; }

            Mod+Shift+1 { move-window-to-workspace 1; }
            Mod+Shift+2 { move-window-to-workspace 2; }
            Mod+Shift+3 { move-window-to-workspace 3; }
            Mod+Shift+4 { move-window-to-workspace 4; }

            Mod+Space { toggle-window-floating; }
            // NOTE: `toggle-windowed-fullscreen` is a no-op in niri 26.04
            // (verified via IPC on both xdg and XWayland windows), so bind the
            // real fullscreen action which actually works.
            Mod+Shift+F         { fullscreen-window; }
            Mod+F   { switch-preset-column-width-back; }
            Mod+R    { switch-preset-column-width; }

            Mod+Minus { consume-window-into-column; }
            Mod+Equal { expel-window-from-column; }

            Mod+O          { toggle-overview; }
            Mod+Shift+Tab { toggle-overview; }

            Print            { screenshot-screen; }
            Shift+Print      { screenshot-window; }
            Ctrl+Shift+Print { screenshot; }
        }

        // Let noctalia's blurred/tinted backdrop (wallpaper) show in the
        // niri overview instead of a flat background color.
        layer-rule {
            match namespace="^noctalia-backdrop"
            place-within-backdrop true
        }

        output "eDP-1" {
            mode "2560x1600@240"
            scale 1.5
            position x=0 y=0
        }

        output "DP-1" {
            mode "2560x1440@210"
            position x=2560 y=0
        }

        layout {
            focus-ring { off; }
            border { off; }

            gaps 20
            center-focused-column "never"
            // A lone column (e.g. the startup kitty) is centered on screen.
            always-center-single-column true

            preset-column-widths {
                proportion 0.5
                proportion 0.8
                proportion 1.0
            }

            default-column-width { proportion 0.85; }

            shadow {
                on
                softness 30
                spread 2
                offset x=0 y=4
                color "#00000064"
            }
        }

        // Rounded corners for every window.
        window-rule {
            geometry-corner-radius 12
            clip-to-geometry true
        }

        animations {
            window-open {
                duration-ms 250
                curve "ease-out-expo"
            }
            window-close {
                duration-ms 250
                curve "ease-out-quad"
            }
            window-movement { spring damping-ratio=1.0 stiffness=800 epsilon=0.0001; }
            window-resize { spring damping-ratio=1.0 stiffness=800 epsilon=0.0001; }
            workspace-switch { spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001; }
            horizontal-view-movement { spring damping-ratio=1.0 stiffness=800 epsilon=0.0001; }
        }

        cursor { xcursor-theme "default"; xcursor-size 22; }
        hotkey-overlay { skip-at-startup; }
      '';
    in
    {
      environment.systemPackages = [ pkgs.niri ];

      # Electron/Chromium apps (QQ, Edge, ...) render natively on Wayland
      # instead of XWayland. Under XWayland fractional scaling (1.5) their UI
      # renders at 1x DPI and the fcitx5 candidate window comes out tiny.
      environment.sessionVariables.NIXOS_OZONE_WL = "1";

      # niri config managed by hjem (modules/hjem.nix).
      hjem.users.${config.my.name}.xdg.config.files."niri/config.kdl" = {
        source = niriConfig;
        clobber = true;
      };
    };
}
