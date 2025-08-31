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

    -- カラースキーム適用完了を待つ
    vim.defer_fn(function()
      -- VS Code Dark テーマカラー定義
      local colors = {
        -- 基本色
        comment = "#6A9955", -- 緑系コメント
        string = "#CE9178", -- オレンジ系文字列
        yellow = "#DCDCAA", -- 黄色（関数名）
        highYellow = "#d6b619", -- 黄色（）{}[]
        purple = "#C678DD", -- 紫（キーワード）
        cyan = "#4EC9B0", -- シアン（型）
        skyblue = "#9CDCFE", -- 水色（変数、属性）
        liteGreen = "#7ed3c5", -- JSXタグ（薄い水色）

        -- import/export系
        pink = "#C284BD", -- ピンク（import/export）
        blue = "#5f9fd3", -- 青（function等）
        blue2 = "#6ac6f7", -- 青（function等） 変数名

        -- JSX/TSX系
        jsxDelimiter = "#808080", -- タグ区切り文字（グレー）

        -- その他
        white = "#FFFFFF", -- 白
        gray = "#CCCCCC", -- グレー（演算子等）
        darkGray = "#5A5A5A", -- 暗いグレー（inlay hints）
        red = "#f90000", -- 赤
      }

      -- -- カスタムハイライト設定
      -- vim.api.nvim_set_hl(0, "Comment", { fg = colors.red }) -- コメントをグレーに
      -- vim.api.nvim_set_hl(0, "String", { fg = colors.string }) -- 文字列をオレンジに
      -- vim.api.nvim_set_hl(0, "Function", { fg = colors.yellow }) -- 関数名を黄色・太字に
      -- vim.api.nvim_set_hl(0, "Keyword", { fg = colors.purple }) -- キーワードを紫・太字に（export含む）
      -- vim.api.nvim_set_hl(0, "Type", { fg = colors.cyan }) -- 型を緑に
      -- vim.api.nvim_set_hl(0, "Variable", { fg = colors.skyblue }) -- 変数を水色に
      -- --
      -- -- Treesitterの既存グループを活用（より効率的）
      -- vim.api.nvim_set_hl(0, "@keyword.import", { fg = colors.pink }) -- import/export専用グループ
      -- vim.api.nvim_set_hl(0, "@keyword.function", { fg = colors.blue }) -- function定義キーワード
      -- vim.api.nvim_set_hl(0, "@keyword.modifier", { fg = colors.blue }) -- const, static等のmodifier
      --
      -- -- await/return系キーワード
      -- vim.api.nvim_set_hl(0, "@keyword.coroutine", { fg = colors.pink }) -- await (coroutine関連)
      -- vim.api.nvim_set_hl(0, "@keyword.return", { fg = colors.pink }) -- return/yield
      --
      -- -- type定義キーワード
      -- vim.api.nvim_set_hl(0, "@keyword.type", { fg = colors.pink }) -- type, interface等の型定義キーワード
      --
      -- -- 区切り文字（括弧は rainbow-delimiters.nvim で管理）
      -- vim.api.nvim_set_hl(0, "@punctuation.delimiter", { fg = colors.gray }) -- ;,.?等の区切り文字（テスト用）
      -- vim.api.nvim_set_hl(0, "@punctuation.special", { fg = colors.blue }) -- 特殊記号（テンプレート文字列内の${}等）
      --
      -- -- オプショナル演算子・その他演算子
      -- vim.api.nvim_set_hl(0, "@operator", { fg = colors.gray }) -- +, -, *, /, =等の演算子
      -- vim.api.nvim_set_hl(0, "@keyword.operator", { fg = colors.gray }) -- &&, ||, ?, :等の英単語演算子
      -- vim.api.nvim_set_hl(0, "@keyword.conditional.ternary", { fg = colors.gray }) -- 三項演算子の ? :
      --
      -- -- JSX/TSX タグの色設定
      -- vim.api.nvim_set_hl(0, "@tag", { fg = colors.liteGreen }) -- HTMLタグ（<div>、<span>等）
      -- vim.api.nvim_set_hl(0, "@tag.tsx", { fg = colors.liteGreen }) -- TSX専用
      -- vim.api.nvim_set_hl(0, "@tag.builtin", { fg = colors.skyblue }) -- 組み込みHTMLタグ
      -- vim.api.nvim_set_hl(0, "@tag.builtin.tsx", { fg = colors.skyblue }) -- TSX専用
      -- vim.api.nvim_set_hl(0, "@tag.delimiter", { fg = colors.jsxDelimiter }) -- <>タグ区切り文字
      -- vim.api.nvim_set_hl(0, "@tag.attribute", { fg = colors.skyblue }) -- 属性名
      -- vim.api.nvim_set_hl(0, "@tag.attribute.tsx", { fg = colors.skyblue }) -- TSX専用
      -- vim.api.nvim_set_hl(0, "@type.tsx", { fg = colors.skyblue }) -- 型定義
      --
      -- -- 定数のハイライト（OCCUPATION、SEX_OPTIONSなど）
      -- vim.api.nvim_set_hl(0, "@constant", { fg = colors.skyblue }) -- 確認用に赤色
      --
      -- -- 例外キーワード（try、catch、throwなど）
      -- vim.api.nvim_set_hl(0, "@keyword.exception", { fg = colors.pink }) -- 例外キーワードを赤色
      --
      -- -- 条件分岐キーワード（if、else、switch、caseなど）
      -- vim.api.nvim_set_hl(0, "@keyword.conditional", { fg = colors.pink }) -- 条件分岐キーワードを赤色
      --
      -- 波括弧のみ黄色に設定（import文含む）
      vim.api.nvim_set_hl(0, "typescriptProp", { fg = colors.red }) -- TypeScript波括弧のみ
      vim.api.nvim_set_hl(0, "typescriptBraces", { fg = colors.highYellow }) -- TypeScript波括弧のみ
      vim.api.nvim_set_hl(0, "typescriptParens", { fg = colors.highYellow}) -- TypeScript波括弧のみ
      vim.api.nvim_set_hl(0, "typescriptTypeBlock", { fg = colors.skyblue }) -- TypeScript波括弧のみ
      vim.api.nvim_set_hl(0, "typescriptDefaultImportName", { fg = colors.skyblue }) -- TypeScript波括弧のみ
      -- vim.api.nvim_set_hl(0, "typescriptProp", { fg = colors.red }) -- TypeScript波括弧のみ
      vim.api.nvim_set_hl(0, "tsxTagName", { fg = colors.cyan }) -- TypeScript波括弧のみ
    end, 100) -- 100ms後に実行してカラースキーム適用を確実にする
  end,
}
