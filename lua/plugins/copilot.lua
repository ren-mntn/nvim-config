--[[
機能概要: GitHub Copilot - AIペアプログラミング支援
設定内容: 最小限の設定でCopilotを有効化
キーバインド: Tab（デフォルト）で提案を受け入れ
--]]
return {
  "github/copilot.vim",
  lazy = false, -- 即座に読み込み
  priority = 1000, -- 高優先度で読み込み
  config = function()
    -- すべてのファイルタイプで有効化（機密ファイルは除外）
    vim.g.copilot_filetypes = {
      ["*"] = true,
      [".env"] = false,
      ["env"] = false,
    }
  end,
}
