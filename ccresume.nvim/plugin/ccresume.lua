-- ccresume.nvim - Claude Code conversation browser for Neovim
-- Plugin entry point

if vim.g.loaded_ccresume then
  return
end
vim.g.loaded_ccresume = 1

-- Auto-setup with default configuration
require("ccresume").setup()