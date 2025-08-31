# Neovim Modifier Key Shortcuts

このファイルは同時押し（Ctrl、Alt、Shift等の修飾キー）を使用するショートカットキーの一覧です。

## キーマップ表記ルール

- `<C-a>` = Ctrl + a（小文字a）
- `<C-A>` = Ctrl + Shift + a（大文字A）
- `<M-a>` = Alt/Meta + a
- `<S-Tab>` = Shift + Tab
- `<D-a>` = Cmd + a（Mac）

**統一ルール**: Shiftキーは大文字表記で統一（`<C-S-a>`は使用禁止、`<C-A>`を使用）

## Claude AI Tools

| キー | 機能 | 説明 |
|------|------|------|
| `<C-c>` | ClaudeCode Chat | ClaudeCodeチャットを開く |
| `<C-q>` | Add File to Claude | 現在のファイルをClaudeのコンテキストに追加 |
| `<C-g>` | Toggle Claude Chat | Claude チャット切り替え |

## Neo-tree Navigation

| キー | 機能 | 説明 |
|------|------|------|
| `<` | Previous Source | Neo-tree前のソースに切り替え |
| `>` | Next Source | Neo-tree次のソースに切り替え |
| `<C-q>` | Add to Claude | Neo-tree選択項目をClaude追加 |
| `A` | Add to Claude (Recursive) | Neo-treeディレクトリを再帰的にClaude追加 |
| `<C-Q>` | Add to Claude (Alt) | Neo-tree選択項目をClaude追加（代替） |

## Window Navigation

| キー | 機能 | 説明 |
|------|------|------|
| `<C-H>` | Go to Left Window | 左のウィンドウに移動 |
| `<C-J>` | Go to Lower Window | 下のウィンドウに移動 |
| `<C-K>` | Go to Upper Window | 上のウィンドウに移動 |
| `<C-L>` | Go to Right Window | 右のウィンドウに移動 |

## Window Resizing

| キー | 機能 | 説明 |
|------|------|------|
| `<C-Up>` | Increase Height | ウィンドウ高さ増加 |
| `<C-Down>` | Decrease Height | ウィンドウ高さ減少 |
| `<C-Left>` | Decrease Width | ウィンドウ幅減少 |
| `<C-Right>` | Increase Width | ウィンドウ幅増加 |

## File Operations

| キー | 機能 | 説明 |
|------|------|------|
| `<C-S>` | Save File | ファイル保存（Insert/Normal/Visual） |
| `<C-S-E>` | Toggle Neo-tree | ファイルツリー表示切り替え |

## Number Operations

| キー | 機能 | 説明 |
|------|------|------|
| `<C-A>` | Increment | 数値インクリメント |
| `<C-X>` | Decrement | 数値デクリメント |
| Visual + `<C-A>` | Increment (Visual) | 選択範囲で数値インクリメント |
| Visual + `<C-X>` | Decrement (Visual) | 選択範囲で数値デクリメント |

## Terminal

| キー | 機能 | 説明 |
|------|------|------|
| `<C-/>` | Terminal (Root Dir) | ルートディレクトリでターミナル |

## Page Navigation

| キー | 機能 | 説明 |
|------|------|------|
| `<C-D>` | Half Page Down | 半ページ下 + カーソル中央 |
| `<C-U>` | Half Page Up | 半ページ上 + カーソル中央 |
| `<C-F>` | Scroll Forward | 前方スクロール |
| `<C-B>` | Scroll Backward | 後方スクロール |

## Buffer Navigation

| キー | 機能 | 説明 |
|------|------|------|
| `<C-PageUp>` | Previous Buffer | 前のバッファ |
| `<C-PageDown>` | Next Buffer | 次のバッファ |

## Special Functions

| キー | 機能 | 説明 |
|------|------|------|
| `<F15>` | Close Buffer (Smart) | 現在のバッファを閉じる（スマート） |
| `<F16>` | Live Grep | 文字列検索（Cmd+Shift+F） |
| `<C-W><Space>` | Window Hydra Mode | ウィンドウ操作モード（which-key） |
| `<C-W><C-D>` | Show Diagnostics | カーソル下の診断を表示 |

## Line Movement

| キー | 機能 | 説明 |
|------|------|------|
| `<M-j>` | Move Line Down | 行を下に移動（Normal/Visual） |
| `<M-k>` | Move Line Up | 行を上に移動（Normal/Visual） |

## Reference Navigation

| キー | 機能 | 説明 |
|------|------|------|
| `<M-n>` | Next Reference | 次の参照に移動 |
| `<M-p>` | Previous Reference | 前の参照に移動 |
| `<M-i>` | Illuminate | 参照ハイライト（Visual/Operator） |

## Git Shortcuts

| キー | 機能 | 説明 |
|------|------|------|
| `<C-CR>` | Commit Staged | ステージ済み変更をコミット（VSCode風） |
| `<C-S-CR>` | Stage All & Commit | 全てステージ＋コミット（VSCode風） |
| `<C-S-G>` | Git Changes | Git変更表示（VSCode風） |

## Search & Find

| キー | 機能 | 説明 |
|------|------|------|
| `<D-F>` | Live Grep (Alt) | 文字列検索（代替） |

## Snippet Navigation

| キー | 機能 | 説明 |
|------|------|------|
| `<S-Tab>` | Previous Snippet | 前のスニペットジャンプ（Select mode） |

---

**注意**: 
- `<C>` = Ctrl
- `<M>` = Alt/Meta  
- `<S>` = Shift
- `<D>` = Cmd（Mac）

**更新日**: 2025年8月27日
