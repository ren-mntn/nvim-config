--[[
機能概要: API Route Jumper - apiClient()呼び出しから対応するサーバーファイルへジャンプ
設定内容: API呼び出し検出、仮想テキスト表示、Telescope統合、ジャンプ機能
キーバインド: ga (API Jump), <leader>as (API Search)
--]]
return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  keys = {
    {
      "ga",
      function()
        -- カーソル位置のAPI呼び出しを取得（改良版）
        local bufnr = vim.api.nvim_get_current_buf()
        local cursor_line, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local text = table.concat(lines, "\n")

        -- カーソル位置を文字位置に変換（範囲チェック付き）
        local cursor_pos = 0
        for i = 1, math.min(cursor_line - 1, #lines) do
          if lines[i] then
            cursor_pos = cursor_pos + #lines[i] + 1 -- +1 for newline
          end
        end
        -- カーソル列も範囲チェック
        local current_line = lines[cursor_line] or ""
        cursor_pos = cursor_pos + math.min(cursor_col, #current_line)

        -- apiClient()の位置を全て見つける
        local start_pos = 1
        while true do
          local api_start = text:find("apiClient%(%)", start_pos)
          if not api_start then
            break
          end

          local after_api_client = text:sub(api_start)

          -- 1行分のAPI呼び出しを取得（セミコロンまたは改行まで）
          local line_end = after_api_client:find(";") or after_api_client:find("\n") or #after_api_client
          local api_line = after_api_client:sub(1, line_end)
          local api_part = ""

          -- HTTPメソッドを含む行かどうかチェック
          if
            api_line:match("%.%$?get%s*%(")
            or api_line:match("%.%$?post%s*%(")
            or api_line:match("%.%$?put%s*%(")
            or api_line:match("%.%$?delete%s*%(")
          then
            api_part = api_line:gsub(";$", ""):gsub("\n$", "")
          end

          -- useAspidaQueryパターンもチェック（コンマを含む場合）
          if api_line:match(",") and not api_line:match("%.%$?[gpd][ueo][tsl]") then
            -- コンマまでを取得
            local comma_pos = api_line:find(",")
            api_part = api_line:sub(1, comma_pos - 1)
          end

          -- カーソルがこのAPI呼び出しの範囲内にあるか確認
          if api_part ~= "" then
            local api_end = api_start + #api_part - 1
            if cursor_pos >= api_start and cursor_pos <= api_end then
              -- サーバーファイルを開く
              require("plugins.api-route-jumper.core").jump_to_server_file(api_part)
              return
            end
          end

          start_pos = api_start + 1
        end

        vim.notify("No API call found at cursor position", vim.log.levels.INFO)
      end,
      desc = "Jump to API server file",
    },
    {
      "<leader>as",
      function()
        require("plugins.api-route-jumper.core").telescope_api_calls()
      end,
      desc = "Search API calls",
    },
  },
  config = function()
    -- API Route Jumper Core Module
    local M = {}

    -- API Route Jumper設定
    local api_jumper = {
      server_route_root = "apps/server/src/routes/",
      api_root_name = "app",
      -- マルチライン対応パターン（複数のHTTPメソッドに対応）
      api_patterns = {
        "apiClient%(%)[%s%S]*%.put%s*%b()",
        "apiClient%(%)[%s%S]*%.get%s*%b()",
        "apiClient%(%)[%s%S]*%.post%s*%b()",
        "apiClient%(%)[%s%S]*%.delete%s*%b()",
        "apiClient%(%)[%s%S]*%.%$put%s*%b()",
        "apiClient%(%)[%s%S]*%.%$get%s*%b()",
        "apiClient%(%)[%s%S]*%.%$post%s*%b()",
        "apiClient%(%)[%s%S]*%.%$delete%s*%b()",
      },
    }

    -- グローバル設定として保存
    vim.g.api_route_jumper = api_jumper

    -- APIコールからサーバーパスを生成（改良版）
    local function generate_server_path(api_call)
      -- apiClient()の位置を探す
      local start_pos = api_call:find("apiClient%(%)")
      if not start_pos then
        return ""
      end

      -- apiClient()以降の文字列を取得
      local after_api_client = api_call:sub(start_pos)

      -- HTTPメソッドまたはコンマまでの部分を抽出（括弧のバランスを考慮）
      local api_part = ""
      local paren_depth = 0
      local in_string = false
      local string_char = nil
      local i = 1

      while i <= #after_api_client do
        local char = after_api_client:sub(i, i)
        local next_chars = after_api_client:sub(i, i + 3)

        -- 文字列の処理
        if not in_string and (char == '"' or char == "'" or char == "`") then
          in_string = true
          string_char = char
        elseif in_string and char == string_char then
          -- エスケープされていない場合のみ
          if after_api_client:sub(i - 1, i - 1) ~= "\\" then
            in_string = false
            string_char = nil
          end
        end

        -- 文字列内でない場合のみ括弧とコンマを処理
        if not in_string then
          -- 括弧の深さを追跡
          if char == "(" then
            paren_depth = paren_depth + 1
          elseif char == ")" then
            paren_depth = paren_depth - 1
          end

          -- トップレベル（括弧の外）でコンマまたはHTTPメソッドを見つけた場合、そこで終了
          if paren_depth == 0 then
            -- HTTPメソッド（.get, .post, .put, .delete）のチェック
            if
              next_chars:match("^%.%$?get")
              or next_chars:match("^%.%$?pos")
              or next_chars:match("^%.%$?put")
              or next_chars:match("^%.%$?del")
            then
              break
            end
            -- トップレベルのコンマで終了
            if char == "," then
              break
            end
          end
        end

        api_part = api_part .. char
        i = i + 1
      end

      -- 改行と余分な空白を除去
      api_part = api_part:gsub("%s+", "")

      -- ドットで分割
      local parts = {}
      for part in api_part:gmatch("[^%.]+") do
        table.insert(parts, part)
      end

      local route_parts = {}
      -- "apiClient()"を除去（インデックス1をスキップ）
      for i = 2, #parts do
        local part = parts[i]
        if part and part ~= "" then
          -- パラメータを除去
          part = part:gsub("%b()", "")

          -- 空文字チェック
          if part ~= "" then
            -- パラメータ名（_で始まる）はそのまま、それ以外の_は-に変換
            if part:match("^_") then
              table.insert(route_parts, part)
            else
              local converted = part:gsub("_", "-")
              table.insert(route_parts, converted)
            end
          end
        end
      end

      return table.concat(route_parts, "/")
    end

    -- API呼び出しを検出する関数（最終改良版）
    local function find_api_calls(bufnr)
      bufnr = bufnr or vim.api.nvim_get_current_buf()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local text = table.concat(lines, "\n")

      local calls = {}

      -- apiClient()の位置を全て見つける
      local start_pos = 1
      while true do
        local api_start = text:find("apiClient%(%)", start_pos)
        if not api_start then
          break
        end

        local after_api_client = text:sub(api_start)

        -- 1行分のAPI呼び出しを取得（セミコロンまたは改行まで）
        local line_end = after_api_client:find(";") or after_api_client:find("\n") or #after_api_client
        local api_line = after_api_client:sub(1, line_end)

        -- HTTPメソッドを含む行かどうかチェック
        if
          api_line:match("%.%$?get%s*%(")
          or api_line:match("%.%$?post%s*%(")
          or api_line:match("%.%$?put%s*%(")
          or api_line:match("%.%$?delete%s*%(")
        then
          -- サーバーパスを生成
          local path = generate_server_path(api_line)

          if path ~= "" then
            -- 行番号と列番号を計算
            local line_num = 1
            local col_num = 1
            local pos = 1

            for i, line in ipairs(lines) do
              local line_end_pos = pos + #line
              if api_start <= line_end_pos then
                line_num = i
                col_num = math.max(1, api_start - pos + 1)
                break
              end
              pos = line_end_pos + 1 -- +1 for newline
            end

            table.insert(calls, {
              text = api_line:gsub(";$", ""):gsub("\n$", ""),
              line = line_num,
              col = col_num,
              path = path,
              start_pos = api_start,
              end_pos = api_start + line_end - 1,
            })
          end
        end

        -- useAspidaQueryパターンもチェック（コンマを含む場合）
        if api_line:match(",") and not api_line:match("%.%$?[gpd][ueo][tsl]") then
          -- コンマまでを取得
          local comma_pos = api_line:find(",")
          local api_part = api_line:sub(1, comma_pos - 1)
          local path = generate_server_path(api_part)

          if path ~= "" then
            -- 行番号と列番号を計算
            local line_num = 1
            local col_num = 1
            local pos = 1

            for i, line in ipairs(lines) do
              local line_end_pos = pos + #line
              if api_start <= line_end_pos then
                line_num = i
                col_num = math.max(1, api_start - pos + 1)
                break
              end
              pos = line_end_pos + 1 -- +1 for newline
            end

            table.insert(calls, {
              text = api_part,
              line = line_num,
              col = col_num,
              path = path,
              start_pos = api_start,
              end_pos = api_start + comma_pos - 2,
            })
          end
        end

        start_pos = api_start + 1
      end

      return calls
    end

    -- サーバーファイルを開く
    function M.jump_to_server_file(api_call)
      local config = vim.g.api_route_jumper
      local route_path = generate_server_path(api_call)
      local server_path = config.server_route_root:gsub("/$", "") .. "/" .. route_path .. "/_handlers.ts"

      -- ワークスペースルートを取得
      local workspace_root = vim.fn.getcwd()
      local full_path = workspace_root .. "/" .. server_path

      -- ファイルを開く
      local ok, _ = pcall(vim.cmd, "edit " .. full_path)
      if not ok then
        vim.notify("Server file not found: " .. server_path, vim.log.levels.WARN)
      end
    end

    -- API呼び出し検索（vim.ui.select使用でエラー回避）
    function M.telescope_api_calls()
      -- バッファの状態確認
      local bufnr = vim.api.nvim_get_current_buf()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        vim.notify("Invalid buffer", vim.log.levels.ERROR)
        return
      end

      local calls = find_api_calls()

      if #calls == 0 then
        vim.notify("No API calls found in current buffer", vim.log.levels.INFO)
        return
      end

      -- 各callエントリの妥当性を検証
      local valid_calls = {}
      for _, call in ipairs(calls) do
        if call.line and call.col and call.text and call.path then
          table.insert(valid_calls, call)
        end
      end

      if #valid_calls == 0 then
        vim.notify("No valid API calls found", vim.log.levels.INFO)
        return
      end

      -- vim.ui.selectを使用（エラーが発生しない安全な方法）
      local items = {}
      for _, call in ipairs(valid_calls) do
        local display = string.format("%d:%d → %s", call.line, call.col, call.path)
        table.insert(items, {
          display = display,
          call = call
        })
      end

      vim.ui.select(items, {
        prompt = "API Calls:",
        format_item = function(item)
          return item.display
        end,
      }, function(choice)
        if choice and choice.call then
          M.jump_to_server_file(choice.call.text)
        end
      end)
    end

    -- 仮想テキスト表示の設定
    local namespace = vim.api.nvim_create_namespace("api_route_jumper")
    local enabled_bufs = {}

    local function show_virtual_text()
      local bufnr = vim.api.nvim_get_current_buf()

      -- ファイルタイプチェック
      local ft = vim.bo[bufnr].filetype
      if not (ft == "typescript" or ft == "typescriptreact" or ft == "javascript" or ft == "javascriptreact") then
        return
      end

      -- 既存の仮想テキストをクリア
      vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

      local calls = find_api_calls(bufnr)
      for _, call in ipairs(calls) do
        -- マルチライン呼び出しでも正しい行に表示（最終行に表示）
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local text = table.concat(lines, "\n")
        local end_line = 1
        local pos = 1

        for i, line in ipairs(lines) do
          local line_end = pos + #line
          if call.end_pos <= line_end then
            end_line = i
            break
          end
          pos = line_end + 1
        end

        -- 安全に仮想テキストを設定（HTTPメソッドの行に表示）
        local safe_line = math.min(end_line - 1, #lines - 1)
        safe_line = math.max(0, safe_line)
        pcall(vim.api.nvim_buf_set_extmark, bufnr, namespace, safe_line, 0, {
          virt_text = { { "  → " .. call.path, "Comment" } },
          virt_text_pos = "eol",
        })
      end

      enabled_bufs[bufnr] = true
    end

    -- バッファ固有の自動コマンドグループ
    local augroup = vim.api.nvim_create_augroup("ApiRouteJumper", { clear = true })

    -- ファイルタイプ別の自動コマンド
    vim.api.nvim_create_autocmd({ "FileType" }, {
      pattern = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
      group = augroup,
      callback = function(args)
        -- 遅延実行で安全性を確保
        vim.defer_fn(function()
          if vim.api.nvim_buf_is_valid(args.buf) then
            show_virtual_text()
          end
        end, 100)
      end,
    })

    -- テキスト変更時の更新（デバウンス付き）
    local update_timer = nil
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
      group = augroup,
      callback = function(args)
        if not enabled_bufs[args.buf] then
          return
        end

        -- タイマーをキャンセル
        if update_timer then
          vim.fn.timer_stop(update_timer)
        end

        -- 遅延更新
        update_timer = vim.fn.timer_start(500, function()
          if vim.api.nvim_buf_is_valid(args.buf) then
            show_virtual_text()
          end
          update_timer = nil
        end)
      end,
    })

    -- バッファ削除時のクリーンアップ
    vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
      group = augroup,
      callback = function(args)
        enabled_bufs[args.buf] = nil
      end,
    })

    -- モジュールをグローバルに公開
    _G.require = _G.require or require
    package.loaded["plugins.api-route-jumper.core"] = M
  end,
}
