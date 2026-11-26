-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt

-- Format (and fix) on save
vim.g.autoformat = true
vim.g.lazyvim_eslint_auto_format = true -- run ESLint --fix on save
vim.g.lazyvim_prettier_needs_config = false -- run Prettier even without a project config

-- Python: Astral tooling (same team as uv). ty = LSP/type checker, ruff = lint + format.
-- Swap to "basedpyright" if ty is missing something you need.
vim.g.lazyvim_python_lsp = "ty"
vim.g.lazyvim_python_ruff = "ruff"

-- Spaces, not tabs
opt.expandtab = true
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2

-- 100-character column width
opt.textwidth = 100
-- opt.colorcolumn = "100"
