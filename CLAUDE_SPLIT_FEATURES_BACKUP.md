# Claude分割機能バックアップ

**日付**: 2025-08-13  
**目的**: ClaudeCode.nvimのマルチセッション・分割機能の実装記録

## 📋 実装概要

### 問題
- ClaudeCode.nvimはシングルトン設計で1つのWebSocketサーバーのみ
- 複数パネル = ミラー表示（同じ会話内容）
- tmux風の独立したマルチセッション管理が不可能

### 解決アプローチ
1. **ClaudeCodeパネル**: 統合機能用（ファイル送信・差分表示）
2. **通常CLIターミナル**: 独立会話用（複数作成可能）

## 🗂️ 実装したファイル

### 1. メインキーマップ設定
**ファイル**: `/Users/ren/.config/nvim/lua/plugins/claude-j-keymaps.lua`

```lua
-- ClaudeCode初期化確認ヘルパー関数
local function ensure_claudecode_initialized()
  local claudecode_ok, claudecode = pcall(require, "claudecode")
  if not claudecode_ok then
    vim.notify("ClaudeCode plugin not found", vim.log.levels.ERROR)
    return false
  end
  
  -- 初期化されていない場合は手動で初期化
  if not claudecode.state.initialized then
    local setup_ok = pcall(function()
      claudecode.setup({
        auto_start = false,
        terminal = {
          provider = "snacks",
          split_side = "right",
          split_width_percentage = 0.30,
        },
      })
    end)
    
    if not setup_ok then
      vim.notify("Failed to initialize ClaudeCode", vim.log.levels.ERROR)
      return false
    end
  end
  
  return true
end

return {
  "folke/which-key.nvim",
  event = "VeryLazy",

  opts = function(_, opts)
    -- 安全な初期化
    opts = opts or {}
    opts.spec = opts.spec or {}

    -- 設定のマージ（完全上書きではない）
    local claude_specs = {
      { "<leader>j", group = "Claude AI", desc = "Claude AI Tools" },
    }

    for _, spec in ipairs(claude_specs) do
      table.insert(opts.spec, spec)
    end

    return opts
  end,

  keys = {
    -- ========== Claude ターミナル・チャット ==========
    {
      "<leader>jj",
      function()
        if ensure_claudecode_initialized() then
          vim.cmd("ClaudeCodeOpen")
        end
      end,
      desc = "Open Claude Chat Panel",
    },
    {
      "<leader>jt",
      function()
        pcall(function()
          vim.cmd("terminal claude")
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
        end)
      end,
      desc = "New Claude CLI Terminal",
    },
    {
      "<leader>jT",
      function()
        pcall(function()
          vim.cmd("vsplit | terminal claude")
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
        end)
      end,
      desc = "New Claude CLI Terminal (Vertical Split)",
    },
    {
      "<leader>jv",
      function()
        if ensure_claudecode_initialized() then
          vim.cmd("vsplit")
          vim.cmd("ClaudeCodeOpen")
        end
      end,
      desc = "ClaudeCode Panel (Vertical Split)",
    },
    {
      "<leader>jh",
      function()
        if ensure_claudecode_initialized() then
          vim.cmd("split")
          vim.cmd("ClaudeCodeOpen")
        end
      end,
      desc = "ClaudeCode Panel (Horizontal Split)",
    },

    -- ========== セッション管理 ==========
    {
      "<leader>jl",
      function()
        pcall(function()
          vim.cmd("ClaudeSessions")
        end)
      end,
      desc = "Sessions List",
    },
    {
      "<leader>jn",
      function()
        -- 新しいClaude会話セッションを開始
        pcall(function()
          vim.cmd("tabnew")
          vim.cmd("terminal claude")
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
        end)
      end,
      desc = "New Claude Session (New Tab)",
    },

    -- ========== Claude Core Operations ==========
    {
      "<leader>jf",
      "<cmd>ClaudeCodeFocus<cr>",
      desc = "Focus/Toggle Claude (Smart)",
    },
    {
      "<leader>js",
      function()
        if ensure_claudecode_initialized() then
          vim.cmd("ClaudeCodeStart")
        end
      end,
      desc = "Start Claude Integration",
    },
    {
      "<leader>jS",
      "<cmd>ClaudeCodeStop<cr>",
      desc = "Stop Claude Integration",
    },
    {
      "<leader>ji",
      "<cmd>ClaudeCodeStatus<cr>",
      desc = "Show Claude Status",
    },
    {
      "<leader>jM",
      "<cmd>ClaudeCodeSelectModel<cr>",
      desc = "Select Claude Model",
    },

    -- ========== File & Context Operations ==========
    {
      "<leader>ja",
      "<cmd>ClaudeCodeAdd %<cr>",
      desc = "Add Current File to Context",
    },
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
    {
      "<leader>jy",
      "<cmd>ClaudeCodeDiffAccept<cr>",
      desc = "Accept Diff (Yes)",
    },
    {
      "<leader>jn",
      "<cmd>ClaudeCodeDiffDeny<cr>",
      desc = "Deny Diff (No)",
    },
  },
}
```

### 2. プラグイン設定
**ファイル**: `/Users/ren/.config/nvim/lua/plugins/claude.lua`

```lua
return {
  "coder/claudecode.nvim",
  branch = "main",
  lazy = false,
  priority = 1000,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },

  config = function()
    local ok, claudecode = pcall(require, "claudecode")
    if not ok then
      vim.notify("ClaudeCode plugin not found", vim.log.levels.ERROR)
      return
    end

    claudecode.setup({
      -- 手動起動で安全な初期化
      auto_start = false,

      -- ターミナル設定
      terminal = {
        split_side = "right",
        split_width_percentage = 0.30,
        provider = "snacks",
        snacks_win_opts = {
          position = "right",
          width = 0.4,
          height = 1.0,
          border = "rounded",
          backdrop = 0,
          wo = {
            winhighlight = "Normal:ClaudeCodeBackground,FloatBorder:ClaudeCodeBorder",
          },
        },
      },

      chat = {
        keymaps = {
          send = "<CR>",
          new_line = "<C-j>",
        },
      },
    })

    -- カスタムハイライトグループの定義
    local colors = require("config.colors")
    vim.api.nvim_set_hl(0, "ClaudeCodeBackground", {
      bg = colors.colors.background,
      fg = colors.colors.white,
    })

    vim.api.nvim_set_hl(0, "ClaudeCodeBorder", {
      bg = colors.colors.background,
      fg = "#666666",
    })

    -- 他の設定（省略）...
  end,
}
```

### 3. ビジュアルモード設定
**ファイル**: `/Users/ren/.config/nvim/lua/plugins/claude-visual-keymaps.lua`

```lua
return {
  "coder/claudecode.nvim",
  config = function()
    vim.keymap.set("v", "<leader>jc", "<cmd>ClaudeCodeSend<cr>", { desc = "Send Selection to Claude" })
    vim.keymap.set("x", "<leader>jc", "<cmd>ClaudeCodeSend<cr>", { desc = "Send Selection to Claude" })
  end,
}
```

## 🎯 キーマップ一覧

### 統合機能
- `<leader>jj`: ClaudeCodeパネルを開く（統合機能）
- `<leader>jv`: ClaudeCodeパネル（垂直分割）
- `<leader>jh`: ClaudeCodeパネル（水平分割）
- `<leader>js`: ClaudeCode統合開始
- `<leader>jS`: ClaudeCode統合停止

### 独立会話
- `<leader>jt`: 新しいClaude CLIターミナル
- `<leader>jT`: 新しいClaude CLIターミナル（垂直分割）
- `<leader>jn`: 新しいClaude会話（新タブ）

### ファイル・コンテキスト
- `<leader>ja`: 現在のファイルをコンテキストに追加
- `<leader>jA`: ファイル選択してコンテキストに追加
- `<leader>jc`: 選択範囲をClaudeに送信（ビジュアルモード）

## 🔧 技術的実装

### 初期化確認ヘルパー
プラグインが初期化されていない場合の自動初期化機能:

```lua
local function ensure_claudecode_initialized()
  local claudecode_ok, claudecode = pcall(require, "claudecode")
  if not claudecode_ok then
    return false
  end
  
  if not claudecode.state.initialized then
    local setup_ok = pcall(function()
      claudecode.setup({
        auto_start = false,
        terminal = { provider = "snacks" }
      })
    end)
    return setup_ok
  end
  
  return true
end
```

### エラーハンドリング
すべてのコマンド実行に`pcall`を使用してエラー時の安全性を確保。

## 📊 学んだ教訓

### ClaudeCode.nvimの設計制約
1. **WebSocketサーバー**: 1ポート = 1Claude接続
2. **ターミナルプロバイダー**: 全てシングルトン設計
3. **統合機能**: 1セッション前提でファイル送信・差分管理

### 最適解
```
ClaudeCodeパネル（統合）: ファイル送信・差分表示
        +
通常CLIターミナル（独立）: 複数の独立した会話
```

## 🚀 将来の改善案

### マルチセッション化するには
1. **WebSocketサーバーの複数起動**: ポート管理機能
2. **ターミナルプロバイダーの配列化**: シングルトン → 配列管理
3. **セッション管理UI**: tmux風のセッション切り替え
4. **ファイルコンテキストの分離**: セッション別のファイル管理

### 推定工数
- **設計変更**: 3-5日
- **実装**: 1-2週間
- **テスト**: 3-5日

## 📝 削除予定ファイル一覧

- `lua/plugins/claude-j-keymaps.lua`
- `lua/plugins/claude-visual-keymaps.lua`
- `DEBUGGING_GUIDE.md`
- `lua/plugins/claude-keymaps-fix.lua.bak`
- `lua/plugins/claude-sessions-simple.lua.bak`
- `lua/plugins/claude-split.lua.bak`

**このバックアップファイルから、将来必要に応じて機能を復元できます。**