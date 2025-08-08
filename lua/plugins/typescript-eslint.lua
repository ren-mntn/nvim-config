return {
  -- TypeScript/JavaScript自動インポート & 整理
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    opts = function(_, opts)
      -- vtslsは自動インポート提案のみ
      opts.servers = opts.servers or {}
      opts.servers.tsserver = false
      opts.servers.vtsls = {
        settings = {
          typescript = {
            updateImportsOnFileMove = { enabled = "always" },
            suggest = {
              autoImports = true,
              completeFunctionCalls = true,
            },
            preferences = {
              includeCompletionsForModuleExports = true,
              includeCompletionsForImportStatements = true,
              includePackageJsonAutoImports = "auto",
            },
          },
          javascript = {
            updateImportsOnFileMove = { enabled = "always" },
            suggest = {
              autoImports = true,
              completeFunctionCalls = true,
            },
            preferences = {
              includeCompletionsForModuleExports = true,
              includeCompletionsForImportStatements = true,
              includePackageJsonAutoImports = "auto",
            },
          },
        },
      }

      -- 保存時に自動修正（不足インポート追加 + 未使用削除 + ESLint整理）
      -- 処理中フラグでリピート防止
      local processing = {}
      
      vim.api.nvim_create_autocmd({ "BufWritePre", "BufWritePost", "User" }, {
        group = vim.api.nvim_create_augroup("TypeScriptAutoFix", { clear = true }),
        pattern = { "*.ts", "*.tsx", "*.js", "*.jsx", "TypeScriptAutoFix" },
        callback = function(args)
          local bufnr = args.data and args.data.bufnr or vim.api.nvim_get_current_buf()
          local filename = args.data and args.data.filename or vim.api.nvim_buf_get_name(bufnr)
          
          -- ファイルが存在し、編集可能で、まだ処理中でない場合のみ実行
          if filename ~= "" and vim.bo[bufnr].buftype == "" and not vim.bo[bufnr].readonly and not processing[filename] then
            processing[filename] = true
            print("🔧 TypeScript自動修正開始: " .. vim.fn.fnamemodify(filename, ":t"))
            
            -- 1. 不足インポートを追加
            vim.lsp.buf.code_action({
              context = { only = { "source.addMissingImports" }, diagnostics = {} },
              apply = true,
            })
            
            -- 少し待ってから未使用インポート削除とESLint実行
            vim.defer_fn(function()
              print("🗑️  未使用インポート削除実行")
              -- 2. 未使用インポートを削除
              vim.lsp.buf.code_action({
                context = { only = { "source.removeUnused" }, diagnostics = {} },
                apply = true,
              })
              
              -- さらに待ってからESLint実行（LSPの処理を待つ）
              vim.defer_fn(function()
                print("⚡ ESLint --fix実行")
                -- 3. ESLint --fix でインポート整理
                local result = vim.fn.system("eslint_d --fix " .. vim.fn.shellescape(filename))
                
                -- ファイルが変更された場合はリロード
                if vim.v.shell_error == 0 or vim.v.shell_error == 1 then
                  vim.cmd("silent! checktime")
                  print("✅ TypeScript自動修正完了")
                else
                  print("❌ ESLint実行エラー: " .. result)
                end
                
                -- 処理完了フラグをクリア（少し遅延してクリア）
                vim.defer_fn(function()
                  processing[filename] = nil
                end, 500)
              end, 200)
            end, 200)
          end
        end,
      })
      
      return opts
    end,
    keys = {
      {
        "<leader>cf",
        function()
          -- 手動でESLint --fixを実行
          local filename = vim.api.nvim_buf_get_name(0)
          if filename ~= "" then
            vim.cmd("!eslint_d --fix " .. vim.fn.shellescape(filename))
            vim.cmd("edit!")
          else
            vim.notify("ファイルが保存されていません", vim.log.levels.WARN)
          end
        end,
        desc = "ESLint --fix (手動実行)",
        ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
      },
      {
        "<leader>ci",
        function()
          -- 不足インポートを追加
          vim.lsp.buf.code_action({
            context = { only = { "source.addMissingImports" }, diagnostics = {} },
            apply = true,
          })
        end,
        desc = "不足インポートを追加",
        ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
      },
      {
        "<leader>cI",
        function()
          -- すべての不足要素を修正
          vim.lsp.buf.code_action({
            context = { only = { "source.fixAll" }, diagnostics = {} },
            apply = true,
          })
        end,
        desc = "すべて修正（インポート含む）",
        ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
      },
      {
        "<leader>cu",
        function()
          -- 未使用インポートを削除
          vim.lsp.buf.code_action({
            context = { only = { "source.removeUnused" }, diagnostics = {} },
            apply = true,
          })
        end,
        desc = "未使用インポート削除",
        ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
      },
    },
  },
}