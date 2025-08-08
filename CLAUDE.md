# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🤖 Claude Code専用管理システム

このNeovim設定は**完全Claude Code管理**です。以下の手順とツールを必ず使用してください。

### 必須：変更前チェック
```bash
# 現在状態をバックアップ
git stash push -m "backup_$(date +%Y%m%d_%H%M%S)"
```

### 必須：変更後検証
```bash
# 基本動作確認
nvim --headless -c "lua print('OK')" -c "qall"
```

### 緊急復旧コマンド
問題が発生した場合は即座に実行：
```bash
git stash apply  # 最新バックアップから復旧
```

## Task Tracking

今後実装予定の機能や改善点については `tasks/list.md` を参照してください。
タスクの対応を開始する際は以下の手順に従ってください：

1. `tasks/list.md` から対応するタスクの `taskNo` を確認
2. `tasks/TASK-{taskNo}.md` ファイルを作成
3. 調査・実装・テストの過程を都度記録
4. 完了後、`tasks/list.md` のチェックマークを `[x]` に更新

**記録すべき内容:**
- 要件分析と設計内容
- 実装方針とアプローチ
- 関連する設定やプラグイン
- テスト内容と結果
- 完成した機能の使用方法

## Bug Tracking

発生したバグや問題点については `bugs/list.md` を参照してください。
問題が修正されたら該当項目のチェックマークを `[x]` に更新してください。

### バグ管理システム

各バグには一意の `issueNo` が割り当てられています。
バグの対応を開始する際は以下の手順に従ってください：

1. `bugs/list.md` から対応するバグの `issueNo` を確認
2. `bugs/BUG-{issueNo}.md` ファイルを作成
3. 調査・修正・テストの過程を都度記録
4. 修正完了後、`bugs/list.md` のチェックマークを `[x]` に更新

**記録すべき内容:**
- 調査内容と発見事項
- 試した修正方法とその結果
- 依存関係や関連する設定
- テスト結果
- 最終的な解決方法

この方式により、バグの対応履歴を保持し、類似問題への対応や設定変更の影響を追跡できます。

## Configuration Architecture

This is a **LazyVim-based** Neovim configuration with Japanese language support. The configuration follows LazyVim's modular architecture:

- `init.lua` - Entry point that bootstraps lazy.nvim
- `lua/config/` - Core configuration files that extend LazyVim defaults:
  - `lazy.lua` - Plugin manager setup with TypeScript, Python, Docker language extras
  - `options.lua` - Japanese locale settings and startup behavior
  - `keymaps.lua` - Custom keybindings for navigation and terminal management
  - `autocmds.lua` - Disabled LazyVim's spell checking
- `lua/plugins/` - Plugin-specific configurations that override or extend LazyVim defaults

## Key Configuration Details

### Language and Locale
- **Japanese language support** enabled with `helplang = { "ja", "en" }` and `language messages ja_JP.UTF-8`
- Spell checking is **globally disabled** for all file types
- LazyVim's markdown spell checking is explicitly removed

### Plugin Management
- Uses **lazy.nvim** with LazyVim as base
- LuaRocks support is **disabled** (`rocks.enabled = false`)
- Automatic plugin update checking enabled but notifications disabled
- Performance optimizations: several default vim plugins disabled (gzip, tarPlugin, etc.)

### Terminal Integration (ToggleTerm)
- Default terminal opens in **vertical split** (80 columns width)
- Custom terminal functions for lazygit, python3, node, and htop
- Comprehensive keybinding scheme under `<leader>t*` prefix
- Terminal-specific keymaps: `<Esc>` for normal mode, numbered terminal access

### Claude Code Integration
- Plugin: `coder/claudecode.nvim` 
- Keybindings under `<leader>c*` prefix:
  - `<leader>cc` - Start chat
  - `<leader>cr` - Reset chat
  - `<leader>ca` - Ask about visual selection (visual mode)
  - `<leader>ca`/`<leader>cd` - Accept/deny diffs

### Custom Keybindings
- **Neo-tree toggle**: `<Leader>e`
- **Buffer navigation**: `<C-PageDown>`/`<C-PageUp>` (next/previous)
- **Buffer close**: `<F15>` (mapped from iTerm2)
- **Live grep**: `<F16>` maps to `<leader>/` (iTerm2 integration)
- **Terminal toggle**: `<C-`>` and `<leader>tt`

### Keyball User Configuration Notes
The user uses **Keyball** (advanced keyboard with trackball and many thumb keys), enabling extensive shortcut key usage and seamless mouse operations.

#### Keyboard Features
1. **Feel free to suggest complex key combinations**
   - Multi-modifier combinations (e.g., `<C-S-A-key>`)
   - Function keys with modifiers
   - Extensive use of Leader key combinations

2. **Layer-friendly suggestions**
   - Thumb cluster keys are easily accessible
   - Can utilize more aggressive keybinding schemes
   - No need to limit to simple/ergonomic defaults

3. **Keybinding Strategy**
   - Group related functions under consistent prefixes
   - Use mnemonic key choices liberally
   - Can assign shortcuts to less frequently used features

#### Mouse Integration Features
Since Keyball provides seamless mouse control:

1. **Click-based Context Switching**
   - Clicking on different areas should optimize the interface
   - Window focus should trigger appropriate mode changes
   - Consider implementing smart click zones

2. **Suggested Mouse Enhancements**
   ```lua
   -- Enable mouse support
   vim.opt.mouse = "a"
   
   -- Example: Click on Neo-tree to focus and expand
   -- Example: Click on terminal to auto-enter insert mode
   -- Example: Click on split borders to resize
   ```

3. **Hybrid Operations**
   - Design for keyboard-mouse combination workflows
   - Quick mouse positioning + keyboard commands
   - Gesture-like operations with modifier keys

## Claude Code必須操作コマンド

### 🔧 変更前の必須準備
```bash
# バックアップ作成
git stash push -m "backup_$(date +%Y%m%d_%H%M%S)"
```

### ⚡ 変更後の必須検証
```bash
# 基本動作確認
nvim --headless -c "lua print('OK')" -c "qall"
```

### 🚨 緊急復旧
```bash
# 問題発生時は即座に実行
git stash apply
```

### 📊 日常メンテナンス
```bash
# プラグイン更新（手動実行推奨）
nvim -c "Lazy update" -c "qa"
```

### 🎯 ターミナル操作
- 複数ターミナル: `<leader>t1-t4`
- LazyGit: `<leader>tg` 
- Python REPL: `<leader>tp`
- Node REPL: `<leader>tn`

## File Structure Patterns

- **Plugin configurations** in `lua/plugins/*.lua` follow lazy.nvim spec format
- Each plugin file returns a table with plugin specification
- Custom keybindings defined in `keys` section of plugin specs
- Configuration in `config` function with `setup()` calls

## Japanese-Specific Features

- Help system prioritizes Japanese documentation
- UI messages displayed in Japanese
- Neo-tree opens automatically on startup when no files specified
- Spell checking completely disabled to avoid conflicts with Japanese text

## Plugin Configuration Standards

### Unified Configuration Pattern

All plugin configurations in `lua/plugins/` follow these patterns for consistency and performance:

1. **Basic Pattern with `opts`** (Preferred for simple configs):
```lua
return {
  "plugin/name",
  opts = {
    -- configuration options
  },
}
```

2. **Pattern with `opts` function** (For extending LazyVim defaults):
```lua
return {
  "plugin/name",
  opts = function(_, opts)
    -- modify opts
    return opts
  end,
}
```

3. **Pattern with `config` function** (Only when complex setup needed):
```lua
return {
  "plugin/name",
  config = function(_, opts)
    require("plugin").setup(opts)
    -- additional setup code
  end,
}
```

### Performance Optimization Guidelines (2024年最新版)

1. **必須：遅延読み込み設定** - 全てのプラグインで指定:
   - `event = "VeryLazy"` - 一般的なプラグイン用
   - `event = "BufRead"` - ファイル読み込み時
   - `cmd = "CommandName"` - コマンド実行時のみ
   - `keys = { "<leader>x" }` - キー使用時のみ
   - `ft = { "typescript", "javascript" }` - 特定ファイルタイプ

2. **パフォーマンス最適化**:
   - Pythonプロバイダー明示設定（options.lua:8-10で実装済み）
   - 不要なruntimeプラグイン無効化（lazy.lua:46-60で実装済み）
   - `opts`パターンを`config`より優先使用

3. **キーマップ統合** - プラグインspec内で定義:
```lua
keys = {
  { "<leader>xx", "<cmd>Command<cr>", desc = "Description" },
  { "<leader>xy", function() ... end, desc = "Description", mode = "v" },
}
```

### Example: Well-Configured Plugin
```lua
return {
  "author/plugin-name",
  dependencies = { "required/dependency" },
  event = { "BufRead", "BufNewFile" }, -- or cmd/keys/ft
  keys = {
    { "<leader>p", "<cmd>PluginCommand<cr>", desc = "Plugin action" },
  },
  opts = {
    setting1 = true,
    setting2 = "value",
  },
}
```

### Configuration Rules (2024年ベストプラクティス)

1. **優先度**：`opts` > `opts function` > `config function`
2. **必須**：全プラグインで遅延読み込み設定（`event`, `cmd`, `keys`, `ft`）
3. **統合**：キーマップはプラグインspec内で定義（keymaps.luaではなく）
4. **最小化**：設定は必要最小限に留める
5. **文書化**：重要な設定に日本語コメント
6. **パターン統一**：既存コードの命名規則・構造に従う
7. **パフォーマンス重視**：起動時間100ms以下を目標

## Claude Code向けプラグイン追加手順

### ⚠️ 必須：追加前の安全確認
```bash
# 必ず実行：現在の状態をバックアップ
git stash push -m "before_plugin_$(date +%Y%m%d_%H%M%S)"
```

### 1. プラグイン追加時の判断基準
```mermaid
flowchart TD
    A[プラグイン追加要求] --> B{LazyVim extrasに存在？}
    B -->|Yes| C[extrasを使用（推奨）]
    B -->|No| D{類似機能のプラグイン存在？}
    D -->|Yes| E{競合する？}
    D -->|No| F[新規追加OK]
    E -->|Yes| G[既存プラグイン無効化 or 追加拒否]
    E -->|No| H[共存設定で追加]
```

### 2. 必須：公式ドキュメント参照（Context7）
🚨 **プラグイン導入時は必ず最初にContext7を使用**

```bash
# Claude Code操作例
"use context7で[プラグイン名]の公式ドキュメントを取得して"
```

**理由：**
- 最新の正確な設定方法を取得
- 非推奨設定の回避
- LazyVim統合の最適化
- 設定ミスによるエラー防止

### 2.1 LazyVim設定継承の必須パターン

#### ❌ 危険：完全上書き
```lua
opts = { setting = "value" }  -- LazyVim設定破壊
opts = { ... }, opts = function() -- 重複opts（エラー）
opts.picker.files = { ... }      -- 直接代入（パフォーマンス劣化）
```

#### ✅ 必須：継承パターン
```lua
opts = function(_, opts)
  opts.setting = opts.setting or {}
  opts.setting = vim.tbl_deep_extend("force", opts.setting, { new = "value" })
  -- 関数継承: local orig = opts.fn; opts.fn = function() orig(); custom(); end
  return opts
end
```

#### 📝 実戦問題と解決
- Snacks遅い→`vim.tbl_deep_extend`使用
- Neo-tree開く→`opts`関数形式
- ToggleTerm重複→単一opts統合

### 3. テンプレート
```lua
return {
  "author/plugin-name",
  event = "VeryLazy", -- cmd/keys/ft
  keys = { { "<leader>xx", "<cmd>Command<cr>", desc = "機能説明" } },
  opts = function(_, opts)
    opts.setting = opts.setting or {}
    opts.setting = vim.tbl_deep_extend("force", opts.setting, { new = "value" })
    return opts
  end,
}
```

### 4. チェック手順
```bash
# 基本確認
nvim --headless -c "lua print('OK')" -c "qall"
nvim --startuptime /tmp/startup.log +qall && tail -1 /tmp/startup.log

# 問題時
git stash apply
```

### 5. 失敗時の即座復旧
```bash
# 問題があれば即座に前の状態に戻す
git stash apply
```

---

## 🚨 Claude Code運用の絶対ルール

### 変更実行前の必須手順
1. **現在状態バックアップ**: `git stash push -m "backup_$(date +%Y%m%d_%H%M%S)"`

### 変更実行後の必須検証
1. **基本動作確認**: `nvim --headless -c "lua print('OK')" -c "qall"`

### 問題発生時の緊急復旧
```bash
git stash apply  # 即座に前の状態に復帰
```

### Claude Codeで使用可能なコマンド
```bash
# プラグイン管理
:Lazy

# キーマップ確認
:WhichKey
```

## 🚨 Snacks.nvim Picker設定の重要な注意点

### node_modules除外が効かない問題と解決法

**症状**: `<leader>ff`でnode_modulesが表示されてしまう

**原因と解決法**:

#### ❌ 間違った設定パターン
```lua
-- これらは動作しない
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = { ... }  -- sourcesは存在しない構造
    }
  }
}

-- cmdとargsの組み合わせも問題
sources = {
  files = {
    cmd = "fd",
    args = { "--exclude", "node_modules" }  -- エラーになる
  }
}
```

#### ✅ 正しい設定パターン
```lua
return {
  "folke/snacks.nvim", 
  opts = function(_, opts)
    opts.picker = opts.picker or {}
    
    -- 直接picker配下に設定
    opts.picker.files = {
      hidden = false,
      ignored = true,     -- 🔑 最重要：gitignoreを尊重
      exclude = {
        "node_modules/**",
        "dist/**",
        "build/**",
      }
    }
    
    opts.picker.grep = {
      hidden = false, 
      ignored = true,     -- 🔑 最重要：gitignoreを尊重
      exclude = {
        "node_modules/**",
        "dist/**",
        "build/**", 
      }
    }
    
    return opts
  end
}
```

#### 🔑 重要なポイント
1. **`ignored = true`**: これが最重要。falseにするとgitignoreが無視される
2. **`opts`関数形式**: LazyVimの既存設定を拡張する正しい方法
3. **`sources`使用禁止**: Snacksにはsources構造は存在しない
4. **glob形式**: `node_modules/**`でディレクトリ配下を完全除外
5. **`cmd`指定時の注意**: `args`との併用でエラーが発生しやすい

#### 📝 トラブルシューティング
```bash
# 設定が反映されない場合
:Lazy reload snacks.nvim

# 現在の設定確認
:lua print(vim.inspect(require("snacks.config").picker))

# gitignoreファイル確認
cat .gitignore | grep node_modules
```