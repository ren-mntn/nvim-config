--[[
CCResume for Neovim - Claude Code会話履歴ブラウザ
独立プラグインとして分離されたccresume機能
キーバインド: <leader>ch (現在のディレクトリ), <leader>cH (全体)
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
      -- デフォルトのキーマッピングを使用
      keys = {
        current_dir = "<leader>ch",  -- 現在のディレクトリの会話
        all = "<leader>cH",          -- 全ての会話
      },
      commands = true,  -- コマンドを有効化
    })
  end,
}