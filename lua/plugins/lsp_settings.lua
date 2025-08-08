return {
  -- LSP設定
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" }, -- ファイル読み込み時
    opts = {
      servers = {
        typos_lsp = {},
        -- tsgoは2025年末までLSP未対応のため、vtslsを使用
        tsserver = false, -- 古いtsserverは無効化
        -- vtsls = {},  -- LazyVimのTypeScript extrasで自動有効化されるのでコメントアウト
      },
    },
  },
}