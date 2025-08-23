--[[
TypeScript + Prettier ハイブリッド設定
機能: <leader>; で保存 + 全自動修正
  - 自動インポート追加: TypeScript LSP
  - インポート整理: ESLint (source.fixAll.eslint)
  - フォーマット: Prettier (source.fixAll.prettier)
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
          local filename = vim.api.nvim_buf_get_name(bufnr)
          local filetype = vim.bo[bufnr].filetype

          -- TypeScript/JavaScript関連ファイルのみ処理
          if not vim.tbl_contains({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, filetype) then
            -- その他のファイルは単純に保存
            vim.cmd("write")
            return
          end

          -- 1. TypeScript LSPで自動インポート追加とインポート整理
          vim.schedule(function()
            -- 自動インポート追加
            pcall(function()
              vim.lsp.buf.code_action({
                context = {
                  only = { "source.addMissingImports" },
                  diagnostics = {},
                },
                apply = true,
              })
            end)

            -- 2. 50ms後にESLintでインポート整理
            vim.defer_fn(function()
              -- ESLintでインポート整理
              pcall(function()
                vim.lsp.buf.code_action({
                  context = {
                    only = { "source.fixAll.eslint" },
                    diagnostics = {},
                  },
                  apply = true,
                })
              end)

              -- 3. ESLintの処理完了を待ってからPrettierでフォーマット
              vim.defer_fn(function()
                local success, result = pcall(function()
                  -- conform.nvimでPrettierフォーマットを実行
                  local conform = require("conform")
                  if conform then
                    return conform.format({ bufnr = bufnr, async = false })
                  else
                    error("conform.nvim not available")
                  end
                end)

                if not success then
                  vim.notify("Prettier format failed: " .. tostring(result), vim.log.levels.WARN)
                end

                -- 4. Prettier処理完了を待ってから保存
                vim.defer_fn(function()
                  vim.cmd("write")
                  vim.notify("✅ 完了: インポート整理 + フォーマット + 保存", vim.log.levels.INFO)
                end, 100)
              end, 100) -- ESLintの処理完了を待つ
            end, 50)
          end)
        end,
        desc = "全自動修正 + 保存 (ESLint + Prettier)",
        mode = "n",
      },
    },
  },

  -- conform.nvim設定はLazyVim extrasで自動設定されるため削除

  -- LSP設定
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- TypeScript LSP (vtsls)のフォーマットを無効化
        vtsls = {
          settings = {
            typescript = {
              format = {
                enable = false, -- Prettierでフォーマット
              },
            },
            javascript = {
              format = {
                enable = false, -- Prettierでフォーマット
              },
            },
          },
        },
      },
    },
  },
}
