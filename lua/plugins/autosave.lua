--[[
auto-save.nvim自動保存プラグイン
機能: ファイル変更時に自動保存
--]]

return {
  "pocco81/auto-save.nvim",
  event = "VeryLazy",
  config = function()
    require("auto-save").setup({
      enabled = true, -- 起動時に有効化
      trigger_events = { "InsertLeave", "TextChanged" }, -- 保存トリガー
      condition = function(buf)
        local fn = vim.fn
        local utils = require("auto-save.utils.data")
        
        -- 変更可能でファイル名があるバッファのみ保存
        if fn.getbufvar(buf, "&modifiable") == 1 and 
           fn.getbufvar(buf, "&filetype") ~= "" and
           utils.not_in(fn.getbufvar(buf, "&filetype"), {"lua"}) then
          return true
        end
        return false
      end,
      write_all_buffers = false, -- 現在のバッファのみ保存
      on_off_commands = true, -- :ASToggleコマンドを有効化
      clean_command_line_interval = 0, -- メッセージを残す
    })
  end,
}