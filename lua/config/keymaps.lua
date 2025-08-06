-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "<Leader>e", "<cmd>Neotree toggle<cr>", { desc = "Toggle Neo-tree" })
vim.keymap.set("n", "<C-S-e>", "<cmd>Neotree toggle<cr>", { desc = "Toggle Neo-tree (Ctrl+Shift+E)" })

-- タブ移動
vim.keymap.set({"n", "i"}, "<C-PageDown>", "<cmd>bnext<CR>", { desc = "Next Buffer" })
vim.keymap.set({"n", "i"}, "<C-PageUp>", "<cmd>bprevious<CR>", { desc = "Previous Buffer" })

-- バッファ削除(iTerm2から<F15>として送信)
vim.keymap.set({ "n", "i" }, "<F15>", "<cmd>bdelete<CR>", { desc = "Close Buffer" })

-- Cmd+Shift+F (iTerm2から<F16>として送信) を <leader>/ にマッピングする
vim.keymap.set("n", "<F16>", "<leader>/", { remap = true, desc = "Live Grep (Cmd+Shift+F)" })

-- ターミナル開閉キーバインドをCtrl + ` に設定
vim.keymap.set("n", "<C-`>", "<cmd>ToggleTerm<cr>", { desc = "Toggle Terminal" })

-- Leaderキーを使ったToggleTermのマッピング
vim.keymap.set("n", "<leader>tt", "<cmd>ToggleTerm<cr>", { desc = "Toggle Terminal" })
vim.keymap.set("n", "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", { desc = "Toggle Horizontal Terminal" })
vim.keymap.set("n", "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>", { desc = "Toggle Vertical Terminal" })
vim.keymap.set("n", "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", { desc = "Toggle Float Terminal" })
vim.keymap.set("n", "<leader>ta", "<cmd>ToggleTermToggleAll<cr>", { desc = "Toggle All Terminals" })
vim.keymap.set("n", "<leader>tn", "<cmd>ToggleTermSetName<cr>", { desc = "Set Terminal Name" })
vim.keymap.set("n", "<leader>ts", "<cmd>TermSelect<cr>", { desc = "Select Terminal" })

-- 特定のターミナルを開く（番号付き）
vim.keymap.set("n", "<leader>t1", "<cmd>1ToggleTerm<cr>", { desc = "Toggle Terminal 1" })
vim.keymap.set("n", "<leader>t2", "<cmd>2ToggleTerm<cr>", { desc = "Toggle Terminal 2" })
vim.keymap.set("n", "<leader>t3", "<cmd>3ToggleTerm<cr>", { desc = "Toggle Terminal 3" })
vim.keymap.set("n", "<leader>t4", "<cmd>4ToggleTerm<cr>", { desc = "Toggle Terminal 4" })

-- 現在の行や選択範囲をターミナルに送信
vim.keymap.set("n", "<leader>tl", "<cmd>ToggleTermSendCurrentLine<cr>", { desc = "Send Current Line to Terminal" })
vim.keymap.set("v", "<leader>tl", "<cmd>ToggleTermSendVisualLines<cr>", { desc = "Send Visual Lines to Terminal" })
vim.keymap.set("v", "<leader>tr", "<cmd>ToggleTermSendVisualSelection<cr>", { desc = "Send Visual Selection to Terminal" })

-- カスタムターミナル
vim.keymap.set("n", "<leader>tg", "<cmd>lua _lazygit_toggle()<cr>", { desc = "Toggle LazyGit" })
vim.keymap.set("n", "<leader>tp", "<cmd>lua _python_toggle()<cr>", { desc = "Toggle Python REPL" })
vim.keymap.set("n", "<leader>tn", "<cmd>lua _node_toggle()<cr>", { desc = "Toggle Node REPL" })
vim.keymap.set("n", "<leader>tc", "<cmd>lua _htop_toggle()<cr>", { desc = "Toggle htop" })

-- 日本語IME切り替えキー（Lang1/Lang2）でinsertモードに入る
vim.keymap.set("n", "<Lang1>", "i", { desc = "Enter Insert Mode (Lang1)" })
vim.keymap.set("n", "<Lang2>", "i", { desc = "Enter Insert Mode (Lang2)" })

-- Vモードでの移動は smooth-movement.lua で管理