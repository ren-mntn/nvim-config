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

-- メイン機能: 会話選択インターフェース
function M.show_conversations(filter_current_dir)
  local conversations = reader.read_conversations(filter_current_dir)

  local title = filter_current_dir and "Claude Code会話履歴 (現在のディレクトリ)"
    or "Claude Code会話履歴"

  if #conversations == 0 then
    local msg = filter_current_dir and "現在のディレクトリの会話履歴が見つかりません"
      or "会話履歴が見つかりません"
    vim.notify(msg, vim.log.levels.WARN)
    return
  end

  -- Snacks.nvim pickerを使用してccresume風のプレビュー機能を実装
  local ok_snacks, snacks = pcall(require, "snacks.picker")
  if ok_snacks then
    -- Snacks.nvim pickerでの表示
    picker.show_with_snacks_picker(conversations, title, start_claude_session, start_new_session, M.config)
  else
    -- フォールバック: vim.ui.selectでシンプル表示
    show_with_vim_ui_select(conversations)
  end
end

-- 現在のディレクトリのみの会話表示
function M.show_current_dir_conversations()
  M.show_conversations(true)
end

-- デフォルト設定
M.config = {
  preview = {
    reverse_order = false, -- trueで新しいメッセージを上に表示
  }
}

-- プラグイン設定
function M.setup(opts)
  opts = opts or {}
  
  -- 設定をマージ
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  -- デフォルトのキーマッピング設定
  if opts.keys ~= false then
    local mappings = opts.keys or {
      current_dir = "<leader>ch",
      all = "<leader>cH",
    }

    vim.keymap.set("n", mappings.current_dir, M.show_current_dir_conversations, {
      desc = "現在ディレクトリのClaude Code履歴",
    })

    vim.keymap.set("n", mappings.all, M.show_conversations, {
      desc = "Claude Code履歴（全体）",
    })
  end

  -- デフォルトのコマンド設定
  if opts.commands ~= false then
    vim.api.nvim_create_user_command("CCResume", M.show_conversations, {
      desc = "Claude Code会話履歴ブラウザを開く",
    })

    vim.api.nvim_create_user_command("CCResumeHere", M.show_current_dir_conversations, {
      desc = "現在のディレクトリのClaude Code会話履歴を開く",
    })
  end
end

return M
