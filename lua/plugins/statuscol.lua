--[[
機能概要: statuscolプラグイン設定 - ステータスカラムの高度なカスタマイズ
設定内容: Diagnostic、GitSigns、行番号、区切り線の統合表示
キーバインド: なし（表示のみ）
--]]
return {
  "luukvbaal/statuscol.nvim",
  event = "VeryLazy",
  opts = function(_, opts)
    local builtin = require("statuscol.builtin")

    -- 安全な初期化
    opts = opts or {}

    -- 設定のマージ（完全上書きではない）
    opts = vim.tbl_deep_extend("force", opts, {
      bt_ignore = { "terminal", "nofile", "ddu-ff", "ddu-ff-filter" },
      relculright = true,
      segments = {
        {
          sign = {
            name = { "Diagnostic.*" },
            maxwidth = 1,
          },
        },
        {
          sign = {
            namespace = { "gitsigns" },
            maxwidth = 1,
            colwidth = 1,
            wrap = true,
          },
        },
        {
          text = { builtin.lnumfunc },
        },
        { text = { "│" } },
      },
    })

    return opts
  end,
}
