-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
local opt = vim.opt
opt.number = true
opt.relativenumber = true

vim.o.ttyfast = true
-- vim.o.lazyredraw = true
--
vim.filetype.add({
  extension = {
    cls = "tex",
  },
})
