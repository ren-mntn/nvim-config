--[[
機能概要: Vimの編集モード（insert、visual、copy、deleteなど）に対応した視覚的なラインハイライト
設定内容: 各モードのカラーカスタマイズとUIエフェクトの設定
キーバインド: なし（自動的にモード変更時に動作）
--]]
return {
  "mvllow/modes.nvim",
  tag = "v0.2.1",
  event = "VeryLazy",
  opts = function(_, opts)
    -- デバッグ（実装時のみ、完了時削除）
    print("=== DEBUG: modes.nvim Initial opts ===")
    print(vim.inspect(opts))
    
    -- 安全な初期化
    opts = opts or {}
    
    -- 設定のマージ（完全上書きではない）
    opts = vim.tbl_deep_extend("force", opts, {
      -- カーソルラインとカーソルのハイライトを有効化
      colors = {
        copy = "#f5c359", -- コピーモード (黄色系)
        delete = "#c75c6a", -- 削除モード (赤色系)  
        insert = "#78ccc5", -- 挿入モード (緑青系)
        visual = "#9745be", -- ビジュアルモード (紫系)
        replace = "#245361", -- 置換モード (青緑系)
      },
      
      -- ハイライト対象の設定
      set_cursor = true, -- カーソル色の変更を有効
      set_cursorline = true, -- カーソルライン色の変更を有効
      set_number = true, -- 行番号色の変更を有効
      
      -- ハイライトの透明度設定
      line_opacity = 0.15, -- カーソルラインの透明度
      
      -- 除外するファイルタイプ
      ignore_filetypes = { 
        "NvimTree", 
        "TelescopePrompt",
        "dashboard",
        "alpha",
        "neo-tree",
        "lazy",
        "mason",
        "toggleterm",
        "help"
      },
    })
    
    -- デバッグ（実装時のみ、完了時削除）
    print("=== DEBUG: modes.nvim Final opts ===")
    print(vim.inspect(opts))
    
    return opts
  end,
}