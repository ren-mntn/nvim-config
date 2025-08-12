--[[
機能概要: Claude Code会話履歴ブラウザ - 直近・全件モード対応
設定内容: 4つのキーマッピングで効率的な履歴アクセス、キャッシュ最適化
キーバインド: <leader>ch/cH/ca/cA (直近/全件 × 現在dir/全体)
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
      "<leader>ch",
      function()
        require("ccresume").show_current_dir_conversations()
      end,
      desc = "現在ディレクトリのClaude Code履歴（直近）",
    },
    {
      "<leader>cH",
      function()
        require("ccresume").show_current_dir_conversations_all()
      end,
      desc = "現在ディレクトリのClaude Code履歴（全件）",
    },
    {
      "<leader>ca",
      function()
        require("ccresume").show_conversations()
      end,
      desc = "Claude Code履歴（直近）",
    },
    {
      "<leader>cA",
      function()
        require("ccresume").show_conversations_all()
      end,
      desc = "Claude Code履歴（全件）",
    },
  },
  opts = function(_, opts)
    -- 安全な初期化
    opts.keys = opts.keys or {}
    opts.preview = opts.preview or {}
    opts.performance = opts.performance or {}

    -- 設定のマージ（完全上書きではない）
    opts.keys = vim.tbl_deep_extend("force", opts.keys, {
      current_dir = "<leader>ch",
      current_dir_all = "<leader>cH",
      all = "<leader>ca",
      all_all = "<leader>cA",
    })

    opts.preview = vim.tbl_deep_extend("force", opts.preview, {
      reverse_order = true,
    })

    opts.performance = vim.tbl_deep_extend("force", opts.performance, {
      recent_limit = 30,
    })

    opts.commands = true

    return opts
  end,
}
