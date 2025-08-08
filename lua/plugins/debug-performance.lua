-- パフォーマンス監視・デバッグプラグイン設定
return {
  {
    "stevearc/profile.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>dp", function() require("profile").start("*") end, desc = "プロファイリング開始" },
      { "<leader>ds", function() require("profile").stop() end, desc = "プロファイリング停止" },
      { "<leader>dr", function() require("profile").report() end, desc = "レポート表示" },
    },
    config = function()
      local profile = require("profile")
      
      -- 2秒以上かかる操作を自動検出
      profile.instrument_autocmds()
      profile.instrument({
        slow_threshold = 2000, -- 2秒以上で警告
      })
      
      -- デバッグ用の通知関数
      local function notify_slow_operation(name, duration)
        vim.notify(
          string.format("⚠️ 遅い操作検出: %s (%.2fms)", name, duration),
          vim.log.levels.WARN,
          { title = "Performance Alert" }
        )
      end
      
      -- 遅い操作を検出する関数
      local original_vim_fn_system = vim.fn.system
      vim.fn.system = function(...)
        local start = vim.loop.hrtime()
        local result = original_vim_fn_system(...)
        local duration = (vim.loop.hrtime() - start) / 1e6
        
        if duration > 1000 then -- 1秒以上で通知
          notify_slow_operation("vim.fn.system", duration)
        end
        
        return result
      end
    end,
  },
  
  {
    "rcarriga/nvim-notify",
    opts = function(_, opts)
      opts.timeout = 5000
      opts.max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end
      opts.max_width = function()
        return math.floor(vim.o.columns * 0.75)
      end
      return opts
    end,
  },
}