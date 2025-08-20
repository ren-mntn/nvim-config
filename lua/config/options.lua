-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.helplang = { "ja", "en" } -- ヘルプを日本語優先に
vim.cmd("language messages ja_JP.UTF-8") -- メッセージを日本語に

-- パフォーマンス最適化：Pythonプロバイダーの明示的設定
vim.g.python3_host_prog = vim.fn.exepath("python3") or "/usr/bin/python3"
vim.g.python_host_prog = vim.fn.exepath("python2") or "/usr/bin/python2"

-- Node.jsのパスをNeovimの環境変数に追加（LSPサーバー用）
-- nodenvの初期化
vim.env.NODENV_ROOT = vim.env.HOME .. "/.nodenv"
vim.env.PATH = vim.env.NODENV_ROOT .. "/bin:" .. vim.env.PATH
vim.env.PATH = vim.env.PATH .. ":/Users/ren/.nodenv/versions/20.18.0/bin"

-- Homebrewのツールパスを追加（fd, ripgrep用）
vim.env.PATH = vim.env.PATH .. ":/opt/homebrew/bin"

-- 設定を整理するためのグループを作成
local augroup = vim.api.nvim_create_augroup("MyCustomAutocmds", { clear = true })

-- セッション自動復元の設定
vim.api.nvim_create_autocmd("VimEnter", {
  group = augroup,
  desc = "Auto restore session on startup",
  nested = true,
  callback = function()
    -- 引数なしで起動した場合のみセッションを復元
    if vim.fn.argc() == 0 and not vim.g.started_with_stdin then
      require("persistence").load()
    end
  end,
})

vim.opt.spell = false -- すべてのファイルでスペルチェックを無効にする

-- 自動フォーマットを無効化（手動でフォーマットする方が安全）
vim.g.autoformat = false

-- swapファイル関連の設定
vim.opt.swapfile = false -- swapファイルを無効化（推奨）
-- または以下の設定でswap警告を自動処理
-- vim.opt.shortmess:append("A") -- swap警告を無視

-- Keyball用マウス設定
vim.opt.mouse = "a" -- 全モードでマウスを有効化
vim.opt.mousescroll = "ver:5,hor:5" -- スクロール速度の調整

-- 行番号表示を通常の絶対行番号に変更
vim.opt.number = true -- 行番号を表示
vim.opt.relativenumber = false -- 相対行番号を無効化

-- キーリピート最適化（スクロール速度向上）
vim.opt.timeoutlen = 300 -- キーマップ待機時間を短縮（デフォルト1000ms）
vim.opt.ttimeoutlen = 10 -- キーコードタイムアウトを短縮
vim.opt.updatetime = 50 -- 更新頻度を高める（デフォルト4000ms）

-- スクロール関連の最適化
vim.opt.scrolloff = 8 -- カーソル周りの表示行数
vim.opt.scroll = 0 -- 0=画面半分スクロール（デフォルト）
vim.opt.lazyredraw = false -- リアルタイム再描画
vim.opt.ttyfast = true -- 高速端末として扱う

-- 診断のインライン表示を有効化
vim.diagnostic.config({
  virtual_text = true,
})
