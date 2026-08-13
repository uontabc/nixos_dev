{ pkgs, ... }:

let
  niriConfig = pkgs.writeText "niri-config.kdl" ''
    input {
        keyboard {
            xkb { layout "us" }
            numlock
            repeat-rate 25
            repeat-delay 600
        }

        touchpad {
            tap
            dwt
            drag-lock
            // natural-scroll
            // accel-profile "flat"
        }

        mouse {
            // natural-scroll
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

    // Noctalia is started by systemd (programs.noctalia.systemd.enable),
    // so we don't need spawn-at-startup here.

    binds {
        Mod+R { reload-config; }

        Mod+Shift+Q { quit; }
        Mod+Q { close-focus-requested; }

        // Noctalia shell
        Mod+Space action.spawn "noctalia" ["msg" "panel-toggle" "launcher"]
        Mod+S     action.spawn "noctalia" ["msg" "panel-toggle" "control-center"]
        Mod+Comma action.spawn "noctalia" ["msg" "settings-toggle"]

        // launchers
        Mod+Return       action.spawn "kitty" []
        Mod+E            action.spawn "kitty" ["-e" "yazi"]
        Mod+Shift+E      action.spawn "kitty" ["-e" "spf"]

        // volume / brightness (noctalia handles via internal msg)
        XF86AudioRaiseVolume    action.spawn "noctalia" ["msg" "volume-up"]
        XF86AudioLowerVolume    action.spawn "noctalia" ["msg" "volume-down"]
        XF86AudioMute           action.spawn "noctalia" ["msg" "volume-mute"]
        XF86MonBrightnessUp     action.spawn "noctalia" ["msg" "brightness-up"]
        XF86MonBrightnessDown   action.spawn "noctalia" ["msg" "brightness-down"]

        // focus / move
        Mod+H focus-column-left
        Mod+L focus-column-right
        Mod+K focus-window-up
        Mod+J focus-window-down
        Mod+Left  focus-column-left
        Mod+Right focus-column-right
        Mod+Up    focus-window-up
        Mod+Down  focus-window-down
        Mod+Tab   focus-window-down

        Mod+Shift+H move-window-left
        Mod+Shift+L move-window-right
        Mod+Shift+K move-window-up
        Mod+Shift+J move-window-down

        // workspaces
        Mod+1 focus-workspace 1
        Mod+2 focus-workspace 2
        Mod+3 focus-workspace 3
        Mod+4 focus-workspace 4
        Mod+5 focus-workspace 5
        Mod+6 focus-workspace 6
        Mod+7 focus-workspace 7
        Mod+8 focus-workspace 8
        Mod+9 focus-workspace 9

        Mod+Shift+1 move-to-workspace 1
        Mod+Shift+2 move-to-workspace 2
        Mod+Shift+3 move-to-workspace 3
        Mod+Shift+4 move-to-workspace 4
        Mod+Shift+5 move-to-workspace 5
        Mod+Shift+6 move-to-workspace 6
        Mod+Shift+7 move-to-workspace 7
        Mod+Shift+8 move-to-workspace 8
        Mod+Shift+9 move-to-workspace 9

        // window state
        Mod+Backspace toggle-window-floating
        Mod+F toggle-windowed-fullscreen
        Mod+Shift+F toggle-column-width "fixed"

        Mod+Minus       consume-window-into-column
        Mod+Equal       expel-window-from-column

        // overview
        Mod+G         action.toggle-overview
        Mod+Shift+Tab toggle-overview

        // hard exit (use Noctalia session panel for normal logout)
        Mod+M quit

        // screenshots (niri builtin UI)
        Print               action.screenshot-screen
        Shift+Print         action.screenshot-window
        Ctrl+Shift+Print    action.screenshot
    }

    layout {
        focus-ring { width 1; off; }
        border { width 1; off; }

        gap 20
        center-focused-column "never"

        preset-column-widths {
            proportion 0.5
            proportion 0.8
            proportion 1.0
        }

        default-column-width { proportion 0.85; }
    }

    animations {
        window-open { duration 250; }
        window-close { duration 250; }
        window-movement { duration 250; }
        workspace-switch { duration 250; }
        horizontal-view-shift { duration 250; }
    }

    cursor { xcursor-theme default; xcursor-size 22; }
    hotkey-overlay { skip-at-startup; }
  '';
in
{
  # niri ships its own wayland-session desktop file in $out/share/wayland-sessions,
  # so installing the package auto-registers the "niri" session.
  environment.systemPackages = [ pkgs.niri ];

  # Symlink the KDL config into /home/onyx/.config/niri/config.kdl.
  # tmpfiles runs after impermanence's bind-mounts, so this is safe even
  # with ephemeral root. `L+` forcibly replaces any existing file (which
  # is what we want — config is declaratively managed).
  systemd.tmpfiles.rules = [
    "d /home/onyx/.config/niri 0755 onyx users -"
    "L+ /home/onyx/.config/niri/config.kdl - - - - ${niriConfig}"
  ];
}