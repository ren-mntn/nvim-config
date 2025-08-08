return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" }, -- ファイル読み込み時
    opts = {
      servers = {
        typos_lsp = {},
      },
    },
  },
}