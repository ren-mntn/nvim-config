return {
  -- LazyVimのデフォルトlualineにClaude Code使用量表示を追加
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      -- Claude Code使用量取得関数
      local function get_claude_usage()
        local cache = vim.g.claude_usage_cache or {}
        local current_time = os.time()

        -- 30秒キャッシュ
        if cache.timestamp and (current_time - cache.timestamp) < 30 then
          return cache.data
        end

        -- ccusage blocks --active --json から取得（絶対パス使用）
        local handle = io.popen("/Users/ren/.nodenv/versions/22.18.0/bin/ccusage blocks --active --json 2>/dev/null")
        if not handle then
          return ""
        end

        local result = handle:read("*a")
        handle:close()

        if not result or result == "" then
          return ""
        end

        local ok, data = pcall(vim.json.decode, result)
        if not ok or not data or not data.blocks or #data.blocks == 0 then
          return ""
        end

        local block = data.blocks[1]
        if not block.isActive then
          return ""
        end

        -- コストと残り時間を表示
        local cost = block.costUSD and string.format("$%.2f", block.costUSD) or "$0.00"

        -- 残り時間を取得（projection.remainingMinutes）
        local remaining_time = ""
        if block.projection and block.projection.remainingMinutes then
          local remaining_minutes = block.projection.remainingMinutes
          local hours = math.floor(remaining_minutes / 60)
          local minutes = remaining_minutes % 60
          remaining_time = string.format("%dh %dm", hours, minutes)
        end

        local display_text = string.format("⏱ %s | %s", remaining_time, cost)

        -- キャッシュ更新
        vim.g.claude_usage_cache = {
          timestamp = current_time,
          data = display_text,
        }

        return display_text
      end

      -- Claude Code使用量セクション
      local claude_usage = {
        get_claude_usage,
        color = { fg = "#f4a261" },
        cond = function()
          local usage = get_claude_usage()
          return usage ~= ""
        end,
      }

      -- ステータスラインの設定をマージ
      opts.sections = opts.sections or {}
      opts.sections.lualine_x = opts.sections.lualine_x or {}

      -- 右側セクションにClaude使用量を追加
      table.insert(opts.sections.lualine_x, 1, claude_usage)

      return opts
    end,
  },
}
