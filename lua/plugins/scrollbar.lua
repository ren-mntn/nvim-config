--[[
機能概要: VSCodeライクなスクロールバー表示機能
設定内容: Git差分とビューポート（ハンドル）表示
キーバインド: なし（自動表示）
--]]
return {
  "petertriho/nvim-scrollbar",
  event = "VeryLazy",
  opts = function(_, opts)
    -- 安全な初期化
    opts = opts or {}

    -- 設定のマージ（完全上書きではない）
    opts = vim.tbl_deep_extend("force", opts, {
      handle = {
        color = "#6b6b6b",
      },
    })

    return opts
  end,
  config = function(_, opts)
    require("scrollbar").setup(opts)

    if pcall(require, "gitsigns") then
      require("scrollbar.handlers.gitsigns").setup()

      -- gitsignsの色を明示的に設定して視認性を改善
      vim.cmd([[
        highlight ScrollbarGitAdd guifg=#4d8900 guibg=NONE
        highlight ScrollbarGitChange guifg=#6a8bff guibg=NONE  
        highlight ScrollbarGitDelete guifg=#f34b50 guibg=NONE
      ]])
    end
  end,
}
