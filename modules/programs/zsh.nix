{
  flake.modules.nixos.zsh =
    { pkgs, config, ... }:
    let
      user = config.my.name;

      starshipConfig = (import ../_starship-theme.nix { inherit pkgs; }).host;
    in
    {
      programs.zsh.enable = true;
      users.users.${user}.shell = pkgs.zsh;

      my.packages = [
        pkgs.zsh-autosuggestions
        pkgs.zsh-syntax-highlighting
        pkgs.starship
      ];

      # $HOME files, managed by hjem (modules/hjem.nix). clobber keeps the
      # old tmpfiles semantics: replace whatever was there before.
      hjem.users.${user} = {
        files.".zshrc" = {
          text = ''
            # History
            HISTFILE="$HOME/.zsh_history"
            HISTSIZE=50000
            SAVEHIST=50000
            setopt hist_ignore_dups hist_ignore_space share_history inc_append_history

            # Prompt (starship)
            eval "$(${pkgs.starship}/bin/starship init zsh)"

            # Options
            setopt auto_cd auto_pushd pushd_ignore_dups extended_glob
            setopt interactive_comments no_beep

            # Completion
            autoload -Uz compinit && compinit
            zstyle ':completion:*' menu select
            zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

            # Plugins
            source "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
            source "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
            ZSH_HIGHLIGHT_STYLES[path]=none
            ZSH_HIGHLIGHT_STYLES[suffix-alias]=none
            ZSH_HIGHLIGHT_STYLES[precommand]=none
            ZSH_HIGHLIGHT_STYLES[autodirectory]=none

            # Aliases
            alias ll='ls -lah'
            alias la='ls -A'
            alias l='ls -lh'
            alias ...='../..'
            alias gs='git status'
            alias ga='git add'
            alias gc='git commit'
            alias gp='git push'
            alias gl='git log --oneline --graph'
          '';
          clobber = true;
        };

        xdg.config.files."starship.toml" = {
          source = starshipConfig;
          clobber = true;
        };
      };
    };
}
