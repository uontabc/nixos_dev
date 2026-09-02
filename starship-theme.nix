{ pkgs }:
# Starship themes.
#
# `host` (symlinked to ~/.config/starship.toml by modules/programs/zsh.nix)
# is the minimal theme from the old codeberg nix-config repo
# (modules/programs/starship.nix): directory + git + nix-shell only.
#
# `devshell` (pointed at via $STARSHIP_CONFIG by modules/devshell.nix) is the
# official "no-empty-icons" preset (https://starship.rs/presets/#no-empty-icons)
# — toolset icons are only shown when the toolset is actually detected.
let
  preset = ''
    "$schema" = 'https://starship.rs/config-schema.json'

    [buf]
    format = '(with [$symbol($version )]($style))'

    [bun]
    format = '(via [$symbol($version )]($style))'

    [c]
    format = '(via [$symbol($version(-$name) )]($style))'

    [cpp]
    format = '(via [$symbol($version(-$name) )]($style))'

    [cmake]
    format = '(via [$symbol($version )]($style))'

    [cobol]
    format = '(via [$symbol($version )]($style))'

    [crystal]
    format = '(via [$symbol($version )]($style))'

    [daml]
    format = '(via [$symbol($version )]($style))'

    [dart]
    format = '(via [$symbol($version )]($style))'

    [deno]
    format = '(via [$symbol($version )]($style))'

    [dotnet]
    format = '(via [$symbol($version )(🎯 $tfm )]($style))'

    [elixir]
    format = '(via [$symbol($version \(OTP $otp_version\) )]($style))'

    [elm]
    format = '(via [$symbol($version )]($style))'

    [erlang]
    format = '(via [$symbol($version )]($style))'

    [fennel]
    format = '(via [$symbol($version )]($style))'

    [fortran]
    format = "(via [$symbol($version )]($style))"

    [gleam]
    format = '(via [$symbol($version )]($style))'

    [golang]
    format = '(via [$symbol($version )]($style))'

    [haskell]
    format = '(via [$symbol($version )]($style))'

    [helm]
    format = '(via [$symbol($version )]($style))'

    [java]
    format = '(via [$symbol($version )]($style))'

    [julia]
    format = '(via [$symbol($version )]($style))'

    [kotlin]
    format = '(via [$symbol($version )]($style))'

    [lua]
    format = '(via [$symbol($version )]($style))'

    [nim]
    format = '(via [$symbol($version )]($style))'

    [nodejs]
    format = '(via [$symbol($version )]($style))'

    [ocaml]
    format = '(via [$symbol($version )(\($switch_indicator$switch_name\) )]($style))'

    [opa]
    format = '(via [$symbol($version )]($style))'

    [package]
    format = '(is [$symbol$version]($style) )'

    [perl]
    format = '(via [$symbol($version )]($style))'

    [php]
    format = '(via [$symbol($version )]($style))'

    [purescript]
    format = '(via [$symbol($version )]($style))'

    [python]
    format = '(via [''${symbol}''${pyenv_prefix}(''${version} )(\($virtualenv\) )]($style))'

    [quarto]
    format = '(via [$symbol($version )]($style))'

    [raku]
    format = '(via [$symbol($version-$vm_version )]($style))'

    [red]
    format = '(via [$symbol($version )]($style))'

    [rlang]
    format = '(via [$symbol($version )]($style))'

    [ruby]
    format = '(via [$symbol($version )]($style))'

    [rust]
    format = '(via [$symbol($version )]($style))'

    [scala]
    format = '(via [$symbol($version )]($style))'

    [swift]
    format = '(via [$symbol($version )]($style))'

    [typst]
    format = '(via [$symbol($version )]($style))'

    [vagrant]
    format = '(via [$symbol($version )]($style))'

    [vlang]
    format = '(via [$symbol($version )]($style))'

    [xmake]
    format = '(via [$symbol($version )]($style))'

    [zig]
    format = '(via [$symbol($version )]($style))'
  '';
in
{
  host = pkgs.writeText "starship.toml" ''
    # Minimal theme (ported from codeberg nix-config).
    # Top-level keys first — in TOML, bare keys after a [table] header
    # belong to that table, so put format/command_timeout/scan_timeout
    # before any [section].
    add_newline = false
    format = "$directory$nix_shell$direnv$fill$git_branch$git_status$line_break$character"
    command_timeout = 1000
    scan_timeout = 50

    [fill]
    symbol = " "

    [nix_shell]
    format = "via [$state nix-shell]($style)"

    [direnv]
    disabled = false
    format = " [$symbol]($style) "

    [directory]
    truncation_symbol = "../"
    truncate_to_repo = false
  '';
  devshell = pkgs.writeText "starship-devshell.toml" preset;
}
