--[[
機能概要: Supermaven AI コード補完プラグイン
設定内容: 基本設定での導入、デフォルトキーバインド使用
キーバインド: <Tab>で補完受け入れ、<C-]>でクリア、<C-j>で単語受け入れ
--]]
return {
  "supermaven-inc/supermaven-nvim",
  event = "VeryLazy",
  opts = function(_, opts)
    -- デバッグ（実装時のみ、完了時削除）
    print("=== DEBUG: Supermaven initial opts ===")
    print(vim.inspect(opts))
    
    -- 基本設定のマージ
    opts = vim.tbl_deep_extend("force", opts or {}, {
      keymaps = {
        accept_suggestion = "<Tab>",
        clear_suggestion = "<C-]>",
        accept_word = "<C-j>",
      },
      ignore_filetypes = {},
      color = {
        suggestion_color = "#ffffff",
        cterm = 244,
      },
      log_level = "info",
      disable_inline_completion = false,
      disable_keymaps = false,
    })
    
    -- デバッグ（実装時のみ、完了時削除）
    print("=== DEBUG: Supermaven final opts ===")
    print(vim.inspect(opts))
    
    return opts
  end,
}