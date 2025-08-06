# Git Worktree 一覧・削除機能 要件書

## 🎯 機能概要

### 🔄 **Worktree一覧・切り替え機能** (`<leader>gw`) - ✅ 完成
**フロー**: `<leader>gw` → Telescope UI → 選択 → ディレクトリ切り替え → Neo-tree自動更新

### 🗑️ **Worktree削除機能** (`<leader>gw` → `Ctrl+D`) - ✅ 完成
**フロー**: worktreeリスト表示 → Ctrl+D → 自動インサートモード → `y`/`N` 確認 → Enter → 自動ノーマルモード → バックグラウンド削除

## 📋 詳細要件

### 🔄 Worktree一覧・切り替え機能

#### 基本操作フロー
- [x] 1. **トリガー**: `<leader>gw` を押す
- [x] 2. **リスト取得**: `git worktree list` でworktree一覧を取得
- [x] 3. **Telescope表示**: worktreeリストをTelescope形式で表示
- [x] 4. **選択・切り替え**: Enter でディレクトリ切り替え
- [x] 5. **Neo-tree更新**: 切り替え後にNeo-tree自動更新

#### 表示機能
- [x] **現在位置表示**: "👈 current"マークで現在のworktreeを明示
- [x] **メインプロジェクト対応**: メインプロジェクト（main）も選択肢に含める
- [x] **相対パス表示**: `./git-worktrees/branch-name` 形式で見やすく表示
- [x] **ブランチ情報**: `🌿 ブランチ名 (ディレクトリ名)` 形式

#### 高度な機能
- [x] **重複回避**: メインプロジェクトとworktreeの重複を自動回避
- [x] **パス解析**: worktree listの複雑な出力を正確にパース
- [x] **安全性**: 存在しないディレクトリは選択不可

### 🗑️ Worktree削除機能

#### 基本操作フロー
- [x] 1. **削除トリガー**: worktreeリスト内で `Ctrl+D` を押す
- [x] 2. **安全性チェック**: main/masterブランチは削除不可
- [x] 3. **確認UI**: 自動インサートモード → `y`/`N` 入力 → Enter → 自動ノーマルモード
- [x] 4. **バックグラウンド削除**: `vim.system`による非同期処理
- [x] 5. **完了通知**: 削除完了または修復完了メッセージ

#### 3段階削除システム
- [x] **Stage 1**: `git worktree prune` で無効なworktreeをクリーンアップ
- [x] **Stage 2**: `git worktree remove --force` で強制削除
- [x] **Stage 3**: 失敗時は `rm -rf` でディレクトリ削除 + `git worktree prune`

#### 高度な削除機能
- [x] **修復機能**: 壊れたworktreeも自動検出・修復削除
- [x] **安全性**: main/masterブランチは削除不可
- [x] **UIノンブロッキング**: `vim.system`による非同期削除でNeovim操作可能
- [x] **自動モード切り替え**: 確認時インサートモード、処理後ノーマルモード

## 🛠️ 技術仕様

### A. Telescope UI設計
```lua
require("telescope.pickers").new({}, {
  prompt_title = "🌳 Git Worktrees",
  finder = require("telescope.finders").new_table({
    results = worktree_list,
    entry_maker = function(entry)
      return {
        value = entry,
        display = entry.display, -- 🌿 ブランチ名 (パス) 👈 current
        ordinal = entry.branch .. " " .. entry.path,
      }
    end,
  }),
  sorter = require("telescope.config").values.generic_sorter({}),
  previewer = false, -- プレビューなしで軽量化
})
```

### B. Worktreeリスト解析
```lua
-- パターン1: "/path commit_hash [branch]"
local path, hash, branch = line:match("^(.-)%s+([%w%d]+)%s+%[(.-)%]")

-- パターン2: "/path commit_hash (bare)"
if not branch then
  path, hash = line:match("^(.-)%s+([%w%d]+)%s+%(")
  -- bareの場合は現在のブランチを取得
  local bare_branch = vim.fn.system("cd " .. path .. " && git branch --show-current")
end
```

### C. 非同期削除処理
```lua
vim.system({ "git", "worktree", "prune" }, {}, function()
  vim.system({ "git", "worktree", "remove", "--force", path }, {}, function(result)
    if result.code ~= 0 then
      -- 修復モード: ディレクトリ削除 + prune
      vim.system({ "rm", "-rf", path }, {}, function()
        vim.system({ "git", "worktree", "prune" }, {}, function()
          vim.notify("🗑️ 修復・削除完了")
        end)
      end)
    end
  end)
end)
```

## ⚠️ エラーハンドリング

### 必須チェック項目
- [x] **Gitリポジトリチェック**: 非Gitディレクトリでは動作しない
- [x] **Worktree存在チェック**: `git worktree list` が空の場合の処理
- [x] **選択検証**: 未選択や無効な選択の処理
- [x] **ディレクトリ存在チェック**: 切り替え前にディレクトリの存在確認

### エラーメッセージ例
- [x] `"❌ Worktreeが見つかりません"`
- [x] `"❌ Worktreeが選択されていません"`
- [x] `"⚠️ mainブランチは削除できません"`
- [x] `"❌ ディレクトリが見つかりません: [パス]"`

## 🎯 成功条件
- [x] **UI応答性**: Telescope UIの高速表示と操作性
- [x] **安全性**: main/masterブランチ保護、確認プロンプト
- [x] **安定性**: 削除処理中もNeovim操作可能
- [x] **修復機能**: 壊れたworktreeの自動修復

## 📋 キーバインド仕様

### メインキー
- `<leader>gw` - Worktree一覧表示

### Telescope内キーバインド
- `Enter` - 選択したworktreeに切り替え
- `Ctrl+D` - 選択したworktreeを削除（確認あり）
- `Esc` - キャンセル

### 確認プロンプト内キーバインド
- `y` + `Enter` - 削除実行
- `N` + `Enter` または `Esc` - キャンセル

## 🔧 最適化ポイント

### パフォーマンス
- [x] **プレビューなし**: Telescopeプレビューを無効化して軽量化
- [x] **バックグラウンド削除**: UIをブロックしない非同期処理
- [x] **キャッシュなし**: リアルタイムでworktree状態を取得

### UX改善
- [x] **現在位置の明確化**: 👈 currentマークで直感的
- [x] **自動モード切り替え**: 入力時は自動でインサートモード
- [x] **進捗表示**: "バックグラウンドで削除処理中..." 等の状況表示

## 🚫 対象外機能
- Worktree作成機能（別機能として実装済み）
- ブランチ詳細情報表示
- コミット履歴表示
- 複数worktree同時削除

## 📋 依存関係
- **telescope.nvim** - UI表示
- **plenary.nvim** - 基盤機能
- **vim.system** - 非同期コマンド実行
- **git** - worktree管理コマンド

## 🎯 リファクタリング対象
- **デバッグメッセージ除去**: 本番環境では不要な`print()`や`vim.notify()`
- **関数分割**: 大きな関数を機能単位で分割
- **エラーハンドリング統一**: 一貫したエラー処理パターン
