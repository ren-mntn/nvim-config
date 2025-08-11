-- ~/.config/nvim/lua/claude-session-manager.lua
-- ClaudeCodeセッション一覧表示・管理モジュール

local M = {}

-- キャッシュ用変数
M._last_system_search = 0
M._system_search_interval = 5000 -- 5秒間隔でのみシステム検索実行
M._cached_system_sessions = {} -- システムセッションのキャッシュ

-- Claudeターミナルバッファかどうかを判定
local function is_claude_terminal(bufname, buftype)
  return buftype == "terminal"
    and (bufname:match("[Cc]laude") or bufname:match("ClaudeCode") or bufname:match("term://.*claude"))
end

-- 現在のNeovimプロセス内のセッションを取得
local function get_current_nvim_sessions()
  local sessions = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local bufname = vim.api.nvim_buf_get_name(buf)
      local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })

      if is_claude_terminal(bufname, buftype) then
        local session_info = M.analyze_session(buf, bufname)
        if session_info then
          session_info.source = "current_nvim"
          table.insert(sessions, session_info)
        end
      end
    end
  end
  return sessions
end

-- Snacks.nvimのターミナルセッションを取得
local function get_snacks_sessions(existing_sessions)
  local sessions = {}
  local ok_snacks, snacks = pcall(require, "snacks")
  if not (ok_snacks and snacks.terminal and snacks.terminal.list) then
    return sessions
  end

  local snacks_terminals = snacks.terminal.list()
  for _, term_win in ipairs(snacks_terminals or {}) do
    if term_win:buf_valid() then
      local buf = term_win.buf
      local bufname = vim.api.nvim_buf_get_name(buf)

      if is_claude_terminal(bufname, "") then
        -- 既に追加済みでないかチェック
        local already_exists = false
        for _, existing in ipairs(existing_sessions) do
          if existing.buffer == buf then
            already_exists = true
            break
          end
        end

        if not already_exists then
          local session_info = M.analyze_session(buf, bufname)
          if session_info then
            session_info.source = "snacks_terminal"
            session_info.snacks_win = term_win
            table.insert(sessions, session_info)
          end
        end
      end
    end
  end
  return sessions
end

-- セッション情報の取得
function M.get_sessions()
  local sessions = get_current_nvim_sessions()

  -- Snacks.nvim のターミナル一覧を追加
  local snacks_sessions = get_snacks_sessions(sessions)
  for _, session in ipairs(snacks_sessions) do
    table.insert(sessions, session)
  end

  -- システムレベルでのClaudeCodeプロセス検索（キャッシュ付き）
  local current_time = vim.fn.localtime() * 1000
  if current_time - M._last_system_search > M._system_search_interval then
    M._cached_system_sessions = {}
    M.add_system_sessions(M._cached_system_sessions)
    M._last_system_search = current_time
  end

  -- キャッシュされたシステムセッションを追加
  for _, cached_session in ipairs(M._cached_system_sessions) do
    table.insert(sessions, cached_session)
  end

  return sessions
end

-- セッション分析
function M.analyze_session(buf, bufname)
  local ok, lines = pcall(vim.api.nvim_buf_get_lines, buf, -100, -1, false)
  if not ok or #lines == 0 then
    return nil
  end

  -- ブランチ名を取得
  local branch_name = M.get_branch_name(bufname)

  -- 状態を取得（既存のterminal.luaシステムと統合）
  local status = M.get_session_status(lines, buf)

  -- 最後のプロンプトを取得
  local last_prompt = M.get_last_prompt(lines)

  -- プロンプトが取得できない場合は、そのセッションを無効とする
  if not last_prompt then
    return nil
  end

  -- パスを取得（bufnameから推測）
  local path = M.extract_path_from_bufname(bufname)

  return {
    buffer = buf,
    bufname = bufname,
    branch = branch_name,
    status = status,
    last_prompt = last_prompt,
    path = path,
  }
end

-- ブランチ名取得
function M.get_branch_name(bufname)
  local path

  -- bufnameからパスを取得
  if bufname and bufname ~= "" then
    path = M.extract_path_from_bufname(bufname)
  else
    path = vim.fn.getcwd()
  end

  -- まずworktreeモジュールから取得を試す
  local ok, worktree = pcall(require, "claude-code.worktree")
  if ok then
    local worktrees = worktree.list_worktrees()

    -- worktreeリストから一致するものを探す
    for _, wt in ipairs(worktrees) do
      if path and path:find(wt.path, 1, true) == 1 then
        return wt.branch or vim.fn.fnamemodify(wt.path, ":t")
      end
    end
  end

  -- gitブランチを取得（パスベース）
  return M.get_branch_name_from_path(path)
end

-- bufnameからパスを抽出
function M.extract_path_from_bufname(bufname)
  -- term://path:port:command の形式からpathを抽出
  local path = bufname:match("^term://([^:]+)")
  if path then
    -- パスを正規化し、プロセスIDが混入していないかチェック
    path = vim.fn.expand(path)

    -- パスが数値で終わっている場合は除去
    path = path:gsub("//%d+$", "")
    path = path:gsub("/%d+$", "")

    -- 存在するディレクトリかチェック
    if vim.fn.isdirectory(path) == 1 then
      return path
    end
  end

  -- その他の形式の場合は現在のディレクトリ
  return vim.fn.getcwd()
end

-- 最後のプロンプトを抽出（Userの入力のみ）
function M.get_last_prompt(lines)
  -- 最後100行を逆順で検索してユーザー入力を探す（範囲を拡大）
  local search_lines = math.min(100, #lines)
  local last_user_prompt = nil
  local found_assistant_response = false

  for i = #lines, math.max(1, #lines - search_lines + 1), -1 do
    local line = lines[i]

    -- 空行をスキップして処理を効率化
    if line:match("^%s*$") then
      goto continue
    end

    -- Claude応答や出力の検出（これらを越えてさらに遡る）
    if
      line:match("^%s*Assistant:")
      or line:match("^%s*Claude:")
      or line:match("^%s*AI:")
      or line:match("I'll help")
      or line:match("I can help")
      or line:match("Let me")
      or line:match("^%s*●") -- 箇条書きの開始
      or line:match("^%s*%d+%. ") -- 番号付きリスト
      or line:match("処理開始")
      or line:match("処理完了")
    then
      found_assistant_response = true
    end

    -- ユーザー入力パターンを検索（応答の後でも継続）
    local prompt, prompt_type = M.extract_prompt_from_line(line)
    if prompt then
      -- 複数行入力の場合は最初の行（完全なプロンプト）を取得
      if prompt_type == ">" then
        last_user_prompt = M.get_multiline_prompt(lines, i)
      else
        last_user_prompt = prompt
      end
      break -- 最初に見つかったユーザー入力が最新
    end

    ::continue::
  end

  -- 見つからない場合は、会話の文脈から推測
  if not last_user_prompt then
    last_user_prompt = M.infer_conversation_context(lines)
  end

  -- プロンプトが見つからない場合は、そのセッション自体を表示対象から除外する
  return last_user_prompt and M.truncate_prompt(last_user_prompt) or nil
end

-- 複数行プロンプトの最初の行を取得
function M.get_multiline_prompt(lines, found_line_index)
  -- found_line_indexから上向きに検索して、プロンプトの開始を見つける
  for i = found_line_index, math.max(1, found_line_index - 10), -1 do
    local line = lines[i]
    local prompt = line:match("^%s*>%s*(.+)")
    if prompt then
      -- Assistant応答でないことを確認
      if
        not prompt:match("Assistant")
        and not prompt:match("Claude")
        and not prompt:match("Update Todos")
        and not prompt:match("Bash%(")
        and not prompt:match("^%s*1分間")
        and not prompt:match("^%s*処理開始")
        and not prompt:match("^%s*処理完了")
      then
        -- 最初の行が最も意味のあるプロンプト
        return prompt
      end
    end
  end

  -- 見つからない場合は、元の行を返す
  return lines[found_line_index]:match("^%s*>%s*(.+)") or lines[found_line_index]
end

-- 行からプロンプトを抽出（Userの入力のみ）
function M.extract_prompt_from_line(line)
  -- Human:, User:, H: パターン（明確にユーザー入力）
  local prompt = line:match("^%s*[Hh]uman:%s*(.+)")
  if prompt then
    return prompt
  end

  prompt = line:match("^%s*[Uu]ser:%s*(.+)")
  if prompt then
    return prompt
  end

  prompt = line:match("^%s*[Hh]:%s*(.+)")
  if prompt then
    return prompt
  end

  -- > で始まる入力行（対話モード・ユーザー入力のみ）
  prompt = line:match("^%s*>%s*(.+)")
  if prompt and not prompt:match("^%s*$") then
    -- Assistant応答や自動出力は除外
    if
      not prompt:match("Assistant")
      and not prompt:match("Claude")
      and not prompt:match("Update Todos")
      and not prompt:match("Bash%(")
      and not prompt:match("^%s*1分間")
      and not prompt:match("^%s*処理開始")
      and not prompt:match("^%s*処理完了")
    then
      return prompt, ">" -- プロンプトのタイプも返す
    end
  end

  -- 自然な日本語入力パターン（画像で確認されたパターンを追加）
  if line:match("これは.*です") or line:match(".*してみて$") or line:match(".*お願いします$") then
    -- ただしAssistant応答は除外
    if not line:match("^%s*Assistant") and not line:match("^%s*AI") and not line:match("^%s*処理") then
      return line:match("^%s*(.+)"), "natural"
    end
  end

  -- 質問文パターン
  if line:match(".*ですか%?$") or line:match(".*してください$") then
    -- ただしAssistant応答は除外
    if not line:match("^%s*Assistant") and not line:match("^%s*AI") then
      return line:match("^%s*(.+)"), "question"
    end
  end

  return nil
end

-- 会話の文脈からユーザー入力を推測
function M.infer_conversation_context(lines)
  -- 最後100行から会話の文脈を分析
  local context_lines = math.min(100, #lines)

  for i = #lines, math.max(1, #lines - context_lines + 1), -1 do
    local line = lines[i]

    -- 作業依頼の文脈パターン
    if line:match("ファイル") and (line:match("作成") or line:match("修正") or line:match("変更")) then
      return "ファイルの"
        .. (line:match("作成") and "作成" or line:match("修正") and "修正" or "変更")
        .. "依頼"
    end

    -- デバッグ・調査依頼
    if line:match("デバッグ") or line:match("調査") or line:match("確認") then
      return "デバッグ・調査依頼"
    end

    -- 実装依頼
    if line:match("実装") or line:match("追加") or line:match("機能") then
      return "機能実装依頼"
    end

    -- 質問
    if line:match("%?") and not line:match("^%s*Assistant") then
      return "質問"
    end
  end

  -- フォールバックではなく、実際にプロンプトが検出できない場合はnilを返す
  return nil
end

-- プロンプトを省略
function M.truncate_prompt(prompt)
  local max_len = 60 -- 長さ制限を60文字に拡張
  if #prompt <= max_len then
    return prompt
  end

  return prompt:sub(1, max_len - 3) .. "..."
end

-- WebSocketアクティビティ監視のための状態管理
M._websocket_monitor = {
  last_activity = 0,
  is_processing = false,
  connection_count = 0,
  message_buffer = {},
}

-- WebSocket監視によるリアルタイム状態検出
function M.check_claudecode_websocket_status()
  -- 1. 環境変数とロックファイルの基本チェック
  local claude_port = vim.env.CLAUDE_CODE_SSE_PORT
  local ide_integration = vim.env.ENABLE_IDE_INTEGRATION

  if not claude_port or ide_integration ~= "true" then
    return nil
  end

  local lock_file = vim.fn.expand("~/.claude/ide/" .. claude_port .. ".lock")
  if vim.fn.filereadable(lock_file) == 0 then
    return nil
  end

  -- 2. ロックファイル内容の解析
  local lock_content = vim.fn.readfile(lock_file)
  if #lock_content == 0 then
    return nil
  end

  local ok, lock_data = pcall(vim.json.decode, table.concat(lock_content, ""))
  if not ok or not lock_data or not lock_data.authToken then
    return nil
  end

  -- 3. WebSocket接続数の監視（処理中の指標）
  local netstat_cmd = string.format("netstat -an | grep ':%s.*ESTABLISHED' | wc -l", claude_port)
  local connection_result = vim.fn.system(netstat_cmd)
  local current_connections = tonumber(connection_result:gsub("%s+", "")) or 0

  -- 4. TCPバッファ状態の監視（データ送受信の検出）
  local buffer_cmd = string.format("lsof -i :%s 2>/dev/null | grep -v LISTEN", claude_port)
  local buffer_result = vim.fn.system(buffer_cmd)
  local has_active_connections = buffer_result and buffer_result ~= ""

  -- 5. ロックファイルの更新頻度監視
  local lock_stat = vim.fn.system("stat -f %m " .. lock_file .. " 2>/dev/null")
  local current_time = os.time()
  local lock_timestamp = tonumber(lock_stat) or 0

  -- 6. 状態判定ロジック
  local time_since_lock_update = current_time - lock_timestamp

  -- 接続数の変化を検出
  if current_connections > M._websocket_monitor.connection_count then
    M._websocket_monitor.last_activity = current_time
    M._websocket_monitor.is_processing = true
  elseif current_connections == 0 and M._websocket_monitor.connection_count > 0 then
    -- 接続が全て閉じられた = 処理完了の可能性
    M._websocket_monitor.is_processing = false
  end

  M._websocket_monitor.connection_count = current_connections

  -- 7. 最終的な状態判定
  if has_active_connections and time_since_lock_update < 3 then
    -- アクティブな接続があり、ロックファイルが最近更新された = 処理中
    return "processing"
  elseif has_active_connections and current_connections > 0 then
    -- 接続はあるが活動が少ない = 待機中
    return "connected"
  elseif current_connections == 0 and time_since_lock_update < 10 then
    -- 最近まで活動があったが現在は非アクティブ = 接続済み
    return "connected"
  elseif lock_timestamp > 0 then
    -- ロックファイルは存在するがアクティビティが少ない
    return "connected"
  end

  return nil
end

-- より詳細なWebSocket監視（実験的）
function M.monitor_websocket_traffic()
  local claude_port = vim.env.CLAUDE_CODE_SSE_PORT
  if not claude_port then
    return nil
  end

  -- TCPトラフィック監視（送受信バイト数）
  local tcpstat_cmd = string.format("netstat -i 2>/dev/null | grep -v '^Kernel' | head -2")
  local traffic_result = vim.fn.system(tcpstat_cmd)

  -- プロセスレベルでのネットワーク活動監視
  local lock_file = vim.fn.expand("~/.claude/ide/" .. claude_port .. ".lock")
  local lock_content = vim.fn.readfile(lock_file)
  if #lock_content > 0 then
    local ok, lock_data = pcall(vim.json.decode, table.concat(lock_content, ""))
    if ok and lock_data and lock_data.pid then
      -- プロセスのネットワーク活動を監視
      local lsof_detail = vim.fn.system(string.format("lsof -p %s -a -i 2>/dev/null", lock_data.pid))

      -- WebSocketメッセージパターンの検出（簡易版）
      if lsof_detail:match("ESTABLISHED") then
        local connection_details = {}
        for line in lsof_detail:gmatch("[^\r\n]+") do
          if line:match("ESTABLISHED") then
            table.insert(connection_details, line)
          end
        end

        -- 接続の詳細情報から活動状況を推測
        if #connection_details > 0 then
          return {
            status = "active_connection",
            connections = #connection_details,
            details = connection_details,
          }
        end
      end
    end
  end

  return nil
end

-- ターミナル出力に基づく状態検出（最優先）
function M.get_terminal_based_status(lines)
  if not lines or #lines == 0 then
    return nil
  end

  -- 最後の5行を重点的にチェック（最新状態の判定）
  local recent_lines = math.min(5, #lines)
  for i = #lines, math.max(1, #lines - recent_lines + 1), -1 do
    local line = lines[i]:lower()

    -- 空行をスキップ
    if line ~= "" then
      -- 1. 明確な処理完了・待機状態の証拠
      if line:match("^%s*>%s*$") or line:match("^%s*>%s+") then
        -- プロンプトが表示されている = 入力待ち状態 = connected
        return "connected"
      end

      -- 2. シェルプロンプトが表示されている
      if line:match("^%s*[%w%-%.]+[@:][%w%-%.]*[%$%%#]%s*$") or line:match("%$%s*$") or line:match("%%%s*$") then
        return "connected"
      end

      -- 3. 処理中断・停止メッセージ
      if line:match("interrupted") or line:match("中断") or line:match("stopped") then
        return "connected"
      end

      -- 4. 明確な処理中の証拠
      if line:match("esc to interrupt") or line:match("esc を押して中断") then
        return "processing"
      end
    end
  end

  -- より広範囲でチェックして処理中の証拠を探す
  local check_lines = math.min(15, #lines)

  for i = #lines, math.max(1, #lines - check_lines + 1), -1 do
    local line = lines[i]:lower()
    local original_line = lines[i]

    if line ~= "" then
      -- 思考・実行中パターン
      if
        line:match("thinking%.%.%.")
        or line:match("processing%.%.%.")
        or line:match("bash%(")
        or line:match("edit%(")
        or line:match("write%(")
        or line:match("実行中")
        or line:match("処理中")
      then
        -- ただし、これらの後に完了の証拠（プロンプトなど）があるかも確認
        local found_completion = false
        for j = i + 1, #lines do
          local next_line = lines[j]:lower()
          if next_line:match("^%s*>%s*$") or next_line:match("^%s*>%s+") then
            -- 処理中の後にプロンプトが出ているので完了済み
            found_completion = true
            return "connected"
          end
        end

        if not found_completion then
          -- 処理中パターンの後にプロンプトが見つからない場合は処理中と判定
          return "processing"
        end
      end
    end
  end

  -- 判定できない場合はnilを返す（他の方法に委ねる）
  return nil
end

-- セッション状態を取得（ClaudeCode.nvimプロトコル対応）
function M.get_session_status(lines, buf)
  -- 1. まず直近のターミナル出力から明確な状態を確認（最優先）
  local terminal_status = M.get_terminal_based_status(lines)
  if terminal_status then
    return terminal_status
  end

  -- 2. WebSocket接続監視による状態確認（補完的）
  local websocket_status = M.check_claudecode_websocket_status()
  if websocket_status then
    return websocket_status
  end

  -- 2. 既存のterminal.luaシステムを使用
  if buf then
    local ok, terminal = pcall(require, "claude-code.terminal")
    if ok and terminal.get_claude_status then
      -- バッファからセッションIDを推測
      local bufname = vim.api.nvim_buf_get_name(buf)

      -- 複数のセッションID推測パターンを試行
      local session_patterns = {
        bufname:match("Claude Terminal %- (.+)"), -- Claude Terminal - sessionname
        bufname:match("term://[^:]+//(%d+):claude"), -- term://path//PID:claude
        "default",
      }

      for _, session_id in ipairs(session_patterns) do
        if session_id then
          local claude_status = terminal.get_claude_status(session_id)

          -- ステータスを標準化
          if claude_status == "running" then
            return "processing"
          elseif claude_status == "waiting" then
            return "waiting"
          elseif claude_status == "ready" then
            return "connected"
          elseif claude_status ~= "none" then
            return "connected"
          end
        end
      end
    end
  end

  -- フォールバック：独自の検出ロジック
  local has_claude_content = false
  local is_waiting_for_input = false
  local is_busy = false

  -- 最後の数行を重点的にチェック（最新状態の判定）
  local recent_lines = math.min(10, #lines)
  for i = #lines, math.max(1, #lines - recent_lines + 1), -1 do
    local line = lines[i]:lower()

    -- 空行が続く場合はスキップ
    if line ~= "" then
      -- ユーザー入力待ちプロンプト（>）の検出 - 最優先
      if line:match("^%s*>%s*$") or line:match("^%s*>%s+") then
        -- 処理が完了してプロンプトが表示されている
        return "connected"
      end

      -- シェルプロンプトチェック
      if line:match("^%s*[%w%-%.]+[@:][%w%-%.]*[%$%%#]%s*$") or line:match("%$%s*$") or line:match("%%%s*$") then
        return "connected"
      end

      -- 処理中断後のメッセージ
      if line:match("interrupted") or line:match("中断") or line:match("stopped") then
        -- 処理が中断されたら接続状態に戻る
        return "connected"
      end
    end
  end

  -- より広範囲での状態検査
  local check_lines = math.min(50, #lines)
  local processed_lines = 0

  for i = #lines, math.max(1, #lines - check_lines + 1), -1 do
    local line = lines[i]:lower()

    -- 空行をスキップ
    if line ~= "" then
      processed_lines = processed_lines + 1

      -- 処理中パターン（最優先で検出）
      if line:match("esc to interrupt") or line:match("esc を押して中断") then
        is_busy = true
        has_claude_content = true
        break -- この場合即座に処理中と判定
      end

      -- 思考中・実行中パターン（拡張版）
      if
        line:match("thinking%.%.%.")
        or line:match("processing%.%.%.")
        or line:match("doing%.%.%.")
        or line:match("%.%.%..*%(") -- "...(何か処理中)"
        or line:match("update todos")
        or line:match("bash%(") -- bashコマンド実行中
        or line:match("edit%(") -- 編集実行中
        or line:match("write%(") -- ファイル書き込み中
        or line:match("read%(") -- ファイル読み込み中
        or line:match("grep%(") -- 検索実行中
        or line:match("実行中")
        or line:match("処理中")
        or line:match("作成中")
        or line:match("修正中")
        or line:match("確認中")
        or line:match("waiting%.%.%.")
        or line:match("working%.%.%.")
      then
        is_busy = true
        has_claude_content = true
      end

      -- 待機中パターン
      if line:match("do you want") or line:match("press enter") or line:match("continue%?") then
        is_waiting_for_input = true
        has_claude_content = true
      end

      -- Claudeコンテンツ
      if line:match("claude") then
        has_claude_content = true
      end

      -- 処理終了後の空行が続く場合も考慮
      if processed_lines > 10 then -- 10個の非空行を確認したら十分
        break
      end
    end
  end

  -- 状態判定（最新の状態を優先）
  -- 最後の数行を再確認して最終判定
  for i = #lines, math.max(1, #lines - 5), -1 do
    local line = lines[i]:lower()
    if line ~= "" then
      -- プロンプトまたは中断メッセージがあれば接続済み
      if
        line:match("^%s*>%s*$")
        or line:match("^%s*>%s+")
        or line:match("interrupted")
        or line:match("中断")
        or line:match("stopped")
      then
        return "connected"
      end
      -- 処理中の確実な証拠
      if line:match("esc to interrupt") then
        return "processing"
      end
    end
  end

  -- フラグに基づく判定
  if is_busy then
    return "processing"
  elseif is_waiting_for_input then
    return "waiting"
  elseif has_claude_content then
    -- Claudeコンテンツがあるが処理中の証拠がない場合は接続済み
    return "connected"
  else
    return "connected"
  end
end

-- セッション一覧を表示
function M.show_sessions()
  local sessions = M.get_sessions()

  if #sessions == 0 then
    vim.notify("No Claude sessions found", vim.log.levels.INFO)
    return
  end

  local lines = {
    "=== Claude Sessions Status ===",
  }

  -- アイコンマッピング
  local icons = {
    disconnected = "🔴",
    connected = "🟢",
    processing = "🔵",
    waiting = "🟡",
    error = "🟠",
    external = "🟣", -- 外部プロセス
  }

  for _, session in ipairs(sessions) do
    local icon = icons[session.status] or "⚪"
    local branch = M.format_branch_name(session.branch)
    local status = "[" .. session.status .. "]"
    local prompt = '"' .. (session.last_prompt or "-") .. '"'

    -- 外部プロセスの場合、PID情報を追加
    if session.source == "file_based" then
      branch = branch .. "(" .. (session.pid or "?") .. ")"
    end

    local line = string.format("%s %-25s %-12s %s", icon, branch, status, prompt)
    table.insert(lines, line)
  end

  table.insert(lines, "====================================")

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- ブランチ名フォーマット
function M.format_branch_name(branch, max_len)
  max_len = max_len or 20
  if #branch <= max_len then
    return branch
  end

  return branch:sub(1, max_len - 3) .. "..."
end

-- セッション切り替え（簡易版）
function M.switch_to_session(session)
  if vim.api.nvim_buf_is_valid(session.buffer) then
    -- バッファを表示
    vim.api.nvim_set_current_buf(session.buffer)
    vim.notify("Switched to: " .. session.branch, vim.log.levels.INFO)
  else
    vim.notify("Session no longer available", vim.log.levels.WARN)
  end
end

-- リアルタイム監視パネル
M.monitor = {
  buf = nil,
  win = nil,
  is_visible = false,
  timer = nil,
}

-- 監視パネルを表示
function M.show_monitor()
  if M.monitor.is_visible then
    return
  end

  -- バッファ作成
  M.monitor.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.monitor.buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.monitor.buf, "swapfile", false)
  vim.api.nvim_buf_set_name(M.monitor.buf, "Claude Sessions Monitor")

  -- フローティングウィンドウ設定
  local width = 40
  local height = 12
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    title = "Claude Sessions",
    title_pos = "center",
    style = "minimal",
  }

  M.monitor.win = vim.api.nvim_open_win(M.monitor.buf, false, win_config)
  M.monitor.is_visible = true

  -- 初期コンテンツ更新
  M.update_monitor_content()

  -- 定期更新タイマー開始
  M.start_monitor_timer()

  -- キーマップ追加
  vim.api.nvim_buf_set_keymap(M.monitor.buf, "n", "q", "", {
    callback = function()
      M.hide_monitor()
    end,
    desc = "Close monitor",
  })

  vim.api.nvim_buf_set_keymap(M.monitor.buf, "n", "r", "", {
    callback = function()
      M.update_monitor_content()
    end,
    desc = "Refresh monitor",
  })
end

-- 監視パネルを非表示
function M.hide_monitor()
  if M.monitor.timer then
    vim.fn.timer_stop(M.monitor.timer)
    M.monitor.timer = nil
  end

  if M.monitor.win and vim.api.nvim_win_is_valid(M.monitor.win) then
    vim.api.nvim_win_close(M.monitor.win, true)
  end

  if M.monitor.buf and vim.api.nvim_buf_is_valid(M.monitor.buf) then
    vim.api.nvim_buf_delete(M.monitor.buf, { force = true })
  end

  M.monitor.buf = nil
  M.monitor.win = nil
  M.monitor.is_visible = false
end

-- 監視パネル切り替え
function M.toggle_monitor()
  if M.monitor.is_visible then
    M.hide_monitor()
  else
    M.show_monitor()
  end
end

-- 右上固定パネル（Snacks.nvimを使用）
M.persistent_panel = {
  win = nil,
  buf = nil,
  is_visible = false,
  timer = nil,
}

-- 右上固定パネルを表示
function M.show_persistent_panel()
  -- Snacks.nvimが利用可能かチェック
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    vim.notify("Snacks.nvim not available, using fallback", vim.log.levels.WARN)
    M.show_monitor()
    return
  end

  if M.persistent_panel.is_visible then
    return
  end

  -- コンテンツバッファ作成
  M.persistent_panel.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.persistent_panel.buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.persistent_panel.buf, "swapfile", false)
  vim.api.nvim_buf_set_name(M.persistent_panel.buf, "Claude Sessions Panel")

  -- セッション数に基づいて高さを動的に調整
  local sessions = M.get_sessions()
  local dynamic_height = math.max(3, math.min(12, #sessions + 2)) -- 最小3行、最大12行

  -- Snacks.winで右上固定ウィンドウを作成
  M.persistent_panel.win = snacks.win({
    buf = M.persistent_panel.buf,
    relative = "editor",
    width = 70, -- 幅を大幅拡大してプロンプト情報をより多く表示
    height = dynamic_height,
    row = 0,
    col = -1, -- 右端
    border = "rounded",
    title = "Claude Sessions",
    title_pos = "center",
    backdrop = false,
    focusable = false, -- フォーカスされないように
    zindex = 100, -- 最前面
    wo = {
      winhighlight = "Normal:FloatNormal,FloatBorder:FloatBorder",
      winblend = 10, -- 少し透明に
    },
    enter = false, -- 自動でenterしない
    persistent = true, -- 永続化
  })

  M.persistent_panel.is_visible = true

  -- 初期コンテンツ更新
  M.update_persistent_content()

  -- 定期更新タイマー開始
  M.start_persistent_timer()

  -- 表示直後に追加更新（少し遅らせて情報を充実させる）
  vim.defer_fn(function()
    if M.persistent_panel.is_visible then
      M.update_persistent_content()
    end
  end, 200)

  -- ウィンドウが閉じられた時の処理
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(M.persistent_panel.win.win),
    once = true,
    callback = function()
      M.hide_persistent_panel()
    end,
  })
end

-- 右上固定パネルを非表示
function M.hide_persistent_panel()
  if M.persistent_panel.timer then
    vim.fn.timer_stop(M.persistent_panel.timer)
    M.persistent_panel.timer = nil
  end

  if M.persistent_panel.win and M.persistent_panel.win:valid() then
    M.persistent_panel.win:close()
  end

  if M.persistent_panel.buf and vim.api.nvim_buf_is_valid(M.persistent_panel.buf) then
    vim.api.nvim_buf_delete(M.persistent_panel.buf, { force = true })
  end

  M.persistent_panel.win = nil
  M.persistent_panel.buf = nil
  M.persistent_panel.is_visible = false
end

-- 右上固定パネル切り替え
function M.toggle_persistent_panel()
  if M.persistent_panel.is_visible then
    M.hide_persistent_panel()
  else
    M.show_persistent_panel()
  end
end

-- 右上固定パネルのコンテンツ更新
function M.update_persistent_content()
  if not M.persistent_panel.buf or not vim.api.nvim_buf_is_valid(M.persistent_panel.buf) then
    return
  end

  local sessions = M.get_sessions()

  -- セッション数に応じてウィンドウサイズを動的調整
  if M.persistent_panel.win and M.persistent_panel.win:valid() then
    local new_height = math.max(3, math.min(12, #sessions + 2)) -- 最小3行、最大12行
    M.persistent_panel.win:update({
      height = new_height,
    })
  end

  local lines = {}

  if #sessions == 0 then
    table.insert(lines, "No active sessions")
  else
    for i, session in ipairs(sessions) do
      if i > 6 then
        break
      end -- 最大6セッションまで表示

      local icon = session.status == "processing" and "🔵"
        or session.status == "waiting" and "🟡"
        or session.status == "error" and "🟠"
        or session.status == "external" and "🟣"
        or "🟢"

      local branch = M.format_branch_name(session.branch, 15) -- ブランチ名長さを15文字に拡張
      local prompt = session.last_prompt or "-"

      -- 外部セッションの場合、プロセス情報も含める
      if session.source == "file_based" then
        -- ブランチ名が短すぎる場合はより詳細な情報を表示
        if #branch < 5 or branch == "unknown" then
          local path_info = session.path and vim.fn.fnamemodify(session.path, ":t") or "?"
          branch = path_info .. "(" .. (session.pid or "?") .. ")"
        else
          branch = branch .. "(" .. (session.pid or "?") .. ")"
        end
      end

      -- プロンプトの長さ調整を大幅拡張
      prompt = prompt:sub(1, 40) -- 40文字まで表示
      if #(session.last_prompt or "") > 40 then
        prompt = prompt .. "..."
      end

      -- 拡張された表示形式
      local line = string.format("%s %-20s %s", icon, branch, prompt)
      table.insert(lines, line)
    end
  end

  -- バッファに書き込み
  vim.api.nvim_buf_set_option(M.persistent_panel.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.persistent_panel.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.persistent_panel.buf, "modifiable", false)
end

-- 右上固定パネルのタイマー開始
function M.start_persistent_timer()
  if M.persistent_panel.timer then
    vim.fn.timer_stop(M.persistent_panel.timer)
  end

  M.persistent_panel.timer = vim.fn.timer_start(1500, function()
    if M.persistent_panel.is_visible then
      M.update_persistent_content()
      M.start_persistent_timer()
    end
  end)
end

-- 監視コンテンツ更新
function M.update_monitor_content()
  if not M.monitor.buf or not vim.api.nvim_buf_is_valid(M.monitor.buf) then
    return
  end

  local sessions = M.get_sessions()

  local lines = {
    "┌─ Claude Sessions ──────────────────┐",
  }

  if #sessions == 0 then
    table.insert(lines, "│ No active sessions                 │")
  else
    for _, session in ipairs(sessions) do
      local icon = session.status == "processing" and "🔵"
        or session.status == "waiting" and "🟡"
        or session.status == "error" and "🟠"
        or session.status == "external" and "🟣"
        or "🟢"

      local branch = M.format_branch_name(session.branch, 10)
      local status = session.status:sub(1, 4) -- proc, wait, conn, etc
      local prompt = (session.last_prompt or "-"):sub(1, 15)
      if #(session.last_prompt or "") > 15 then
        prompt = prompt .. "..."
      end

      -- 外部セッションの場合、プロセス情報も含める
      if session.source == "file_based" then
        branch = branch .. "(" .. tostring(session.pid or "?"):sub(-4) .. ")" -- PIDの末尾4桁
      end

      local line = string.format("│%s %-15s [%s] %s", icon, branch, status, prompt)

      -- 長さ調整（38文字に合わせる）
      if #line > 38 then
        line = line:sub(1, 35) .. "...│"
      else
        line = line .. string.rep(" ", 38 - #line) .. "│"
      end

      table.insert(lines, line)
    end
  end

  table.insert(
    lines,
    "├────────────────────────────────────┤"
  )
  table.insert(lines, "│ q: close  r: refresh               │")
  table.insert(
    lines,
    "└────────────────────────────────────┘"
  )

  -- バッファに書き込み
  vim.api.nvim_buf_set_option(M.monitor.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.monitor.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.monitor.buf, "modifiable", false)
end

-- 監視タイマー開始
function M.start_monitor_timer()
  if M.monitor.timer then
    vim.fn.timer_stop(M.monitor.timer)
  end

  M.monitor.timer = vim.fn.timer_start(2000, function()
    if M.monitor.is_visible then
      M.update_monitor_content()
      M.start_monitor_timer() -- 再帰的に継続
    end
  end)
end

-- システムレベルでのClaudeCodeセッション検索
function M.add_system_sessions(sessions)
  -- ファイルベースセッション管理の追加
  M.add_file_based_sessions(sessions)

  -- プロセス検索は補完的に実行
  local search_patterns = {
    "ps aux | grep -E '[Cc]laude.*[Cc]ode' | grep -v grep", -- ClaudeCode
    "ps aux | grep -E 'claude' | grep -v grep", -- claude CLI
    "ps aux | grep -E 'anthropic' | grep -v grep", -- Anthropic関連
  }

  for _, pattern in ipairs(search_patterns) do
    local ps_result = vim.fn.system(pattern)

    if vim.v.shell_error == 0 and ps_result ~= "" then
      for line in ps_result:gmatch("[^\r\n]+") do
        -- Neovimプロセス自体は除外
        if not line:match("nvim") and not line:match("grep") then
          local working_dir = M.extract_working_dir_from_ps(line)
          if working_dir then
            -- 既存のセッションと重複しないかチェック
            local path_exists = false
            for _, existing in ipairs(sessions) do
              if existing.path and existing.path == working_dir then
                path_exists = true
                break
              end
            end

            if not path_exists then
              local branch_name = M.get_branch_name_from_path(working_dir)
              local process_name = line:match("%S+$") or "unknown"
              -- 動的ステータス検出を実行
              local dynamic_status = M.get_external_session_status(nil, working_dir)

              table.insert(sessions, {
                buffer = nil,
                bufname = "system_process",
                branch = branch_name,
                status = dynamic_status,
                last_prompt = "Process: " .. process_name,
                path = working_dir,
                source = "system_process",
              })
            end
          end
        end
      end
    end
  end
end

-- 外部セッションの動的ステータスを取得
function M.get_external_session_status(pid, path)
  -- WebSocketベースのステータス確認を最優先
  local websocket_status = M.check_claudecode_websocket_status()
  if websocket_status and websocket_status ~= "connected" then
    return websocket_status
  end

  -- PIDが提供されている場合、プロセスの詳細な状態確認を試行
  if pid then
    -- プロセスが存在するか確認
    if not M.is_process_alive(pid) then
      return "disconnected"
    end

    -- プロセスの最近のアクティビティをチェック
    local proc_stat_cmd = string.format("ps -p %d -o %%cpu,etime 2>/dev/null | tail -1", pid)
    local proc_result = vim.fn.system(proc_stat_cmd)
    if proc_result and proc_result ~= "" then
      local cpu_usage, elapsed = proc_result:match("([%d%.]+)%s+([%d:%-]+)")
      if cpu_usage then
        local cpu_num = tonumber(cpu_usage) or 0
        -- CPU使用率が高い場合は処理中と判定
        if cpu_num > 1.0 then
          return "processing"
        end
      end
    end
  end

  -- デフォルトは接続状態
  return "connected"
end

-- ファイルベースセッション管理（複数のNeovimプロセス間での情報共有）
function M.add_file_based_sessions(sessions)
  local session_file = "/tmp/claude_sessions.json"

  -- 現在のセッション情報をファイルに書き込み
  M.write_current_session_to_file(session_file)

  -- 他のNeovimプロセスの既存セッション情報を読み込み
  local file_sessions = M.read_sessions_from_file(session_file)

  -- 現在のプロセスPIDを取得
  local current_pid = vim.fn.getpid()

  for _, file_session in ipairs(file_sessions) do
    -- 自分のプロセスでない、かつPIDが有効かチェック
    if file_session.pid and file_session.pid ~= current_pid and M.is_process_alive(file_session.pid) then
      -- ClaudeCodeセッションのみを対象とする
      if M.is_claudecode_session(file_session) then
        -- 既存のセッションと重複しないかチェック
        local exists = false
        for _, existing in ipairs(sessions) do
          if existing.pid == file_session.pid then
            exists = true
            break
          end
        end

        if not exists then
          -- 動的ステータス検出を実行
          local dynamic_status = M.get_external_session_status(file_session.pid, file_session.path)

          table.insert(sessions, {
            buffer = nil,
            bufname = "external_nvim",
            branch = file_session.branch,
            status = dynamic_status,
            last_prompt = file_session.last_prompt or "External ClaudeCode session",
            path = file_session.path,
            source = "file_based",
            pid = file_session.pid,
          })
        end
      end
    end
  end
end

-- 現在のセッション情報をファイルに書き込み
function M.write_current_session_to_file(session_file)
  local current_pid = vim.fn.getpid()
  local current_sessions = {}
  local has_claude_session = false

  -- 現在のNeovimプロセス内のセッションを収集
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
      local bufname = vim.api.nvim_buf_get_name(buf)

      if
        buftype == "terminal"
        and (bufname:match("[Cc]laude") or bufname:match("ClaudeCode") or bufname:match("term://.*claude"))
      then
        local session_info = M.analyze_session(buf, bufname)
        if session_info then
          has_claude_session = true
          -- パスの正規化（PIDが混入することを防ぐ）
          local clean_path = session_info.path or vim.fn.getcwd()
          clean_path = clean_path:gsub("//.*$", "") -- //以降を削除
          clean_path = clean_path:gsub("/+", "/") -- 連続スラッシュを単一に

          table.insert(current_sessions, {
            pid = current_pid,
            path = clean_path,
            branch = session_info.branch or M.get_branch_name_from_path(clean_path),
            status = session_info.status,
            last_prompt = session_info.last_prompt or "Claude session",
            timestamp = os.time(),
          })
        end
      end
    end
  end

  -- 既存のファイルから他のプロセスの情報を読み取り、マージする
  local all_sessions = M.read_sessions_from_file(session_file)

  -- 古いセッション情報のクリーンアップ（24時間以上古い、または無効なプロセス）
  local current_time = os.time()
  all_sessions = vim.tbl_filter(function(session)
    -- 現在のプロセスの古い情報は削除
    if session.pid == current_pid then
      return false
    end

    -- 24時間以上古いセッションは削除
    if session.timestamp and (current_time - session.timestamp) > 86400 then
      return false
    end

    -- プロセスが存在しない場合は削除
    if session.pid and not M.is_process_alive(session.pid) then
      return false
    end

    -- 異常なパス形式（PIDが混入）は削除
    if session.path and session.path:match("//[%d]+$") then
      return false
    end

    return true
  end, all_sessions)

  -- 現在のセッション情報を追加
  for _, session in ipairs(current_sessions) do
    table.insert(all_sessions, session)
  end

  -- ClaudeCodeセッションが無い場合は記録しない（ClaudeCodeセッションのみを管理）
  -- 通常のNeovimセッションはClaude Sessionsパネルに表示させない

  -- ファイルに書き込み（JSONエンコード）
  local ok, encoded = pcall(vim.json.encode, all_sessions)
  if ok then
    vim.fn.writefile({ encoded }, session_file)
  end
end

-- ファイルからセッション情報を読み込み
function M.read_sessions_from_file(session_file)
  local sessions = {}

  if vim.fn.filereadable(session_file) == 1 then
    local content = vim.fn.readfile(session_file)
    if #content > 0 then
      local ok, decoded = pcall(vim.json.decode, content[1])
      if ok and type(decoded) == "table" then
        sessions = decoded
      end
    end
  end

  return sessions
end

-- プロセスが生きているかチェック
function M.is_process_alive(pid)
  if not pid then
    return false
  end
  local result = vim.fn.system("ps -p " .. pid .. " > /dev/null 2>&1")
  return vim.v.shell_error == 0
end

-- psコマンドの出力から作業ディレクトリを抽出
function M.extract_working_dir_from_ps(ps_line)
  -- lsofコマンドで該当プロセスの作業ディレクトリを取得
  local pid = ps_line:match("^%S+%s+(%d+)")
  if pid then
    local lsof_result = vim.fn.system("lsof -p " .. pid .. " -d cwd 2>/dev/null | tail -1")
    if vim.v.shell_error == 0 then
      local cwd = lsof_result:match("%S+$")
      if cwd and cwd ~= "" then
        return cwd
      end
    end
  end
  return nil
end

-- パスからブランチ名を取得
function M.get_branch_name_from_path(path)
  if not path or path == "" then
    path = vim.fn.getcwd()
  end

  -- パスを正規化
  path = vim.fn.expand(path)

  -- ディレクトリが存在するかチェック
  if vim.fn.isdirectory(path) == 0 then
    return "unknown"
  end

  local result = vim.fn.system("cd '" .. path .. "' && git symbolic-ref --short HEAD 2>/dev/null")
  if vim.v.shell_error == 0 then
    local branch = result:gsub("\n", ""):gsub("^%s+", ""):gsub("%s+$", "")

    -- 空文字や数値のみの場合はディレクトリ名を使用
    if branch == "" or branch:match("^%d+$") then
      return vim.fn.fnamemodify(path, ":t") or "unknown"
    end

    -- 短縮処理
    if branch:match("^feature/") then
      return "feat/" .. branch:sub(9)
    elseif branch:match("^hotfix/") then
      return "fix/" .. branch:sub(8)
    elseif branch:match("^bugfix/") then
      return "bug/" .. branch:sub(8)
    end
    return branch
  end

  return vim.fn.fnamemodify(path, ":t") or "unknown"
end

-- 定期的なセッション情報書き込みタイマー
M.auto_sync_timer = nil

-- 自動同期を開始
function M.start_auto_sync()
  if M.auto_sync_timer then
    vim.fn.timer_stop(M.auto_sync_timer)
  end

  M.auto_sync_timer = vim.fn.timer_start(2000, function() -- 2秒間隔
    M.write_current_session_to_file("/tmp/claude_sessions.json")
    M.start_auto_sync() -- 再帰的に継続
  end)
end

-- 自動同期を停止
function M.stop_auto_sync()
  if M.auto_sync_timer then
    vim.fn.timer_stop(M.auto_sync_timer)
    M.auto_sync_timer = nil
  end
end

-- 現在の作業状況を詳細に取得
function M.get_current_work_info()
  -- 現在のバッファ情報
  local current_buf = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(current_buf)
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = current_buf })
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = current_buf })

  -- 特殊なバッファタイプの判定
  if buftype == "help" then
    local help_topic = vim.fn.fnamemodify(bufname, ":t:r")
    return {
      type = "help",
      prompt = "Reading: " .. help_topic .. " help",
    }
  elseif buftype == "quickfix" then
    return {
      type = "quickfix",
      prompt = "Browsing quickfix list",
    }
  elseif buftype == "terminal" then
    return
  else
    -- 通常のファイル
    local filename = vim.fn.fnamemodify(bufname, ":t")
    local extension = vim.fn.fnamemodify(bufname, ":e")

    -- ファイルの変更状況
    local modified = vim.api.nvim_get_option_value("modified", { buf = current_buf })
    local readonly = vim.api.nvim_get_option_value("readonly", { buf = current_buf })

    local status = ""
    if readonly then
      status = " (readonly)"
    elseif modified then
      status = " (modified)"
    end

    return {
      type = "file",
      prompt = "Editing: " .. filename .. status,
    }
  end
end

-- ClaudeCodeセッションかどうかを判定
function M.is_claudecode_session(session)
  -- 明確にClaudeCodeに関連する情報がある場合のみtrue
  if not session then
    return false
  end

  local last_prompt = session.last_prompt or ""
  local work_type = session.work_type or ""
  local status = session.status or ""

  -- 明らかにClaudeCodeセッション
  if status == "processing" or status == "waiting" then
    return true
  end

  -- ClaudeCodeプロンプトパターン
  local claudecode_patterns = {
    -- Claude関連のプロンプト
    "claude",
    "ai assistant",
    "technical.*question",
    "implement.*feature",
    "debug.*issue",
    "help.*with",
    "create.*function",
    "fix.*bug",
    "技術的な質問",
    "実装.*して",
    "修正.*して",
    "作成.*して",
    "デバッグ.*して",
    "助けて",
  }

  for _, pattern in ipairs(claudecode_patterns) do
    if last_prompt:lower():match(pattern) then
      return true
    end
  end

  -- 単純なファイル編集やバッファ操作は除外
  local non_claudecode_patterns = {
    "editing:",
    "new.*buffer",
    "empty buffer",
    "terminal session",
    "browsing.*list",
    "file browser",
    "picker",
    "finder",
  }

  for _, pattern in ipairs(non_claudecode_patterns) do
    if last_prompt:lower():match(pattern) then
      return false
    end
  end

  -- work_typeがscratchやfileの場合は通常のNeovimセッション
  if work_type == "scratch" or work_type == "file" or work_type == "terminal" then
    return false
  end

  -- 不明な場合はfalse（保守的にClaudeCodeセッション以外として扱う）
  return false
end

-- セッションファイルの完全クリーンアップ
function M.cleanup_session_file()
  local session_file = "/tmp/claude_sessions.json"
  local current_time = os.time()

  -- 既存セッションを読み込み
  local sessions = M.read_sessions_from_file(session_file)

  -- クリーンアップ（ClaudeCodeセッションのみを対象）
  local clean_sessions = vim.tbl_filter(function(session)
    -- 24時間以上古いセッションは削除
    if session.timestamp and (current_time - session.timestamp) > 86400 then
      return false
    end

    -- プロセスが存在しない場合は削除
    if session.pid and not M.is_process_alive(session.pid) then
      return false
    end

    -- 異常なパス形式（PIDが混入）は削除
    if session.path and session.path:match("//[%d]+$") then
      return false
    end

    -- ClaudeCodeセッション以外は削除
    if not M.is_claudecode_session(session) then
      return false
    end

    -- ClaudeCodeセッションのみ残す
    return true
  end, sessions)

  -- クリーンアップ結果を保存
  local ok, encoded = pcall(vim.json.encode, clean_sessions)
  if ok then
    vim.fn.writefile({ encoded }, session_file)
    vim.notify(
      string.format("Session file cleaned: %d → %d entries", #sessions, #clean_sessions),
      vim.log.levels.INFO
    )
  else
    vim.notify("Failed to cleanup session file", vim.log.levels.ERROR)
  end

  return clean_sessions
end

-- モジュール読み込み時に自動同期を開始
M.start_auto_sync()

return M
