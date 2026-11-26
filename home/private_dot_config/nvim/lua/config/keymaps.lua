-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Type jk quickly in insert mode to escape
vim.keymap.set("i", "jk", "<Esc>", { desc = "Exit insert mode" })
