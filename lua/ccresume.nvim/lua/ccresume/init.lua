local M = {}

local reader = require("ccresume.reader")
local picker = require("ccresume.picker")

-- 選択された会話でClaudeCode.nvimを開始
local function start_claude_session(conversation)
  -- 現在のディレクトリを変更
  vim.cmd("cd " .. vim.fn.fnameescape(conversation.project_path))

  -- ClaudeCode.nvimの推奨アプローチ: terminal_cmdを動的に設定
  local ok_claudecode, claudecode = pcall(require, "claudecode")
  if ok_claudecode then
    -- 現在の設定を保存
    local original_config = vim.deepcopy(claudecode.config or {})

    -- resumeコマンドで一時的に設定を更新
    claudecode.setup(vim.tbl_deep_extend("force", original_config, {
      terminal_cmd = string.format("claude --resume %s", vim.fn.shellescape(conversation.session_id)),
    }))

    -- ClaudeCodeを起動
    vim.cmd("ClaudeCode")

    -- 元の設定に戻す（遅延実行で確実に復元）
    vim.defer_fn(function()
      claudecode.setup(original_config)
    end, 500)

    vim.notify(string.format("📖 会話を再開: %s", conversation.title), vim.log.levels.INFO)
  else
    -- フォールバック: 直接ターミナルでclaudeコマンドを実行
    local cmd = string.format("claude --resume %s", vim.fn.shellescape(conversation.session_id))
    local ok_snacks = pcall(require, "snacks.terminal")
    if ok_snacks then
      require("snacks.terminal").open(cmd, {
        win = { position = "right", width = 0.4 },
      })
    else
      vim.cmd("terminal " .. cmd)
    end
    vim.notify("⚠️ ClaudeCode.nvim未使用 - 通常のターミナルで実行", vim.log.levels.WARN)
  end
end

-- 新しいセッションを開始
local function start_new_session(project_path)
  project_path = project_path or vim.fn.getcwd()

  -- 現在のディレクトリを変更
  vim.cmd("cd " .. vim.fn.fnameescape(project_path))

  -- ClaudeCode.nvimで新しいセッションを開始
  local ok_claudecode = pcall(require, "claudecode")
  if ok_claudecode then
    -- 新しいセッションの場合は通常通りClaudeCodeを起動
    vim.cmd("ClaudeCode")
    vim.notify(
      string.format("🚀 新しいセッション開始: %s", vim.fn.fnamemodify(project_path, ":t")),
      vim.log.levels.INFO
    )
  else
    -- フォールバック
    local ok_snacks = pcall(require, "snacks.terminal")
    if ok_snacks then
      require("snacks.terminal").open("claude", {
        win = { position = "right", width = 0.4 },
        cwd = project_path,
      })
    else
      vim.cmd("terminal claude")
    end
    vim.notify("⚠️ ClaudeCode.nvim未使用 - 通常のターミナルで実行", vim.log.levels.WARN)
  end
end

-- vim.ui.select用のフォールバック関数
local function show_with_vim_ui_select(conversations)
  -- 新しいセッション開始オプションを最初に追加
  local items = { "[N] 新しいセッションを開始" }

  -- 選択肢の準備（番号を1から開始）
  for i, conv in ipairs(conversations) do
    local display_text = string.format(
      "[%d] %s (%d msgs) - %s",
      i,
      conv.title,
      conv.message_count,
      vim.fn.fnamemodify(conv.project_path, ":t")
    )
    table.insert(items, display_text)
  end

  -- vim.ui.selectを使用して選択インターフェースを表示
  vim.ui.select(items, {
    prompt = "Claude Code会話を選択:",
    format_item = function(item)
      return item
    end,
  }, function(choice, idx)
    if not choice then
      return -- キャンセル
    end

    if idx == 1 then
      -- 新しいセッション開始
      start_new_session()
    else
      -- 既存の会話を再開（idx-1が実際の会話インデックス）
      local conv_idx = idx - 1
      local selected_conv = conversations[conv_idx]
      if selected_conv then
        start_claude_session(selected_conv)
      else
        vim.notify("選択された会話が見つかりません", vim.log.levels.ERROR)
      end
    end
  end)
end

-- 直近モード: 最新N件のみ取得（もっと見る機能付き）
function M.show_conversations_recent(filter_current_dir, limit)
  limit = limit or (M.config.performance and M.config.performance.recent_limit or 30)

  local title = filter_current_dir
      and string.format("Claude Code会話履歴 (現在のディレクトリ) - 直近%d件", limit)
    or string.format("Claude Code会話履歴 - 直近%d件", limit)

  local current_conversations = reader.read_recent_conversations(filter_current_dir, limit)

  if #current_conversations == 0 then
    local msg = filter_current_dir and "現在のディレクトリの会話履歴が見つかりません"
      or "会話履歴が見つかりません"
    vim.notify(msg, vim.log.levels.WARN)
    return
  end

  local ok_snacks = pcall(require, "snacks.picker")
  if ok_snacks then
    -- 「全件を見る」コールバック
    local view_all_callback = function()
      -- 現在のモードに応じて全件モードに切り替え
      if filter_current_dir then
        M.show_conversations_all(true) -- 現在ディレクトリの全件
      else
        M.show_conversations_all(false) -- 全体の全件
      end
    end

    picker.show_with_snacks_picker_view_all(
      current_conversations,
      title,
      start_claude_session,
      start_new_session,
      M.config,
      view_all_callback
    )
  else
    show_with_vim_ui_select(current_conversations)
  end
end

-- 全件モード: 全データを読み込んでから表示
function M.show_conversations_all(filter_current_dir)
  local title = filter_current_dir and "Claude Code会話履歴 (現在のディレクトリ) - 全件"
    or "Claude Code会話履歴 - 全件"

  local conversations = reader.read_conversations(filter_current_dir)

  if #conversations == 0 then
    local msg = filter_current_dir and "現在のディレクトリの会話履歴が見つかりません"
      or "会話履歴が見つかりません"
    vim.notify(msg, vim.log.levels.WARN)
    return
  end

  local ok_snacks = pcall(require, "snacks.picker")
  if ok_snacks then
    picker.show_with_snacks_picker(conversations, title, start_claude_session, start_new_session, M.config)
  else
    show_with_vim_ui_select(conversations)
  end
end

-- 後方互換性のため残す（デフォルトは直近モード）
function M.show_conversations(filter_current_dir)
  M.show_conversations_recent(filter_current_dir)
end

-- 現在のディレクトリのみの会話表示（直近）
function M.show_current_dir_conversations()
  M.show_conversations_recent(true)
end

-- 現在のディレクトリのみの会話表示（全件）
function M.show_current_dir_conversations_all()
  M.show_conversations_all(true)
end

-- デフォルト設定
M.config = {
  preview = {
    reverse_order = false, -- 新しいメッセージを上に表示するか
  },
  performance = {
    recent_limit = 30, -- 直近モードでの初期取得件数
  },
}

-- プラグイン設定
function M.setup(opts)
  opts = opts or {}

  -- 設定をマージ
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  -- デフォルトのキーマッピング設定
  if opts.keys ~= false then
    local mappings = opts.keys
      or {
        current_dir = "<leader>jr", -- 現在ディレクトリ（直近）
        current_dir_all = "<leader>jR", -- 現在ディレクトリ（全件）
        all = "<leader>j/", -- 全体（直近）
        all_all = "<leader>j?", -- 全体（全件）
      }

    vim.keymap.set("n", mappings.current_dir, M.show_current_dir_conversations, {
      desc = "現在ディレクトリのClaude Code履歴（直近）",
    })

    vim.keymap.set("n", mappings.current_dir_all, M.show_current_dir_conversations_all, {
      desc = "現在ディレクトリのClaude Code履歴（全件）",
    })

    vim.keymap.set("n", mappings.all, M.show_conversations, {
      desc = "Claude Code履歴（直近）",
    })

    vim.keymap.set("n", mappings.all_all, M.show_conversations_all, {
      desc = "Claude Code履歴（全件）",
    })
  end

  -- デフォルトのコマンド設定
  if opts.commands ~= false then
    vim.api.nvim_create_user_command("CCResume", M.show_conversations, {
      desc = "Claude Code会話履歴ブラウザを開く（直近）",
    })

    vim.api.nvim_create_user_command("CCResumeAll", M.show_conversations_all, {
      desc = "Claude Code会話履歴ブラウザを開く（全件）",
    })

    vim.api.nvim_create_user_command("CCResumeHere", M.show_current_dir_conversations, {
      desc = "現在のディレクトリのClaude Code会話履歴を開く（直近）",
    })

    vim.api.nvim_create_user_command("CCResumeHereAll", M.show_current_dir_conversations_all, {
      desc = "現在のディレクトリのClaude Code会話履歴を開く（全件）",
    })
  end
end

return M
