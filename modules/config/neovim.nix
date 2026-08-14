{
  flake.modules.nixos.neovim =
    { pkgs, config, ... }:
    let
      home = "/home/${config.my.name}";

      # The treesitter grammar packages from the nvim-treesitter derivation
      # selected by this config. Declaring a subset keeps closure size and
      # build time in check; the lazy.nvim variant was forced to fetch on
      # demand at runtime — Nix bakes them in at build time instead.
      ts = config.programs.nixvim.plugins.treesitter.package.builtGrammars;
    in
    {
      programs.nixvim = {
        enable = true;
        defaultEditor = true;

        # options (formerly vim.opt.*)
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
          completeopt = [ "menuone" "noselect" ];
        };

        # leader & save/quit
        globals.mapleader = " ";
        keymaps = [
          { mode = "n"; key = "<leader>w"; action = "<cmd>w<cr>"; options.desc = "Save"; }
          { mode = "n"; key = "<leader>q"; action = "<cmd>q<cr>"; options.desc = "Quit"; }
        ];

        colorschemes.tokyonight = {
          enable = true;
          settings.style = "night";
        };

        plugins = {
          treesitter = {
            enable = true;
            highlight.enable = true;
            grammarPackages = with ts; [
              tree-sitter-bash
              tree-sitter-lua
              tree-sitter-nix
              tree-sitter-vim
              tree-sitter-vimdoc
            ];
          };

          lualine = {
            enable = true;
            settings = {
              options = {
                theme = "tokyonight";
                globalstatus = true;
                icons_enabled = true;
              };
              sections = {
                lualine_a = [ "mode" ];
                lualine_b = [ "branch" ];
                lualine_c = [
                  {
                    __unkeyed-1 = "filename";
                    symbols = {
                      modified = " ";
                      readonly = "";
                    };
                  }
                  "filetype"
                ];
                lualine_x = [ "diagnostics" ];
                lualine_y = [ "lsp_status" ];
                lualine_z = [ "location" "progress" ];
              };
            };
          };
          which-key.enable = true;
          web-devicons.enable = true; # telescope picks this up; enable explicitly

          telescope = {
            enable = true;
            keymaps = {
              "<leader><space>" = "find_files";
              "<leader>fg" = "live_grep";
            };
          };
        };
      };

      # nixvim asserts incompatibility with `programs.neovim.enable`, so the
      # `vim Alias`/`viAlias` knobs from the nixpkgs neovim module are off the
      # table. Re-create them as real binaries on PATH so non-interactive
      # callers (e.g. git) keep working.
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