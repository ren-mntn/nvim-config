--[[
機能概要: カーソル位置の現在のコードコンテキスト（関数、クラス、条件文等）を画面上部に常時表示
設定内容: 日本語環境に最適化、フローティング表示、カーソル追従
キーバインド: <leader>tc - コンテキスト表示の切り替え
--]]
return {
  "nvim-treesitter/nvim-treesitter-context",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  event = "BufRead",
  keys = {
    {
      "<leader>tz",
      function()
        require("treesitter-context").toggle()
      end,
      desc = "Treesitterコンテキスト表示切り替え",
    },
  },
  opts = function(_, opts)
    -- 安全な初期化
    opts = opts or {}

    -- 設定のマージ（完全上書きではない）
    opts = vim.tbl_deep_extend("force", opts, {
      enable = true, -- プラグインを有効化
      max_lines = 0, -- コンテキスト行数の制限なし（全て表示）
      min_window_height = 0, -- 最小ウィンドウ高さ制限なし
      line_numbers = true, -- 行番号を表示
      multiline_threshold = 20, -- 複数行表示の閾値
      trim_scope = "outer", -- スコープのトリミング方法
      mode = "cursor", -- カーソル位置ベースでコンテキスト計算
      -- separator = nil, -- 区切り文字（デフォルトではなし）
      zindex = 20, -- フローティングウィンドウのz-index
      on_attach = nil, -- アタッチ時のコールバック
    })

    return opts
  end,
  config = function(_, opts)
    local context = require("treesitter-context")
    context.setup(opts)

    -- カスタムハイライトグループの設定
    vim.defer_fn(function()
      -- コンテキストウィンドウの背景色
      vim.api.nvim_set_hl(0, "TreesitterContext", {
        bg = "#1e1e1e", -- 暗い背景
        fg = "#d4d4d4", -- 明るい文字色
      })

      -- コンテキスト行番号
      vim.api.nvim_set_hl(0, "TreesitterContextLineNumber", {
        fg = "#858585", -- グレーの行番号
      })

      -- 区切り線（下端）
      vim.api.nvim_set_hl(0, "TreesitterContextBottom", {
        underline = true, -- 下線で区切り
        sp = "#404040", -- グレーの区切り線
      })

      -- 区切り線の行番号
      vim.api.nvim_set_hl(0, "TreesitterContextLineNumberBottom", {
        fg = "#858585",
        underline = true,
        sp = "#404040",
      })

      -- ハイライト設定完了
    end, 150)
  end,
}
