--[[
機能概要: Claude Code会話履歴ブラウザ - 直近・全件モード対応
設定内容: 4つのキーマッピングで効率的な履歴アクセス、キャッシュ最適化
キーバインド: <leader>jr/jR/j//jl (直近/全件 × 現在dir/全体)
--]]
return {
  dir = vim.fn.expand("~/.config/nvim/lua/ccresume.nvim"),
  name = "ccresume.nvim",
  dependencies = {
    "coder/claudecode.nvim",
    "folke/snacks.nvim",
  },
  event = "VeryLazy",
  keys = {
    {
      "<leader>jr",
      function()
        require("ccresume").show_current_dir_conversations()
      end,
      desc = "Resume (Current Dir)",
    },
    {
      "<leader>jR",
      function()
        require("ccresume").show_current_dir_conversations_all()
      end,
      desc = "Resume All (Current Dir)",
    },
    {
      "<leader>j/",
      function()
        require("ccresume").show_conversations_all()
      end,
      desc = "All Resume",
    },
    {
      "<leader>jl",
      function()
        require("ccresume").show_conversations()
      end,
      desc = "Sessions List",
    },
  },
  opts = function(_, opts)
    -- 安全な初期化
    opts.preview = opts.preview or {}
    opts.performance = opts.performance or {}

    opts.preview = vim.tbl_deep_extend("force", opts.preview, {
      reverse_order = true,
    })

    opts.performance = vim.tbl_deep_extend("force", opts.performance, {
      recent_limit = 30,
    })

    opts.commands = true
    opts.keys = false -- Lazyのkeysテーブルを使用するため無効化

    return opts
  end,
}
