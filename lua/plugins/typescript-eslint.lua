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
      -- 保存時にESLint --fixを実行
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = vim.api.nvim_create_augroup("ESLintAutoFix", { clear = true }),
        pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
        callback = function()
          local bufnr = vim.api.nvim_get_current_buf()
          local filename = vim.api.nvim_buf_get_name(bufnr)
          
          -- ファイルが存在し、編集可能な場合のみ実行
          if filename ~= "" and vim.bo[bufnr].buftype == "" and not vim.bo[bufnr].readonly then
            -- eslint_d --fix を実行
            local result = vim.fn.system("eslint_d --fix " .. vim.fn.shellescape(filename))
            
            -- ファイルが変更された場合はリロード
            if vim.v.shell_error == 0 or vim.v.shell_error == 1 then
              vim.cmd("silent! checktime")
            end
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
    },
  },
}