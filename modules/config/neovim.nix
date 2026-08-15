{
  flake.modules.nixos.neovim =
    { pkgs, config, lib, ... }:
    let
      home = "/home/${config.my.name}";

      # Treesitter grammar packages selected below; declared here so the
      # closure ships them prebuilt instead of fetching at runtime.
      ts = config.programs.nixvim.plugins.treesitter.package.builtGrammars;
    in
    {
      programs.nixvim = {
        enable = true;
        defaultEditor = true;

        # ---- core options -------------------------------------------------
        opts = {
          number = true;
          relativenumber = true;
          expandtab = true;
          tabstop = 2;
          shiftwidth = 2;
          smartindent = true;
          termguicolors = true;
          scrolloff = 8;
          signcolumn = "yes";
          undofile = true;
          ignorecase = true;
          smartcase = true;
          cursorline = true;
          wrap = false;
          splitright = true;
          splitbelow = true;
          mouse = "a";
          updatetime = 200; # fast git gutter / lsp updates
          completeopt = [ "menuone" "noselect" ];
        };

        globals.mapleader = " ";

        # ---- keymaps -------------------------------------------------------
        keymaps = [
          # buffer ops
          { mode = "n"; key = "<leader>w"; action = "<cmd>w<cr>"; options.desc = "Save"; }
          { mode = "n"; key = "<leader>q"; action = "<cmd>q<cr>"; options.desc = "Quit"; }
          { mode = "n"; key = "<leader>bd"; action = "<cmd>bdelete<cr>"; options.desc = "Delete buffer"; }
          { mode = "n"; key = "<Tab>"; action = "<cmd>bnext<cr>"; options.desc = "Next buffer"; }
          { mode = "n"; key = "<S-Tab>"; action = "<cmd>bprevious<cr>"; options.desc = "Prev buffer"; }
          # window navigation
          { mode = "n"; key = "<C-h>"; action = "<C-w>h"; options.desc = "Window left"; }
          { mode = "n"; key = "<C-j>"; action = "<C-w>j"; options.desc = "Window down"; }
          { mode = "n"; key = "<C-k>"; action = "<C-w>k"; options.desc = "Window up"; }
          { mode = "n"; key = "<C-l>"; action = "<C-w>l"; options.desc = "Window right"; }
          # misc
          { mode = "n"; key = "<Esc>"; action = "<cmd>nohlsearch<cr>"; options.desc = "Clear search"; }
          { mode = "n"; key = "<leader>e"; action = "<cmd>NvimTreeToggle<cr>"; options.desc = "Toggle file tree"; }
        ];

        # ---- theme ---------------------------------------------------------
        colorschemes.tokyonight = {
          enable = true;
          settings.style = "night";
        };

        # ---- plugins -------------------------------------------------------
        plugins = {
          treesitter = {
            enable = true;
            highlight.enable = true;
            indent.enable = true;
            grammarPackages = with ts; [
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
              tree-sitter-vim
              tree-sitter-vimdoc
              tree-sitter-yaml
            ];
          };

          lualine.enable = true;
          which-key.enable = true;
          web-devicons.enable = true;
          lastplace.enable = true;
          undotree.enable = true;

          # LSP
          lsp = {
            enable = true;
            keymaps = {
              silent = true;
              diagnostic = {
                "<leader>k" = "goto_prev";
                "<leader>j" = "goto_next";
              };
              lspBuf = {
                gd = "definition";
                gD = "references";
                gt = "type_definition";
                gi = "implementation";
                K = "hover";
                "<leader>rn" = "rename";
                "<leader>ca" = "code_action";
              };
            };
            servers = {
              nixd.enable = true; # Nix language server
              lua_ls.enable = true;
              bashls.enable = true;
            };
          };

          # Completion
          cmp = {
            enable = true;
            autoEnableSources = true;
            settings = {
              sources = [
                { name = "nvim_lsp"; }
                { name = "luasnip"; }
                { name = "path"; }
                { name = "buffer"; }
              ];
              mapping = {
                "<Tab>" = "cmp.mapping.select_next_item()";
                "<S-Tab>" = "cmp.mapping.select_prev_item()";
                "<C-j>" = "cmp.mapping.select_next_item()";
                "<C-k>" = "cmp.mapping.select_prev_item()";
                "<CR>" = "cmp.mapping.confirm({ select = true })";
                "<C-Space>" = "cmp.mapping.complete()";
                "<C-e>" = "cmp.mapping.abort()";
              };
            };
          };
          luasnip.enable = true;
          friendly-snippets.enable = true;

          # Formatting (conform.nvim)
          conform-nvim = {
            enable = true;
            settings = {
              format_on_save = {
                lspFallback = true;
                timeoutMs = 500;
              };
              formatters_by_ft = {
                nix = [ "nixfmt" ];
                lua = [ "stylua" ];
                bash = [ "shfmt" ];
                sh = [ "shfmt" ];
                javascript = [ "prettierd" ];
                typescript = [ "prettierd" ];
                json = [ "prettierd" ];
                markdown = [ "prettierd" ];
                python = [ "ruff_fix" "ruff_format" ];
                rust = [ "rustfmt" ];
                c = [ "clang_format" ];
                cpp = [ "clang_format" ];
              };
              formatters = {
                nixfmt = {
                  command = lib.getExe pkgs.nixfmt;
                };
                stylua = {
                  command = lib.getExe pkgs.stylua;
                };
                shfmt = {
                  command = lib.getExe pkgs.shfmt;
                };
                prettierd = {
                  command = lib.getExe pkgs.prettierd;
                };
              };
            };
          };

          # Linting (nvim-lint)
          lint = {
            enable = true;
            autoInstall.enable = true;
            lintersByFt = {
              nix = [ "nix" "statix" ];
              bash = [ "shellcheck" ];
              sh = [ "shellcheck" ];
              python = [ "ruff" ];
              markdown = [ "markdownlint" ];
            };
          };

          # Git
          gitsigns = {
            enable = true;
            settings.current_line_blame = true;
          };

          # Navigation
          telescope = {
            enable = true;
            keymaps = {
              "<leader><space>" = "find_files";
              "<leader>fg" = "live_grep";
              "<leader>fb" = "buffers";
              "<leader>fh" = "help_tags";
            };
          };
          flash.enable = true;

          # Editing conveniences
          comment.enable = true;
          nvim-autopairs.enable = true;
          nvim-surround.enable = true;
          indent-blankline.enable = true;
          todo-comments.enable = true;

          # Diagnostics UI
          trouble.enable = true;

          # File tree
          nvim-tree = {
            enable = true;
            openOnSetup = false;
          };
        };

        extraConfigLua = ''
          -- Highlight yanked text
          vim.api.nvim_create_autocmd("TextYankPost", {
            group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
            callback = function()
              vim.highlight.on_yank()
            end,
          })

          -- Make nix files use 2-space indent and enable nixd formatting
          vim.api.nvim_create_autocmd("FileType", {
            pattern = { "nix" },
            callback = function()
              vim.bo.tabstop = 2
              vim.bo.shiftwidth = 2
              vim.bo.expandtab = true
            end,
          })
        '';
      };

      # nixvim asserts incompatibility with `programs.neovim.enable`, so the
      # `vim`/`vi` aliases are re-created as real binaries on PATH so
      # non-interactive callers (e.g. git) keep working.
      environment.systemPackages = with pkgs; [
        gcc # C compiler (rare at runtime — treesitter grammars ship prebuilt)
        ripgrep # telescope live_grep
        fd # telescope find_files

        (writeShellScriptBin "vi" ''exec nvim "$@"'')
        (writeShellScriptBin "vim" ''exec nvim "$@"'')
      ];

      # The undo directory is recreated on every boot (impermanence wipes
      # state) — just make sure it exists for in-session undo. The
      # `~/.config/nvim/` dir is left for any local overrides; nixvim bakes its
      # config into the wrapper, so there is no init.lua to symlink anymore.
      systemd.tmpfiles.rules = [
        "d ${home}/.local/state/nvim/undo 0755 ${config.my.name} users -"
        "d ${home}/.config/nvim 0755 ${config.my.name} users -"
      ];
    };
}