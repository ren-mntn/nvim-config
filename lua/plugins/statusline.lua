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
      -- プロセス実行中フラグを追加して重複実行を防ぐ
      local is_fetching = false

      local function get_claude_usage()
        local cache = vim.g.claude_usage_cache or {}
        local current_time = os.time()

        -- キャッシュが有効な場合は即座に返す（2分間）
        if cache.timestamp and (current_time - cache.timestamp) < 120 then
          return cache.data or ""
        end

        -- 既に実行中の場合はキャッシュデータを返す
        if is_fetching then
          return cache.data or ""
        end

        -- フラグを立てて実行開始
        is_fetching = true

        -- 非同期ccusage実行（UIブロック回避）
        vim.system(
          { "/Users/ren/.nodenv/versions/22.18.0/bin/ccusage", "blocks", "--active", "--json" },
          { text = true, timeout = 5000 }, -- 5秒タイムアウトを追加
          function(result)
            -- 実行完了フラグをリセット
            is_fetching = false

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

      -- タイマーベースの更新（カーソル移動とは独立）
      local timer = vim.loop.new_timer()
      local cached_usage = ""

      -- 初回実行と定期更新（2分ごと）
      local function update_usage()
        cached_usage = get_claude_usage()
      end

      -- 初回実行
      vim.defer_fn(update_usage, 1000)

      -- 2分ごとに更新
      timer:start(0, 120000, vim.schedule_wrap(update_usage))

      table.insert(opts.sections.lualine_x, 1, {
        function()
          return cached_usage
        end, -- キャッシュ値を返すだけ
        color = { fg = "#f4a261" },
        cond = function()
          return cached_usage ~= ""
        end,
      })

      return opts
    end,
  },
}
