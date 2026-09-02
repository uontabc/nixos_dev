{
  flake.modules.nixos.neovim =
    { pkgs, config, ... }:
    let
      home = "/home/${config.my.name}";

      # Declarative init.lua, read from the repo and embedded in the wrapper
      # (loaded via VIMINIT, so ~/.config/nvim is not consulted). Plugins come
      # from Nix packages on the runtimepath — nothing is fetched at runtime.
      initLua = builtins.readFile ./neovim/init.lua;

      # Treesitter parsers: nvim-treesitter 0.10+ ships queries; the grammars
      # are built as separate vim plugins and merged onto the runtimepath by
      # vimUtils.packDir. Keep this list in sync with the emacs treesit set.
      treesitter = (
        pkgs.vimPlugins.nvim-treesitter.withPlugins (
          p: with p; [
            tree-sitter-bash
            tree-sitter-c
            tree-sitter-cpp
            tree-sitter-css
            tree-sitter-html
            tree-sitter-javascript
            tree-sitter-json
            tree-sitter-lua
            tree-sitter-markdown
            tree-sitter-nix
            tree-sitter-python
            tree-sitter-rust
            tree-sitter-toml
            tree-sitter-typescript
            tree-sitter-yaml
          ]
        )
      );
    in
    {
      programs.neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true; # git/cron/sudo expect `vi` on PATH
        vimAlias = true;
        configure = {
          customLuaRC = initLua;
          packages.onyx = {
            start = with pkgs.vimPlugins; [
              # Theme / UI
              tokyonight-nvim
              lualine-nvim
              nvim-web-devicons

              # Treesitter
              treesitter
              nvim-treesitter-textobjects
              nvim-treesitter-context
              rainbow-delimiters-nvim
              indent-blankline-nvim

              # Fuzzy finder / file tree
              telescope-nvim
              plenary-nvim
              telescope-fzf-native-nvim
              nvim-tree-lua

              # Git
              gitsigns-nvim
              neogit

              # Completion
              nvim-cmp
              cmp-nvim-lsp
              cmp-buffer
              cmp-path
              cmp-cmdline
              cmp_luasnip
              luasnip
              friendly-snippets
              nvim-autopairs

              # LSP / format / lint
              nvim-lspconfig
              conform-nvim
              nvim-lint

              # Editing conveniences
              comment-nvim
              nvim-surround
              todo-comments-nvim
              flash-nvim

              # Leader key help
              which-key-nvim
            ];
          };
        };
      };

      environment.systemPackages = with pkgs; [
        # Telescope providers
        ripgrep
        fd

        # LSP servers
        nixd # Nix
        lua-language-server # Lua (for editing this config)
        bash-language-server # Bash

        # Formatters (conform.nvim)
        nixfmt
        stylua
        shfmt
        ruff
        jq

        # Linters (nvim-lint)
        shellcheck
        statix

        # Wayland clipboard (unnamedplus)
        wl-clipboard
      ];

      environment.variables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };

      # Impermanence wipes home each boot; recreate the state/data dirs owned by
      # the user (tmpfiles would otherwise leave them root-owned and Neovim
      # couldn't write its shada/undo files). Mirrors the old Emacs setup.
      systemd.tmpfiles.rules = [
        "d ${home}/.local/share/nvim 0755 ${config.my.name} users -"
        "d ${home}/.local/state/nvim 0755 ${config.my.name} users -"
        "d ${home}/.local/state/nvim/undo 0755 ${config.my.name} users -"
      ];
    };
}
