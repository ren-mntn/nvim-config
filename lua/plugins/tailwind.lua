--[[
機能概要: Tailwind CSS設定 - blink.cmp連携・カラー表示
設定内容: tailwindcss-language-server設定、blink.cmp用カラー表示、補完最適化
対応形式: class名補完、カラーコード表示、Tailwind CSS IntelliSense
--]]
return {

  -- LSP設定
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tailwindcss = {
          -- filetypeを追加指定
          filetypes = {
            "html",
            "css",
            "scss",
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
            "vue",
            "svelte",
          },
          settings = {
            tailwindCSS = {
              classAttributes = { "class", "className", "class:list", "classList", "ngClass" },
              lint = {
                cssConflict = "warning",
                invalidApply = "error",
                invalidConfigPath = "error",
                invalidScreen = "error",
                invalidTailwindDirective = "error",
                invalidVariant = "error",
                recommendedVariantOrder = "warning",
              },
              validate = true,
            },
          },
        },
      },
    },
  },

  -- nvim-highlight-colorsでTailwindカラーを表示（blink.cmp対応済み）
  {
    "brenoprata10/nvim-highlight-colors",
    opts = {
      render = "background",
      enable_named_colors = true,
      enable_tailwind = true,
    },
  },
}