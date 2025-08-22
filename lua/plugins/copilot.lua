--[[
機能概要: GitHub Copilot + blink.cmp統合 - blink.cmp経由でCopilot提案を取得
設定内容: blink-cmp-copilot推奨設定に従いsuggestionとpanel両方を無効化
キーバインド: blink.cmpのキーマッピングでCopilot提案も利用可能
--]]
return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  opts = function(_, opts)
    opts = opts or {}

    -- パネル機能を無効化（blink-cmp-copilot推奨設定）
    opts.panel = vim.tbl_deep_extend("force", opts.panel or {}, {
      enabled = false,
    })

    -- blink.cmpとの統合のため提案機能を無効化
    opts.suggestion = vim.tbl_deep_extend("force", opts.suggestion or {}, {
      enabled = false,
    })

    -- ファイルタイプ設定
    opts.filetypes = vim.tbl_deep_extend("force", opts.filetypes or {}, {
      yaml = false,
      markdown = false,
      help = false,
      gitcommit = false,
      gitrebase = false,
      hgcommit = false,
      svn = false,
      cvs = false,
      [".env"] = false,
      ["env"] = false,
    })

    return opts
  end,
}
