local M = {}

-- プロジェクトパスの短縮表示（ccresume形式）
local function format_project_path(path)
  local home = vim.fn.expand("~")
  if path:find(home, 1, true) == 1 then
    return "~" .. path:sub(#home + 1)
  end
  return path
end

-- 日付フォーマット（ccresume形式：MMM dd HH:mm）
local function format_date(timestamp)
  if not timestamp or timestamp == "" then
    return "Jan 01 00:00"
  end

  local time_num = 0
  if type(timestamp) == "string" then
    -- ISO 8601形式をパース
    local year, month, day, hour, min, sec = timestamp:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if year then
      time_num = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec),
      })
    end
  else
    time_num = tonumber(timestamp) or 0
  end

  if time_num > 0 then
    return os.date("%b %d %H:%M", time_num)
  else
    return "Jan 01 00:00"
  end
end

-- 会話サマリーの生成（ccresumeと同じロジック）
local function generate_conversation_summary(messages)
  -- ユーザーメッセージで実際のテキストコンテンツがあるものを抽出
  local user_messages = {}
  for _, msg in ipairs(messages) do
    if msg.type == "user" then
      local content_text = ""

      -- メッセージコンテンツを抽出
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

      -- ツール結果メッセージをスキップ
      if not content_text:match("^%[Tool Result%]") and not content_text:match("^%[Tool Output%]") then
        local trimmed = vim.trim(content_text)
        if trimmed ~= "" then
          table.insert(user_messages, trimmed)
        end
      end
    end
  end

  if #user_messages == 0 then
    return "No user messages"
  end

  -- 最初の意味のあるユーザーメッセージを取得
  local first_message = user_messages[1]

  -- メッセージをクリーンアップ
  local cleaned_message = first_message
    :gsub("[\r\n]+", " ") -- 改行を空白に
    :gsub("<[^>]*>", "") -- HTMLタグ除去
    :gsub("%s+", " ") -- 複数空白を単一空白に
    :gsub("[`'\"]", "") -- クォート除去
    :gsub("^%[.*?%]%s*", "") -- [Tool: xxx] プレフィックス除去

  cleaned_message = vim.trim(cleaned_message)

  -- 空の場合は次のメッセージを試す
  if cleaned_message == "" and #user_messages > 1 then
    local second_message = user_messages[2]
    cleaned_message = second_message
      :gsub("[\r\n]+", " ")
      :gsub("<[^>]*>", "")
      :gsub("%s+", " ")
      :gsub("[`'\"]", "")
      :gsub("^%[.*?%]%s*", "")
    cleaned_message = vim.trim(cleaned_message)
  end

  return cleaned_message ~= "" and cleaned_message or "No summary available"
end

-- Snacks.nvim picker用の表示関数
function M.show_with_snacks_picker(conversations, picker_title, start_claude_session, start_new_session)
  -- 新しいセッションオプションを含むアイテム作成
  local items = { { title = "🆕 新しいセッションを開始", is_new = true } }

  for i, conv in ipairs(conversations) do
    -- ccresumeと同じ形式で表示文字列を生成
    local date_str = format_date(conv.created_at)
    local project_path = format_project_path(conv.project_path)
    local summary = generate_conversation_summary(conv.messages or {})
    local display_title = string.format("%s | %s | %s", date_str, vim.fn.fnamemodify(project_path, ":t"), summary)

    table.insert(items, {
      title = display_title,
      conversation = conv,
      text = summary, -- picker検索用
      file = conv.project_path, -- ディレクトリ表示用
      preview = conv.preview, -- プレビュー内容
      messages = conv.messages or {}, -- メッセージ配列
      timestamp = conv.created_at or "", -- ソート用
    })
  end

  local picker = require("snacks.picker").pick({
    source = "ccresume",
    items = items,
    -- リストに初期フォーカスを設定（検索フォームではなく）
    focus = "list",
    win = {
      list = {
        keys = {
          -- リストからでも検索フォームに移動できるようにする
          ["/"] = { "focus_input", mode = { "n" } },
          ["i"] = { "focus_input", mode = { "n" } },
        },
      },
      input = {
        title = picker_title or "Claude Code会話履歴",
      },
      preview = {
        title = "会話プレビュー",
      },
    },
    -- 最新が上に来るようにソート
    sort = function(a, b)
      -- 新しいセッションは常に一番上
      if a.is_new and not b.is_new then
        return true
      end
      if not a.is_new and b.is_new then
        return false
      end
      if a.is_new and b.is_new then
        return false
      end

      -- タイムスタンプで比較（新しい方が上）
      local time_a = 0
      local time_b = 0

      if a.timestamp and a.timestamp ~= "" then
        if type(a.timestamp) == "string" then
          local year, month, day, hour, min, sec = a.timestamp:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
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
          time_a = tonumber(a.timestamp) or 0
        end
      end

      if b.timestamp and b.timestamp ~= "" then
        if type(b.timestamp) == "string" then
          local year, month, day, hour, min, sec = b.timestamp:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
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
          time_b = tonumber(b.timestamp) or 0
        end
      end

      return time_a > time_b -- 新しい方が上
    end,
    format = function(item, _)
      if item.is_new then
        return { { "🆕 新しいセッションを開始" } }
      else
        return { { item.title } }
      end
    end,
    preview = function(ctx)
      -- バッファを変更可能に設定
      local buf = ctx.buf
      vim.bo[buf].modifiable = true
      vim.bo[buf].readonly = false

      if ctx.item.is_new then
        local lines = {
          "🚀 新しいClaude Codeセッションを開始",
          "",
          "現在のディレクトリ: " .. vim.fn.getcwd(),
          "",
          "新しい会話を始めます。",
        }
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].filetype = "markdown"
      elseif ctx.item.conversation then
        local conv = ctx.item.conversation
        local lines = {}

        -- ccresumeと同じヘッダー形式
        local duration = 0
        if conv.created_at and conv.created_at ~= "" then
          local end_time = os.time() -- 現在時刻を終了時刻とする
          local start_time = 0

          if type(conv.created_at) == "string" then
            local year, month, day, hour, min, sec = conv.created_at:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
            if year then
              start_time = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec),
              })
            end
          else
            start_time = tonumber(conv.created_at) or 0
          end

          if start_time > 0 then
            duration = math.floor((end_time - start_time) / 60) -- 分単位
          end
        end

        table.insert(lines, string.format("Conversation History (%d messages, %d min)", conv.message_count, duration))
        table.insert(lines, "")
        table.insert(lines, "Session: " .. (conv.session_id:sub(1, 8) or "unknown"))
        table.insert(lines, "Directory: " .. format_project_path(conv.project_path))
        table.insert(lines, "Branch: -") -- ブランチ情報は後で実装
        table.insert(lines, "")

        -- メッセージ履歴をccresume形式で表示
        local message_line_data = {} -- 色付けのための行情報を保存
        if conv.messages and #conv.messages > 0 then
          local displayed_messages = 0
          local max_messages = 10 -- 最大表示メッセージ数

          for i = math.max(1, #conv.messages - max_messages + 1), #conv.messages do
            local msg = conv.messages[i]
            if msg and msg.timestamp then
              local timestamp = 0
              if type(msg.timestamp) == "string" then
                local year, month, day, hour, min, sec = msg.timestamp:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
                if year then
                  timestamp = os.time({
                    year = tonumber(year),
                    month = tonumber(month),
                    day = tonumber(day),
                    hour = tonumber(hour),
                    min = tonumber(min),
                    sec = tonumber(sec),
                  })
                end
              else
                timestamp = tonumber(msg.timestamp) or 0
              end

              local time_str = timestamp > 0 and os.date("%H:%M:%S", timestamp) or "00:00:00"
              local role = msg.type == "user" and "User" or "Assistant"

              -- メッセージコンテンツを抽出
              local content_text = ""
              local is_tool_message = false
              if msg.message and msg.message.content then
                local content = msg.message.content
                if type(content) == "string" then
                  content_text = content
                elseif type(content) == "table" then
                  for _, item in ipairs(content) do
                    if type(item) == "string" then
                      content_text = item
                      break
                    elseif type(item) == "table" then
                      if item.type == "text" and item.text then
                        content_text = item.text
                        break
                      elseif item.type == "tool_use" and item.name then
                        content_text = string.format("[Tool: %s]", item.name)
                        is_tool_message = true
                        break
                      elseif item.type == "thinking" then
                        content_text = "[Thinking...]"
                        break
                      end
                    end
                  end
                end
              elseif msg.content then
                if type(msg.content) == "string" then
                  content_text = msg.content
                end
              end

              -- 最初の行のみを表示
              local first_line = content_text:match("([^\n\r]*)")
              if first_line and first_line ~= "" then
                -- 最大80文字に制限
                if #first_line > 80 then
                  first_line = first_line:sub(1, 77) .. "..."
                end

                local line_content = string.format("[%s] (%s) %s", role, time_str, first_line)
                table.insert(lines, line_content)

                -- 色付けのための情報を保存
                table.insert(message_line_data, {
                  line = #lines - 1, -- 0ベース行番号（現在追加した行）
                  role = role,
                  is_tool = is_tool_message or content_text:match("^%[Tool"),
                  role_end = string.len(string.format("[%s] (%s)", role, time_str)),
                })

                displayed_messages = displayed_messages + 1
              end
            end
          end

          if displayed_messages == 0 then
            table.insert(lines, "No message content available")
          end
        else
          table.insert(lines, "No messages found")
        end

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].filetype = "markdown"

        -- メッセージの色付け（行全体）
        for _, msg_data in ipairs(message_line_data) do
          local line_num = msg_data.line
          -- 行番号が有効範囲内にあることを確認
          if line_num >= 0 and line_num < #lines then
            local line_content = lines[line_num + 1] -- linesは1ベース

            if msg_data.role == "User" then
              -- User行全体を水色に
              vim.api.nvim_buf_add_highlight(buf, -1, "DiagnosticInfo", line_num, 0, -1)
            else
              -- Assistant行の色分け
              if msg_data.is_tool then
                -- ツールメッセージ行全体を橙色に
                vim.api.nvim_buf_add_highlight(buf, -1, "DiagnosticWarn", line_num, 0, -1)
              end
              -- 通常のAssistantメッセージは白色（デフォルト）なのでハイライトなし
            end
          end
        end
      end

      -- バッファを読み取り専用に戻す
      vim.bo[buf].modifiable = false
      vim.bo[buf].readonly = true

      return true
    end,
    confirm = function(picker_instance, item)
      picker_instance:close()
      if item.is_new then
        start_new_session()
      else
        start_claude_session(item.conversation)
      end
    end,
  })

  return picker
end

return M
