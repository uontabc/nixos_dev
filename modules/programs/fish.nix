{
  # Login shell: fish (replaces the old zsh setup). Autosuggestions and
  # syntax highlighting are built in, so only starship (prompt) is added.
  # User config lives in ~/.config/fish/config.fish, managed by hjem; fish
  # history lives under ~/.local/share/fish/fish_history, which impermanence
  # persists via the `~/.local/share` directory.
  flake.modules.nixos.fish =
    { pkgs, config, ... }:
    let
      user = config.my.name;
    in
    {
      programs.fish.enable = true;
      users.users.${user}.shell = pkgs.fish;

      my.packages = [ pkgs.starship ];

      hjem.users.${user}.xdg.config.files."fish/config.fish" = {
        text = ''
          # Managed by NixOS (modules/programs/fish.nix) via hjem — edit the
          # module, not this file.

          # No welcome banner (use double quotes here — Nix indented strings
          # end at two single quotes).
          set -g fish_greeting ""

          # Prompt (starship)
          starship init fish | source

          # Aliases
          alias ll 'ls -lah'
          alias la 'ls -A'
          alias l 'ls -lh'
          alias gs 'git status'
          alias ga 'git add'
          alias gc 'git commit'
          alias gp 'git push'
          alias gl 'git log --oneline --graph'

          # mkdir + cd in one step
          function mkcd
              mkdir -p $argv && cd $argv[1]
          end
        '';
        clobber = true;
      };
    };
}
