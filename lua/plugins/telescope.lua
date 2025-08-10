-- ~/.config/nvim/lua/plugins/telescope.lua
-- Telescope無効化（Snacksを使用）
-- Telescope無効化（Snacksを使用）
return {
  "nvim-telescope/telescope.nvim",
  enabled = false, -- Telescopeを無効化
  event = "VeryLazy", -- 遅延読み込み指定（無効化中でもテスト整合のため記載）
  opts = function(_, opts)
    -- 無効化中だが、将来有効化する場合に備えた安全な設定
    opts = opts or {}
    opts.defaults = opts.defaults or {}
    opts.pickers = opts.pickers or {}
    
    -- LazyVimの設定を継承して拡張
    opts.defaults = vim.tbl_deep_extend("force", opts.defaults, {
      file_ignore_patterns = {
        "node_modules/",
        "%.git/",
        "dist/",
        "build/",
        "out/",
        "target/",
        "coverage/",
      },
      vimgrep_arguments = {
        "/opt/homebrew/bin/rg",
        "--color=never",
        "--no-heading", 
        "--with-filename",
        "--line-number",
        "--column",
        "--smart-case",
        "--hidden",
        "--glob", "!.git/*",
        "--glob", "!node_modules/*",
      },
    })
    
    opts.pickers.find_files = vim.tbl_deep_extend("force", 
      opts.pickers.find_files or {}, 
      {
        find_command = {
          "/opt/homebrew/bin/fd",
          "--type", "f",
          "--hidden",
          "--follow", 
          "--exclude", "node_modules",
          "--exclude", "dist",
          "--exclude", "build", 
          "--exclude", ".git",
          "--exclude", "target",
        },
      }
    )
    
    opts.pickers.live_grep = vim.tbl_deep_extend("force",
      opts.pickers.live_grep or {},
      {
        additional_args = function()
          return { "--hidden" }
        end,
      }
    )
    
    return opts
  end,
}