--[[
機能概要: Biome統合フォーマット設定
設定内容: <leader>; で保存 + Biomeによる全自動修正（インポート整理・フォーマット・修正）
キーバインド: <leader>; - Biome LSPによるインポート整理 + フォーマット + 保存
--]]

return {
  -- キーマップ設定（標準的なLazyVim方式）
  {
    "LazyVim/LazyVim",
    keys = {
      {
        "<leader>;",
        function()
          local bufnr = vim.api.nvim_get_current_buf()
          local filetype = vim.bo[bufnr].filetype

          -- TypeScript/JavaScript関連ファイル以外は単純に保存
          if not vim.tbl_contains({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, filetype) then
            if vim.bo[bufnr].buftype == "" and vim.bo[bufnr].modifiable then
              vim.cmd("write")
            end
            return
          end

          -- Biome LSP code actionでインポート整理とfixAll
          vim.lsp.buf.code_action({
            context = {
              only = { "source.organizeImports" },
              diagnostics = {},
            },
            apply = true,
          })

          -- fixAllも実行
          vim.defer_fn(function()
            vim.lsp.buf.code_action({
              context = {
                only = { "source.fixAll" },
                diagnostics = {},
              },
              apply = true,
            })
          end, 50)

          -- fixAll完了後にフォーマットと保存
          vim.defer_fn(function()
            -- Biomeでフォーマット
            local success = pcall(function()
              local conform = require("conform")
              conform.format({
                bufnr = bufnr,
                async = false,
                formatters = { "biome" },
              })
            end)

            if not success then
              vim.notify("Biome format failed", vim.log.levels.WARN)
            end

            -- 保存
            vim.defer_fn(function()
              if vim.bo[bufnr].buftype == "" and vim.bo[bufnr].modifiable then
                vim.cmd("write")
              end
              vim.notify(
                "✅ 完了: Biomeインポート整理 + fixAll + フォーマット + 保存",
                vim.log.levels.INFO
              )
            end, 100)
          end, 150)
        end,
        desc = "Biome全自動修正 + 保存",
        mode = "n",
      },
    },
  },
}
