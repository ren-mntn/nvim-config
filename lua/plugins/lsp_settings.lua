return {
  -- LSP設定
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      
      -- typos_lsp設定
      opts.servers.typos_lsp = {}
      
      return opts
    end,
  },
}