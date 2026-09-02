-- Onyx Neovim — managed by NixOS (modules/programs/neovim.nix).
-- Every plugin is a Nix package already on the runtimepath, so a plain
-- require() works and nothing is ever fetched from the network at runtime.

-- ---------------------------------------------------------------------------
-- Leader + core options
-- ---------------------------------------------------------------------------

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.number = true
opt.relativenumber = true -- like nvim relativenumber
opt.cursorline = true     -- highlight current line
opt.wrap = false          -- no soft wrap
opt.scrolloff = 8         -- keep 8 lines of context
opt.sidescrolloff = 8

opt.expandtab = true -- spaces, not tabs
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.autoindent = true
opt.smartindent = true

opt.ignorecase = true
opt.smartcase = true

opt.termguicolors = true
opt.signcolumn = "yes"
opt.completeopt = "menu,menuone,noselect"
opt.splitright = true
opt.splitbelow = true
opt.updatetime = 300 -- faster LSP/gitsigns updates

-- Persistent undo (impermanence persists ~/.local/state; tmpfiles owns the dir).
opt.undofile = true
local undo_dir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undo_dir, "p")
opt.undodir = undo_dir

-- Wayland clipboard (wl-clipboard is installed by the module).
opt.clipboard = "unnamedplus"

-- ---------------------------------------------------------------------------
-- Theme + statusline + icons
-- ---------------------------------------------------------------------------

require("tokyonight").setup({ style = "night" })
vim.cmd.colorscheme("tokyonight")

require("nvim-web-devicons").setup({})

require("lualine").setup({
  options = { theme = "tokyonight" },
})

-- ---------------------------------------------------------------------------
-- Treesitter (parsers + queries come from Nix)
-- ---------------------------------------------------------------------------

-- nvim-treesitter 0.10+ only manages parser installs; parsers and highlight
-- queries are already provided by the Nix packages, so we just enable
-- Neovim's built-in treesitter highlighting per filetype.
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

-- Syntax-aware text objects (function/class) and moves, like the emacs
-- setup's tree-sitter integration.
require("nvim-treesitter-textobjects").setup({
  select = { lookahead = true },
  move = { set_jumps = true },
})

local select_textobject = require("nvim-treesitter-textobjects.select").select_textobject
vim.keymap.set({ "x", "o" }, "af", function() select_textobject("@function.outer", "textobjects") end, { desc = "Outer function" })
vim.keymap.set({ "x", "o" }, "if", function() select_textobject("@function.inner", "textobjects") end, { desc = "Inner function" })
vim.keymap.set({ "x", "o" }, "ac", function() select_textobject("@class.outer", "textobjects") end, { desc = "Outer class" })
vim.keymap.set({ "x", "o" }, "ic", function() select_textobject("@class.inner", "textobjects") end, { desc = "Inner class" })

local move = require("nvim-treesitter-textobjects.move")
vim.keymap.set({ "n", "x", "o" }, "]m", function() move.goto_next_start("@function.outer", "textobjects") end, { desc = "Next function" })
vim.keymap.set({ "n", "x", "o" }, "[m", function() move.goto_previous_start("@function.outer", "textobjects") end, { desc = "Previous function" })
vim.keymap.set({ "n", "x", "o" }, "]M", function() move.goto_next_end("@function.outer", "textobjects") end, { desc = "Next function end" })
vim.keymap.set({ "n", "x", "o" }, "[M", function() move.goto_previous_end("@function.outer", "textobjects") end, { desc = "Previous function end" })

-- Sticky context: keep the enclosing function/class header visible.
require("treesitter-context").setup({})

-- rainbow-delimiters auto-attaches via its FileType autocommand; no setup call.
-- Indent guides.
require("ibl").setup({})

-- ---------------------------------------------------------------------------
-- Fuzzy finder (Telescope)
-- ---------------------------------------------------------------------------

local telescope = require("telescope")
telescope.setup({
  defaults = {
    sorting_strategy = "ascending",
    layout_config = { prompt_position = "top" },
  },
})
pcall(telescope.load_extension, "fzf")

-- ---------------------------------------------------------------------------
-- File tree (nvim-tree)
-- ---------------------------------------------------------------------------

require("nvim-tree").setup({
  view = { width = 30, side = "left" },
})

-- ---------------------------------------------------------------------------
-- Git (gitsigns gutter + neogit status)
-- ---------------------------------------------------------------------------

require("gitsigns").setup({})
require("neogit").setup({})

-- ---------------------------------------------------------------------------
-- Completion (nvim-cmp + LuaSnip)
-- ---------------------------------------------------------------------------

local cmp = require("cmp")
local luasnip = require("luasnip")

require("luasnip.loaders.from_vscode").lazy_load()

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.abort(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
  }, {
    { name = "buffer" },
    { name = "path" },
  }),
})

-- Completion on the command line (`:`, `/`, `?`).
cmp.setup.cmdline(":", {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = "path" },
  }, {
    { name = "cmdline" },
  }),
})

-- Auto-close pairs, and keep them in sync with cmp confirmations.
local npairs = require("nvim-autopairs")
npairs.setup({})
local cmp_autopairs = require("nvim-autopairs.completion.cmp")
cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())

-- ---------------------------------------------------------------------------
-- LSP (nvim-lspconfig 0.11+: server defaults from the plugin's lsp/<server>.lua,
-- wired via vim.lsp.config / vim.lsp.enable; servers are Nix packages on PATH)
-- ---------------------------------------------------------------------------

-- Shared on_attach + nvim-cmp capabilities for every server. The resolved
-- config merges this '*' layer under the plugin defaults (lsp/<server>.lua),
-- and nvim deep-merges `capabilities` into make_client_capabilities() at
-- client creation (vim.lsp.client.create).
local capabilities = require("cmp_nvim_lsp").default_capabilities()

vim.lsp.config("*", {
  capabilities = capabilities,
  on_attach = function(_, bufnr)
    local map = function(keys, func, desc)
      vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
    end
    map("gd", vim.lsp.buf.definition, "Go to definition")
    map("gD", vim.lsp.buf.references, "Find references")
    map("gi", vim.lsp.buf.implementation, "Go to implementation")
    map("gt", vim.lsp.buf.type_definition, "Go to type definition")
    map("K", vim.lsp.buf.hover, "Hover documentation")
    map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    map("<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("<leader>d", vim.diagnostic.open_float, "Line diagnostics")
    map("[d", vim.diagnostic.goto_prev, "Previous diagnostic")
    map("]d", vim.diagnostic.goto_next, "Next diagnostic")
  end,
})

-- Per-server overrides; everything else comes from the plugin defaults
-- (cmd, filetypes, root_markers).
vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
      telemetry = { enable = false },
    },
  },
})

vim.lsp.enable({ "nixd", "lua_ls", "bashls" })

-- ---------------------------------------------------------------------------
-- Formatting (conform) + linting (nvim-lint)
-- ---------------------------------------------------------------------------

require("conform").setup({
  formatters_by_ft = {
    nix = { "nixfmt" },
    lua = { "stylua" },
    sh = { "shfmt" },
    bash = { "shfmt" },
    python = { "ruff_format" },
    json = { "jq" },
  },
  format_on_save = {
    timeout_ms = 500,
    lsp_format = "fallback",
  },
})

require("lint").linters_by_ft = {
  nix = { "statix" },
  sh = { "shellcheck" },
  bash = { "shellcheck" },
  python = { "ruff" },
}
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  callback = function()
    require("lint").try_lint()
  end,
})

-- ---------------------------------------------------------------------------
-- Editing conveniences (mirroring the old Emacs setup)
-- ---------------------------------------------------------------------------

require("Comment").setup({}) -- gc / gcc (evil-commentary)
require("nvim-surround").setup({}) -- ys/ds/cs (evil-surround)

require("todo-comments").setup({}) -- hl-todo

-- flash: label-based jumping (avy).
require("flash").setup({})
vim.keymap.set({ "n", "x", "o" }, "s", function() require("flash").jump() end, { desc = "Flash jump" })
vim.keymap.set({ "n", "x", "o" }, "S", function() require("flash").treesitter() end, { desc = "Flash treesitter" })

-- ---------------------------------------------------------------------------
-- which-key (last, so it annotates everything above)
-- ---------------------------------------------------------------------------

local wk = require("which-key")
wk.setup({ preset = "modern" })

wk.add({
  { "<leader>w", "<cmd>write<cr>", desc = "Save" },
  { "<leader>q", "<cmd>close<cr>", desc = "Close buffer" },
  { "<leader>b", group = "buffer" },
  { "<leader>bn", "<cmd>bnext<cr>", desc = "Next buffer" },
  { "<leader>bp", "<cmd>bprevious<cr>", desc = "Previous buffer" },
  { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "File tree" },
  { "<leader>f", group = "find" },
  { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find file" },
  { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
  { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
  { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Grep (ripgrep)" },
  { "<leader>g", group = "git" },
  { "<leader>gg", "<cmd>Neogit<cr>", desc = "Git status" },
  { "<leader>x", "<cmd>Telescope commands<cr>", desc = "Commands" },
})
