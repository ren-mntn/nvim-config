return {
  -- LSP設定
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    opts = function(_, opts)
      -- typos_lsp設定
      opts.servers = opts.servers or {}
      opts.servers.typos_lsp = {}
      
      -- 古いtsserverは無効化（LazyVimのTypeScript extrasがvtslsを使用）
      opts.servers.tsserver = false
      
      return opts
    end,
  },
}