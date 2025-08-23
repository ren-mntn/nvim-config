-- ~/.config/nvim/lua/plugins/linting.lua
return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      -- ファイル保存時とファイルを開いた時にチェックを実行
      events = { "BufWritePost", "BufReadPost" },
    },
  },
}
