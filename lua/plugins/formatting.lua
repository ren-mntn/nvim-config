--[[
機能概要: Biome統合フォーマット設定
設定内容: <leader>; で保存 + Biomeによる全自動修正（インポート整理・フォーマット・修正）
キーバインド: <leader>; - Biome LSPによるインポート整理 + フォーマット + 保存
--]]

return {
  -- キーマップ設定（標準的なLazyVim方式）
  {
    "LazyVim/LazyVim",
    keys = {
      {
        "<leader>;",
        function()
          -- ⏱️ パフォーマンス測定開始
          local start_time = vim.loop.hrtime()
          local times = {}
          
          local bufnr = vim.api.nvim_get_current_buf()
          local filetype = vim.bo[bufnr].filetype
          times.buffer_info = vim.loop.hrtime()

          -- TypeScript/JavaScript関連ファイル以外は単純に保存
          if not vim.tbl_contains({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, filetype) then
            times.non_ts_check = vim.loop.hrtime()
            if vim.bo[bufnr].buftype == "" and vim.bo[bufnr].modifiable then
              vim.cmd("write")
              times.save = vim.loop.hrtime()
              
              -- 非TS/JSファイルの時間レポート
              local report = string.format(
                "⏱️ 非TS/JSファイル処理時間:\n" ..
                "- バッファ情報取得: %.2fms\n" ..
                "- ファイル種別判定: %.2fms\n" ..
                "- 保存処理: %.2fms\n" ..
                "📊 総処理時間: %.2fms",
                (times.buffer_info - start_time) / 1000000,
                (times.non_ts_check - times.buffer_info) / 1000000,
                (times.save - times.non_ts_check) / 1000000,
                (times.save - start_time) / 1000000
              )
              vim.notify(report, vim.log.levels.INFO)
            end
            return
          end

          -- Biome CLIで全処理実行
          local filename = vim.api.nvim_buf_get_name(bufnr)
          times.filename = vim.loop.hrtime()
          
          vim.notify("🔄 Biome実行中...", vim.log.levels.INFO)
          times.notify = vim.loop.hrtime()
          
          -- 非同期でBiome実行（Mason固定パス）
          local biome_path = vim.fn.stdpath("data") .. "/mason/bin/biome"
          times.path_build = vim.loop.hrtime()
          
          -- Biomeサーバーの自動起動関数
          local function ensure_biome_server_running(callback)
            -- サーバー状態確認
            vim.system({ biome_path, "start" }, {
              cwd = vim.fn.getcwd(),
            }, function(start_result)
              vim.schedule(function()
                if start_result.code == 0 then
                  -- サーバー起動成功または既に起動済み
                  callback()
                else
                  -- サーバー起動失敗時は通常のcheckに戻す
                  vim.notify("⚠️ Biomeサーバー起動失敗、通常モードで実行", vim.log.levels.WARN)
                  callback(true) -- fallback flag
                end
              end)
            end)
          end
          
          -- サーバー確認後にBiome実行
          ensure_biome_server_running(function(fallback)
            local cmd_args = { biome_path, "check", "--write" }
            if not fallback then
              table.insert(cmd_args, "--use-server")
            end
            table.insert(cmd_args, filename)
            
            vim.system(cmd_args, {
              cwd = vim.fn.getcwd(),
            }, function(result)
              times.biome_complete = vim.loop.hrtime()
              
              vim.schedule(function()
                times.schedule_start = vim.loop.hrtime()
                -- 外部変更を自動リロード（警告を回避）
                vim.cmd("checktime")
                times.checktime = vim.loop.hrtime()
                
                local status_icon = result.code == 0 and "✅" or "⚠️"
                local mode_text = fallback and " (通常モード)" or " (サーバーモード)"
                vim.notify(
                  status_icon .. " 完了: Biomeインポート整理 + fixAll + フォーマット" .. mode_text,
                  vim.log.levels.INFO
                )
                times.final_notify = vim.loop.hrtime()
                
                -- 詳細時間レポート（1つのメッセージで）
                local report = string.format(
                  "⏱️ Biome処理詳細時間:\n" ..
                  "- 初期設定 (バッファ情報～パス構築): %.2fms\n" ..
                  "- Biome CLI実行: %.2fms\n" ..
                  "- checktime (リロード): %.2fms\n" ..
                  "- 最終通知: %.2fms\n" ..
                  "📊 総処理時間: %.2fms\n" ..
                  "🔍 Biome終了コード: %s\n" ..
                  "🖥️ 実行モード: %s",
                  (times.path_build - start_time) / 1000000,
                  (times.biome_complete - times.path_build) / 1000000,
                  (times.checktime - times.schedule_start) / 1000000,
                  (times.final_notify - times.checktime) / 1000000,
                  (times.final_notify - start_time) / 1000000,
                  tostring(result.code or "nil"),
                  fallback and "通常モード" or "サーバーモード"
                )
                
                -- エラーがあれば追加
                if result.stderr and result.stderr ~= "" then
                  report = report .. "\n❌ Biome stderr: " .. result.stderr
                end
                
                vim.notify(report, vim.log.levels.INFO)
              end)
            end)
          end)
        end,
        desc = "Biome全自動修正 + 保存",
        mode = "n",
      },
    },
  },
}
