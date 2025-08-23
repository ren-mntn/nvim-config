--[[
機能概要: カーソル下の単語と同じ単語を自動的にハイライト表示
設定内容: LSP・Tree-sitter・正規表現を使った参照ハイライト
キーバインド: なし（ハイライトのみ）
--]]
return {
  "RRethy/vim-illuminate",
  event = { "BufReadPost", "BufNewFile" },
  opts = function(_, opts)
    -- デバッグ（実装時のみ、完了時削除）
    -- print("=== DEBUG: vim-illuminate Initial opts ===")
    -- print(vim.inspect(opts))
    
    -- 安全な初期化
    opts = opts or {}
    
    -- 設定のマージ（完全上書きではない）
    opts = vim.tbl_deep_extend("force", opts, {
      providers = { "lsp", "treesitter", "regex" },
      delay = 100,
      filetypes_denylist = {
        "dirbuf",
        "dirvish",
        "fugitive",
        "alpha",
        "NvimTree",
        "lazy",
        "neogitstatus",
        "Trouble",
        "trouble",
        "lir",
        "Outline",
        "spectre_panel",
        "toggleterm",
        "DressingSelect",
        "TelescopePrompt",
      },
      filetypes_allowlist = {},
      modes_denylist = {},
      modes_allowlist = {},
      providers_regex_syntax_denylist = {},
      providers_regex_syntax_allowlist = {},
      under_cursor = true,
    })
    
    -- デバッグ（実装時のみ、完了時削除）
    -- print("=== DEBUG: vim-illuminate Final opts ===")
    -- print(vim.inspect(opts))
    
    return opts
  end,
  config = function(_, opts)
    require("illuminate").configure(opts)
  end,
}
