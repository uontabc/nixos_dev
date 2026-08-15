{ pkgs }:
let
  theme = {
    format = "$directory$git_branch$git_status$character";

    directory = {
      truncation_length = 3;
      truncation_symbol = "…/";
      style = "bold bright-blue";
      format = "[$path]($style)";
      substitutions = { "~" = ""; };
    };

    git_branch = {
      symbol = "|";
      style = "bold purple";
      format = "[$symbol$branch]($style)";
    };

    git_status = {
      style = "bold bright-yellow";
      format = "[$all_status$ahead_behind]($style)";
      ahead = ">";
      behind = "<";
      diverged = "<>";
      staged = "+";
      modified = "*";
      deleted = "-";
      renamed = "~";
      untracked = "?";
      conflicted = "!";
    };

    character = {
      success_symbol = "[❯](bold green)";
      error_symbol = "[❯](bold red)";
      vicmd_symbol = "[❮](bold yellow)";
    };
  };

  toml = pkgs.formats.toml { };
in
{
  host = toml.generate "starship.toml" theme;
  devshell = toml.generate "starship-devshell.toml" (theme // {
    format = "$nix_shell $directory$git_branch$git_status$character";
    nix_shell = {
      format = "[$symbol]($style)";
      style = "bold purple";
    };
  });
}
