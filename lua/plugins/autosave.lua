return {
  "Pocco81/auto-save.nvim",
  event = { "TextChanged", "InsertLeave" }, -- 遅延読み込み
  opts = {
    -- オートセーブを有効にする
    enabled = true,
    -- 保存を実行するタイミング
    trigger_events = { "TextChanged", "InsertLeave" },
    -- TextChangedイベントの遅延時間（ミリ秒）
    -- 最後のキー入力から1秒後に保存を実行し、入力のたびに保存が走るのを防ぐ
    debounce = 1000,
    -- 既存のファイルのみオートセーブの対象にする
    conditions = {
      exists = true,
      modifiable = true,
    },
    -- BufWritePreイベントを確実に発生させる
    write_all_buffers = false,
    clean_command_line_interval = 0,
    on_off_commands = true,
    execution_message = {
      enabled = false, -- メッセージを非表示
    },
    -- TypeScript/JavaScript自動修正との連携
    callbacks = {
      before_saving = function()
        local bufnr = vim.api.nvim_get_current_buf()
        local filename = vim.api.nvim_buf_get_name(bufnr)
        local filetype = vim.bo[bufnr].filetype
        
        -- TypeScript/JavaScriptファイルの場合のみ実行
        if vim.tbl_contains({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, filetype) then
          -- TypeScriptAutoFixイベントを発火
          vim.api.nvim_exec_autocmds("User", {
            pattern = "TypeScriptAutoFix",
            data = { bufnr = bufnr, filename = filename }
          })
        end
      end,
    },
  },
}
