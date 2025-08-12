local M = {}

-- Claude Code設定ディレクトリの検出
local function get_claude_config_dir()
  -- ClaudeCode.nvimのlockfileから設定ディレクトリを検出
  local ide_dir = vim.fn.expand("~/.claude/ide")
  if vim.fn.isdirectory(ide_dir) == 1 then
    -- lockfileから実際のworkspaceFoldersを読み取る
    local lockfiles = vim.fn.glob(ide_dir .. "/*.lock", false, true)
    if #lockfiles > 0 then
      -- 最初のlockfileから情報を取得
      local ok, content = pcall(vim.fn.readfile, lockfiles[1])
      if ok and content then
        local json_str = table.concat(content, "\n")
        local success, data = pcall(vim.json.decode, json_str)
        if success and data and data.workspaceFolders and #data.workspaceFolders > 0 then
          -- workspaceFoldersの最初のパスを使用
          local workspace = data.workspaceFolders[1]
          -- .claudeディレクトリを探す
          local claude_dir = workspace .. "/.claude"
          if vim.fn.isdirectory(claude_dir) == 1 then
            return claude_dir
          end
        end
      end
    end
  end

  -- フォールバック: 標準的な場所をチェック
  local config_dirs = {
    vim.env.CLAUDE_CONFIG_DIR,
    vim.fn.expand("~/.claude"),
    vim.fn.expand("~/.config/claude"),
    vim.fn.getcwd() .. "/.claude", -- カレントディレクトリも確認
  }

  for _, dir in ipairs(config_dirs) do
    if dir and vim.fn.isdirectory(dir) == 1 then
      return dir
    end
  end

  return nil
end

-- 会話データの読み取り
function M.read_conversations(filter_current_dir)
  -- ccresumeと同じディレクトリ構造を使用: ~/.claude/projects/
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
      local ok, lines = pcall(vim.fn.readfile, file_path)
      if ok and lines and #lines > 0 then
        local messages = {}
        local session_id = vim.fn.fnamemodify(file_path, ":t:r")
        local created_at = nil
        local project_path_decoded = nil

        -- 各行をパース
        for _, line in ipairs(lines) do
          local success, msg = pcall(vim.json.decode, line)
          if success and msg then
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
    local time_a = 0
    local time_b = 0

    -- created_atを数値に変換（ISO形式の場合は変換、数値の場合はそのまま）
    if a.created_at and a.created_at ~= "" then
      if type(a.created_at) == "string" then
        -- ISO 8601形式のタイムスタンプを秒に変換
        local year, month, day, hour, min, sec = a.created_at:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
        if year then
          time_a = os.time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour),
            min = tonumber(min),
            sec = tonumber(sec),
          })
        end
      else
        time_a = tonumber(a.created_at) or 0
      end
    end

    if b.created_at and b.created_at ~= "" then
      if type(b.created_at) == "string" then
        local year, month, day, hour, min, sec = b.created_at:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
        if year then
          time_b = os.time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour),
            min = tonumber(min),
            sec = tonumber(sec),
          })
        end
      else
        time_b = tonumber(b.created_at) or 0
      end
    end

    -- タイムスタンプが取得できない場合はファイル更新時刻を使用
    if time_a == 0 then
      local stat_a = vim.loop.fs_stat(a.file_path)
      time_a = stat_a and stat_a.mtime.sec or 0
    end
    if time_b == 0 then
      local stat_b = vim.loop.fs_stat(b.file_path)
      time_b = stat_b and stat_b.mtime.sec or 0
    end

    return time_a > time_b
  end)

  return conversations
end

return M
