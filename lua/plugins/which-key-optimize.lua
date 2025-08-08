-- which-keyを移動キーで無効化してスムーズな移動を実現

return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy", -- 遅延読み込み
    opts = {
      delay = 200,
      spec = {
        -- 移動キーはwhich-keyを非表示にして遅延を防ぐ
        { "j", hidden = true, mode = { "n", "v" } },
        { "k", hidden = true, mode = { "n", "v" } },
        { "h", hidden = true, mode = { "n", "v" } },
        { "l", hidden = true, mode = { "n", "v" } },
      },
    },
  },
}