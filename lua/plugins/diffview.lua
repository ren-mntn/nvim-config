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
          -- gh CLIでPR一覧取得 → 選択 → worktree作成 → diffview開く
          local function get_pr_list()
            local success, result = pcall(function()
              return vim
                .system({ "gh", "pr", "list", "--state", "open", "--json", "number,title,headRefName" }, { text = true })
                :wait()
            end)

            if not success or result.code ~= 0 then
              vim.notify("Failed to fetch PRs. Make sure gh CLI is authenticated.", vim.log.levels.ERROR)
              return {}
            end

            local pr_data = vim.json.decode(result.stdout)
            local pr_items = {}

            for _, pr in ipairs(pr_data) do
              table.insert(pr_items, {
                text = string.format("#%d: %s", pr.number, pr.title),
                pr_number = pr.number,
                branch = pr.headRefName,
                title = pr.title,
              })
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
            title = "PR Worktree Workflow [Enter: worktree + diffview]",
            format = function(item, picker)
              return { { item.text, "Normal" } }
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

      -- PRインラインコメント表示機能
      {
        "<leader>gpc",
        function()
          -- PRコメントをコード内にインライン表示
          local function show_inline_pr_comments()
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

            -- 次に、真のインラインコメント（コード行へのコメント）を取得
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

            local namespace = vim.api.nvim_create_namespace("pr_comments")

            -- 既存のコメントをクリア
            vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)

            local comment_count = 0
            local buffer_line_count = vim.api.nvim_buf_line_count(0)

            -- 0. 真のインラインコメント（コード行への直接コメント）- 最優先
            local current_file = vim.fn.expand("%:.") -- 相対パス
            if #inline_comments > 0 then
              for _, inline_comment in ipairs(inline_comments) do
                -- 現在のファイルのコメントのみ表示
                if inline_comment.path == current_file and inline_comment.body and inline_comment.user then
                  comment_count = comment_count + 1
                  local line_num = inline_comment.line or inline_comment.original_line or inline_comment.position
                  local comment_text = string.format(
                    "📍 %s (行%s): %s",
                    inline_comment.user,
                    tostring(line_num),
                    inline_comment.body:gsub("\n", " "):sub(1, 100)
                  )

                  -- 実際の行番号を使用（1-based to 0-based）
                  local target_line = math.max(0, math.min(buffer_line_count - 1, (tonumber(line_num) or 1) - 1))

                  local success, error_msg = pcall(function()
                    vim.api.nvim_buf_set_extmark(0, namespace, target_line, 0, {
                      virt_text = { { " " .. comment_text, "DiagnosticWarn" } },
                      virt_text_pos = "eol",
                      hl_mode = "combine",
                      priority = 1000, -- 高優先度でインラインコメントを表示
                    })
                  end)

                  if not success then
                    vim.notify(
                      "Failed to set inline comment extmark: " .. (error_msg or "unknown"),
                      vim.log.levels.WARN
                    )
                  end
                end
              end
            end

            -- 1. General PR comments (一般コメント)
            if pr_data.comments then
              for i, comment in ipairs(pr_data.comments) do
                if comment.body and comment.body ~= "" and comment.author then
                  comment_count = comment_count + 1
                  local comment_text =
                    string.format("💬 %s: %s", comment.author.login, comment.body:gsub("\n", " "):sub(1, 80))

                  -- コメントを分散して配置（3行目から開始）
                  local target_line = math.min(buffer_line_count - 1, 2 + (comment_count - 1) * 2)

                  local success, error_msg = pcall(function()
                    vim.api.nvim_buf_set_extmark(0, namespace, target_line, 0, {
                      virt_text = { { " " .. comment_text, "DiagnosticInfo" } },
                      virt_text_pos = "eol",
                      hl_mode = "combine",
                    })
                  end)

                  if not success then
                    vim.notify("Failed to set extmark: " .. (error_msg or "unknown"), vim.log.levels.WARN)
                  end
                end
              end
            end

            -- 2. Review comments (reviewsのコメント)
            if pr_data.reviews then
              for i, review in ipairs(pr_data.reviews) do
                if review.body and review.body ~= "" and review.author then
                  comment_count = comment_count + 1
                  local review_state = review.state or "COMMENTED"
                  local icon = review_state == "APPROVED" and "✅"
                    or review_state == "CHANGES_REQUESTED" and "🔴"
                    or "📝"

                  local comment_text = string.format(
                    "%s %s (%s): %s",
                    icon,
                    review.author.login,
                    review_state,
                    review.body:gsub("\n", " "):sub(1, 60)
                  )

                  local hl_group = review_state == "APPROVED" and "DiagnosticOk"
                    or review_state == "CHANGES_REQUESTED" and "DiagnosticError"
                    or "DiagnosticWarn"

                  local target_line = math.min(buffer_line_count - 1, 2 + (comment_count - 1) * 2)

                  local success, error_msg = pcall(function()
                    vim.api.nvim_buf_set_extmark(0, namespace, target_line, 0, {
                      virt_text = { { " " .. comment_text, hl_group } },
                      virt_text_pos = "eol",
                      hl_mode = "combine",
                    })
                  end)

                  if not success then
                    vim.notify("Failed to set review extmark: " .. (error_msg or "unknown"), vim.log.levels.WARN)
                  end
                end
              end
            end

            -- 3. Latest reviews (最新レビュー)
            if pr_data.latestReviews then
              for i, review in ipairs(pr_data.latestReviews) do
                if review.body and review.body ~= "" and review.author then
                  -- 既に表示されたレビューと重複しないようにチェック
                  local is_duplicate = false
                  if pr_data.reviews then
                    for _, existing_review in ipairs(pr_data.reviews) do
                      if existing_review.id == review.id then
                        is_duplicate = true
                        break
                      end
                    end
                  end

                  if not is_duplicate then
                    comment_count = comment_count + 1
                    local comment_text =
                      string.format("🔄 %s (Latest): %s", review.author.login, review.body:gsub("\n", " "):sub(1, 70))

                    local target_line = math.min(buffer_line_count - 1, 2 + (comment_count - 1) * 2)

                    local success, error_msg = pcall(function()
                      vim.api.nvim_buf_set_extmark(0, namespace, target_line, 0, {
                        virt_text = { { " " .. comment_text, "DiagnosticHint" } },
                        virt_text_pos = "eol",
                        hl_mode = "combine",
                      })
                    end)

                    if not success then
                      vim.notify(
                        "Failed to set latest review extmark: " .. (error_msg or "unknown"),
                        vim.log.levels.WARN
                      )
                    end
                  end
                end
              end
            end

            -- コメント情報をステータスラインに表示
            local inline_count = 0
            for _, inline_comment in ipairs(inline_comments) do
              if inline_comment.path == current_file then
                inline_count = inline_count + 1
              end
            end

            local status_text = string.format(
              "PR #%s: %d件のコメント表示中 (%d件インライン) [📄 <leader>gpt: ターミナル表示]",
              pr_data.number,
              comment_count,
              inline_count
            )
            vim.notify(status_text, vim.log.levels.INFO)

            -- デバッグ: コメント表示位置の確認
            if comment_count > 0 then
              -- extmarkの状態を確認
              local marks = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })

              vim.notify(
                string.format(
                  "💡 %d件のコメントを行の右端に表示しました。実際の extmark 数: %d",
                  comment_count,
                  #marks
                ),
                vim.log.levels.INFO
              )

              -- デバッグ: extmarkの詳細を表示
              for i, mark in ipairs(marks) do
                vim.notify(
                  string.format("ExtMark %d: 行%d, 詳細: %s", i, mark[2] + 1, vim.inspect(mark[4])),
                  vim.log.levels.DEBUG
                )
              end

              -- 最初のコメントにジャンプ
              if #marks > 0 then
                vim.defer_fn(function()
                  vim.api.nvim_win_set_cursor(0, { marks[1][2] + 1, 0 })
                  vim.notify(
                    "👆 カーソルを最初のコメント位置（行"
                      .. (marks[1][2] + 1)
                      .. "）に移動しました。行末を確認してください。",
                    vim.log.levels.INFO
                  )
                end, 500)
              end
            else
              vim.notify("⚠️ 表示可能なコメントが見つかりませんでした", vim.log.levels.WARN)
            end

            -- コメントナビゲーション用のキーマッピング追加
            if comment_count > 0 then
              vim.keymap.set("n", "]c", function()
                -- 次のコメントへ移動
                local marks = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, {})
                if #marks > 0 then
                  local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
                  for _, mark in ipairs(marks) do
                    if mark[2] > current_line then
                      vim.api.nvim_win_set_cursor(0, { mark[2] + 1, 0 })
                      return
                    end
                  end
                  -- 最初のコメントへ
                  vim.api.nvim_win_set_cursor(0, { marks[1][2] + 1, 0 })
                end
              end, { buffer = true, desc = "次のPRコメント" })

              vim.keymap.set("n", "[c", function()
                -- 前のコメントへ移動
                local marks = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, {})
                if #marks > 0 then
                  local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
                  for i = #marks, 1, -1 do
                    if marks[i][2] < current_line then
                      vim.api.nvim_win_set_cursor(0, { marks[i][2] + 1, 0 })
                      return
                    end
                  end
                  -- 最後のコメントへ
                  vim.api.nvim_win_set_cursor(0, { marks[#marks][2] + 1, 0 })
                end
              end, { buffer = true, desc = "前のPRコメント" })
            else
              vim.notify("⚠️ このPRにはコメントがありません", vim.log.levels.WARN)
            end
          end

          show_inline_pr_comments()
        end,
        desc = "PR Inline Comments (インラインコメント)",
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

      -- PRインラインコメントをクリア
      {
        "<leader>gph",
        function()
          local namespace = vim.api.nvim_create_namespace("pr_comments")
          vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)

          -- キーマッピングをクリア
          pcall(vim.keymap.del, "n", "]c", { buffer = true })
          pcall(vim.keymap.del, "n", "[c", { buffer = true })

          vim.notify("🧹 PRインラインコメントを非表示にしました", vim.log.levels.INFO)
        end,
        desc = "Hide PR Inline Comments",
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

          -- 現在の行に仮想テキストを追加
          local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1

          vim.api.nvim_buf_set_extmark(0, namespace, current_line, 0, {
            virt_text = {
              {
                " 🔥 TEST VIRTUAL TEXT - もしこれが見えたら仮想テキスト機能は動作しています",
                "ErrorMsg",
              },
            },
            virt_text_pos = "eol",
            hl_mode = "combine",
          })

          vim.notify(
            "🧪 テスト用仮想テキストを現在の行に表示しました（行末）",
            vim.log.levels.INFO
          )

          -- 3行下にも追加
          if current_line + 3 < vim.api.nvim_buf_line_count(0) then
            vim.api.nvim_buf_set_extmark(0, namespace, current_line + 3, 0, {
              virt_text = { { " 💡 これも見えますか？", "WarningMsg" } },
              virt_text_pos = "eol",
              hl_mode = "combine",
            })
          end

          -- namespace情報も表示
          vim.notify("Namespace ID: " .. namespace, vim.log.levels.INFO)

          -- 10秒後に自動クリア
          vim.defer_fn(function()
            vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
            vim.notify("🧹 テスト用仮想テキストを削除しました", vim.log.levels.INFO)
          end, 10000)
        end,
        desc = "Test Virtual Text Display",
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
      })

      -- デバッグ（実装時のみ、完了時削除）
      -- print("=== DEBUG: Final diffview opts ===")
      -- print(vim.inspect(opts))

      return opts
    end,
  },
}
