return {
  -- シンプルなBufWritePreベースの自動修正
  {
    "neovim/nvim-lspconfig",
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
      
      return opts
    end,
  },
  
  -- BufWritePreでESLint自動修正
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- 保存時に自動修正（不足インポート追加 + ESLint --fix）
      -- 処理中フラグでリピート防止
      local processing = {}
      
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = vim.api.nvim_create_augroup("TypeScriptAutoFix", { clear = true }),
        pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
        callback = function()
          local bufnr = vim.api.nvim_get_current_buf()
          local filename = vim.api.nvim_buf_get_name(bufnr)
          
          -- ファイルが存在し、編集可能で、まだ処理中でない場合のみ実行
          if filename ~= "" and vim.bo[bufnr].buftype == "" and not vim.bo[bufnr].readonly and not processing[filename] then
            processing[filename] = true
            
            -- 1. 不足インポートを追加
            vim.lsp.buf.code_action({
              context = { only = { "source.addMissingImports" }, diagnostics = {} },
              apply = true,
            })
            
            -- 少し待ってからESLint実行（LSPの処理を待つ）
            vim.defer_fn(function()
              -- 2. ESLint --fix でインポート整理
              local result = vim.fn.system("eslint_d --fix " .. vim.fn.shellescape(filename))
              
              -- ファイルが変更された場合はリロード
              if vim.v.shell_error == 0 or vim.v.shell_error == 1 then
                vim.cmd("silent! checktime")
              end
              
              -- 処理完了フラグをクリア（少し遅延してクリア）
              vim.defer_fn(function()
                processing[filename] = nil
              end, 500)
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
    },
  },
}