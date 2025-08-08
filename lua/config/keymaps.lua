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

-- ToggleTermのキーマップはlua/plugins/toggleterm.luaで管理

-- 日本語IME切り替えキー（Lang1/Lang2）でinsertモードに入る
vim.keymap.set("n", "<Lang1>", "i", { desc = "Enter Insert Mode (Lang1)" })
vim.keymap.set("n", "<Lang2>", "i", { desc = "Enter Insert Mode (Lang2)" })

-- Vモードでの移動は smooth-movement.lua で管理