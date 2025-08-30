--[[
機能概要: blink.cmp設定 - Super-tab・Copilot統合・境界線
設定内容: super-tabプリセット、Copilot統合、ドキュメント境界線、最適化表示
キーバインド: Tab受け入れ、Shift-Tab戻る、Ctrl+u/d スクロール、Ctrl+k シグネチャ
--]]
return {
  "saghen/blink.cmp",
  enabled = false,
  dependencies = {
    "fang2hou/blink-copilot",
  },
  opts = function(_, opts)
    -- Copilotソース追加
    opts.sources = opts.sources or {}
    opts.sources.default = opts.sources.default or {}

    if not vim.tbl_contains(opts.sources.default, "copilot") then
      table.insert(opts.sources.default, "copilot")
    end

    -- Copilotプロバイダー設定
    opts.sources.providers = vim.tbl_deep_extend("force", opts.sources.providers or {}, {
      copilot = {
        name = "copilot",
        module = "blink-copilot",
        score_offset = 100,
        async = true,
      },
    })

    -- キーマップ設定（手動設定でLazyVim互換）
    opts.keymap = vim.tbl_deep_extend("force", opts.keymap or {}, {
      ["<Tab>"] = {
        function(cmp)
          if cmp.snippet_active() then
            return cmp.accept()
          else
            return cmp.select_and_accept()
          end
        end,
        "snippet_forward",
        "fallback",
      },
      ["<S-Tab>"] = { "snippet_backward", "fallback" },
      ["<C-u>"] = { "scroll_documentation_up", "fallback" },
      ["<C-d>"] = { "scroll_documentation_down", "fallback" },
      ["<C-k>"] = { "show_signature", "hide_signature", "fallback" },
    })

    -- 表示最適化設定
    opts.completion = vim.tbl_deep_extend("force", opts.completion or {}, {
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 500,
        window = {
          border = "single",
        },
      },
      menu = {
        border = "single",
        auto_show = true,
        draw = {
          columns = { { "kind_icon" }, { "label", "label_description", gap = 1 } },
        },
      },
    })

    -- シグネチャヘルプ設定
    opts.signature = vim.tbl_deep_extend("force", opts.signature or {}, {
      enabled = true,
      window = {
        border = "single",
      },
    })

    return opts
  end,
}
