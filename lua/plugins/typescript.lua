--[[
機能概要: TypeScript LSP設定 - 最高性能追求 (typescript-tools.nvim)
設定内容: vtslsから直接tsserver通信による高速化、モノレポ対応
キーバインド: LSP標準キーマップ
--]]
return {
  -- typescript-tools.nvim：vtslsより高速な直接tsserver通信
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    opts = function()
      return {
        -- モノレポ対応：.gitをルートとして検出
        root_dir = require("lspconfig.util").root_pattern(".git"),

        on_attach = function(client, bufnr)
          -- Prettierでフォーマットするため、LSPフォーマットを無効化
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end,

        settings = {
          -- 診断用tsserverを無効化してメモリ消費を削減
          separate_diagnostic_server = false,
          -- 診断のタイミング：insert_leave時（パフォーマンス重視）
          publish_diagnostic_on = "insert_leave",
          -- コードアクションとしてimport整理機能を公開
          expose_as_code_action = { "organize_imports", "add_missing_imports", "remove_unused_imports" },
          -- JSX自動クローズタグ
          jsx_close_tag = {
            enable = true,
            filetypes = { "javascriptreact", "typescriptreact" },
          },
          -- tsserver設定
          tsserver_file_preferences = {
            includeInlayParameterNameHints = "all",
            includeCompletionsForModuleExports = true,
            quotePreference = "auto",
          },
          tsserver_format_options = {
            allowIncompleteCompletions = false,
            allowRenameOfImportPath = false,
          },
        },
      }
    end,
  },

  -- LazyVim TypeScript extra設定を無効化（vtslsと競合回避）
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- vtslsを無効化（typescript-tools.nvimと競合を避ける）
      opts.servers = opts.servers or {}
      opts.servers.vtsls = vim.tbl_deep_extend("force", opts.servers.vtsls or {}, {
        enabled = false,
      })

      return opts
    end,
  },
}
