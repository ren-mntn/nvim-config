--[[
機能概要: TypeScript統合フォーマット設定（Oxlint対応）
設定内容: <leader>; で保存 + 全自動修正（TypeScript LSP + Prettier + Oxlint）
キーバインド: <leader>; - 自動インポート + TypeScript修正 + Prettier + 保存 + Oxlint診断
--]]

return {
  -- キーマップ設定（標準的なLazyVim方式）
  {
    "LazyVim/LazyVim",
    keys = {
      {
        "<leader>;",
        function()
          local start_time = vim.loop.hrtime()
          print("=== <leader>; 開始 ===")

          -- 各ステップの時間を記録する変数
          local step_times = {}

          local bufnr = vim.api.nvim_get_current_buf()
          local filename = vim.api.nvim_buf_get_name(bufnr)
          local filetype = vim.bo[bufnr].filetype

          -- TypeScript/JavaScript関連ファイルのみ処理
          if not vim.tbl_contains({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, filetype) then
            -- その他のファイルは単純に保存
            vim.cmd("write")
            local elapsed = (vim.loop.hrtime() - start_time) / 1e6
            print(string.format("非TS/JSファイル保存完了: %.2fms", elapsed))
            return
          end

          -- 1. TypeScript LSPで自動インポート追加とインポート整理（typescript-tools.nvim専用コマンド）
          vim.schedule(function()
            local step1_start = vim.loop.hrtime()
            -- typescript-tools.nvim独自のコマンド使用
            pcall(function()
              vim.cmd("TSToolsAddMissingImports")
            end)
            local step1_elapsed = (vim.loop.hrtime() - step1_start) / 1e6
            step_times.step1 = step1_elapsed

            -- 2. ESLintでimport整理（処理完了後すぐに次へ）
            vim.schedule(function()
              local step2_start = vim.loop.hrtime()
              pcall(function()
                local current_file = vim.api.nvim_buf_get_name(bufnr)

                -- ワークスペースディレクトリを特定
                local workspace_dir = string.match(current_file, "(/Users/ren/workspace/aeon%-pet/apps/[^/]+)")
                if not workspace_dir then
                  print("ワークスペースが見つかりません")
                  return
                end

                -- pre-commitと同じESLint設定でimport整理
                local eslint_start = vim.loop.hrtime()
                local eslint_cmd = string.format(
                  "cd %s && ./node_modules/.bin/eslint --fix --config .eslintrc.js %s",
                  vim.fn.shellescape(workspace_dir),
                  vim.fn.shellescape(current_file)
                )

                local result = vim.fn.system(eslint_cmd)
                local eslint_elapsed = (vim.loop.hrtime() - eslint_start) / 1e6
                print(string.format("ESLint実行時間: %.2fms", eslint_elapsed))

                if vim.v.shell_error ~= 0 then
                  print("ESLint error:", vim.inspect(result))
                end

                -- ファイルをリロード
                vim.cmd("edit!")
              end)
              local step2_elapsed = (vim.loop.hrtime() - step2_start) / 1e6
              step_times.step2 = step2_elapsed

              -- 3. conform.nvimでフォーマット（ESLint完了後すぐに実行）
              vim.schedule(function()
                local step3_start = vim.loop.hrtime()
                local success, result = pcall(function()
                  -- conform.nvimでPrettierフォーマットを実行
                  local conform = require("conform")
                  if conform then
                    return conform.format({ bufnr = bufnr, async = false })
                  else
                    error("conform.nvim not available")
                  end
                end)

                if not success then
                  vim.notify("Prettier format failed: " .. tostring(result), vim.log.levels.WARN)
                else
                  local step3_elapsed = (vim.loop.hrtime() - step3_start) / 1e6
                  step_times.step3 = step3_elapsed
                end

                -- 4. 保存（Prettier完了後すぐに実行）
                vim.schedule(function()
                  local step4_start = vim.loop.hrtime()
                  vim.cmd("write")
                  local step4_elapsed = (vim.loop.hrtime() - step4_start) / 1e6
                  step_times.step4 = step4_elapsed

                  -- 5. Oxlint自動修正＋診断（保存完了後すぐに実行）
                  vim.schedule(function()
                    local step5_start = vim.loop.hrtime()
                    pcall(function()
                      -- Oxlintで自動修正実行（安全な修正のみ）
                      local current_file_path = vim.api.nvim_buf_get_name(bufnr)
                      local cmd =
                        string.format("oxlint --fix --fix-suggestions %s", vim.fn.shellescape(current_file_path))
                      vim.fn.system(cmd)

                      -- ファイルをリロード（修正内容を反映）
                      vim.cmd("edit!")
                    end)

                    -- 修正後に診断実行（少し待機が必要）
                    vim.defer_fn(function()
                      if vim.fn.exists(":OxlintCheck") == 2 then
                        vim.cmd("OxlintCheck")
                      end
                    end, 50)

                    local step5_elapsed = (vim.loop.hrtime() - step5_start) / 1e6
                    step_times.step5 = step5_elapsed
                    local total_elapsed = (vim.loop.hrtime() - start_time) / 1e6

                    -- 全てのステップの時間を表示
                    local cumulative = 0
                    local performance_report = { "=== パフォーマンスレポート ===" }

                    for i, step_name in ipairs({ "step1", "step2", "step3", "step4", "step5" }) do
                      local step_labels = {
                        step1 = "TSToolsAddMissingImports",
                        step2 = "ESLint",
                        step3 = "Prettier",
                        step4 = "保存",
                        step5 = "Oxlint",
                      }
                      if step_times[step_name] then
                        cumulative = cumulative + step_times[step_name]
                        table.insert(
                          performance_report,
                          string.format(
                            "Step%d (%s): %.2fms [累積: %.2fms]",
                            i,
                            step_labels[step_name],
                            step_times[step_name],
                            cumulative
                          )
                        )
                      end
                    end

                    table.insert(performance_report, string.format("全体時間: %.2fms", total_elapsed))
                    table.insert(performance_report, "=====================")

                    -- レポートを表示（少し遅らせて確実に表示）
                    vim.defer_fn(function()
                      -- デバッグ: step_timesの内容を確認
                      print("DEBUG - step_times:", vim.inspect(step_times))
                      
                      -- 1行で全ての時間を表示
                      local parts = {}
                      local labels = {"TSTools", "ESLint", "Prettier", "保存", "Oxlint"}
                      for i, step_name in ipairs({"step1", "step2", "step3", "step4", "step5"}) do
                        if step_times[step_name] then
                          table.insert(parts, string.format("%s:%.0fms", labels[i], step_times[step_name]))
                        end
                      end
                      local report = string.format("⏱️ %s | 全体:%.0fms", table.concat(parts, " "), total_elapsed)
                      print(report)
                    end, 10)
                  end)
                end)

                vim.notify(
                  "✅ 完了: インポート整理 + フォーマット + 保存 + Oxlint自動修正",
                  vim.log.levels.INFO
                )
              end)
            end)
          end)
        end,
        desc = "全自動修正 + 保存 (TypeScript + Prettier + Oxlint)",
        mode = "n",
      },
    },
  },
}
