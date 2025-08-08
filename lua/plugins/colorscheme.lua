return {
  "tomasiser/vim-code-dark",
  lazy = false, -- カラースキームは即座に読み込む（仕様上正しい）
  priority = 1000, -- 他のプラグインより先に読み込む
  config = function()
    vim.cmd.colorscheme("codedark")
  end,
}
