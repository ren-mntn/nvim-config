-- ~/.config/nvim/lua/claude-status-working.lua
-- ClaudeCode ステータス管理モジュール（動作確認済み版）

local M = {}

-- 状態管理
local status = {
  current_state = "disconnected", -- disconnected, connected, processing, waiting, error
  last_update = nil,
}

-- 設定（完全シンプル版）
local config = {
  enabled = false,
}



-- ステータス更新
function M.set_status(new_state)
  if not config.enabled then
    return
  end

  -- 同じ状態の場合は更新しない
  if status.current_state == new_state then
    return
  end

  status.current_state = new_state
  status.last_update = vim.fn.localtime()

  -- UI更新をスケジュール
  vim.schedule(function()
    M.update_display()
  end)
  
  -- デバッグ出力
  if vim.g.claude_debug then
    vim.notify(
      string.format("[Claude] Status changed to: %s", new_state),
      vim.log.levels.INFO
    )
  end
end

-- 表示更新（完全シンプル版）
function M.update_display()
  if not config.enabled then
    return
  end

  -- 最小限のグローバル変数のみ
  vim.g.claude_status = status.current_state
  
  -- デバッグ出力のみ
  if vim.g.claude_debug then
    vim.notify(
      string.format("[Claude] Status updated to: %s", status.current_state),
      vim.log.levels.INFO
    )
  end
end

-- WebSocket状態監視（メイン判定システム）
function M.check_websocket_status()
  -- 1. 環境変数チェック
  local claude_port = vim.env.CLAUDE_CODE_SSE_PORT
  local ide_integration = vim.env.ENABLE_IDE_INTEGRATION

  if not claude_port or ide_integration ~= "true" then
    return nil
  end

  -- 2. ロックファイルチェック
  local lock_file = vim.fn.expand("~/.claude/ide/" .. claude_port .. ".lock")
  if vim.fn.filereadable(lock_file) == 0 then
    return "disconnected"
  end

  -- 3. ネットワーク接続数チェック
  local netstat_cmd = string.format("netstat -an | grep ':%s.*ESTABLISHED' | wc -l", claude_port)
  local connection_result = vim.fn.system(netstat_cmd)
  local current_connections = tonumber(connection_result:gsub("%s+", "")) or 0

  -- 4. ロックファイルの更新時間チェック（処理中の判定に重要）
  local lock_stat = vim.fn.system("stat -f %m " .. lock_file .. " 2>/dev/null")
  local current_time = os.time()
  local lock_timestamp = tonumber(lock_stat) or 0
  local time_since_update = current_time - lock_timestamp

  -- 5. TCP送受信バイト数チェック（より詳細な活動検出）
  local lsof_cmd = string.format("lsof -i :%s -n 2>/dev/null | grep ESTABLISHED | wc -l", claude_port)
  local active_connections = tonumber(vim.fn.system(lsof_cmd):gsub("%s+", "")) or 0

  -- デバッグ出力
  if vim.g.claude_debug then
    vim.notify(
      string.format(
        "WebSocket: port=%s, netstat_conn=%d, lsof_conn=%d, lock_age=%ds",
        claude_port,
        current_connections,
        active_connections,
        time_since_update
      ),
      vim.log.levels.INFO
    )
  end

  -- 6. 状態判定（WebSocketベース）
  if current_connections > 0 and time_since_update <= 3 then
    -- アクティブな接続 + 最近のロックファイル更新 = 確実に処理中
    return "processing"
  elseif active_connections > 0 and time_since_update <= 8 then
    -- 接続があり、比較的最近の活動 = 処理中の可能性高い
    return "processing"
  elseif current_connections > 0 or active_connections > 0 then
    -- 接続はあるが活動が少ない = 接続済み（アイドル）
    return "connected"
  elseif time_since_update <= 15 then
    -- 最近まで活動があった = まだ接続済み
    return "connected"
  else
    -- 長時間活動なし = 切断
    return "disconnected"
  end
end

-- ターミナル監視（waiting状態検出専用）
function M.check_terminal_waiting(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  -- 最後の10行のみチェック（waiting検出に特化）
  local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, -10, -1, false)
  if not ok then
    return false
  end

  -- 最新の行から順にチェック
  for i = #lines, 1, -1 do
    local line = lines[i]:lower()

    -- 空行をスキップ
    if line ~= "" then
      -- waiting状態のパターン（ユーザー入力を求めている）
      if line:match("do you want") 
         or line:match("would you like")
         or line:match("press enter") 
         or line:match("continue%?")
         or line:match("│.*%?%s*$") -- 質問形式
         or line:match("y/n")
         or line:match("yes/no")
         or line:match("確認してください")
         or line:match("よろしいですか")
         or line:match("続行しますか") then
        return true
      end
    end
  end

  return false
end

-- メイン監視関数（WebSocket中心）
function M.monitor_terminal_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- 1. WebSocket状態をチェック（メイン判定）
  local websocket_status = M.check_websocket_status()
  
  if websocket_status == "disconnected" then
    M.set_status("disconnected")
    return
  elseif websocket_status == "processing" then
    -- WebSocketで処理中が検出された場合、ターミナルでwaiting確認
    local is_waiting = M.check_terminal_waiting(bufnr)
    if is_waiting then
      M.set_status("waiting")
    else
      M.set_status("processing")
    end
    return
  elseif websocket_status == "connected" then
    -- WebSocketで接続済みが検出された場合、ターミナルでwaiting確認
    local is_waiting = M.check_terminal_waiting(bufnr)
    if is_waiting then
      M.set_status("waiting")
    else
      M.set_status("connected")
    end
    return
  end

  -- 2. WebSocketが利用できない場合のフォールバック
  local is_waiting = M.check_terminal_waiting(bufnr)
  if is_waiting then
    M.set_status("waiting")
  else
    M.set_status("connected") -- デフォルト
  end

  -- デバッグ出力
  if vim.g.claude_debug then
    vim.notify(
      string.format(
        "Status: websocket=%s, waiting=%s -> %s",
        websocket_status or "nil",
        tostring(is_waiting),
        status.current_state
      ),
      vim.log.levels.INFO
    )
  end
end

-- 設定更新
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", config, user_config or {})

  if config.enabled then
    -- 初期状態設定
    M.set_status("disconnected")

    -- ターミナル監視の設定（高頻度監視）
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufEnter", "CursorMoved", "CursorMovedI" }, {
      pattern = "*",
      callback = function(event)
        local bufname = vim.api.nvim_buf_get_name(event.buf)
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = event.buf })

        -- Claudeターミナルのみ監視
        if buftype == "terminal" and (bufname:match("claude") or bufname:match("ClaudeCode")) then
          -- 即座に監視（遅延を短縮）
          vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(event.buf) then
              M.monitor_terminal_buffer(event.buf)
            end
          end, 50) -- 100ms -> 50msに短縮
        end
      end,
      desc = "Monitor Claude terminal for processing state (high frequency)",
    })

    -- 定期監視タイマー（バックアップ）
    local function periodic_monitor()
      vim.defer_fn(function()
        -- 全てのClaudeターミナルを定期チェック
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(buf) then
            local bufname = vim.api.nvim_buf_get_name(buf)
            local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
            
            if buftype == "terminal" and (bufname:match("claude") or bufname:match("ClaudeCode")) then
              M.monitor_terminal_buffer(buf)
            end
          end
        end
        
        periodic_monitor() -- 再帰的に継続
      end, 1000) -- 1秒間隔
    end
    
    periodic_monitor()
  end
end

-- 現在の状態を取得
function M.get_status()
  return {
    state = status.current_state,
    last_update = status.last_update,
  }
end

-- 手動でのリセット
function M.reset()
  M.set_status("disconnected")
end

-- ClaudeCode イベント用のフック関数
function M.on_claude_start()
  M.set_status("connected")
end

function M.on_claude_processing()
  M.set_status("processing")
end

function M.on_claude_idle()
  if status.current_state == "processing" or status.current_state == "waiting" then
    M.set_status("connected")
  end
end

function M.on_claude_waiting()
  M.set_status("waiting")
end

function M.on_claude_error()
  M.set_status("error")
  -- エラー状態から5秒後に接続状態に戻す
  vim.defer_fn(function()
    if status.current_state == "error" then
      M.set_status("connected")
    end
  end, 5000)
end

function M.on_claude_stop()
  M.set_status("disconnected")
end

-- デバッグ用関数
function M.test_current_buffer()
  local buf = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(buf)
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })

  vim.notify("Testing buffer: " .. bufname .. " (type: " .. buftype .. ")", vim.log.levels.WARN)

  if buftype == "terminal" then
    M.monitor_terminal_buffer(buf)
  else
    vim.notify("Current buffer is not a terminal", vim.log.levels.ERROR)
  end
end

function M.show_status()
  local current_status = M.get_status()
  local websocket_status = M.check_websocket_status()
  
  vim.notify("Claude Status: " .. vim.inspect(current_status), vim.log.levels.WARN)
  vim.notify("WebSocket status: " .. (websocket_status or "not available"), vim.log.levels.WARN)
  
  -- 環境変数の確認
  local claude_port = vim.env.CLAUDE_CODE_SSE_PORT
  local ide_integration = vim.env.ENABLE_IDE_INTEGRATION
  vim.notify("Environment: CLAUDE_CODE_SSE_PORT=" .. (claude_port or "nil") .. ", ENABLE_IDE_INTEGRATION=" .. (ide_integration or "nil"), vim.log.levels.INFO)
end

function M.toggle_debug()
  vim.g.claude_debug = not vim.g.claude_debug
  vim.notify("Claude debug mode: " .. tostring(vim.g.claude_debug), vim.log.levels.INFO)
end

return M