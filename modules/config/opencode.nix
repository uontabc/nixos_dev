{
  flake.modules.nixos.opencode =
    { pkgs, config, ... }:
    let
      home = "/home/${config.my.name}";
      authDir = "${home}/.local/share/opencode";

      opencodeConfig = pkgs.writeText "opencode.json" (
        builtins.toJSON {
          "$schema" = "https://opencode.ai/config.json";
          username = config.my.name;
          # Version is managed by nix — no auto-update.
          autoupdate = false;
          # Don't share sessions unless explicitly asked.
          share = "manual";

          mcp = {
            # GitHub API — needs a token. Set GITHUB_PERSONAL_ACCESS_TOKEN in
            # your shell/env; opencode expands ${VAR} at startup. Without it the
            # server fails to start but the others keep working.
            github = {
              type = "local";
              command = [ "npx" "-y" "@modelcontextprotocol/server-github" ];
              environment.GITHUB_PERSONAL_ACCESS_TOKEN = "\${GITHUB_PERSONAL_ACCESS_TOKEN}";
            };

            # Read/write files outside the workspace (the whole home dir).
            filesystem = {
              type = "local";
              command = [ "npx" "-y" "@modelcontextprotocol/server-filesystem" home ];
            };

            # Real NixOS packages/options search (no more hallucinated names).
            mcp-nixos = {
              type = "local";
              command = [ "mcp-nixos" ];
            };
          };

          # nil — the Nix language server.
          lsp.nil = {
            command = [ "nil" ];
            extensions = [ "nix" ];
          };
        }
      );
    in
    {
      # nodejs/npx is required by the npx-based MCP servers.
      my.packages = [ pkgs.opencode pkgs.nodejs pkgs.nil pkgs.mcp-nixos ];

      systemd.tmpfiles.rules = [
        "d ${home}/.config/opencode 0755 ${config.my.name} users -"
        "L+ ${home}/.config/opencode/opencode.json - - - - ${opencodeConfig}"
        "d ${authDir} 0700 ${config.my.name} users -"
      ];

      # API keys live in ~/.local/share/opencode/auth.json
      # (e.g. {"deepseek": {"api_key": "..."}}). Manage it manually:
      #   opencode auth login   # or write the file yourself
      # (`.local/share` is persisted by impermanence, so it survives reboots.)
    };
}