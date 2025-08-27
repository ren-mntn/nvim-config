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

  keys = {
    -- Claude AI統一キーマップ - <leader>j系統
    { "<leader>j", group = "Claude AI", desc = "Claude AI Tools" },

    -- ========== 直接アクセス（競合しないキー） ==========
    {
      "<C-g>",
      function()
        -- neo-treeにフォーカスがある場合は無効化
        local filetype = vim.bo.filetype
        if filetype == "neo-tree" then
          return
        end

        -- 現在のバッファがClaudeCodeターミナルかチェック
        local bufname = vim.api.nvim_buf_get_name(0)
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = 0 })

        -- ターミナルバッファかつClaudeCode関連の場合はウィンドウを閉じる
        if buftype == "terminal" and (bufname:match("claude") or bufname:match("ClaudeCode")) then
          vim.cmd("close")
        else
          -- そうでなければClaudeCodeを開く
          vim.cmd("ClaudeCode")
        end
      end,
      desc = "Toggle Claude Chat",
    },
    { "<C-q>", "<cmd>ClaudeCodeAdd %<CR>", desc = "Add Current File to Claude" },

    -- ========== Claude ターミナル・チャット ==========
    { "<leader>jj", "<cmd>ClaudeCode<CR>", desc = "Chat" },

    -- ========== Claude Core Operations ==========
    { "<leader>js", "<cmd>ClaudeCodeStart<CR>", desc = "Start Claude Integration" },
    { "<leader>jS", "<cmd>ClaudeCodeStop<CR>", desc = "Stop Claude Integration" },
    { "<leader>ji", "<cmd>ClaudeCodeStatus<CR>", desc = "Show Claude Status" },

    -- ========== File & Context Operations ==========
    { "<leader>ja", "<cmd>ClaudeCodeAdd %<CR>", desc = "Add Current File to Context" },
    {
      "<leader>jA",
      function()
        local file = vim.fn.input("Add file to context: ", "", "file")
        if file ~= "" then
          vim.cmd("ClaudeCodeAdd " .. vim.fn.shellescape(file))
        end
      end,
      desc = "Add File to Context (Browse)",
    },

    -- ========== Claude Diff Operations ==========
    { "<leader>jy", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept Diff (Yes)" },
    { "<leader>jn", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny Diff (No)" },

    -- ========== Visual Mode - Send Selection ==========
    {
      "<leader>j",
      "<cmd>ClaudeCodeSend<cr>",
      mode = { "v", "x" },
      desc = "Send Selection to Claude",
    },

    -- ========== Sessions Panel ==========
    {
      "<leader>jp",
      function()
        local sm = pcall(require, "claude-session-manager")
        if sm and require("claude-session-manager").toggle_persistent_panel then
          require("claude-session-manager").toggle_persistent_panel()
        else
          vim.notify("Sessions panel not available", vim.log.levels.WARN)
        end
      end,
      desc = "Sessions Panel",
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
        provider = "snacks",
        -- フローティングウィンドウ設定
        snacks_win_opts = {
          position = "right", -- 右側に配置
          width = 0.4, -- 幅を40%に縮小
          height = 1.0, -- 高さは画面全体
          backdrop = 0, -- 背景透明度を無効化（右側パネルなので）
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

    -- フォーカス時の背景（少し明るく）
    vim.api.nvim_set_hl(0, "ClaudeCodeBackgroundFocused", {
      bg = "#262525", -- 少し明るい背景
      fg = colors.colors.white,
    })

    -- Shift+Enterのマッピングを手動で追加（オプション）
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "claudecode",
      callback = function()
        vim.keymap.set("i", "<S-CR>", "<C-j>", { buffer = true, desc = "Insert new line" })
      end,
    })

    -- ClaudeCodeウィンドウのフォーカス管理
    local function update_claude_border()
      -- すべてのウィンドウをチェック
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, buf = pcall(vim.api.nvim_win_get_buf, win)
        if ok then
          local bufname = vim.api.nvim_buf_get_name(buf)
          local buftype = vim.api.nvim_buf_get_option(buf, "buftype")

          -- ターミナルバッファかつClaudeCodeのバッファを探す
          if buftype == "terminal" and (bufname:match("claude") or bufname:match("ClaudeCode")) then
            -- 現在のウィンドウかチェック
            if win == vim.api.nvim_get_current_win() then
              -- フォーカスあり：明るい背景
              pcall(vim.api.nvim_win_set_option, win, "winhighlight", "Normal:ClaudeCodeBackgroundFocused")
            else
              -- フォーカスなし：通常の背景
              pcall(vim.api.nvim_win_set_option, win, "winhighlight", "Normal:ClaudeCodeBackground")
            end
          end
        end
      end
    end

    -- ウィンドウフォーカス変更時にボーダー更新
    vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave", "TermOpen", "TermClose" }, {
      callback = function()
        vim.defer_fn(update_claude_border, 50)
      end,
    })

    -- ClaudeCodeターミナルのフォーカス時に自動でinsertモードに入り、IMEを英数に切り替え
    vim.api.nvim_create_autocmd("WinEnter", {
      callback = function()
        local win = vim.api.nvim_get_current_win()
        local ok, buf = pcall(vim.api.nvim_win_get_buf, win)
        if ok then
          local bufname = vim.api.nvim_buf_get_name(buf)
          local buftype = vim.api.nvim_buf_get_option(buf, "buftype")

          -- ターミナルバッファかつClaudeCodeのバッファの場合、insertモードに入り、IMEを英数に切り替え
          if buftype == "terminal" and (bufname:match("claude") or bufname:match("ClaudeCode")) then
            -- IMEを英数に切り替え（macism使用）
            vim.fn.system("macism com.apple.keylayout.ABC")
            -- ターミナルモードに入る（ターミナルでは自動的にinsertモード相当になる）
            vim.cmd("startinsert")
          end
        end
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
    vim.keymap.set("n", "<leader>jp", function()
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
