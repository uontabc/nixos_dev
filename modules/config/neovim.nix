{
  flake.modules.nixos.neovim =
    { pkgs, config, ... }:
    let
      home = "/home/${config.my.name}";

      neovimConfig = pkgs.writeText "init.lua" ''
        -- options
        vim.opt.number = true
        vim.opt.relativenumber = true
        vim.opt.expandtab = true
        vim.opt.tabstop = 2
        vim.opt.shiftwidth = 2
        vim.opt.smartindent = true
        vim.opt.termguicolors = true
        vim.opt.scrolloff = 8
        vim.opt.signcolumn = "yes"
        vim.opt.undofile = true
        vim.opt.ignorecase = true
        vim.opt.smartcase = true
        vim.opt.completeopt = { "menuone", "noselect" }

        -- leader & save/quit
        vim.g.mapleader = " "
        vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
        vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })

        -- bootstrap lazy.nvim (runtime plugin manager)
        local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
        if not vim.loop.fs_stat(lazypath) then
          vim.fn.system({
            "git", "clone", "--filter=blob:none",
            "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
          })
        end
        vim.opt.rtp:prepend(lazypath)

        require("lazy").setup({
          { "folke/tokyonight.nvim", lazy = false, priority = 1000, config = function()
            vim.cmd.colorscheme("tokyonight-night")
          end },
          { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
            config = function()
              require("nvim-treesitter.configs").setup({
                ensure_installed = { "lua", "nix", "bash", "vim", "vimdoc" },
                highlight = { enable = true },
              })
            end },
          { "nvim-lualine/lualine.nvim", config = true },
          { "folke/which-key.nvim", event = "VeryLazy", config = true },
          { "nvim-telescope/telescope.nvim", dependencies = "nvim-lua/plenary.nvim",
            keys = { { "<leader><space>", "<cmd>Telescope find_files<cr>" },
                     { "<leader>fg", "<cmd>Telescope live_grep<cr>" } },
            config = true },
        })
      '';
    in
    {
      programs.neovim = {
        enable = true;
        defaultEditor = true;
        vimAlias = true;
        viAlias = true;
      };

      environment.systemPackages = with pkgs; [
        gcc
        ripgrep
        fd
      ];

      systemd.tmpfiles.rules = [
        "d ${home}/.local/state/nvim/undo 0755 ${config.my.name} users -"
        "d ${home}/.config/nvim 0755 ${config.my.name} users -"
        "L+ ${home}/.config/nvim/init.lua - - - - ${neovimConfig}"
      ];
    };
}