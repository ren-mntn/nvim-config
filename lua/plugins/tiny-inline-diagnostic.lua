--[[
機能概要: インライン診断メッセージの美しい表示
設定内容: LazyVim標準の診断をtiny-inline-diagnosticで置き換え
キーバインド: なし（診断表示の自動化）
--]]
return {
  "rachartier/tiny-inline-diagnostic.nvim",
  event = "VeryLazy",
  priority = 1000, -- 他の診断設定より前に読み込み
  opts = function(_, opts)
    -- デバッグ（実装時のみ、完了時削除）
    -- print("=== DEBUG: tiny-inline-diagnostic opts ===")
    -- print(vim.inspect(opts))

    -- 安全な初期化
    opts = opts or {}

    -- tiny-inline-diagnosticの設定
    local config = {
      signs = {
        left = "",
        right = "",
        diag = "●",
        arrow = "    ",
        up_arrow = "    ",
        vertical = "│",
        vertical_end = "╰",
      },
      hi = {
        error = "DiagnosticError",
        warn = "DiagnosticWarn",
        info = "DiagnosticInfo",
        hint = "DiagnosticHint",
        arrow = "NonText",
        background = "CursorLine",
      },
      blend = {
        factor = 0.27,
      },
      options = {
        show_source = false,
        throttle = 20,
        softwrap = 30,
        multiple_diag_under_cursor = false,
        multilines = false,
        overflow = {
          mode = "wrap",
        },
        format = nil,
        break_line = {
          enabled = false,
          after = 30,
        },
      },
    }

    -- 設定のマージ
    opts = vim.tbl_deep_extend("force", opts, config)

    -- デバッグ（実装時のみ、完了時削除）
    -- print("=== DEBUG: Final tiny-inline-diagnostic opts ===")
    -- print(vim.inspect(opts))

    return opts
  end,
  config = function(_, opts)
    -- pcallでエラーハンドリング
    local ok, tiny_inline_diagnostic = pcall(require, "tiny-inline-diagnostic")
    if not ok then
      vim.notify("tiny-inline-diagnostic: プラグインの読み込みに失敗しました", vim.log.levels.ERROR)
      return
    end

    -- プラグインのセットアップ
    local setup_ok, err = pcall(tiny_inline_diagnostic.setup, opts)
    if not setup_ok then
      vim.notify(
        "tiny-inline-diagnostic: セットアップに失敗しました - " .. tostring(err),
        vim.log.levels.ERROR
      )
      return
    end

    -- LazyVimのデフォルト診断virtual_textを無効化
    vim.diagnostic.config({
      virtual_text = false, -- tiny-inline-diagnosticを使用するため無効化
    })

    vim.notify("tiny-inline-diagnostic: セットアップ完了", vim.log.levels.INFO)
  end,
}
