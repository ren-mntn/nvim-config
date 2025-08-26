--[[
機能概要: LSPの定義/参照/実装をVSCode風のピークプレビューで表示するプラグイン
設定内容: 最小設定でglance.nvimを導入、基本的なキーマッピングを設定
キーバインド: gD(定義), gR(参照), gY(型定義), gM(実装)
--]]
return {
  "DNLHC/glance.nvim",
  event = "VeryLazy",
  keys = {
    { "gd", vim.lsp.buf.definition, desc = "定義に移動" },
    { "gD", "<cmd>Glance definitions<cr>", desc = "定義を表示" },
    { "gR", "<cmd>Glance references<cr>", desc = "参照を表示" },
    { "gY", "<cmd>Glance type_definitions<cr>", desc = "型定義を表示" },
    { "gM", "<cmd>Glance implementations<cr>", desc = "実装を表示" },
  },
  opts = {
    height = 18,
    zindex = 45,
  },
}
