-- ~/.config/nvim/lua/plugins/session-manager.lua
-- セッション管理（VSCode風の前回状態復元）
return {
  -- 自動セッション管理
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {
      -- セッションを保存するディレクトリ
      dir = vim.fn.expand(vim.fn.stdpath("state") .. "/sessions/"),
      -- 自動保存の設定
      options = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp" },
      -- 前回のセッションを自動復元
      pre_save = function()
        -- 一時的なバッファやターミナルは保存しない
        vim.api.nvim_exec_autocmds("User", { pattern = "SessionSavePre" })
      end,
    },
    keys = {
      -- セッション復元
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
      -- 最後のセッション復元
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
      -- 現在のディレクトリのセッション復元
      { "<leader>qd", function() require("persistence").load({ dir = vim.fn.getcwd() }) end, desc = "Restore Dir Session" },
      -- セッション保存停止
      { "<leader>qS", function() require("persistence").stop() end, desc = "Don't Save Current Session" },
    },
  },

  -- Snacks.nvimのdashboard設定を拡張（セッション復元ボタン追加）
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      -- 既存のdashboard設定を拡張
      if opts.dashboard and opts.dashboard.sections then
        -- セッション復元のキーを追加
        local keys_section = nil
        for i, section in ipairs(opts.dashboard.sections) do
          if section.section == "keys" then
            keys_section = section
            break
          end
        end
        
        if not keys_section then
          -- keys セクションが見つからない場合は新規作成
          table.insert(opts.dashboard.sections, 2, { section = "keys", gap = 1, padding = 1 })
        end
      end
      
      return opts
    end,
  },
}