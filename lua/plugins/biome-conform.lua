--[[
機能概要: Biome Checkフォーマッター - インポート整理・リント・フォーマット統合
設定内容: conform.nvimでbiome-checkフォーマッターを実装
キーバインド: なし（conform.nvim経由で呼び出し）
--]]
return {
  -- 【Biome設定】
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- formatters_by_ftを初期化
      opts.formatters_by_ft = opts.formatters_by_ft or {}

      -- TypeScript/JavaScript用のフォーマッター設定
      local web_formatter = { "biome-check", stop_after_first = true }

      opts.formatters_by_ft.typescript = web_formatter
      opts.formatters_by_ft.typescriptreact = web_formatter
      opts.formatters_by_ft.javascript = web_formatter
      opts.formatters_by_ft.javascriptreact = web_formatter
      opts.formatters_by_ft.json = web_formatter
      opts.formatters_by_ft.jsonc = web_formatter

      -- カスタムフォーマッターの設定
      opts.formatters = opts.formatters or {}

      -- biome-checkフォーマッター定義
      opts.formatters["biome-check"] = {
        command = function()
          local mason_path = vim.fn.stdpath("data") .. "/mason/bin/biome"
          if vim.fn.executable(mason_path) == 1 then
            return mason_path
          elseif vim.fn.executable("biome") == 1 then
            return "biome"
          else
            return "biome" -- fallback
          end
        end,
        -- biome checkコマンド：unsafe fixも含めてReact Hooks依存配列修正を実行
        args = { "check", "--write", "--unsafe", "--assist-enabled=true", "--stdin-file-path", "$FILENAME" },
        stdin = true,
        -- ワーキングディレクトリをプロジェクトルートに設定
        cwd = function(self, ctx)
          if not ctx or not ctx.filename then
            return nil
          end
          local root_files = vim.fs.find({ "biome.json", "biome.jsonc", "package.json" }, {
            path = ctx.filename,
            upward = true,
          })
          return root_files[1] and vim.fs.dirname(root_files[1]) or nil
        end,
        -- 条件チェック：Biome設定ファイルがある場合のみ実行
        condition = function(self, ctx)
          if not ctx or not ctx.filename then
            return false
          end

          local supported_ft = {
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
            "json",
            "jsonc",
          }

          local bufnr = vim.fn.bufnr(ctx.filename)
          local filetype = bufnr > 0 and vim.bo[bufnr].filetype or ""

          if not vim.tbl_contains(supported_ft, filetype) then
            return false
          end

          -- Biome設定ファイルの存在確認
          local root_files = vim.fs.find({ "biome.json", "biome.jsonc" }, {
            path = ctx.filename,
            upward = true,
          })

          return root_files[1] ~= nil
        end,
      }

      return opts
    end,
  },

  -- 【ESLint設定 - 一時的にコメントアウト】
  --[[
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- formatters_by_ftを初期化
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      
      -- TypeScript/JavaScript用のESLintフォーマッター設定
      local web_formatter = { "eslint_d", stop_after_first = true }
      
      opts.formatters_by_ft.typescript = web_formatter
      opts.formatters_by_ft.typescriptreact = web_formatter
      opts.formatters_by_ft.javascript = web_formatter
      opts.formatters_by_ft.javascriptreact = web_formatter
      
      -- カスタムフォーマッターの設定
      opts.formatters = opts.formatters or {}
      
      -- eslint_dフォーマッター定義（simple-import-sort使用）
      opts.formatters.eslint_d = {
        command = "eslint_d",
        -- ESLint --fixでsimple-import-sortによるインポート整理を実行
        args = { "--fix", "--stdin", "--stdin-filename", "$FILENAME" },
        stdin = true,
        -- ワーキングディレクトリをプロジェクトルートに設定
        cwd = function(self, ctx)
          if not ctx or not ctx.filename then
            return nil
          end
          local root_files = vim.fs.find({ ".eslintrc.js", ".eslintrc.json", "eslint.config.js", "package.json" }, {
            path = ctx.filename,
            upward = true,
          })
          return root_files[1] and vim.fs.dirname(root_files[1]) or nil
        end,
        -- 条件チェック：ESLint設定ファイルがある場合のみ実行
        condition = function(self, ctx)
          if not ctx or not ctx.filename then
            return false
          end

          local supported_ft = {
            "javascript",
            "javascriptreact", 
            "typescript",
            "typescriptreact",
          }

          local bufnr = vim.fn.bufnr(ctx.filename)
          local filetype = bufnr > 0 and vim.bo[bufnr].filetype or ""

          if not vim.tbl_contains(supported_ft, filetype) then
            return false
          end

          -- ESLint設定ファイルの存在確認
          local root_files = vim.fs.find({ ".eslintrc.js", ".eslintrc.json", "eslint.config.js" }, {
            path = ctx.filename,
            upward = true,
          })

          return root_files[1] ~= nil
        end,
      }
      
      return opts
    end,
  },
  --]]
}
