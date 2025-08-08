-- 人気のカラースキーム選択肢：
-- "folke/tokyonight.nvim"     -- Tokyo Night（人気）
-- "catppuccin/nvim"          -- Catppuccin（パステル）
-- "rebelot/kanagawa.nvim"    -- 和風カラー
-- "ellisonleao/gruvbox.nvim" -- Gruvbox（温かい色調）

return {
  "tomasiser/vim-code-dark",
  lazy = false, -- カラースキームは即座に読み込む（仕様上正しい）
  priority = 1000, -- 他のプラグインより先に読み込む
  config = function()
    vim.cmd.colorscheme("codedark")
    
    -- カスタムハイライト設定
    vim.api.nvim_set_hl(0, "Comment", { fg = "#6A9955" })  -- コメントをグレーに
    vim.api.nvim_set_hl(0, "String", { fg = "#CE9178" })                  -- 文字列をオレンジに
    vim.api.nvim_set_hl(0, "Function", { fg = "#DCDCAA" })   -- 関数名を黄色・太字に
    vim.api.nvim_set_hl(0, "Keyword", { fg = "#C678DD" })    -- キーワードを紫・太字に（export含む）
    vim.api.nvim_set_hl(0, "Type", { fg = "#4EC9B0" })                    -- 型を緑に
    vim.api.nvim_set_hl(0, "Variable", { fg = "#9CDCFE" })                -- 変数を水色に
    
    -- Treesitterの既存グループを活用（より効率的）
    vim.api.nvim_set_hl(0, "@keyword.import", { fg = "#C284BD" })     -- import/export専用グループ
    vim.api.nvim_set_hl(0, "@keyword.function", { fg = "#5497CF" })   -- function定義キーワード
    vim.api.nvim_set_hl(0, "@keyword.modifier", { fg = "#5497CF" })   -- const, static等のmodifier
    
    -- await/return系キーワード
    vim.api.nvim_set_hl(0, "@keyword.coroutine", { fg = "#C284BD" })  -- await (coroutine関連)
    vim.api.nvim_set_hl(0, "@keyword.return", { fg = "#C284BD" })     -- return/yield
    
    -- type定義キーワード
    vim.api.nvim_set_hl(0, "@keyword.type", { fg = "#C284BD" })        -- type, interface等の型定義キーワード
    
    -- 区切り文字（括弧は rainbow-delimiters.nvim で管理）
    vim.api.nvim_set_hl(0, "@punctuation.delimiter", { fg = "#CCCCCC", })  -- ;,.?等の区切り文字（テスト用）
    vim.api.nvim_set_hl(0, "@punctuation.special", { fg = "#5497CF" })               -- 特殊記号（テンプレート文字列内の${}等）
    
    -- オプショナル演算子・その他演算子
    vim.api.nvim_set_hl(0, "@operator", { fg = "#CCCCCC" })             -- +, -, *, /, =等の演算子
    vim.api.nvim_set_hl(0, "@keyword.operator", { fg = "#CCCCCC" })     -- &&, ||, ?, :等の英単語演算子
    vim.api.nvim_set_hl(0, "@keyword.conditional.ternary", { fg = "#CCCCCC" }) -- 三項演算子の ? :
    
    -- LSP inlay hints のカラー調整（薄いグレーに）
    vim.api.nvim_set_hl(0, "LspInlayHint", { 
      fg = "#5A5A5A", 
      bg = "NONE", 
      italic = true 
    })
  end,
}
