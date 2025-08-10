--[[
機能概要: Git差分可視化・PRレビュー・worktree統合プラグイン
設定内容: VSCode風UI、PRレビュー最適化(--imply-local)、worktree連携、PRコメント表示
キーバインド: 
  <leader>gpr (PR review), <leader>gpw (PR worktree + diffview)
  <leader>gpc (PR inline comments), <leader>gpt (comments terminal)
  <leader>gph (hide comments), <leader>gpa (add comment), <leader>gpv (conversations)
  <leader>gpb (browser), <leader>gps (PR status)
--]]
return {
  -- Git差分可視化・PRレビュー・worktree統合
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      -- VSCode風のキーバインド（Neo-treeと統合）
      { "<leader>gD", "<cmd>DiffviewFileHistory %<cr>", desc = "Git History (現在ファイル)" },
      { "<leader>gC", "<cmd>DiffviewClose<cr>", desc = "Diff View 閉じる" },

      -- ステージング操作（VSCode風）
      { "<leader>gv", "<cmd>DiffviewOpen HEAD~1<cr>", desc = "前回コミットとの差分" },

      -- PRレビュー最適化機能
      {
        "<leader>gpr",
        function()
          -- PRレビュー用: origin/HEAD...HEAD --imply-local でLSP機能付き差分
          local success, error_msg = pcall(function()
            vim.cmd("DiffviewOpen origin/HEAD...HEAD --imply-local")
          end)

          if not success then
            -- origin/HEADが設定されていない場合の対処
            vim.notify("Setting up origin/HEAD...", vim.log.levels.INFO)
            vim.system({ "git", "remote", "set-head", "-a", "origin" }, {}, function(result)
              vim.schedule(function()
                if result.code == 0 then
                  vim.cmd("DiffviewOpen origin/HEAD...HEAD --imply-local")
                  vim.notify("PR review opened with LSP support", vim.log.levels.INFO)
                else
                  -- fallback: mainブランチを使用
                  vim.cmd("DiffviewOpen origin/main...HEAD --imply-local")
                  vim.notify("PR review opened (fallback to main)", vim.log.levels.WARN)
                end
              end)
            end)
          else
            vim.notify("PR review opened with LSP support", vim.log.levels.INFO)
          end
        end,
        desc = "PR Review (LSP対応)",
      },

      -- PR個別コミット履歴
      {
        "<leader>gpR",
        function()
          vim.cmd("DiffviewFileHistory --range=origin/HEAD...HEAD --right-only --no-merges")
          vim.notify("PR commits history opened", vim.log.levels.INFO)
        end,
        desc = "PR Commits History",
      },

      -- PR worktree 統合ワークフロー
      {
        "<leader>gpw",
        function()
          -- まず現在のユーザー名を取得（エラーハンドリング強化）
          local current_user = nil
          local user_success, current_user_result = pcall(function()
            return vim.system({ "gh", "api", "user", "--jq", ".login" }, { text = true }):wait()
          end)

          if user_success and current_user_result.code == 0 then
            current_user = vim.trim(current_user_result.stdout)
          else
            -- ユーザー取得に失敗してもPR一覧は表示する
            vim.notify("Warning: Could not get current user, review status may be inaccurate", vim.log.levels.WARN)
          end

          -- gh CLIでPR一覧取得 → 選択 → worktree作成 → diffview開く
          local function get_pr_list()
            -- レビュー状態判定に必要なフィールドを追加
            local success, result = pcall(function()
              return vim
                .system({
                  "gh",
                  "pr",
                  "list",
                  "--state",
                  "open",
                  "--json",
                  "number,title,headRefName,author,reviewRequests,reviews",
                }, { text = true })
                :wait()
            end)

            if not success or result.code ~= 0 then
              local error_msg = result and result.stderr or "unknown error"
              vim.notify("Failed to fetch PRs: " .. error_msg, vim.log.levels.ERROR)
              return {}
            end

            local pr_data = vim.json.decode(result.stdout)
            local pr_items = {}

            -- デバッグコード削除済み

            for _, pr in ipairs(pr_data) do
              -- レビュー状態を詳細に判定
              local status_icon = ""
              local highlight = "Normal"
              local sort_priority = 100 -- デフォルト優先度

              -- 自分がレビュー依頼されているかチェック（複数パターンに対応）
              local review_requested = false
              if current_user and pr.reviewRequests then
                for _, request in ipairs(pr.reviewRequests) do
                  if request then
                    -- パターン1: requestedReviewer.login
                    if request.requestedReviewer and request.requestedReviewer.login == current_user then
                      review_requested = true
                      break
                    end
                    -- パターン2: 直接loginフィールド
                    if request.login == current_user then
                      review_requested = true
                      break
                    end
                    -- パターン3: requestオブジェクト自体がユーザー情報を持つ
                    if type(request) == "string" and request == current_user then
                      review_requested = true
                      break
                    end
                  end
                end
              end

              -- 自分が既にレビューしたかチェック
              local already_reviewed = false
              if current_user and pr.reviews then
                for _, review in ipairs(pr.reviews) do
                  if review.author and review.author.login == current_user then
                    already_reviewed = true
                    break
                  end
                end
              end

              -- 状態に応じてアイコンと色を設定
              -- まず自分のPRかどうかをチェック（最優先で判定）
              if current_user and pr.author and pr.author.login == current_user then
                status_icon = "📤 [自分のPR] "
                highlight = "DiagnosticInfo" -- 青色
                sort_priority = 30 -- 3番目
              elseif review_requested and not already_reviewed then
                status_icon = "☑️ [要レビュー] "
                highlight = "DiagnosticWarn" -- 黄色
                sort_priority = 10 -- 1番目（最優先）
              elseif already_reviewed then
                status_icon = "✅ [レビュー済] "
                highlight = "DiagnosticOk" -- 緑色
                sort_priority = 20 -- 2番目
              else
                status_icon = ""
                sort_priority = 40 -- 4番目（最低）
              end

              table.insert(pr_items, {
                text = string.format("[%d] %s#%d: %s", sort_priority, status_icon, pr.number, pr.title),
                pr_number = pr.number,
                branch = pr.headRefName,
                title = pr.title,
                highlight = highlight,
                sort_priority = sort_priority,
                author = pr.author and pr.author.login or "unknown",
                review_requested = review_requested,
                already_reviewed = already_reviewed,
              })
            end

            -- ソート: 要レビュー > レビュー済み > 自分のPR > その他
            table.sort(pr_items, function(a, b)
              -- デバッグ出力
              print(
                string.format(
                  "Comparing: %d vs %d (priorities: %d vs %d)",
                  a.pr_number,
                  b.pr_number,
                  a.sort_priority,
                  b.sort_priority
                )
              )

              if a.sort_priority ~= b.sort_priority then
                return a.sort_priority < b.sort_priority
              end
              -- 同じ優先度なら番号順（新しいPRが上に来るように）
              return a.pr_number > b.pr_number
            end)

            -- ソート後の順序確認
            print("=== After sort ===")
            for i, item in ipairs(pr_items) do
              print(string.format("%d: [%d] PR #%d", i, item.sort_priority, item.pr_number))
            end

            return pr_items
          end

          local pr_list = get_pr_list()
          if #pr_list == 0 then
            return
          end

          -- Snacks pickerでPR選択
          Snacks.picker({
            source = "static",
            items = pr_list,
            title = "📋 PR一覧 [☑️要レビュー ✅レビュー済 📤自分のPR]",
            format = function(item, picker)
              return { { item.text, item.highlight } }
            end,
            confirm = function(picker)
              local item = picker:current()
              if not item then
                return
              end

              picker:close()

              -- gh pr checkout
              vim.notify("Checking out PR #" .. item.pr_number .. "...", vim.log.levels.INFO)
              vim.system({ "gh", "pr", "checkout", tostring(item.pr_number) }, {}, function(checkout_result)
                vim.schedule(function()
                  if checkout_result.code ~= 0 then
                    vim.notify("Failed to checkout PR #" .. item.pr_number, vim.log.levels.ERROR)
                    return
                  end

                  -- worktree作成関数を呼び出し（git-worktree.luaと連携）
                  local git_worktree_ok, git_worktree = pcall(require, "git-worktree")
                  if git_worktree_ok and git_worktree.create_worktree_for_branch then
                    -- git-worktree.luaの関数を使用
                    git_worktree.create_worktree_for_branch(item.branch, function(worktree_path)
                      if worktree_path then
                        -- worktree作成後、diffviewでPRレビュー開始
                        vim.defer_fn(function()
                          vim.cmd("DiffviewOpen origin/HEAD...HEAD --imply-local")
                          vim.notify("PR worktree + diffview opened for #" .. item.pr_number, vim.log.levels.INFO)
                        end, 1000)
                      end
                    end)
                  else
                    -- fallback: 直接diffviewを開く
                    vim.cmd("DiffviewOpen origin/HEAD...HEAD --imply-local")
                    vim.notify("PR diffview opened for #" .. item.pr_number .. " (no worktree)", vim.log.levels.INFO)
                  end
                end)
              end)
            end,
          })
        end,
        desc = "PR Worktree + Diffview",
      },

      -- PRコメント診断表示機能（インライン）
      {
        "<leader>gpc",
        function()
          -- PRコメント用のカスタムハイライトグループを設定
          vim.api.nvim_set_hl(0, "PRComment", { fg = "#ffffff", bg = "#444444" })
          vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesInfo", { fg = "#ffffff", bg = "#444444" })

          -- キャッシュクリアして手動で再取得
          _G.pr_comments_cache = nil
          vim.notify("🔄 PRコメントキャッシュをクリアして診断表示します", vim.log.levels.INFO)

          -- PRコメントを診断API（インライン）で表示
          local function show_pr_comments_inline()
            -- まず基本的なPR情報を取得
            local success, result = pcall(function()
              return vim
                .system({
                  "gh",
                  "pr",
                  "view",
                  "--json",
                  "number,reviews,comments,latestReviews,url",
                }, { text = true })
                :wait()
            end)

            if not success or result.code ~= 0 then
              vim.notify(
                "PRコメントを取得できませんでした: " .. (result.stderr or "unknown error"),
                vim.log.levels.ERROR
              )
              return
            end

            local pr_data = vim.json.decode(result.stdout)

            -- インラインコメント（コード行への直接コメント）を取得
            local inline_comments = {}
            local inline_success, inline_result = pcall(function()
              return vim
                .system({
                  "gh",
                  "api",
                  "repos/:owner/:repo/pulls/" .. pr_data.number .. "/comments",
                  "--jq",
                  "map(select(.position != null)) | map({body: .body, path: .path, line: .line, position: .position, user: .user.login, original_line: .original_line})",
                }, { text = true })
                :wait()
            end)

            if inline_success and inline_result.code == 0 then
              local success_parse, parsed_comments = pcall(function()
                return vim.json.decode(inline_result.stdout)
              end)
              if success_parse then
                inline_comments = parsed_comments
              end
            end

            -- 現在のファイルパスを取得
            local current_file = vim.fn.expand("%:.")

            -- DiffViewの場合は実際のファイルパスを取得
            if current_file:match("^diffview://") then
              local success_diffview, diffview_lib = pcall(require, "diffview.lib")
              if success_diffview then
                local view = diffview_lib.get_current_view()
                if view then
                  local file = view:infer_cur_file()
                  if file and file.path then
                    current_file = file.path
                  end
                end
              end
            end

            -- 診断APIでPRコメントを設定
            local namespace = vim.api.nvim_create_namespace("pr_comments_diagnostics")
            vim.diagnostic.reset(namespace, 0)

            local comment_count = 0
            local buffer_line_count = vim.api.nvim_buf_line_count(0)
            local diagnostics = {}

            -- インラインコメント処理
            for _, inline_comment in ipairs(inline_comments) do
              if inline_comment.path == current_file and inline_comment.body and inline_comment.user then
                comment_count = comment_count + 1
                local line_num = inline_comment.line or inline_comment.original_line or inline_comment.position
                local target_line = math.max(0, math.min(buffer_line_count - 1, (tonumber(line_num) or 1) - 1))

                -- コメント内容を整形（改行文字を完全に除去）
                local comment_text = inline_comment
                  .body
                  :gsub("\r\n", " ") -- Windows改行をスペースに
                  :gsub("\r", " ") -- CRをスペースに
                  :gsub("\n", " ") -- LFをスペースに
                  :gsub("%s+", " ") -- 連続するスペースを1つに

                -- PRコメント診断を作成（名前の後に改行を追加）
                local full_message = "💬 " .. inline_comment.user .. ":\n" .. comment_text

                table.insert(diagnostics, {
                  lnum = target_line,
                  col = 0,
                  message = full_message,
                  severity = vim.diagnostic.severity.INFO,
                  source = "PR Comment",
                })
              end
            end

            -- 診断を設定（現在のバッファのみ）
            if #diagnostics > 0 then
              local current_bufnr = vim.api.nvim_get_current_buf()

              -- 診断データを設定
              vim.diagnostic.set(namespace, current_bufnr, diagnostics)

              -- namespace固有の表示設定（テキスト折り返しあり）
              vim.diagnostic.config({
                virtual_text = false,
                underline = false,
                signs = false,
                virtual_lines = {
                  only_current_line = false,
                  highlight_whole_line = false,
                  -- 60文字で改行するフォーマット関数
                  format = function(diagnostic)
                    local max_width = 60
                    local lines = {}
                    local current_line = ""
                    local message = diagnostic.message

                    -- 文字を1つずつ処理して強制改行
                    for i = 1, vim.fn.strchars(message) do
                      local char = vim.fn.strcharpart(message, i - 1, 1)
                      local test_line = current_line .. char

                      if vim.fn.strdisplaywidth(test_line) <= max_width then
                        current_line = test_line
                      else
                        -- 現在の行を追加して新しい行を開始
                        if current_line ~= "" then
                          table.insert(lines, current_line)
                        end
                        current_line = char
                      end
                    end

                    -- 最後の行を追加
                    if current_line ~= "" then
                      table.insert(lines, current_line)
                    end

                    -- 複数行を改行で結合して返す
                    return table.concat(lines, "\n")
                  end,
                },
              }, namespace)
            end

            -- ステータス表示
            local inline_count = 0
            for _, inline_comment in ipairs(inline_comments) do
              if inline_comment.path == current_file then
                inline_count = inline_count + 1
              end
            end

            local status_text = string.format(
              "PR #%s: %d件のインラインコメント（診断表示中）",
              pr_data.number,
              inline_count
            )
            vim.notify(status_text, vim.log.levels.INFO)

            if inline_count == 0 then
              vim.notify("⚠️ このファイルにはPRコメントがありません", vim.log.levels.WARN)
            end
          end

          show_pr_comments_inline()
        end,
        desc = "PR Comments Inline Display (診断API)",
      },

      -- PRコメントターミナル表示
      {
        "<leader>gpt",
        function()
          local function get_current_pr()
            local success, result = pcall(function()
              return vim.system({ "gh", "pr", "view", "--json", "number" }, { text = true }):wait()
            end)

            if success and result.code == 0 then
              local pr_data = vim.json.decode(result.stdout)
              return pr_data.number
            end
            return nil
          end

          local current_pr = get_current_pr()

          if current_pr then
            vim.cmd("split")
            vim.cmd("terminal gh pr view " .. current_pr .. " --comments")
            vim.cmd("startinsert")
            vim.notify("📄 PR #" .. current_pr .. " コメントをターミナル表示", vim.log.levels.INFO)
          else
            vim.ui.input({
              prompt = "PR番号を入力: ",
              default = "",
            }, function(input)
              if input and input ~= "" then
                vim.cmd("tabnew")
                vim.cmd("terminal gh pr view " .. input .. " --comments")
                vim.cmd("startinsert")
                vim.notify("📄 PR #" .. input .. " コメントをターミナル表示", vim.log.levels.INFO)
              end
            end)
          end
        end,
        desc = "PR Comments Terminal (ターミナル表示)",
      },

      -- PRコメント診断をクリア
      {
        "<leader>gph",
        function()
          local namespace = vim.api.nvim_create_namespace("pr_comments_diagnostics")
          local current_bufnr = vim.api.nvim_get_current_buf()
          vim.diagnostic.reset(namespace, current_bufnr)

          vim.notify("🧹 PRコメント診断をクリアしました", vim.log.levels.INFO)
        end,
        desc = "PRコメント診断クリア",
      },

      -- PRコメントのデバッグ情報表示
      {
        "<leader>gpd",
        function()
          vim.cmd("tabnew")
          vim.cmd("terminal gh pr view --json 'number,reviews,comments,latestReviews' | jq .")
          vim.cmd("startinsert")
          vim.notify("📊 PRデータのデバッグ情報を表示中...", vim.log.levels.INFO)
        end,
        desc = "PR Debug Info",
      },

      -- 仮想テキスト表示のテスト
      {
        "<leader>gpT",
        function()
          -- シンプルな仮想テキストテスト
          local namespace = vim.api.nvim_create_namespace("test_virtual_text")

          -- 既存をクリア
          vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)

          -- 現在の行に仮想テキストを追加（行末）
          local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1

          vim.api.nvim_buf_set_extmark(0, namespace, current_line, 0, {
            virt_text = {
              {
                " 🔥 行末テスト",
                "ErrorMsg",
              },
            },
            virt_text_pos = "eol",
            hl_mode = "combine",
          })

          -- 現在の行の下に仮想行を追加（インラインコメント風）
          local test_virt_lines_namespace = vim.api.nvim_create_namespace("test_virt_lines")
          vim.api.nvim_buf_set_extmark(0, test_virt_lines_namespace, current_line, 0, {
            virt_lines = {
              {
                { "  ├─ ", "Comment" },
                { "💬 テストユーザー: ", "DiagnosticWarn" },
                {
                  "これは行の下に表示されるテストコメントです。GitHubライクな表示！",
                  "Comment",
                },
              },
              {
                { "  │  ", "Comment" },
                { "長いコメントは複数行に分かれて表示されます。", "Comment" },
              },
            },
            virt_lines_above = false, -- 該当行の下に表示
            hl_mode = "combine",
          })

          vim.notify(
            "🧪 仮想テキスト（行末）と仮想行（下部）の両方をテスト表示しました",
            vim.log.levels.INFO
          )

          -- 10秒後に自動クリア
          vim.defer_fn(function()
            vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
            vim.api.nvim_buf_clear_namespace(0, test_virt_lines_namespace, 0, -1)
            vim.notify("🧹 テスト用仮想テキスト/仮想行を削除しました", vim.log.levels.INFO)
          end, 10000)
        end,
        desc = "Test Virtual Text & Lines Display",
      },

      -- PRコメントに返信・ディスカッション
      {
        "<leader>gpa",
        function()
          -- PRレビューコメントを追加
          local current_file = vim.fn.expand("%:p")
          local current_line = vim.api.nvim_win_get_cursor(0)[1]

          vim.ui.input({
            prompt = "💬 レビューコメント: ",
            default = "",
          }, function(comment)
            if comment and comment ~= "" then
              -- gh CLIでコメントを追加
              local cmd = string.format('gh pr comment --body "%s"', comment:gsub('"', '\\"'))

              vim.system({ "sh", "-c", cmd }, {}, function(result)
                vim.schedule(function()
                  if result.code == 0 then
                    vim.notify("✓ コメントを追加しました", vim.log.levels.INFO)
                    -- インラインコメントを更新
                    vim.defer_fn(function()
                      vim.cmd("normal! <leader>gpc")
                    end, 1000)
                  else
                    vim.notify("❌ コメントの追加に失敗しました", vim.log.levels.ERROR)
                  end
                end)
              end)
            end
          end)
        end,
        desc = "Add PR Review Comment",
      },

      -- PRコンバーセーションを解決
      {
        "<leader>gpv",
        function()
          -- 現在のPRのコンバーセーション一覧を表示
          local success, result = pcall(function()
            return vim
              .system({
                "gh",
                "pr",
                "view",
                "--json",
                "reviews",
              }, { text = true })
              :wait()
          end)

          if success and result.code == 0 then
            local pr_data = vim.json.decode(result.stdout)
            local conversations = {}

            if pr_data.reviews then
              for i, review in ipairs(pr_data.reviews) do
                if review.body and review.body ~= "" then
                  table.insert(conversations, {
                    text = string.format("#%d: %s (%s)", i, review.body:sub(1, 60) .. "...", review.author.login),
                    review_id = review.id,
                    author = review.author.login,
                    body = review.body,
                  })
                end
              end
            end

            if #conversations == 0 then
              vim.notify("🤷 解決可能なコンバーセーションはありません", vim.log.levels.INFO)
              return
            end

            -- Snacks pickerでコンバーセーション選択
            Snacks.picker({
              source = "static",
              items = conversations,
              title = "💬 PR Conversations [Enter: 詳細表示]",
              format = function(item, picker)
                return { { item.text, "Normal" } }
              end,
              confirm = function(picker)
                local item = picker:current()
                if item then
                  -- コンバーセーション詳細を新しいタブで表示
                  vim.cmd("tabnew")
                  local lines = {
                    "# PR Conversation Details",
                    "",
                    "**Author:** " .. item.author,
                    "**Review ID:** " .. tostring(item.review_id),
                    "",
                    "## Comment:",
                    item.body,
                    "",
                    "---",
                    "**Actions:**",
                    "- Press 'r' to reply",
                    "- Press 'q' to close",
                  }

                  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
                  vim.bo.filetype = "markdown"
                  vim.bo.modifiable = false

                  -- 返信キーマッピング
                  vim.keymap.set("n", "r", function()
                    vim.ui.input({
                      prompt = "💬 返信: ",
                    }, function(reply)
                      if reply and reply ~= "" then
                        local cmd = string.format('gh pr comment --body "%s"', reply:gsub('"', '\\"'))
                        vim.system({ "sh", "-c", cmd }, {}, function(reply_result)
                          vim.schedule(function()
                            if reply_result.code == 0 then
                              vim.notify("✓ 返信しました", vim.log.levels.INFO)
                            else
                              vim.notify("❌ 返信に失敗しました", vim.log.levels.ERROR)
                            end
                          end)
                        end)
                      end
                    end)
                  end, { buffer = true, desc = "返信" })

                  vim.keymap.set("n", "q", "<cmd>bd<cr>", { buffer = true, desc = "閉じる" })
                end
              end,
            })
          else
            vim.notify("コンバーセーションを取得できませんでした", vim.log.levels.ERROR)
          end
        end,
        desc = "PR Conversations & Reply",
      },

      -- PRブラウザで開く
      {
        "<leader>gpb",
        function()
          local success, result = pcall(function()
            return vim.system({ "gh", "pr", "view", "--json", "url" }, { text = true }):wait()
          end)

          if success and result.code == 0 then
            local pr_data = vim.json.decode(result.stdout)
            vim.fn.system("open " .. vim.fn.shellescape(pr_data.url))
            vim.notify("🌍 PRをブラウザで開きました", vim.log.levels.INFO)
          else
            vim.notify("現在のブランチはPRではありません", vim.log.levels.WARN)
          end
        end,
        desc = "Open PR in Browser",
      },

      -- PRレビューステータス表示
      {
        "<leader>gps",
        function()
          local success, result = pcall(function()
            return vim.system({ "gh", "pr", "status" }, { text = true }):wait()
          end)

          if success and result.code == 0 then
            -- 新しいタブでステータス表示
            vim.cmd("tabnew")
            vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(result.stdout, "\n"))
            vim.bo.filetype = "markdown"
            vim.bo.modifiable = false
            vim.notify("📋 PRステータスを表示中...", vim.log.levels.INFO)
          else
            vim.notify("PR情報を取得できませんでした", vim.log.levels.ERROR)
          end
        end,
        desc = "PR Status & Checks",
      },

      -- Neo-tree Gitサイドバーとの連携用
      {
        "<leader>gdf",
        function()
          -- フォーカスされたファイルでDiffviewを開く
          local current_file = vim.fn.expand("%:p")
          if current_file and current_file ~= "" then
            vim.cmd("DiffviewFileHistory " .. current_file)
          else
            vim.cmd("DiffviewOpen")
          end
        end,
        desc = "Diff focused file",
      },
    },

    opts = function(_, opts)
      -- デバッグ（実装時のみ、完了時削除）
      -- print("=== DEBUG: Initial diffview opts ===")
      -- print(vim.inspect(opts))

      -- 安全な初期化
      opts = opts or {}

      -- 設定のマージ（完全上書きではない）
      opts = vim.tbl_deep_extend("force", opts, {
        -- VSCode風の3ペインレイアウト
        view = {
          default = {
            layout = "diff2_horizontal", -- 横並び表示
          },
          file_history = {
            layout = "diff2_horizontal",
          },
        },

        -- ファイルパネルの設定
        file_panel = {
          listing_style = "tree", -- ツリー表示
          tree_options = {
            flatten_dirs = true,
            folder_statuses = "always", -- フォルダステータス表示
          },
          win_config = {
            position = "left",
            width = 35, -- VSCode風のサイドバー幅
            win_opts = {},
          },
        },

        -- PRレビュー最適化: デフォルト引数設定
        default_args = {
          DiffviewOpen = { "--imply-local" }, -- 常にLSP機能を有効化
          DiffviewFileHistory = {},
        },

        -- デフォルトのキーマップ（VSCode風に調整）
        keymaps = {
          view = {
            -- Stage/Unstageファイル
            {
              "n",
              "s",
              function()
                vim.cmd("Git add " .. vim.fn.expand("%:p"))
                vim.notify("Staged: " .. vim.fn.expand("%:t"))
              end,
              { desc = "Stage file" },
            },

            {
              "n",
              "u",
              function()
                vim.cmd("Git reset HEAD " .. vim.fn.expand("%:p"))
                vim.notify("Unstaged: " .. vim.fn.expand("%:t"))
              end,
              { desc = "Unstage file" },
            },

            -- コミット
            { "n", "cc", "<cmd>Git commit<cr>", { desc = "Commit" } },
            { "n", "ca", "<cmd>Git commit --amend<cr>", { desc = "Commit --amend" } },

            -- リフレッシュ
            { "n", "<F5>", "<cmd>DiffviewRefresh<cr>", { desc = "Refresh" } },

            -- ファイルを開く
            {
              "n",
              "<cr>",
              function()
                local lib = require("diffview.lib")
                local view = lib.get_current_view()
                if view then
                  local file = view:infer_cur_file()
                  if file then
                    vim.cmd("edit " .. file.absolute_path)
                  end
                end
              end,
              { desc = "Open file" },
            },
          },

          file_panel = {
            -- VSCode風のファイル操作
            {
              "n",
              "<cr>",
              function()
                require("diffview.actions").select_entry()
              end,
              { desc = "Open file" },
            },

            {
              "n",
              "s",
              function()
                require("diffview.actions").toggle_stage_entry()
              end,
              { desc = "Stage/Unstage" },
            },

            {
              "n",
              "S",
              function()
                require("diffview.actions").stage_all()
              end,
              { desc = "Stage all" },
            },

            {
              "n",
              "U",
              function()
                require("diffview.actions").unstage_all()
              end,
              { desc = "Unstage all" },
            },

            -- ファイル操作
            {
              "n",
              "R",
              function()
                require("diffview.actions").refresh_files()
              end,
              { desc = "Refresh files" },
            },

            {
              "n",
              "d",
              function()
                require("diffview.actions").restore_entry()
              end,
              { desc = "Discard changes" },
            },
          },
        },

        -- ファイルアイコンとカラー
        icons = {
          folder_closed = "",
          folder_open = "",
        },

        -- Git情報の表示設定
        signs = {
          fold_closed = "",
          fold_open = "",
        },

        -- フック設定（PRコメント自動表示 - diff_buf_readフックを使用）
        hooks = {
          -- diff_buf_readフックを使用してDiffビューのバッファが読み込まれた時に実行
          diff_buf_read = function(bufnr)
            -- PRコメント用のカスタムハイライトグループを設定
            vim.api.nvim_set_hl(0, "PRComment", { fg = "#ffffff", bg = "#444444" })
            vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesInfo", { fg = "#ffffff", bg = "#444444" })

            -- DiffView用の基本設定
            vim.opt_local.wrap = false
            vim.opt_local.list = false

            -- PRコメント自動表示（ディレイなし）
            -- PRかどうかチェック
            local pr_check = vim.system({ "gh", "pr", "view", "--json", "number" }, { text = true }):wait()
            if pr_check.code ~= 0 then
              return
            end

            -- グローバルキャッシュから取得または新規取得
            local inline_comments = {}
            if _G.pr_comments_cache then
              inline_comments = _G.pr_comments_cache
              -- 通知削除: キャッシュからPRコメント取得
            else
              -- 通知削除: PRコメントを初回取得中

              -- PR情報取得
              local pr_data_result = vim
                .system({
                  "gh",
                  "pr",
                  "view",
                  "--json",
                  "number,reviews,comments,latestReviews",
                }, { text = true })
                :wait()

              if pr_data_result.code ~= 0 then
                return
              end

              local pr_data = vim.json.decode(pr_data_result.stdout)
              if not pr_data or not pr_data.number then
                return
              end

              -- インラインコメント取得
              local inline_success, inline_result = pcall(function()
                return vim
                  .system({
                    "gh",
                    "api",
                    "repos/:owner/:repo/pulls/" .. pr_data.number .. "/comments",
                    "--jq",
                    "map(select(.position != null)) | map({body: .body, path: .path, line: .line, position: .position, user: .user.login, original_line: .original_line})",
                  }, { text = true })
                  :wait()
              end)

              if not (inline_success and inline_result.code == 0 and inline_result.stdout ~= "[]") then
                vim.notify("⚠️  インラインコメント取得失敗", vim.log.levels.WARN)
                return
              end

              local comments_data = vim.json.decode(inline_result.stdout)
              if not (type(comments_data) == "table" and #comments_data > 0) then
                vim.notify("⚠️  コメントデータが空", vim.log.levels.WARN)
                return
              end

              inline_comments = comments_data
              -- キャッシュに保存
              _G.pr_comments_cache = inline_comments
            end

            -- DiffViewからファイルパス取得
            local actual_file_path = nil
            local diffview = require("diffview.lib").get_current_view()
            if diffview and diffview.panel and diffview.panel.cur_file then
              actual_file_path = diffview.panel.cur_file.path
            end

            if not actual_file_path then
              return
            end

            -- ファイルに該当するコメントをフィルタ
            local file_comments = {}
            for _, comment in ipairs(inline_comments) do
              if comment.path == actual_file_path then
                table.insert(file_comments, comment)
              end
            end

            if #file_comments == 0 then
              return
            end

            -- PRコメントを診断APIで表示（自動）
            local namespace = vim.api.nvim_create_namespace("pr_comments_diagnostics_auto")
            vim.diagnostic.reset(namespace, bufnr)

            local comment_count = 0
            local diagnostics = {}

            for _, comment in ipairs(file_comments) do
              local target_line = (comment.line or comment.position or comment.original_line or 1) - 1
              target_line = math.max(0, target_line)

              if target_line < vim.api.nvim_buf_line_count(bufnr) then
                comment_count = comment_count + 1

                -- コメント内容を整形（改行文字を完全に除去）
                local comment_text = comment
                  .body
                  :gsub("\r\n", " ") -- Windows改行をスペースに
                  :gsub("\r", " ") -- CRをスペースに
                  :gsub("\n", " ") -- LFをスペースに
                  :gsub("%s+", " ") -- 連続するスペースを1つに

                -- PRコメント診断を作成（名前の後に改行を追加）
                local author = comment.user or "unknown"
                local full_message = "💬 " .. author .. ":\n" .. comment_text

                table.insert(diagnostics, {
                  lnum = target_line,
                  col = 0,
                  message = full_message,
                  severity = vim.diagnostic.severity.INFO,
                  source = "PR Comment (Auto)",
                })
              end
            end

            -- 診断を設定（該当バッファのみ）
            if #diagnostics > 0 then
              -- 診断データを設定
              vim.diagnostic.set(namespace, bufnr, diagnostics)

              -- namespace固有の表示設定（テキスト折り返しあり）
              vim.diagnostic.config({
                virtual_text = false,
                underline = false,
                signs = false,
                virtual_lines = {
                  only_current_line = false,
                  highlight_whole_line = false,
                  -- 60文字で改行するフォーマット関数
                  format = function(diagnostic)
                    local max_width = 60
                    local lines = {}
                    local current_line = ""
                    local message = diagnostic.message

                    -- 文字を1つずつ処理して強制改行
                    for i = 1, vim.fn.strchars(message) do
                      local char = vim.fn.strcharpart(message, i - 1, 1)
                      local test_line = current_line .. char

                      if vim.fn.strdisplaywidth(test_line) <= max_width then
                        current_line = test_line
                      else
                        -- 現在の行を追加して新しい行を開始
                        if current_line ~= "" then
                          table.insert(lines, current_line)
                        end
                        current_line = char
                      end
                    end

                    -- 最後の行を追加
                    if current_line ~= "" then
                      table.insert(lines, current_line)
                    end

                    -- 複数行を改行で結合して返す
                    return table.concat(lines, "\n")
                  end,
                },
              }, namespace)
            end

            -- floating window実装削除済み - 診断APIを使用

            -- 通知削除: PRコメント表示完了通知
          end,

          view_opened = function(view)
            -- DiffView開くときの通知のみ（ディレイなし）
            local pr_check = vim.system({ "gh", "pr", "view", "--json", "number" }, { text = true }):wait()
            if pr_check.code == 0 then
              vim.notify("🔍 PRレビュー モードで開きました", vim.log.levels.INFO)
            end
          end,
        },
      })

      -- デバッグ（実装時のみ、完了時削除）
      -- print("=== DEBUG: Final diffview opts ===")
      -- print(vim.inspect(opts))

      return opts
    end,
  },
}
