--[[
機能概要: leap.nvimをベースに、f/F/t/Tモーションを強化します。
設定内容: ラベルが表示されるモードをnormalとvisualに限定します。
キーバインド: このプラグインは既存のf/F/t/Tを自動的に上書きします。
--]]
return {
  "ggandor/flit.nvim",
  dependencies = { "ggandor/leap.nvim" },
  event = "VeryLazy",
  opts = function(_, opts)
    local custom_opts = {
      labeled_modes = "nv",
    }
    return vim.tbl_deep_extend("force", opts, custom_opts)
  end,
}
