--[[
機能概要: カラーコード（#ff0000、rgb()など）をリアルタイムでハイライト表示
設定内容: 高速なLuaJITパーサーによる自動カラーハイライト
キーバインド: なし（自動動作）
--]]
return {
  "norcalli/nvim-colorizer.lua",
  event = "BufRead",
  opts = function(_, opts)
    -- 安全な初期化
    opts = opts or {}

    -- 設定のマージ（完全上書きではない）
    return vim.tbl_deep_extend("force", opts, {
      "*", -- すべてのファイルでカラーハイライトを有効化
      css = { rgb_fn = true }, -- CSSのrgb()関数を解析
      html = { names = false }, -- HTML色名によるハイライトを無効化
      javascript = { rgb_fn = true }, -- JavaScriptのrgb()関数を解析
      typescript = { rgb_fn = true }, -- TypeScriptのrgb()関数を解析
      lua = { names = false }, -- Lua色名によるハイライトを無効化
    })
  end,
  config = function(_, opts)
    require("colorizer").setup(opts)
  end,
}
