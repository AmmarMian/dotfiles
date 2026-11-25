-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
-- localleader = "\" par défaut dans LazyVim : pénible en AZERTY, et c'est le
-- préfixe de tous les raccourcis vimtex.
vim.g.maplocalleader = ","

local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.spell = false

vim.o.ttyfast = true
-- vim.o.lazyredraw = true
--
vim.filetype.add({
  extension = {
    cls = "tex",
  },
})
