--[[
CCResume for Neovim - Claude Code会話履歴ブラウザ
独立プラグインとして分離されたccresume機能
キーバインド: 
  - <leader>ch (現在のディレクトリ・直近)
  - <leader>cH (現在のディレクトリ・全件)
  - <leader>ca (全体・直近)
  - <leader>cA (全体・全件)
--]]

return {
  dir = vim.fn.expand("~/.config/nvim/ccresume.nvim"),
  name = "ccresume.nvim",
  dependencies = {
    "coder/claudecode.nvim",
    "folke/snacks.nvim",
  },
  config = function()
    require("ccresume").setup({
      keys = {
        current_dir = "<leader>ch",      -- 現在のディレクトリ（直近）
        current_dir_all = "<leader>cH",  -- 現在のディレクトリ（全件）
        all = "<leader>ca",              -- 全体（直近）
        all_all = "<leader>cA",          -- 全体（全件）
      },
      commands = true,
      preview = {
        reverse_order = true,
      },
      performance = {
        recent_limit = 30,
      },
    })
  end,
}