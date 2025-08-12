local M = {}

-- キャッシュ管理
local cache = {
  conversations_all = nil, -- 全件取得用キャッシュ
  last_scan_time_all = 0, -- 全件取得用タイムスタンプ
  conversations_recent = {}, -- 直近取得用キャッシュ（フィルタ別）
  last_scan_time_recent = {}, -- 直近取得用タイムスタンプ（フィルタ別）
  cache_duration = 30, -- キャッシュ保持時間（秒）
}

-- 安全なJSON解析
local function safe_json_decode(str)
  local ok, result = pcall(vim.json.decode, str)
  return ok and result or nil
end

-- 安全なファイル読み込み
local function safe_read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and lines or nil
end

-- タイムスタンプ解析
function M.parse_timestamp(timestamp)
  if not timestamp or timestamp == "" then
    return nil
  end

  if type(timestamp) == "number" then
    return timestamp
  end

  if type(timestamp) == "string" then
    local year, month, day, hour, min, sec = timestamp:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if year then
      return os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec),
      })
    end
  end

  return nil
end

-- ファイル一覧を高速取得
function M.scan_files_fast()
  local projects_dir = vim.fn.expand("~/.claude/projects")
  if vim.fn.isdirectory(projects_dir) == 0 then
    return {}
  end

  local file_list = {}
  local project_dirs = vim.fn.readdir(projects_dir)

  for _, project_dir in ipairs(project_dirs) do
    local project_path = projects_dir .. "/" .. project_dir
    local files = vim.fn.globpath(project_path, "*.jsonl", false, true)

    for _, file_path in ipairs(files) do
      -- ファイル統計情報のみ取得（内容は読まない）
      local stat = vim.loop.fs_stat(file_path)
      if stat then
        table.insert(file_list, {
          path = file_path,
          size = stat.size,
          mtime = stat.mtime.sec,
          project_dir = project_dir,
        })
      end
    end
  end

  -- ファイル更新時刻でソート（新しい順）
  table.sort(file_list, function(a, b)
    return a.mtime > b.mtime
  end)

  return file_list
end

-- ユーザーコンテンツ抽出のヘルパー関数
function M.extract_user_content(msg)
  local content_text = ""

  if msg.message and msg.message.content then
    local content = msg.message.content
    if type(content) == "string" then
      content_text = content
    elseif type(content) == "table" then
      for _, item in ipairs(content) do
        if type(item) == "string" then
          content_text = item
          break
        elseif type(item) == "table" and item.text then
          content_text = item.text
          break
        elseif type(item) == "table" and item.type == "text" and item.text then
          content_text = item.text
          break
        end
      end
    end
  elseif msg.content then
    if type(msg.content) == "string" then
      content_text = msg.content
    elseif type(msg.content) == "table" then
      for _, item in ipairs(msg.content) do
        if type(item) == "string" then
          content_text = item
          break
        elseif type(item) == "table" and item.text then
          content_text = item.text
          break
        end
      end
    end
  end

  return content_text
end

-- 直近N件を取得
function M.read_recent_conversations(filter_current_dir, limit)
  limit = limit or 30

  -- キャッシュキーを生成
  local cache_key = string.format("%s_%d", filter_current_dir and "current" or "all", limit)
  local current_time = os.time()

  -- キャッシュチェック
  if
    cache.conversations_recent[cache_key]
    and cache.last_scan_time_recent[cache_key]
    and (current_time - cache.last_scan_time_recent[cache_key]) < cache.cache_duration
  then
    return cache.conversations_recent[cache_key]
  end

  -- ファイル統計情報のみで高速スキャン
  local file_list = M.scan_files_fast()
  if #file_list == 0 then
    return {}
  end

  local conversations = {}
  local processed_count = 0

  -- 効率的な処理：必要な分だけファイルを読んで即座に判定
  for _, file_info in ipairs(file_list) do
    if processed_count >= limit then
      break -- 必要数に達したら停止
    end

    local lines = safe_read_file(file_info.path)
    if lines and #lines > 0 then
      local session_id = vim.fn.fnamemodify(file_info.path, ":t:r")
      local created_at = nil
      local project_path_decoded = nil

      -- 最初の数行のみ読んで基本情報を取得
      local lines_to_check = math.min(#lines, 5)
      for i = 1, lines_to_check do
        local msg = safe_json_decode(lines[i])
        if msg then
          if not created_at and msg.timestamp then
            created_at = msg.timestamp
          end
          if not project_path_decoded and msg.cwd then
            project_path_decoded = msg.cwd
          end
          if created_at and project_path_decoded then
            break
          end
        end
      end

      -- フィルタリングチェック
      if filter_current_dir then
        local current_dir = vim.fn.getcwd()
        if project_path_decoded ~= current_dir then
          goto continue -- このファイルをスキップ
        end
      end

      -- 全メッセージをパース（条件を満たした場合のみ）
      local messages = {}
      for _, line in ipairs(lines) do
        local msg = safe_json_decode(line)
        if msg then
          table.insert(messages, msg)
        end
      end

      if #messages > 0 then
        local title = "新しい会話"
        for _, msg in ipairs(messages) do
          if msg.type == "user" then
            local content_text = M.extract_user_content(msg)
            if content_text and content_text ~= "" then
              content_text = string.gsub(content_text, "\n", " ")
              content_text = string.gsub(content_text, "%s+", " ")
              content_text = vim.trim(content_text)
              if content_text ~= "" then
                title = string.sub(content_text, 1, 60)
                if #content_text > 60 then
                  title = title .. "..."
                end
                break
              end
            end
          end
        end

        table.insert(conversations, {
          session_id = session_id,
          title = title,
          project_path = project_path_decoded or vim.fn.getcwd(),
          created_at = created_at or "",
          message_count = #messages,
          file_path = file_info.path,
          messages = messages,
          _cached_time = M.parse_timestamp(created_at) or file_info.mtime,
        })

        processed_count = processed_count + 1
      end
    end

    ::continue::
  end

  -- キャッシュに保存
  cache.conversations_recent[cache_key] = conversations
  cache.last_scan_time_recent[cache_key] = current_time

  return conversations
end

-- 全件取得
function M.read_conversations(filter_current_dir)
  -- 全件取得用の別キャッシュをチェック
  local current_time = os.time()
  if cache.conversations_all and (current_time - cache.last_scan_time_all) < cache.cache_duration then
    -- フィルタリングが必要な場合は再フィルタリング
    if filter_current_dir then
      local current_dir = vim.fn.getcwd()
      local filtered = vim.tbl_filter(function(conv)
        return conv.project_path == current_dir
      end, cache.conversations_all)
      return filtered
    else
      return cache.conversations_all
    end
  end

  local projects_dir = vim.fn.expand("~/.claude/projects")

  if vim.fn.isdirectory(projects_dir) == 0 then
    vim.notify("Claude Code会話履歴が見つかりません: " .. projects_dir, vim.log.levels.WARN)
    return {}
  end

  local conversations = {}

  -- 各プロジェクトディレクトリをスキャン
  local project_dirs = vim.fn.readdir(projects_dir)
  for _, project_dir in ipairs(project_dirs) do
    local project_path = projects_dir .. "/" .. project_dir

    -- JSONLファイルを探す (UUID形式のファイル名)
    local files = vim.fn.globpath(project_path, "*.jsonl", false, true)

    for _, file_path in ipairs(files) do
      -- JSONLファイルは行ごとにJSONオブジェクトが格納されている
      local lines = safe_read_file(file_path)
      if lines and #lines > 0 then
        local messages = {}
        local session_id = vim.fn.fnamemodify(file_path, ":t:r")
        local created_at = nil
        local project_path_decoded = nil

        -- 各行をパース
        for _, line in ipairs(lines) do
          local msg = safe_json_decode(line)
          if msg then
            table.insert(messages, msg)
            -- 最初のメッセージから情報を取得
            if not created_at and msg.timestamp then
              created_at = msg.timestamp
            end
            -- プロジェクトパス: ccresumeと同様にmessages[0].cwdから取得
            if not project_path_decoded and msg.cwd then
              project_path_decoded = msg.cwd
            end
          end
        end

        if #messages > 0 then
          -- フィルター処理：現在のディレクトリのプロジェクトのみ
          if filter_current_dir then
            local current_dir = vim.fn.getcwd()
            if project_path_decoded ~= current_dir then
              goto continue
            end
          end
          -- 最初のユーザーメッセージをタイトルとして使用
          local title = "新しい会話"

          for _, msg in ipairs(messages) do
            local content_text = ""

            -- 様々なメッセージ形式に対応
            if msg.type == "user" then
              -- パターン1: msg.message.content
              if msg.message and msg.message.content then
                local content = msg.message.content
                if type(content) == "string" then
                  content_text = content
                elseif type(content) == "table" then
                  -- 配列形式の場合
                  for _, item in ipairs(content) do
                    if type(item) == "string" then
                      content_text = item
                      break
                    elseif type(item) == "table" and item.text then
                      content_text = item.text
                      break
                    elseif type(item) == "table" and item.type == "text" and item.text then
                      content_text = item.text
                      break
                    end
                  end
                end
                -- パターン2: msg.content (直接)
              elseif msg.content then
                if type(msg.content) == "string" then
                  content_text = msg.content
                elseif type(msg.content) == "table" then
                  for _, item in ipairs(msg.content) do
                    if type(item) == "string" then
                      content_text = item
                      break
                    elseif type(item) == "table" and item.text then
                      content_text = item.text
                      break
                    end
                  end
                end
              end
            end

            if content_text ~= "" then
              -- 改行を空白に置換し、最初の60文字を取得
              content_text = string.gsub(content_text, "\n", " ")
              content_text = string.gsub(content_text, "%s+", " ") -- 複数空白を1つに
              content_text = vim.trim(content_text) -- 前後の空白削除

              if content_text ~= "" then
                title = string.sub(content_text, 1, 60)
                if #content_text > 60 then
                  title = title .. "..."
                end
                break
              end
            end
          end

          -- メッセージ履歴のプレビュー用テキストを作成
          local preview_messages = {}
          local msg_count = 0
          for _, msg in ipairs(messages) do
            if msg_count >= 5 then
              break
            end -- 最大5メッセージまで

            local role_prefix = ""
            local content_text = ""

            if msg.type == "user" then
              role_prefix = "👤 User: "
              -- ユーザーメッセージのコンテンツ抽出（上記と同じロジック）
              if msg.message and msg.message.content then
                local content = msg.message.content
                if type(content) == "string" then
                  content_text = content
                elseif type(content) == "table" and content[1] then
                  if type(content[1]) == "string" then
                    content_text = content[1]
                  elseif content[1].text then
                    content_text = content[1].text
                  end
                end
              elseif msg.content then
                if type(msg.content) == "string" then
                  content_text = msg.content
                elseif type(msg.content) == "table" and msg.content[1] then
                  if type(msg.content[1]) == "string" then
                    content_text = msg.content[1]
                  elseif msg.content[1].text then
                    content_text = msg.content[1].text
                  end
                end
              end
            elseif msg.type == "assistant" then
              role_prefix = "🤖 Assistant: "
              if msg.message and msg.message.content then
                if type(msg.message.content) == "string" then
                  content_text = msg.message.content
                elseif type(msg.message.content) == "table" and msg.message.content[1] then
                  if type(msg.message.content[1]) == "string" then
                    content_text = msg.message.content[1]
                  elseif msg.message.content[1].text then
                    content_text = msg.message.content[1].text
                  end
                end
              end
            end

            if content_text ~= "" then
              content_text = string.gsub(content_text, "\n", " ")
              content_text = string.gsub(content_text, "%s+", " ")
              content_text = vim.trim(content_text)

              if #content_text > 100 then
                content_text = string.sub(content_text, 1, 100) .. "..."
              end

              if content_text ~= "" then
                table.insert(preview_messages, role_prefix .. content_text)
                msg_count = msg_count + 1
              end
            end
          end

          local preview_text = table.concat(preview_messages, "\n\n")

          table.insert(conversations, {
            session_id = session_id,
            title = title,
            project_path = project_path_decoded or vim.fn.getcwd(),
            created_at = created_at or "",
            message_count = #messages,
            file_path = file_path,
            preview = preview_text,
            messages = messages, -- メッセージ配列も保存
          })
        end
        ::continue::
      end
    end
  end

  -- 作成日時でソート（新しい順）
  table.sort(conversations, function(a, b)
    -- キャッシュされた数値タイムスタンプを使用
    if not a._cached_time then
      a._cached_time = M.parse_timestamp(a.created_at)
        or (function()
          local stat = vim.loop.fs_stat(a.file_path)
          return stat and stat.mtime.sec or 0
        end)()
    end
    if not b._cached_time then
      b._cached_time = M.parse_timestamp(b.created_at)
        or (function()
          local stat = vim.loop.fs_stat(b.file_path)
          return stat and stat.mtime.sec or 0
        end)()
    end
    return a._cached_time > b._cached_time
  end)

  -- 全件取得用キャッシュに保存
  cache.conversations_all = conversations
  cache.last_scan_time_all = current_time

  -- フィルタリングが必要な場合は実行
  if filter_current_dir then
    local current_dir = vim.fn.getcwd()
    local filtered = vim.tbl_filter(function(conv)
      return conv.project_path == current_dir
    end, conversations)
    return filtered
  end

  return conversations
end

return M
