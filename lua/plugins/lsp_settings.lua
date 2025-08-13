return {
  -- LSP設定
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    opts = function(_, opts)
      -- 安全な初期化
      opts = opts or {}
      opts.servers = opts.servers or {}

      -- typos_lsp設定
      opts.servers.typos_lsp = {}

      -- 古いtsserverは無効化（LazyVimのTypeScript extrasがvtslsを使用）
      opts.servers.tsserver = false

      return opts
    end,
  },
}
