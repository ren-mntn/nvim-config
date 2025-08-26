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
        -- モノレポ対応：各プロジェクトディレクトリをルートとして検出
        root_dir = require("lspconfig.util").root_pattern("tsconfig.json", "package.json", ".git"),

        on_attach = function(client, bufnr)
          -- Prettierでフォーマットするため、LSPフォーマットを無効化
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end,

        settings = {
          -- 診断用tsserverを有効化して診断表示を改善
          separate_diagnostic_server = true,
          -- 診断のタイミング：変更時（リアルタイム診断）
          publish_diagnostic_on = "change",
          -- コードアクションとしてimport整理機能とクイックフィックスを公開
          expose_as_code_action = { 
            "organize_imports", 
            "add_missing_imports", 
            "remove_unused_imports",
            "fix_all"
          },
          -- JSX自動クローズタグ
          jsx_close_tag = {
            enable = true,
            filetypes = { "javascriptreact", "typescriptreact" },
          },
          -- tsserver設定
          tsserver_file_preferences = {
            includeInlayParameterNameHints = "literals",
            includeCompletionsForModuleExports = true,
            quotePreference = "auto",
            -- React Hooks関連の詳細エラー表示を有効化
            includeInlayEnumMemberValueHints = true,
            includeInlayFunctionLikeReturnTypeHints = true,
            includeInlayVariableTypeHints = false,
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
      opts.servers.vtsls = false
      opts.servers.tsserver = false
      return opts
    end,
  },
}
