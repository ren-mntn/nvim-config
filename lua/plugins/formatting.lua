--[[
機能概要: TSServer + ESLint統合フォーマット設定
設定内容: <leader>; で保存 + TSServer自動インポート + ESLint修正
キーバインド: <leader>; - TSServer自動インポート + ESLint修正 + 保存
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
          if
            not vim.tbl_contains(
              { "typescript", "typescriptreact", "javascript", "javascriptreact", "json", "jsonc" },
              filetype
            )
          then
            if vim.bo[bufnr].buftype == "" and vim.bo[bufnr].modifiable then
              vim.cmd("write")
            end
            return
          end

          -- 1. TSServer自動インポート追加
          vim.lsp.buf.code_action({
            filter = function(action)
              return action.kind
                and (
                  action.kind:match("source%.addMissingImports")
                  or action.kind:match("quickfix%.ts%.addMissingImports")
                  or action.title:match("[Aa]dd.*[Ii]mport")
                  or action.title:match("[Ff]ix.*[Ii]mport")
                  or action.title:match("Import.*from")
                )
            end,
            apply = true,
          })

          -- 2. ESLint修正を実行
          vim.defer_fn(function()
            local eslint_client = vim.lsp.get_clients({ name = "eslint", bufnr = bufnr })[1]
            if eslint_client then
              vim.cmd("EslintFixAll")
            end

            -- 3. 保存
            vim.defer_fn(function()
              if vim.bo[bufnr].buftype == "" and vim.bo[bufnr].modifiable then
                vim.cmd("write")
              end
              vim.notify("✅ TSServer + ESLint修正完了", vim.log.levels.INFO)
            end, 10) -- ESLint処理後に保存
          end, 10) -- TSServer処理後にESLint実行
        end,
        desc = "auto fix with TSServer + ESLint + save",
        mode = "n",
      },
    },
  },
}
