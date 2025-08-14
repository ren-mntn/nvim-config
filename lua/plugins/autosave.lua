--[[
機能概要: TypeScript/JavaScript自動保存・自動インポート機能
設定内容: TextChanged/InsertLeave時の自動保存、BufWritePost時の自動インポート実行
キーバインド: u, Ctrl-R, g-, g+ (Undo追跡用)
--]]

local in_undo_mode = {}
local autosave_timer = {}

-- Undo操作の追跡
local function setup_undo_tracking()
  vim.keymap.set("n", "u", function()
    local bufnr = vim.api.nvim_get_current_buf()
    in_undo_mode[bufnr] = vim.loop.hrtime()
    return "u"
  end, { expr = true, desc = "Undo with tracking" })

  vim.keymap.set("n", "<C-r>", function()
    local bufnr = vim.api.nvim_get_current_buf()
    in_undo_mode[bufnr] = vim.loop.hrtime()
    return "<C-r>"
  end, { expr = true, desc = "Redo with tracking" })

  vim.keymap.set("n", "g-", function()
    local bufnr = vim.api.nvim_get_current_buf()
    in_undo_mode[bufnr] = vim.loop.hrtime()
    return "g-"
  end, { expr = true, desc = "Earlier with tracking" })

  vim.keymap.set("n", "g+", function()
    local bufnr = vim.api.nvim_get_current_buf()
    in_undo_mode[bufnr] = vim.loop.hrtime()
    return "g+"
  end, { expr = true, desc = "Later with tracking" })
end

-- 自動保存機能
local function save_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  if bufname == "" or not vim.bo[bufnr].modifiable or vim.bo[bufnr].readonly or not vim.bo[bufnr].modified then
    return
  end

  local save_ok, err = pcall(function()
    vim.cmd("silent write")
  end)

  if not save_ok then
    vim.notify("Auto-save failed for buffer: " .. bufnr, vim.log.levels.WARN)
  end
end

local function trigger_autosave()
  local bufnr = vim.api.nvim_get_current_buf()

  if autosave_timer[bufnr] then
    local timer = autosave_timer[bufnr]
    autosave_timer[bufnr] = nil

    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end

  autosave_timer[bufnr] = vim.defer_fn(function()
    save_buffer()
    autosave_timer[bufnr] = nil
  end, 100)
end

-- 自動インポート機能
local function handle_auto_import()
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype

  -- TypeScript/JavaScriptファイルのみ
  if not vim.tbl_contains({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, filetype) then
    return
  end

  -- Undo保護 (2秒以内のUndo後は実行しない)
  local now = vim.loop.hrtime()
  local undo_time = in_undo_mode[bufnr] or 0
  if (now - undo_time) < 2000000000 then
    return
  end

  -- インポートエラーの確認
  local diagnostics = vim.diagnostic.get(bufnr)
  local has_import_errors = false
  for _, diag in ipairs(diagnostics) do
    if string.match(diag.message, "Cannot find name") or string.match(diag.message, "is not defined") then
      has_import_errors = true
      break
    end
  end

  if not has_import_errors then
    return
  end

  -- 自動インポート + ESLintインポート整理（2段階処理）
  vim.schedule(function()
    local import_ok, _ = pcall(function()
      -- まずインポートを追加
      vim.lsp.buf.code_action({
        context = {
          only = { "source.addMissingImports" },
          diagnostics = {},
        },
        apply = true,
      })

      -- 500ms後にESLintの自動修正を実行（import/order対応）
      vim.defer_fn(function()
        local eslint_ok, _ = pcall(function()
          -- ESLint自動修正でインポート順序を修正
          vim.lsp.buf.code_action({
            context = {
              only = { "source.fixAll.eslint" },
              diagnostics = {},
            },
            apply = true,
          })
        end)

        if not eslint_ok then
          -- ESLintが利用できない場合は標準のorganizeImportsにフォールバック
          vim.lsp.buf.code_action({
            context = {
              only = { "source.organizeImports" },
              diagnostics = {},
            },
            apply = true,
          })
        end
      end, 500)
    end)

    if not import_ok then
      vim.notify("Auto-import failed for buffer: " .. bufnr, vim.log.levels.WARN)
    end
  end)
end

-- 初期化
setup_undo_tracking()

-- 自動保存設定
vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
  pattern = "*",
  callback = trigger_autosave,
})

-- 自動インポート設定
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
  callback = handle_auto_import,
})

return {}
