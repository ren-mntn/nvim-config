--[[
TypeScript + Biome ハイブリッド設定
機能: <leader>; で保存 + 全自動修正
  - 自動インポート追加: TypeScript LSP
  - インポート整理: ESLint (source.fixAll.eslint)
  - 自動修正: Biome (source.fixAll.biome)
--]]

return {
  -- シンプルなキーマップ設定
  {
    "folke/which-key.nvim",
    optional = true,
    opts = function(_, opts)
      -- 既存の<leader>;関連のキーマップを削除
      opts.spec = opts.spec or {}
      
      -- 新しいキーマップを追加
      table.insert(opts.spec, {
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
              
              -- 3. ESLintの処理完了を待ってからBiomeで自動修正
              vim.defer_fn(function()
                pcall(function()
                  vim.lsp.buf.code_action({
                    context = {
                      only = { "source.fixAll.biome" },
                      diagnostics = {},
                    },
                    apply = true,
                  })
                end)
                
                -- 4. Biome処理完了を待ってから保存
                vim.defer_fn(function()
                  vim.cmd("write")
                end, 100)
              end, 100) -- ESLintの処理完了を待つ
            end, 50)
          end)
        end,
        desc = "全自動修正 + 保存 (ESLint + Biome)",
        mode = { "n" },
      })
      
      return opts
    end,
  },
  
  -- Biome LSP設定
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Biome LSP
        biome = {
          capabilities = {
            workspace = {
              didChangeWatchedFiles = {
                dynamicRegistration = true,
              },
            },
          },
        },
        -- TypeScript LSP (vtsls)のフォーマットを無効化
        vtsls = {
          settings = {
            typescript = {
              format = {
                enable = false, -- Biomeでフォーマット
              },
            },
            javascript = {
              format = {
                enable = false, -- Biomeでフォーマット
              },
            },
          },
        },
      },
    },
  },
}