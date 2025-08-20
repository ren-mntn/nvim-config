-- Bufferline カスタマイズ設定例
-- このファイルを有効にすると、バッファラインの見た目と動作をカスタマイズできます

return {
  "akinsho/bufferline.nvim",
  event = "VeryLazy",
  keys = {
    -- バッファピン留め
    { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle Pin" },
    { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Non-Pinned Buffers" },
    
    -- バッファ削除操作
    { "<leader>bo", "<Cmd>BufferLineCloseOthers<CR>", desc = "Delete Other Buffers" },
    { "<leader>br", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
    { "<leader>bl", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
    
    -- バッファ移動（基本）
    { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
    { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
    { "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
    { "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
    
    -- keymaps.luaから移動: ページキーでのバッファ移動
    { "<C-PageDown>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer", mode = { "n", "i" } },
    { "<C-PageUp>", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous Buffer", mode = { "n", "i" } },
    
    -- keymaps.luaから移動: バッファ削除 (iTerm2から<F15>として送信)
    { "<F15>", "<cmd>BufferLinePickClose<cr>", desc = "Pick Buffer to Close", mode = { "n", "i" } },
    
    -- 番号でバッファ選択
    { "<leader>1", "<cmd>BufferLineGoToBuffer 1<cr>", desc = "Buffer 1" },
    { "<leader>2", "<cmd>BufferLineGoToBuffer 2<cr>", desc = "Buffer 2" },
    { "<leader>3", "<cmd>BufferLineGoToBuffer 3<cr>", desc = "Buffer 3" },
    { "<leader>4", "<cmd>BufferLineGoToBuffer 4<cr>", desc = "Buffer 4" },
    { "<leader>5", "<cmd>BufferLineGoToBuffer 5<cr>", desc = "Buffer 5" },
    { "<leader>6", "<cmd>BufferLineGoToBuffer 6<cr>", desc = "Buffer 6" },
    { "<leader>7", "<cmd>BufferLineGoToBuffer 7<cr>", desc = "Buffer 7" },
    { "<leader>8", "<cmd>BufferLineGoToBuffer 8<cr>", desc = "Buffer 8" },
    { "<leader>9", "<cmd>BufferLineGoToBuffer 9<cr>", desc = "Buffer 9" },
  },
  opts = {
    options = {
      -- 基本設定
      mode = "buffers", -- バッファ表示モード
      themable = true, -- テーマのカスタマイズ許可
      numbers = "none", -- 番号表示（1,2,3...）
      -- スタイル
      -- separator_style = "slant",           -- スラント型セパレーター
      always_show_bufferline = true, -- 常に表示
      -- インジケーター
      indicator = {
        icon = "▎",
        style = "underline", -- アンダーラインスタイル
      },
      -- アイコン
      buffer_close_icon = "✕",
      modified_icon = "●",
      close_icon = "",
      left_trunc_marker = "",
      right_trunc_marker = "",
      -- 診断表示
      diagnostics = "nvim_lsp",
      diagnostics_update_in_insert = false,
      diagnostics_indicator = function(count, level, diagnostics_dict, context)
        local s = " "
        for e, n in pairs(diagnostics_dict) do
          local sym = e == "error" and " " or (e == "warning" and " " or " ")
          s = s .. n .. sym
        end
        return s
      end,
      -- サイドバー対応
      offsets = {
        {
          filetype = "neo-tree",
          text = "File Explorer",
          highlight = "Directory",
          separator = true,
        },
      },
      clickable = true, -- クリックでバッファ切り替えdd
      -- ホバー
      hover = {
        enabled = true,
        delay = 100,
        reveal = { "close" },
      },
      -- ソート
      sort_by = "insert_after_current",
      -- カスタムフィルター（特定のバッファを非表示）
      custom_filter = function(buf_number, buf_numbers)
        local buftype = vim.bo[buf_number].buftype
        if buftype == "terminal" then
          return false
        end
        return true
      end,
      -- グループ機能
      groups = {
        options = {
          toggle_hidden_on_enter = true,
        },
        items = {
          {
            name = "Tests",
            icon = "",
            priority = 2,
            matcher = function(buf)
              return buf.path:match("%.test%.") or buf.path:match("%.spec%.")
            end,
          },
          {
            name = "Docs",
            icon = "",
            priority = 1,
            matcher = function(buf)
              return buf.path:match("%.md") or buf.path:match("%.txt")
            end,
          },
        },
      },
    },
  },
}

