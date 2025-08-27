# CLAUDE.md

Claude Code (claude.ai/code) がこのNeovim設定リポジトリで作業する際の指示システムです。

<context>
このNeovim設定は完全Claude Code管理です。LazyVimベースの設定であり、プラグイン競合や設定エラーを防ぐため、厳格なパターンの遵守が必要です。エラーは必ず発生するという前提で、デバッグ可能な実装を行います。
</context>

## 🚨 絶対遵守事項

<critical>
以下は例外なく遵守すべき原則です：

### 実装前の必須事項
- [ ] **Context7での公式ドキュメント確認**: 必ず最初に実行（新規実装・バグ対応・設定変更すべて）
  - 新規実装: 「Context7で[プラグイン名]の公式ドキュメントを取得して」
  - バグ対応: 「Context7で[プラグイン名]のトラブルシューティングを確認して」
  - 設定変更: 「Context7で[プラグイン名]の設定オプションを確認して」

### 実装パターンの厳格遵守
- [ ] **LazyVim設定継承パターン必須**: `opts = function(_, opts)` 形式のみ使用
- [ ] **設定マージ必須**: `vim.tbl_deep_extend("force", ...)` を必ず使用
- [ ] **完全上書き禁止**: `opts = { setting = "value" }` は絶対禁止

### エラー前提の実装
- [ ] **デバッグ機能の実装**: 全ての実装にログ出力を追加
- [ ] **エラーハンドリング**: `pcall` によるエラー処理を実装
- [ ] **ユーザーへのフィードバック**: 問題発生時は詳細ログを提供してもらう
</critical>

ABSOLUTE REQUIREMENT: 上記パターンに従わない実装は一切受け入れられません。

## 📐 標準実装テンプレート

<template>
すべてのプラグイン設定はこのテンプレートに従います：

```lua
--[[
機能概要: [プラグインの主要機能を1-2行で説明]
設定内容: [カスタマイズ内容と理由]
キーバインド: [主要なキーマッピング]
--]]
return {
  "author/plugin-name",
  dependencies = { "required/dependency" },
  event = "VeryLazy", -- または BufRead, cmd, keys, ft
  keys = {
    { "<leader>xx", "<cmd>Command<cr>", desc = "機能説明" },
  },
  opts = function(_, opts)
    -- デバッグ（実装時のみ、完了時削除）
    -- print("=== DEBUG: Initial opts ===")
    -- print(vim.inspect(opts))
    
    -- 安全な初期化
    opts.target = opts.target or {}
    
    -- 設定のマージ（完全上書きではない）
    opts.target = vim.tbl_deep_extend("force", opts.target, {
      custom_setting = "value"
    })
    
    -- デバッグ（実装時のみ、完了時削除）
    -- print("=== DEBUG: Final opts ===")
    -- print(vim.inspect(opts.target))
    
    return opts
  end,
}
```
</template>

## 🔄 実装ワークフロー

<workflow>
### フェーズ1: 事前準備
- [ ] Context7で公式ドキュメント取得
- [ ] LazyVim extrasの確認
- [ ] 既存プラグインとの競合確認

### フェーズ2: デバッグ付き実装
- [ ] テンプレートに基づく実装
- [ ] デバッグログの追加
- [ ] エラーハンドリングの実装
- [ ] 段階的テスト

### フェーズ3: 問題解決
- [ ] **Context7で関連プラグインの情報確認**（バグ対応時は必須）
- [ ] エラー発生時はユーザーに`:messages`の内容を依頼
- [ ] デバッグ出力から原因特定
- [ ] 修正と再テスト

### フェーズ4: クリーンアップ
- [ ] デバッグコードの完全削除
- [ ] **Styluaフォーマット実行**: `stylua lua/plugins/[modified-file].lua`
- [ ] 実装パターンの最終確認
- [ ] パフォーマンステスト: `nvim --startuptime /tmp/startup.log +qall`
- [ ] **ショートカットキーの更新**: 新規・変更したキーマップは`SHORTCUTS.md`に記載
</workflow>

## 🔧 コード品質管理

### Lua Linter/Formatter
- **Stylua**: Rustベースの高速フォーマッター（必須使用）
- **Selene**: 静的解析・型チェック（推奨）
- **インストール**: `brew install stylua selene`

### 必須実行タイミング
- **プラグインコード変更時**: 必ずstyluaフォーマットを実行
- **実装完了時**: 品質チェックリストでフォーマット確認
- **コミット前**: 構文エラー・スタイル確認

## 🛠️ トラブルシューティング

<troubleshooting>
### エラー診断手順
1. **Context7確認**: 関連プラグインの公式情報・トラブルシューティング確認
2. **構文チェック**: `stylua --check lua/plugins/[file].lua`
3. **ログ確認**: `:messages`
4. **設定確認**: `:lua print(vim.inspect(require("plugin.config")))`
5. **リロード**: `:Lazy reload [plugin-name]`

### よくある問題と解決法
- **構文エラー**: styluaでチェック・フォーマット実行
- **設定が反映されない**: LazyVim設定継承パターンの確認
- **起動エラー**: バックアップから復旧 `git stash apply`
- **パフォーマンス問題**: 遅延読み込み設定の確認
</troubleshooting>

## 📋 品質チェックリスト

<checklist>
実装完了時の必須確認事項：

- [ ] Context7でドキュメント確認済み
- [ ] `opts = function(_, opts)` パターン使用
- [ ] `vim.tbl_deep_extend` でマージ実装
- [ ] 機能概要コメント記載
- [ ] 遅延読み込み設定済み
- [ ] デバッグコード削除済み
- [ ] **Styluaフォーマット適用済み**: `stylua lua/plugins/[file].lua`
- [ ] 動作確認: `nvim --headless -c "lua print('OK')" -c "qall"`
- [ ] **ショートカットキー記載済み**: 新規・変更したキーマップは`SHORTCUTS.md`に記載済み
</checklist>

## 🏗️ アーキテクチャ概要

<architecture>
- **基盤**: LazyVim（Neovimディストリビューション）
- **プラグイン管理**: lazy.nvim
- **設定構造**:
  - `init.lua`: エントリポイント
  - `lua/config/`: コア設定
  - `lua/plugins/`: プラグイン設定（ここを主に編集）
  - `SHORTCUTS.md`: ショートカットキー一覧（修飾キー使用のもののみ）
- **言語**: 日本語対応（`helplang = { "ja", "en" }`）
</architecture>

---

YOU MUST: すべての作業（新規実装・バグ対応・設定変更）は必ずContext7から開始すること。
CRITICAL: LazyVim設定継承パターンを破壊する実装は絶対禁止。
