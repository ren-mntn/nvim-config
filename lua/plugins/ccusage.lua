--[[
機能概要: Claude Code使用量をNeovim内で追跡・表示するプラグイン
設定内容: CCUsageコマンドの提供、lualineとの統合設定
キーバインド: :CCUsage コマンドで使用量確認
依存関係: ccusage CLI（npm install -g ccusage）
--]]
return {
  "S1M0N38/ccusage.nvim",
  version = "1.*",
  event = "VeryLazy",
  opts = function(_, opts)
    -- 安全な初期化
    opts = opts or {}

    -- ccusageコマンドの絶対パスを指定
    opts.ccusage_cmd = "/Users/ren/.nodenv/versions/22.18.0/bin/ccusage"

    return opts
  end,
}
