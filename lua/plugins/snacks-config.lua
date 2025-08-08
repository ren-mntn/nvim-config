-- ~/.config/nvim/lua/plugins/snacks-config.lua
-- Snacks.nvim設定（高速検索・node_modules除外）
return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    -- 既存のpicker設定を安全に拡張
    opts.picker = opts.picker or {}

    -- LazyVimの既存設定を継承してファイル検索設定を拡張
    opts.picker.files = vim.tbl_deep_extend("force", 
      opts.picker.files or {}, 
      {
        hidden = false,
        ignored = true,  -- gitignoreを尊重（最重要）
        exclude = {
          "node_modules/**",
          "dist/**",
          "build/**",
          ".git/**",
          "target/**",
          "coverage/**",
        }
      }
    )
    
    -- LazyVimの既存設定を継承してテキスト検索設定を拡張
    opts.picker.grep = vim.tbl_deep_extend("force", 
      opts.picker.grep or {}, 
      {
        hidden = false,
        ignored = true,  -- gitignoreを尊重（最重要）
        exclude = {
          "node_modules/**",
          "dist/**", 
          "build/**",
          ".git/**",
          "target/**",
          "coverage/**",
        }
      }
    )
    
    return opts
  end,
  config = function(_, opts)
    require("snacks").setup(opts)
    
    -- カスタムハイライトグループを定義する関数
    local function set_snacks_highlights()
      vim.api.nvim_set_hl(0, "SnacksPickerInput", { 
        bg = "#1E1E1E",  -- 入力欄の背景色
        fg = "#f7fafc"   -- 白い文字色
      })
      
      vim.api.nvim_set_hl(0, "SnacksPickerList", { 
        bg = "#1E1E1E",  -- リストの背景色
        fg = "#f7fafc"   -- ライトグレー文字
      })
      
      vim.api.nvim_set_hl(0, "SnacksPickerPreview", { 
        bg = "#1E1E1E",  -- プレビューの背景色
        fg = "#f7fafc"   -- ほぼ白の文字
      })
      
      vim.api.nvim_set_hl(0, "SnacksPickerBorder", { 
        bg = "#1E1E1E",
        fg = "#bcbcbc"   -- 境界線の色
      })
    end
    
    -- 初回設定
    set_snacks_highlights()
    
    -- ColorScheme変更後にも再適用（テーマ変更で上書きされるのを防ぐ）
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = set_snacks_highlights,
      desc = "Re-apply Snacks picker highlights after colorscheme change"
    })
  end,
  keys = {
    -- VSCode風ショートカット追加
    { "<S-D-f>", function() require("snacks").picker.grep() end, desc = "Live Grep (Snacks)" },
    { "<D-S-f>", function() require("snacks").picker.grep() end, desc = "Live Grep (Snacks Alt)" },
    
    -- 便利なショートカット
    { "<leader>ff", function() require("snacks").picker.files() end, desc = "Find Files" },
    { "<leader>fg", function() require("snacks").picker.grep() end, desc = "Live Grep" },
    { "<leader>fb", function() require("snacks").picker.buffers() end, desc = "Buffers" },
    { "<leader>fr", function() require("snacks").picker.recent() end, desc = "Recent Files" },
  },
}