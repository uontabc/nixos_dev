{
  flake.modules.nixos.zsh =
    { pkgs, config, ... }:
    let
      home = "/home/${config.my.name}";

      starshipConfig = pkgs.writeText "starship.toml" ''
        format = """
        $directory$git_branch$git_status$python$rust$golang
        $character"""

        [directory]
        truncation_length = 3
        truncation_symbol = "…/"

        [git_branch]
        symbol = " "
        style = "bold purple"

        [git_status]
        style = "bold yellow"

        [python]
        symbol = " "

        [rust]
        symbol = " "

        [golang]
        symbol = " "

        [character]
        success_symbol = "[❯](bold green)"
        error_symbol = "[❯](bold red)"
        vicmd_symbol = "[❮](bold yellow)"
      '';

      zshrc = pkgs.writeText "zshrc" ''
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
    in
    {
      programs.zsh.enable = true;
      users.users.${config.my.name}.shell = pkgs.zsh;

      my.packages = [
        pkgs.zsh-autosuggestions
        pkgs.zsh-syntax-highlighting
        pkgs.starship
      ];

      systemd.tmpfiles.rules = [
        "L+ ${home}/.zshrc - - - - ${zshrc}"
        "d ${home}/.config 0755 ${config.my.name} users -"
        "L+ ${home}/.config/starship.toml - - - - ${starshipConfig}"
      ];
    };
}
