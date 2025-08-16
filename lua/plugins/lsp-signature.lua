--[[
機能概要: LSP関数シグネチャーのリアルタイム表示
設定内容: フローティングウィンドウでパラメータヒント、仮想テキスト表示
キーバインド: Ctrl+k でシグネチャーヘルプ手動表示
--]]
return {
  "ray-x/lsp_signature.nvim",
  event = "VeryLazy",
  keys = {
    {
      "<C-k>",
      function()
        require("lsp_signature").signature()
      end,
      mode = { "n", "i" },
      desc = "LSPシグネチャーヘルプ",
    },
  },
  opts = function(_, opts)
    -- 安全な初期化
    opts = opts or {}

    -- 設定のマージ
    local config = vim.tbl_deep_extend("force", opts, {
      -- フローティングウィンドウ設定
      floating_window = true,
      floating_window_above_cur_line = true,
      floating_window_off_x = 1,
      floating_window_off_y = 0,
      close_timeout = 4000,
      fix_pos = false,

      -- ボーダーとスタイル
      handler_opts = {
        border = "rounded",
      },

      -- ヒント設定
      hint_enable = true,
      hint_prefix = "🐼 ",
      hint_scheme = "String",

      -- ドキュメント設定
      doc_lines = 10,
      max_height = 12,
      max_width = 80,
      wrap = true,

      -- 自動トリガー
      auto_close_after = nil,
      extra_trigger_chars = {},
      zindex = 200,
      padding = " ",

      -- 選択オプション
      always_trigger = true,
      select_signature_key = nil,
      move_cursor_key = nil,

      -- ログとデバッグ
      debug = false,
      log_path = vim.fn.stdpath("cache") .. "/lsp_signature.log",
      verbose = false,

      -- 透明度
      transparency = nil,
      shadow_blend = 36,
      shadow_guibg = "Black",
      timer_interval = 200,
      toggle_key = nil,

      -- フローティングウィンドウの色設定
      hi_parameter = "LspSignatureActiveParameter",

      -- 仮想テキスト設定
      virtual_text_mode = false,
    })

    return config
  end,
  config = function(_, opts)
    require("lsp_signature").setup(opts)

    -- カスタムハイライトグループの設定
    vim.api.nvim_set_hl(0, "LspSignatureActiveParameter", {
      bg = "#ff9e64",
      fg = "#1a1b26",
      bold = true,
      italic = true,
    })
  end,
}
