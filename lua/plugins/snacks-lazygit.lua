--[[
機能概要: LazyVimのSnacks.nvim経由でlazygitの設定をカスタマイズ
設定内容: 背景色をグレーに変更、差分表示を左右分割に設定
キーバインド: <leader>gg (lazygit), <leader>gl (log), <leader>gf (file log)
--]]
return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    -- 安全な初期化
    opts.lazygit = opts.lazygit or {}

    -- カスタム設定ファイルパス
    local config_path = vim.fn.expand("~/.config/nvim/lua/plugins/lazygit-config.yml")

    -- 設定のマージ（完全上書きではない）
    opts.lazygit = vim.tbl_deep_extend("force", opts.lazygit, {
      -- 自動設定（テーマとNeovim統合）を無効化
      configure = false,

      -- カスタム設定ファイルを指定（正しい引数名）
      args = { "--use-config-file", config_path },

      -- ウィンドウ設定
      win = {
        style = "lazygit",
        width = 0.9,
        height = 0.9,
      },
    })

    -- グレー背景用のハイライトグループを作成
    vim.api.nvim_set_hl(0, "LazygitGrayBg", { bg = "#181818" })

    -- lazygitウィンドウスタイルでグレー背景を設定
    opts.styles = opts.styles or {}
    opts.styles.lazygit = vim.tbl_deep_extend("force", opts.styles.lazygit or {}, {
      wo = {
        winhighlight = "Normal:LazygitGrayBg,NormalFloat:LazygitGrayBg",
      },
      backdrop = false,
    })

    return opts
  end,

  keys = {
    {
      "<leader>gg",
      function()
        Snacks.lazygit()
      end,
      desc = "Lazygit",
    },
    {
      "<leader>gl",
      function()
        Snacks.lazygit.log()
      end,
      desc = "Lazygit Log",
    },
    {
      "<leader>gf",
      function()
        Snacks.lazygit.log_file()
      end,
      desc = "Lazygit Log File",
    },
  },
}
