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
    -- ステータス管理モジュールの初期化（完全シンプル版）
    local claude_status = require("claude-status-working")
    claude_status.setup({
      enabled = true,
    })

    require("claudecode").setup({
      -- ターミナル設定
      terminal = {
        split_side = "right",
        split_width_percentage = 0.30,
        provider = "auto",
        -- フローティングウィンドウ設定
        snacks_win_opts = {
          position = "right", -- 右側に配置
          width = 0.4, -- 幅を40%に縮小
          height = 1.0, -- 高さは画面全体
          border = "rounded",
          backdrop = 0, -- 背景透明度を無効化（右側パネルなので）
          wo = {
            winhighlight = "Normal:ClaudeCodeBackground,FloatBorder:ClaudeCodeBorder",
          },
        },
      },

      -- チャットウィンドウのキーマップ設定
      chat = {
        keymaps = {
          send = "<CR>", -- Enterで送信
          new_line = "<C-j>", -- Ctrl+Jで改行（Shift+Enterが動作しない場合の代替）
        },
      },
    })

    -- カスタムハイライトグループの定義（背景色変更用）
    local colors = require("config.colors")
    vim.api.nvim_set_hl(0, "ClaudeCodeBackground", {
      bg = colors.colors.background, -- 指定の背景色
      fg = colors.colors.white, -- 白い文字色
    })

    vim.api.nvim_set_hl(0, "ClaudeCodeBorder", {
      bg = colors.colors.background, -- ボーダーも同じ背景色
      fg = "#666666", -- グレーのボーダー色
    })

    -- Shift+Enterのマッピングを手動で追加（オプション）
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "claudecode",
      callback = function()
        vim.keymap.set("i", "<S-CR>", "<C-j>", { buffer = true, desc = "Insert new line" })
      end,
    })

    -- ClaudeCode イベント監視の設定
    local augroup = vim.api.nvim_create_augroup("ClaudeStatusMonitor", { clear = true })

    -- ターミナル起動時（ClaudeCode開始）
    vim.api.nvim_create_autocmd("TermOpen", {
      group = augroup,
      pattern = "*claude*",
      callback = function()
        claude_status.on_claude_start()
        -- セッション情報を即座に同期（安全に読み込み）
        local ok, sm = pcall(require, "claude-session-manager")
        if ok then
          sm.write_current_session_to_file("/tmp/claude_sessions.json")
        end
      end,
    })

    -- ターミナル終了時（ClaudeCode停止）
    vim.api.nvim_create_autocmd("TermClose", {
      group = augroup,
      pattern = "*claude*",
      callback = function()
        claude_status.on_claude_stop()
        -- セッション情報を即座に同期（安全に読み込み）
        local ok, sm = pcall(require, "claude-session-manager")
        if ok then
          sm.write_current_session_to_file("/tmp/claude_sessions.json")
        end
      end,
    })

    -- 手動ステータス制御コマンドの追加
    vim.api.nvim_create_user_command("ClaudeStatusProcessing", function()
      claude_status.on_claude_processing()
    end, { desc = "Set Claude status to processing" })

    vim.api.nvim_create_user_command("ClaudeStatusIdle", function()
      claude_status.on_claude_idle()
    end, { desc = "Set Claude status to idle" })

    vim.api.nvim_create_user_command("ClaudeStatusError", function()
      claude_status.on_claude_error()
    end, { desc = "Set Claude status to error" })

    vim.api.nvim_create_user_command("ClaudeStatusReset", function()
      claude_status.reset()
    end, { desc = "Reset Claude status to disconnected" })

    -- デバッグコマンドを追加
    vim.api.nvim_create_user_command("ClaudeStatusDebug", function()
      claude_status.show_status()
      
      -- 現在のターミナルバッファをリスト
      local terminals = {}
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
          local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
          if buftype == "terminal" then
            local bufname = vim.api.nvim_buf_get_name(buf)
            table.insert(terminals, { buf = buf, name = bufname })
          end
        end
      end
      vim.notify("Found terminals: " .. vim.inspect(terminals), vim.log.levels.WARN)
    end, { desc = "Debug Claude status and terminal buffers" })

    -- 手動で監視テスト
    vim.api.nvim_create_user_command("ClaudeStatusTest", function()
      claude_status.test_current_buffer()
    end, { desc = "Test monitoring on current buffer" })
    
    -- デバッグモード切り替え
    vim.api.nvim_create_user_command("ClaudeDebugToggle", function()
      claude_status.toggle_debug()
    end, { desc = "Toggle Claude debug mode" })

    -- セッション管理コマンドを追加（オプション・安全にロード）
    local function get_session_manager()
      local ok, sm = pcall(require, "claude-session-manager")
      if not ok then
        vim.notify("Session manager not available (optional feature)", vim.log.levels.INFO)
        return nil
      end
      return sm
    end

    -- セッション管理コマンド
    vim.api.nvim_create_user_command("ClaudeSessions", function()
      local sm = get_session_manager()
      if sm then 
        sm.show_sessions() 
      else
        -- フォールバック：基本的なターミナル一覧
        local terminals = {}
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(buf) then
            local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
            local bufname = vim.api.nvim_buf_get_name(buf)
            if buftype == "terminal" and (bufname:match("claude") or bufname:match("ClaudeCode")) then
              table.insert(terminals, bufname)
            end
          end
        end
        
        if #terminals > 0 then
          vim.notify("Claude terminals found:\n" .. table.concat(terminals, "\n"), vim.log.levels.INFO)
        else
          vim.notify("No Claude terminals found", vim.log.levels.INFO)
        end
      end
    end, { desc = "Show Claude sessions" })

    -- 右上固定パネルコマンド
    vim.api.nvim_create_user_command("ClaudePersistent", function()
      local sm = get_session_manager()
      if sm and sm.toggle_persistent_panel then
        sm.toggle_persistent_panel()
      else
        vim.notify("Persistent panel feature not available", vim.log.levels.WARN)
      end
    end, { desc = "Toggle persistent Claude sessions panel" })

    -- モニターコマンド
    vim.api.nvim_create_user_command("ClaudeMonitor", function()
      local sm = get_session_manager()
      if sm and sm.toggle_monitor then
        sm.toggle_monitor()
      else
        vim.notify("Monitor feature not available", vim.log.levels.WARN)
      end
    end, { desc = "Toggle Claude monitor" })

    -- キーマップ設定
    vim.keymap.set("n", "<leader>cl", function()
      vim.cmd("ClaudeSessions")
    end, { desc = "Claude Sessions List" })

    -- 右上固定パネル（重要な機能）
    vim.keymap.set("n", "<leader>cp", function()
      local sm = get_session_manager()
      if sm and sm.toggle_persistent_panel then
        sm.toggle_persistent_panel()
      else
        vim.notify("Persistent panel not available - using fallback", vim.log.levels.WARN)
        vim.cmd("ClaudeSessions")
      end
    end, { desc = "Claude Sessions Panel" })

    -- モニター表示
    vim.keymap.set("n", "<leader>cm", function()
      local sm = get_session_manager()
      if sm and sm.toggle_monitor then
        sm.toggle_monitor()
      else
        vim.notify("Monitor not available - using fallback", vim.log.levels.WARN)
        vim.cmd("ClaudeSessions")
      end
    end, { desc = "Claude Monitor" })
  end,
}
