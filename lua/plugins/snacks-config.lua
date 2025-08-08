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