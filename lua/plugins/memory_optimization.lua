--[[
メモリ最適化設定
機能: LSPサーバーのメモリ使用量を制限してシステム全体のパフォーマンスを向上
設定内容:
  - TypeScript LSP: 3GB → 1GB制限
  - 不要なAutoImport機能を無効化
  - ESLintのメモリ制限追加
--]]

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- デバッグ（実装時のみ、完了時削除）
      -- print("=== DEBUG: Memory optimization - Initial opts ===")
      -- print(vim.inspect(opts))

      -- 安全な初期化
      opts.servers = opts.servers or {}

      -- TypeScript LSP (vtsls) のメモリ最適化
      opts.servers.vtsls = vim.tbl_deep_extend("force", opts.servers.vtsls or {}, {
        -- メモリ制限を1GBに設定
        cmd = {
          "node",
          "--max-old-space-size=1024", -- 1GB制限
          vim.fn.exepath("vtsls"),
          "--stdio",
        },
        settings = {
          typescript = {
            preferences = {
              -- 大規模プロジェクトで重いAutoImportを無効化
              includePackageJsonAutoImports = "off",
              includeCompletionsForModuleExports = false,
            },
            format = {
              enable = false, -- Biomeでフォーマット
            },
            -- インクリメンタルビルドを無効化してメモリ節約
            disableAutomaticTypingAcquisition = true,
          },
          javascript = {
            preferences = {
              includePackageJsonAutoImports = "off",
              includeCompletionsForModuleExports = false,
            },
            format = {
              enable = false, -- Biomeでフォーマット
            },
          },
        },
      })

      -- ESLint Language Server のメモリ制限
      opts.servers.eslint = vim.tbl_deep_extend("force", opts.servers.eslint or {}, {
        cmd = {
          "node",
          "--max-old-space-size=512", -- 512MB制限
          vim.fn.exepath("vscode-eslint-language-server"),
          "--stdio",
        },
      })

      -- デバッグ（実装時のみ、完了時削除）
      -- print("=== DEBUG: Memory optimization - Final opts ===")
      -- print(vim.inspect(opts.servers.vtsls))

      return opts
    end,
  },
}
