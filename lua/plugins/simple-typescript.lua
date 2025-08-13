--[[
シンプルなTypeScript設定 - 重複インポート問題の解決
目的: tsserver単体でTypeScriptを管理し、重複LSPの問題を解決
--]]

return {
  -- LazyVimのデフォルトTypeScript設定を無効化
  { "yioneko/nvim-vtsls", enabled = false },

  -- TypeScript Language Server（tsserver単体）
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- 他のTypeScript LSPを無効化
      opts.servers = opts.servers or {}
      opts.servers.vtsls = false
      opts.servers.ts_ls = false
      
      -- tsserver設定
      opts.servers.tsserver = {
        settings = {
          typescript = {
            suggest = {
              autoImports = true,
            },
          },
          javascript = {
            suggest = {
              autoImports = true, 
            },
          },
        },
      }
      
      return opts
    end,
  },

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
            -- 自動インポートのcode actionを実行
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
        {
          "<leader>;o",
          function()
            -- インポート整理
            vim.lsp.buf.code_action({
              context = {
                only = { "source.organizeImports" },
                diagnostics = {},
              },
              apply = true,
            })
          end,
          desc = "インポート整理",
        },
      },
    },
  },
}