-- ~/.config/nvim/lua/plugins/claude.lua

return {
  "coder/claudecode.nvim",
  branch = "main",
  -- このプラグインが動作するために必要な他のプラグイン
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },

  -- ↓↓↓ このkeysセクションを追記します ↓↓↓
  keys = {
    -- この最初の行が、<leader>c を "Claude" という名前のメニューとして定義します
    { "<leader>c", group = "Claude", desc = "Claude AI Menu" },
    -- 以下は、そのメニューの中に表示される項目です
    { "<leader>cc", "<cmd>ClaudeCode<CR>", desc = "Chat" },
    { "<leader>cr", "<cmd>ClaudeReset<CR>", desc = "Reset Chat" },
    { "<leader>ca", "<cmd>ClaudeCodeDiffAccept<CR>", desc = "Accept Diff" },
    { "<leader>cd", "<cmd>ClaudeCodeDiffDeny<CR>", desc = "Deny Diff" },
    { "<leader>c", "<cmd>ClaudeCode<CR>", desc = "Claude Chat" },
    -- ノーマルモードで <leader>ca を押すとチャット開始
    { "<leader>cc", "<cmd>ClaudeCode<CR>", desc = "Claude - Ask (Chat)" },
    -- チャット履歴をリセット
    { "<leader>cr", "<cmd>ClaudeReset<CR>", desc = "Claude - Reset Chat" },
    -- ビジュアルモードでコード選択中に <leader>ca を押すと、そのコードについて質問
    {
      "<leader>ca",
      ":'[,']ClaudeCode<CR>",
      mode = "v",
      desc = "Claude - Ask about selection",
    },
  },

  -- configセクションで、すべてデフォルト設定で動作させます
  config = function()
    require("claudecode").setup({
      -- ターミナル設定
      terminal = {
        split_side = "right",
        split_width_percentage = 0.30,
        provider = "auto",
        -- フローティングウィンドウ設定
        snacks_win_opts = {
          position = "right",  -- 右側に配置
          width = 0.4,         -- 幅を40%に縮小
          height = 1.0,        -- 高さは画面全体
          border = "rounded",
          backdrop = 0,        -- 背景透明度を無効化（右側パネルなので）
          wo = {
            winhighlight = "Normal:ClaudeCodeBackground,FloatBorder:ClaudeCodeBorder"
          }
        },
      },
      
      -- チャットウィンドウのキーマップ設定
      chat = {
        keymaps = {
          send = "<CR>",        -- Enterで送信
          new_line = "<C-j>",   -- Ctrl+Jで改行（Shift+Enterが動作しない場合の代替）
        }
      }
    })
    
    -- カスタムハイライトグループの定義（背景色変更用）
    vim.api.nvim_set_hl(0, "ClaudeCodeBackground", { 
      bg = "#1E1E1E",  -- 指定の背景色
      fg = "#FFFFFF"   -- 白い文字色
    })
    
    vim.api.nvim_set_hl(0, "ClaudeCodeBorder", { 
      bg = "#1E1E1E",  -- ボーダーも同じ背景色
      fg = "#666666"   -- グレーのボーダー色
    })
    
    -- Shift+Enterのマッピングを手動で追加（オプション）
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "claudecode",
      callback = function()
        vim.keymap.set("i", "<S-CR>", "<C-j>", { buffer = true, desc = "Insert new line" })
      end,
    })
  end,
}
