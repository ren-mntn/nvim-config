-- Telescope パフォーマンス最適化設定
return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope", -- コマンド実行時のみ読み込み
  dependencies = {
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },
  },
  opts = function(_, opts)
    -- デフォルト設定をベースに最適化
    opts = opts or {}
    
    -- パフォーマンス最適化設定
    opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
      -- ファイルの並び替えアルゴリズム最適化
      sorting_strategy = "ascending",
      layout_strategy = "horizontal",
      layout_config = {
        horizontal = {
          prompt_position = "top",
          preview_width = 0.55,
          results_width = 0.8,
        },
        vertical = {
          mirror = false,
        },
        width = 0.87,
        height = 0.80,
      },
      
      -- 検索結果の制限でパフォーマンス向上
      file_ignore_patterns = {
        "node_modules",
        ".git/",
        "%.lock",
        "__pycache__",
        "%.sqlite3",
        "%.ipynb",
        "vendor/*",
        "%.jpg",
        "%.jpeg",
        "%.png",
        "%.svg",
        "%.otf",
        "%.ttf",
      },
      
      -- プレビューの最適化
      preview = {
        check_mime_type = false,
        filesize_limit = 0.1, -- MB
      },
      
      -- バッファ管理の最適化
      cache_picker = {
        num_pickers = 20,
      },
    })
    
    -- find_files 専用設定
    opts.pickers = vim.tbl_deep_extend("force", opts.pickers or {}, {
      find_files = {
        -- 高速化のためhiddenファイルをデフォルトでは除外
        hidden = false,
        -- ripgrepの使用でパフォーマンス向上
        find_command = { "fd", "--type", "f", "--strip-cwd-prefix" },
        -- 結果数制限
        results_limit = 1000,
      },
    })
    
    -- 拡張機能の設定
    opts.extensions = vim.tbl_deep_extend("force", opts.extensions or {}, {
      fzf = {
        fuzzy = true,
        override_generic_sorter = true,
        override_file_sorter = true,
        case_mode = "smart_case",
      },
    })
    
    return opts
  end,
  
  config = function(_, opts)
    local telescope = require("telescope")
    telescope.setup(opts)
    
    -- 拡張機能のロード
    pcall(telescope.load_extension, "fzf")
  end,
}