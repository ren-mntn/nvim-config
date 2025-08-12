local M = {}

-- プロジェクトパスの短縮表示
local function format_project_path(path)
  local home = vim.fn.expand("~")
  if path:find(home, 1, true) == 1 then
    return "~" .. path:sub(#home + 1)
  end
  return path
end

-- 日付フォーマット
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

-- 会話サマリーの生成
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

-- アイテムリスト作成のヘルパー関数
local function create_items(conversations, show_view_all)
  local items = { { title = "🆕 新しいセッションを開始", is_new = true } }

  for i, conv in ipairs(conversations) do
    local date_str = format_date(conv.created_at)
    local project_path = format_project_path(conv.project_path)
    local summary = generate_conversation_summary(conv.messages or {})
    local display_title = string.format("%s | %s | %s", date_str, vim.fn.fnamemodify(project_path, ":t"), summary)

    table.insert(items, {
      title = display_title,
      conversation = conv,
      text = summary,
      file = conv.project_path,
      preview = conv.preview,
      messages = conv.messages or {},
      timestamp = conv.created_at or "",
    })
  end

  -- 「全件を見る」ボタンを追加
  if show_view_all then
    table.insert(items, {
      title = "📋 全件を見る",
      is_view_all = true,
    })
  end

  return items
end

-- 「全件を見る」機能付きPicker
function M.show_with_snacks_picker_view_all(
  conversations,
  picker_title,
  start_claude_session,
  start_new_session,
  config,
  view_all_callback
)
  local show_view_all = view_all_callback ~= nil
  local items = create_items(conversations, show_view_all)

  local picker = require("snacks.picker").pick({
    source = "ccresume",
    items = items,
    focus = "list",
    win = {
      list = {
        keys = {
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
    sort = function(a, b)
      if a.is_new and not b.is_new then
        return true
      end
      if not a.is_new and b.is_new then
        return false
      end
      if a.is_new and b.is_new then
        return false
      end
      if a.is_view_all then
        return false -- 「全件を見る」は最後に表示
      end
      if b.is_view_all then
        return true
      end

      local reader = require("ccresume.reader")
      local time_a = reader.parse_timestamp(a.timestamp) or 0
      local time_b = reader.parse_timestamp(b.timestamp) or 0

      return time_a > time_b
    end,
    format = function(item, _)
      if item.is_new then
        return { { "🆕 新しいセッションを開始" } }
      elseif item.is_view_all then
        return { { "📋 全件を見る" } }
      else
        return { { item.title } }
      end
    end,
    preview = function(ctx)
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
      elseif ctx.item.is_view_all then
        local lines = {
          "📋 全件を見る",
          "",
          "すべての会話履歴を読み込んで表示します。",
          "",
          "Enterキーを押して全件モードに切り替えてください。",
        }
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].filetype = "markdown"
      elseif ctx.item.conversation then
        -- プレビュー表示
        local conv = ctx.item.conversation
        local lines = {}

        local duration = 0
        local reader = require("ccresume.reader")
        local start_time = reader.parse_timestamp(conv.created_at)
        if start_time then
          local end_time = os.time()
          duration = math.floor((end_time - start_time) / 60)
        end

        table.insert(lines, string.format("Conversation History (%d messages, %d min)", conv.message_count, duration))
        table.insert(lines, "")
        table.insert(lines, "Session: " .. (conv.session_id:sub(1, 8) or "unknown"))
        table.insert(lines, "Directory: " .. format_project_path(conv.project_path))
        table.insert(lines, "Branch: -")
        table.insert(lines, "")

        -- メッセージ表示（簡略版）
        if conv.messages and #conv.messages > 0 then
          local reverse_order = config and config.preview and config.preview.reverse_order or false
          local start_idx, end_idx, step = 1, #conv.messages, 1
          if reverse_order then
            start_idx, end_idx, step = #conv.messages, 1, -1
          end

          for i = start_idx, end_idx, step do
            local msg = conv.messages[i]
            if msg and msg.timestamp then
              local timestamp = reader.parse_timestamp(msg.timestamp) or 0
              local time_str = timestamp > 0 and os.date("%H:%M:%S", timestamp) or "00:00:00"
              local role = msg.type == "user" and "User" or "Assistant"

              local content_text = ""
              if msg.message and msg.message.content then
                if type(msg.message.content) == "string" then
                  content_text = msg.message.content
                end
              elseif msg.content then
                if type(msg.content) == "string" then
                  content_text = msg.content
                end
              end

              local first_line = content_text:match("([^\n\r]*)")
              if first_line and first_line ~= "" then
                if #first_line > 80 then
                  first_line = first_line:sub(1, 77) .. "..."
                end
                table.insert(lines, string.format("[%s] (%s) %s", role, time_str, first_line))
              end
            end
          end
        else
          table.insert(lines, "No messages found")
        end

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].filetype = "markdown"
      end

      vim.bo[buf].modifiable = false
      vim.bo[buf].readonly = true
      return true
    end,
    confirm = function(picker_instance, item)
      if item.is_new then
        picker_instance:close()
        start_new_session()
      elseif item.is_view_all then
        -- 「全件を見る」が選択された場合
        picker_instance:close()
        if view_all_callback then
          view_all_callback()
        end
      else
        picker_instance:close()
        start_claude_session(item.conversation)
      end
    end,
  })

  return picker
end

-- Snacks.nvim picker用の表示関数
function M.show_with_snacks_picker(conversations, picker_title, start_claude_session, start_new_session, config)
  local items = create_items(conversations)

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
    -- 時系列順でソート
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
      local reader = require("ccresume.reader")
      local time_a = reader.parse_timestamp(a.timestamp) or 0
      local time_b = reader.parse_timestamp(b.timestamp) or 0

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

        -- ヘッダー情報の表示
        local duration = 0
        local reader = require("ccresume.reader")
        local start_time = reader.parse_timestamp(conv.created_at)
        if start_time then
          local end_time = os.time()
          duration = math.floor((end_time - start_time) / 60) -- 分単位
        end

        table.insert(lines, string.format("Conversation History (%d messages, %d min)", conv.message_count, duration))
        table.insert(lines, "")
        table.insert(lines, "Session: " .. (conv.session_id:sub(1, 8) or "unknown"))
        table.insert(lines, "Directory: " .. format_project_path(conv.project_path))
        table.insert(lines, "Branch: -")
        table.insert(lines, "")

        local message_line_data = {}
        if conv.messages and #conv.messages > 0 then
          local displayed_messages = 0

          -- 設定に基づいてメッセージの順序を決定
          local reverse_order = config and config.preview and config.preview.reverse_order or false
          local start_idx, end_idx, step = 1, #conv.messages, 1
          if reverse_order then
            start_idx, end_idx, step = #conv.messages, 1, -1
          end

          for i = start_idx, end_idx, step do
            local msg = conv.messages[i]
            if msg and msg.timestamp then
              local timestamp = reader.parse_timestamp(msg.timestamp) or 0
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

        -- 設定に基づいてスクロール位置を調整
        vim.schedule(function()
          local wins = vim.api.nvim_list_wins()
          for _, win in ipairs(wins) do
            if vim.api.nvim_win_get_buf(win) == buf then
              local reverse_order = config and config.preview and config.preview.reverse_order or false
              if reverse_order then
                -- 新しいメッセージが上にある場合は上部を表示
                vim.api.nvim_win_set_cursor(win, { 1, 0 })
              else
                -- 従来通り最下部を表示
                local line_count = vim.api.nvim_buf_line_count(buf)
                vim.api.nvim_win_set_cursor(win, { line_count, 0 })
              end
              break
            end
          end
        end)

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
