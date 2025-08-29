-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "<Leader>e", "<cmd>Neotree toggle<cr>", { desc = "Toggle Neo-tree" })
vim.keymap.set("n", "<C-S-e>", "<cmd>Neotree toggle<cr>", { desc = "Toggle Neo-tree (Ctrl+Shift+E)" })

-- ファイル保存と終了
vim.keymap.set({ "n", "i", "v" }, "<C-s>", "<cmd>w<CR>", { desc = "Save file" })
vim.keymap.set("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
vim.keymap.set("n", "<leader>Q", "<cmd>qa<CR>", { desc = "Quit all" })
vim.keymap.set("n", "<leader>x", "<cmd>x<CR>", { desc = "Save and quit" })

-- Cmd+Shift+F (iTerm2から<F16>として送信) を <leader>/ にマッピングする
vim.keymap.set("n", "<F16>", "<leader>/", { remap = true, desc = "Live Grep (Cmd+Shift+F)" })

-- ToggleTermのキーマップはlua/plugins/toggleterm.luaで管理

-- 日本語IME切り替えキー（Lang1/Lang2）でinsertモードに入る
vim.keymap.set("n", "<Lang1>", "i", { desc = "Enter Insert Mode (Lang1)" })
vim.keymap.set("n", "<Lang2>", "i", { desc = "Enter Insert Mode (Lang2)" })

-- Vモードでの移動は smooth-movement.lua で管理

-- Git クイックコミット機能（Conventional Commits）
vim.keymap.set("n", "<leader>gC", function()
  -- ステージ済みファイルがあるかチェック
  local staged = vim.fn.system("git diff --cached --name-only"):gsub("%s+", "")
  if staged == "" then
    vim.notify("No staged changes to commit", vim.log.levels.WARN)
    return
  end

  -- Conventional Commitsのタイプ選択
  local commit_types = {
    "🎉 init: プロジェクト初期化",
    "✨ feat: 新規機能追加",
    "🐞 fix: バグ修正",
    "📃 docs: ドキュメントのみの変更",
    "🦄 refactor: リファクタリング（新規機能やバグ修正を含まない）",
    "🧪 test: 不足テストの追加や既存テストの修正",
  }

  vim.ui.select(commit_types, {
    prompt = "コミットタイプの選択:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if not choice then
      return
    end

    -- 絵文字とタイプを抽出（例: "✨" and "feat" from "✨ feat: 新規機能追加"）
    local emoji = choice:match("^([^%s]+)")
    local commit_type = choice:match("%s+([^:]+):")

    -- メッセージを入力
    vim.ui.input({
      prompt = emoji .. " " .. commit_type .. ": ",
      default = "",
    }, function(msg)
      if msg and msg ~= "" then
        local full_msg = emoji .. " " .. commit_type .. ": " .. msg
        -- サイレントコミット（警告を非表示）
        vim.cmd("silent! Git commit -m '" .. full_msg .. "'")
        vim.notify("✅ Committed: " .. full_msg, vim.log.levels.INFO)
      end
    end)
  end)
end, { desc = "Conventional Commit" })

-- Git ステージ全て＋コミット
vim.keymap.set("n", "<leader>gA", function()
  vim.ui.input({ prompt = "Commit message (will stage all): " }, function(msg)
    if msg and msg ~= "" then
      vim.cmd("Git add .")
      vim.cmd("Git commit -m '" .. msg .. "'")
      vim.notify("Staged all & committed: " .. msg, vim.log.levels.INFO)
    end
  end)
end, { desc = "Stage All & Commit" })

-- Git コミット取り消し機能
vim.keymap.set("n", "<leader>gu", function()
  -- 最新コミットの情報を取得
  local last_commit = vim.fn.system("git log -1 --oneline"):gsub("%s+$", "")
  if last_commit == "" then
    vim.notify("No commits to undo", vim.log.levels.WARN)
    return
  end

  -- 取り消し方法を選択
  local undo_options = {
    " soft: コミット取り消し（変更は保持・ステージ済み）",
    " mixed: コミット取り消し（変更は保持・未ステージ）",
  }

  vim.ui.select(undo_options, {
    prompt = "取り消し方法を選択:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if not choice then
      return
    end

    local reset_type = "mixed" -- デフォルト
    if choice:match("soft") then
      reset_type = "soft"
    elseif choice:match("mixed") then
      reset_type = "mixed"
    end

    -- 選択後即実行
    vim.cmd("Git reset --" .. reset_type .. " HEAD~1")
    vim.notify("✅ " .. reset_type .. " reset完了", vim.log.levels.INFO)
  end)
end, { desc = "Undo Last Commit" })

-- 高速移動用キーマップ（Keyball向け）
-- 注意: mはマーク機能、,はリピートジャンプ逆方向を上書き
vim.keymap.set("n", "m", "5j", { desc = "Fast down (5 lines)" })
vim.keymap.set("n", ",", "5k", { desc = "Fast up (5 lines)" })

-- さらに高速移動
vim.keymap.set("n", "<S-j>", "10j", { desc = "Very fast down (10 lines)" })
vim.keymap.set("n", "<S-k>", "10k", { desc = "Very fast up (10 lines)" })

-- ページ移動の代替
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Half page down + center" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Half page up + center" })

-- カスタムモーション：「`」を「0」と同等にする
vim.keymap.set({ "n", "v", "o" }, "`", "0", { desc = "Move to start of line (custom)" })

-- LSP Code Action
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Action" })

-- Snacks.nvimを強制的に優先させる設定（LazyVimデフォルトを上書き）
-- 既存のキーマップを削除してから設定
vim.keymap.del("n", "<leader>fg", { silent = true })
vim.keymap.set("n", "<leader>fg", function()
  require("snacks").picker.grep()
end, { desc = "Live Grep (Snacks)", buffer = false, silent = true })

-- 遅延実行でも念のため設定（LazyVimのVeryLazyイベント後に実行）
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    -- 既存マッピングを削除
    pcall(vim.keymap.del, "n", "<leader>fg", { silent = true })
    -- 新しいマッピングを設定
    vim.keymap.set("n", "<leader>fg", function()
      require("snacks").picker.grep()
    end, { desc = "Live Grep (Snacks)", buffer = false, silent = true })
  end,
})
