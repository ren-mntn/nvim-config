--[[
TypeScript設定
目的: vtsls（LazyVim推奨）+ カスタムキーマップ
--]]

return {
  -- TypeScript用キーマップ
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>;", group = "TypeScript", mode = { "n", "v" } },
        {
          "<leader>;f",
          function()
            vim.lsp.buf.format()
          end,
          desc = "フォーマット",
        },
        {
          "<leader>;i",
          function()
            -- 自動インポート（選択画面なし）
            vim.lsp.buf.code_action({
              context = {
                only = { "source.addMissingImports" },
                diagnostics = {},
              },
              apply = true,
            })
          end,
          desc = "自動インポート",
        },
      },
    },
  },
}
