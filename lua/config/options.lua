-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.helplang = { "ja", "en" } -- ヘルプを日本語優先に
vim.cmd("language messages ja_JP.UTF-8") -- メッセージを日本語に

-- Node.jsのパスをNeovimの環境変数に追加（LSPサーバー用）
vim.env.PATH = vim.env.PATH .. ":/Users/ren/.nodenv/versions/20.18.0/bin"


-- 設定を整理するためのグループを作成
local augroup = vim.api.nvim_create_augroup("MyCustomAutocmds", { clear = true })

-- 2. 起動時にNeo-treeを開く
vim.api.nvim_create_autocmd("User", {
  group = augroup,
  pattern = "LazyVimStarted", -- VimEnter から変更
  desc = "Open Neo-tree on startup if no file is specified",
  callback = function()
    if vim.fn.argc() == 0 then
      vim.cmd("Neotree")
    end
  end,
})

vim.opt.spell = false -- すべてのファイルでスペルチェックを無効にする

-- swapファイル関連の設定
vim.opt.swapfile = false -- swapファイルを無効化（推奨）
-- または以下の設定でswap警告を自動処理
-- vim.opt.shortmess:append("A") -- swap警告を無視

-- Keyball用マウス設定
vim.opt.mouse = "a" -- 全モードでマウスを有効化
vim.opt.mousescroll = "ver:3,hor:3" -- スクロール速度の調整