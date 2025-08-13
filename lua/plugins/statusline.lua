--[[
機能概要: LazyVimデフォルトlualineにClaude Code使用量表示を追加
設定内容: 非同期ccusage実行でUIブロックを回避、1分間隔キャッシュで軽量化
キーバインド: なし（ステータスライン表示のみ）
--]]
return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      local function get_claude_usage()
        local cache = vim.g.claude_usage_cache or {}
        local current_time = os.time()

        -- 1分キャッシュでパフォーマンス最適化
        if cache.timestamp and (current_time - cache.timestamp) < 60 then
          return cache.data or ""
        end

        -- 非同期ccusage実行（UIブロック回避）
        vim.system(
          { "/Users/ren/.nodenv/versions/22.18.0/bin/ccusage", "blocks", "--active", "--json" },
          { text = true },
          function(result)
            if result.code ~= 0 or not result.stdout or result.stdout == "" then
              vim.g.claude_usage_cache = { timestamp = current_time, data = "" }
              return
            end

            local ok, data = pcall(vim.json.decode, result.stdout)
            if not ok or not data or not data.blocks or #data.blocks == 0 then
              vim.g.claude_usage_cache = { timestamp = current_time, data = "" }
              return
            end

            local block = data.blocks[1]
            if not block.isActive then
              vim.g.claude_usage_cache = { timestamp = current_time, data = "" }
              return
            end

            local cost = block.costUSD and string.format("$%.2f", block.costUSD) or "$0.00"
            local remaining_time = ""
            
            if block.projection and block.projection.remainingMinutes then
              local remaining_minutes = block.projection.remainingMinutes
              local hours = math.floor(remaining_minutes / 60)
              local minutes = remaining_minutes % 60
              remaining_time = string.format("%dh %dm", hours, minutes)
            end

            vim.g.claude_usage_cache = {
              timestamp = current_time,
              data = string.format("⏱ %s | %s", remaining_time, cost),
            }
          end
        )

        return cache.data or ""
      end

      -- Claude使用量セクション設定
      opts.sections = opts.sections or {}
      opts.sections.lualine_x = opts.sections.lualine_x or {}

      table.insert(opts.sections.lualine_x, 1, {
        get_claude_usage,
        color = { fg = "#f4a261" },
        cond = function()
          return get_claude_usage() ~= ""
        end,
      })

      return opts
    end,
  },
}
