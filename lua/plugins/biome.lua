--[[
機能概要: Biome統合設定 - LSP・フォーマッター・リンター完全移行
設定内容: ESLint/Prettier完全代替、モノレポ対応
キーバインド: Biome全機能統合（import整理・フォーマット・リント修正）
--]]

return {
  -- nvim-lspconfig: BiomeのLSP設定（簡素化）
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- 一時的にLSPを無効化し、CLIフォールバック方式のみ使用

      return opts
    end,
  },

  -- conform.nvim: Biomeフォーマッター設定
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}

      -- Biomeフォーマッターをファイルタイプ別に設定
      local biome_filetypes = {
        "javascript",
        "javascriptreact",
        "typescript",
        "typescriptreact",
        "vue",
        "svelte",
        "astro",
        "json",
        "jsonc",
      }

      for _, ft in ipairs(biome_filetypes) do
        -- 既存の設定を保持しつつBiomeを優先
        local existing = opts.formatters_by_ft[ft] or {}
        opts.formatters_by_ft[ft] = { "biome", stop_after_first = true, lsp_format = "fallback" }
      end

      -- Biomeフォーマッターのカスタム設定
      opts.formatters = opts.formatters or {}
      opts.formatters.biome = {
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
        args = function(self, ctx)
          return { "format", "--stdin-file-path", ctx.filename or "$FILENAME" }
        end,
        stdin = true,
        condition = function(self, ctx)
          if not ctx or not ctx.filename then
            return false
          end

          local supported_ft = {
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
            "vue",
            "svelte",
            "astro",
            "json",
            "jsonc",
          }

          local bufnr = vim.fn.bufnr(ctx.filename)
          local filetype = bufnr > 0 and vim.bo[bufnr].filetype or ""

          if not vim.tbl_contains(supported_ft, filetype) then
            return false
          end

          local root_files = vim.fs.find({ "biome.json", "biome.jsonc" }, {
            path = ctx.filename,
            upward = true,
          })

          return root_files[1] ~= nil
        end,
        cwd = function(self, ctx)
          if not ctx or not ctx.filename then
            return nil
          end
          local root_files = vim.fs.find({ "biome.json", "biome.jsonc" }, {
            path = ctx.filename,
            upward = true,
          })
          return root_files[1] and vim.fs.dirname(root_files[1]) or nil
        end,
      }

      return opts
    end,
  },
}
