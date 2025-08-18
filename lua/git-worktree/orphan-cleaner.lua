--[[
機能概要: 孤児LSPプロセスの定期クリーンアップ
設定内容: 15分間隔でのプロセス監視、自動終了
--]]

local M = {}

-- 定期クリーンアップ（内部関数）
local function cleanup_orphan_processes()
  local cleaned = 0
  
  -- TypeScript tsserver プロセス
  local ts_result = vim.fn.system("ps aux | grep -E 'tsserver.js.*tscancellation' | grep -v grep")
  if ts_result ~= "" then
    for line in ts_result:gmatch("[^\n]+") do
      local pid = line:match("^%S+%s+(%d+)")
      if pid then
        os.execute(string.format("kill -TERM %s 2>/dev/null", pid))
        cleaned = cleaned + 1
      end
    end
  end
  
  -- 重複した vtsls/eslint プロセス（2個以上ある場合は古いものを終了）
  local vtsls_count = tonumber(vim.fn.system("ps aux | grep 'vtsls --stdio' | grep -v grep | wc -l")) or 0
  local eslint_count = tonumber(vim.fn.system("ps aux | grep 'vscode-eslint-language-server --stdio' | grep -v grep | wc -l")) or 0
  
  if vtsls_count > 1 then
    local vtsls_result = vim.fn.system("ps aux | grep 'vtsls --stdio' | grep -v grep | head -n -1")
    for line in vtsls_result:gmatch("[^\n]+") do
      local pid = line:match("^%S+%s+(%d+)")
      if pid then
        os.execute(string.format("kill -TERM %s 2>/dev/null", pid))
        cleaned = cleaned + 1
      end
    end
  end
  
  if eslint_count > 1 then
    local eslint_result = vim.fn.system("ps aux | grep 'vscode-eslint-language-server --stdio' | grep -v grep | head -n -1")
    for line in eslint_result:gmatch("[^\n]+") do
      local pid = line:match("^%S+%s+(%d+)")
      if pid then
        os.execute(string.format("kill -TERM %s 2>/dev/null", pid))
        cleaned = cleaned + 1
      end
    end
  end
  
  if cleaned > 0 then
    vim.notify(string.format("🧹 孤児プロセス %d個を削除", cleaned))
  end
end

-- 自動クリーンアップの開始（唯一の公開関数）
function M.start_periodic_cleanup()
  local timer = vim.loop.new_timer()
  
  -- 15分間隔で実行
  timer:start(900000, 900000, vim.schedule_wrap(cleanup_orphan_processes))
  
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
      end
    end,
    once = true
  })
end

return M