return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
    "nvim-telescope/telescope.nvim",
  },
  cmd = "Neotree", -- 遅延読み込み
  keys = {
    -- ファイルツリー操作（VSCode風）
    { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle Neo-tree" },
    { "<leader>E", "<cmd>Neotree reveal<cr>", desc = "Reveal current file in Neo-tree" },
    { "<leader>fe", "<cmd>Neotree toggle<cr>", desc = "Toggle Neo-tree" },
    { "<leader>fE", "<cmd>Neotree reveal<cr>", desc = "Reveal current file in Neo-tree" },
    
    -- VSCode風のサイドバー切り替え
    { "<C-S-e>", "<cmd>Neotree filesystem<cr>", desc = "File Explorer (VSCode)" },
    { "<C-S-g>", "<cmd>Neotree git_status<cr>", desc = "Git Status Sidebar (VSCode)" },
    { "<C-S-b>", "<cmd>Neotree buffers<cr>", desc = "Buffer List Sidebar" },
    
    -- Keyball向けの高度なキー組み合わせ
    { "<C-A-e>", function()
      -- ファイルエクスプローラーを開いて現在ファイルを表示
      vim.cmd("Neotree filesystem reveal")
    end, desc = "Reveal in File Explorer" },
    
    { "<C-A-g>", function()
      -- Git Status開いて、変更があれば自動でDiffview起動
      vim.cmd("Neotree git_status")
      vim.defer_fn(function()
        local git_changes = vim.fn.system("git diff --name-only")
        if git_changes:gsub("%s+", "") ~= "" then
          vim.cmd("DiffviewOpen")
        end
      end, 500)
    end, desc = "Git Status + Auto Diff" },
    
    -- 便利なキーバインド（従来機能）
    { "<leader>gs", "<cmd>Neotree git_status<cr>", desc = "Git Status Tree" },
    { "<leader>gb", "<cmd>Neotree buffers<cr>", desc = "Buffer Tree" },
    
    -- クイックアクセス（Keyball親指キー活用）
    { "<F13>", "<cmd>Neotree filesystem<cr>", desc = "Files (F13)" },
    { "<F14>", "<cmd>Neotree git_status<cr>", desc = "Git (F14)" },
    { "<F15>", "<cmd>Neotree buffers<cr>", desc = "Buffers (F15)" },
  },
  opts = {
    close_if_last_window = true,
    popup_border_style = "rounded",
    enable_git_status = true,
    enable_diagnostics = true,
    enable_modified_markers = true,
    enable_opened_markers = true,
    sort_case_insensitive = false,
    
    -- VSCode風の統合サイドバー設定
    sources = { "filesystem", "buffers", "git_status" },
    source_selector = {
      winbar = true,
      statusline = false,
      separator = { left = "", right= "" },
      show_separator_on_edge = false,
      sources = {
        { source = "filesystem", display_name = " 󰉓 Files " },
        { source = "buffers", display_name = " 󰈚 Buffers " },
        { source = "git_status", display_name = " 󰊢 Git " },
      },
      content_layout = "start", -- VSCode風のタブレイアウト
      tabs_layout = "equal", -- タブ幅を均等に
    },
    
    default_component_configs = {
      container = {
        enable_character_fade = true
      },
      indent = {
        indent_size = 2,
        padding = 1,
        with_markers = true,
        indent_marker = "│",
        last_indent_marker = "└",
        highlight = "NeoTreeIndentMarker",
        with_expanders = nil,
        expander_collapsed = "",
        expander_expanded = "",
        expander_highlight = "NeoTreeExpander",
      },
      icon = {
        folder_closed = "",
        folder_open = "",
        folder_empty = "ﰊ",
        default = "*",
        highlight = "NeoTreeFileIcon"
      },
      modified = {
        symbol = "[+]",
        highlight = "NeoTreeModified",
      },
      name = {
        trailing_slash = false,
        use_git_status_colors = true,
        highlight = "NeoTreeFileName",
      },
      git_status = {
        symbols = {
          added     = "✚", -- or "✚", but this is redundant info if you use git_status_colors on the name
          modified  = "", -- or "", but this is redundant info if you use git_status_colors on the name
          deleted   = "✖",-- this can only be used in the git_status source
          renamed   = "",-- this can only be used in the git_status source
          untracked = "",
          ignored   = "",
          unstaged  = "",
          staged    = "",
          conflict  = "",
        }
      },
    },
    
    window = {
      position = "left",
      width = 35, -- VSCode風の幅
      mapping_options = {
        noremap = true,
        nowait = true,
      },
      mappings = {
        ["<space>"] = { 
          "toggle_node", 
          nowait = false, -- disable `nowait` if you have existing combos starting with this char that you want to use 
        },
        ["<2-LeftMouse>"] = "open",
        ["<cr>"] = "open",
        ["<esc>"] = "revert_preview",
        ["P"] = { "toggle_preview", config = { use_float = true } },
        ["l"] = "focus_preview",
        ["S"] = "open_split",
        ["s"] = "open_vsplit",
        ["t"] = "open_tabnew",
        ["w"] = "open_with_window_picker",
        ["C"] = "close_node",
        ["z"] = "close_all_nodes",
        ["a"] = { 
          "add",
          config = {
            show_path = "none" -- "none", "relative", "absolute"
          }
        },
        ["A"] = "add_directory", 
        ["d"] = "delete",
        ["r"] = "rename",
        ["y"] = "copy_to_clipboard",
        ["x"] = "cut_to_clipboard",
        ["p"] = "paste_from_clipboard",
        ["c"] = "copy", 
        ["m"] = "move",
        ["q"] = "close_window",
        ["R"] = "refresh",
        ["?"] = "show_help",
        ["<"] = "prev_source",
        [">"] = "next_source",
        
        -- VSCode風のタブ切り替え（数字キー）
        ["1"] = function() vim.cmd("Neotree filesystem") end,
        ["2"] = function() vim.cmd("Neotree buffers") end,
        ["3"] = function() vim.cmd("Neotree git_status") end,
        
        -- Git操作キーマップ（Git Status表示時のみ有効）
        ["gs"] = function()
          local state = require("neo-tree.sources.manager").get_state()
          if state.name == "git_status" then
            return "git_add_file"
          end
        end,
        ["gu"] = function()
          local state = require("neo-tree.sources.manager").get_state()
          if state.name == "git_status" then
            return "git_unstage_file"
          end
        end,
        ["gr"] = function()
          local state = require("neo-tree.sources.manager").get_state()
          if state.name == "git_status" then
            return "git_revert_file"
          end
        end,
        
        -- Telescopeファイル検索
        ["f"] = function()
          vim.cmd("Neotree close")
          require("telescope.builtin").find_files()
        end,
        
        -- 統合されたDiffView操作
        ["gd"] = function()
          local state = require("neo-tree.sources.manager").get_state()
          local node = state.tree:get_node()
          
          pcall(function() vim.cmd("DiffviewClose") end)
          vim.defer_fn(function()
            if state.name == "git_status" and node and node.path then
              pcall(function()
                vim.cmd("DiffviewFileHistory " .. vim.fn.shellescape(node.path))
              end)
            elseif node and node.path and vim.fn.isdirectory(node.path) == 0 then
              pcall(function()
                vim.cmd("DiffviewFileHistory " .. vim.fn.shellescape(node.path))
              end)
            else
              pcall(function()
                vim.cmd("DiffviewOpen")
              end)
            end
          end, 100)
        end,
        
        -- VSCode風のファイル操作強化
        ["o"] = function()
          local state = require("neo-tree.sources.manager").get_state()
          local node = state.tree:get_node()
          if node then
            if state.name == "git_status" and node.path then
              -- Git Status: 安全にDiffviewを開く
              pcall(function() vim.cmd("DiffviewClose") end)
              vim.defer_fn(function()
                pcall(function()
                  vim.cmd("DiffviewFileHistory " .. vim.fn.shellescape(node.path))
                end)
                vim.defer_fn(function()
                  vim.cmd("edit " .. vim.fn.fnameescape(node.path))
                end, 150)
              end, 100)
            else
              -- 通常のファイル: 単純に開く
              vim.cmd("edit " .. vim.fn.fnameescape(node.path or ""))
            end
          end
        end,
      }
    },
    filesystem = {
      filtered_items = {
        visible = true, -- 隠しファイルを表示
        hide_dotfiles = false,
      },
      follow_current_file = {
        enabled = true, -- 現在のファイルを自動的にフォロー
        leave_dirs_open = false, -- 他のディレクトリは閉じる
      },
      use_libuv_file_watcher = true, -- ファイル変更の自動検知
    },
    -- ファイルを開いたときの動作（条件付きで閉じる）
    event_handlers = {
      {
        event = "file_opened",
        handler = function(file_path)
          -- Diffviewやgit関連のバッファの場合は閉じない
          local bufname = vim.api.nvim_buf_get_name(0)
          if bufname:match("^diffview://") or bufname:match("^fugitive://") then
            return -- 何もしない
          end
          
          -- 現在のソースがgit_statusの場合は閉じない
          local manager = require("neo-tree.sources.manager")
          local state = manager.get_state("neo-tree")
          
          if state and state.current_position then
            local current_source = state.current_position.source_name or "filesystem"
            if current_source == "git_status" then
              return -- 何もしない（閉じない）
            end
          end
          
          -- それ以外の場合は閉じる
          require("neo-tree.command").execute({ action = "close" })
        end,
      },
    },
    -- ファイルネスト機能（関連ファイルをグループ化）
    nesting_rules = {
      ["package.json"] = {
        pattern = "^package%.json$",
        files = { "package-lock.json", "yarn.lock", "pnpm-lock.yaml" },
      },
      ["tsconfig.json"] = {
        pattern = "^tsconfig%.json$",
        files = { "tsconfig.*.json" },
      },
      ["Cargo.toml"] = {
        pattern = "^Cargo%.toml$",
        files = { "Cargo.lock" },
      },
      [".gitignore"] = {
        pattern = "^%.gitignore$",
        files = { ".gitattributes", ".gitmodules" },
      },
      ["README.md"] = {
        pattern = "^README%.md$",
        files = { "README.*", "readme.*" },
      },
      ["go.mod"] = {
        pattern = "^go%.mod$",
        files = { "go.sum" },
      },
      ["composer.json"] = {
        pattern = "^composer%.json$",
        files = { "composer.lock" },
      },
    },
    
    -- Git Status専用の設定（VSCode風）
    git_status = {
      window = {
        position = "left",
        width = 35,
        mappings = {
          ["A"]  = "git_add_all",
          ["gu"] = "git_unstage_file",
          ["ga"] = "git_add_file",
          ["gr"] = "git_revert_file",
          ["gc"] = "git_commit",
          ["gp"] = "git_push",
          ["gg"] = "git_commit_and_push",
          ["o"]  = { "show_help", nowait=false, config = { title = "Order by", prefix_key = "o" }},
          ["oc"] = { "order_by_created", nowait = false },
          ["od"] = { "order_by_diagnostics", nowait = false },
          ["om"] = { "order_by_modified", nowait = false },
          ["on"] = { "order_by_name", nowait = false },
          ["os"] = { "order_by_size", nowait = false },
          ["ot"] = { "order_by_type", nowait = false },
          
          -- DiffView統合（Git Status専用）
          ["gd"] = function()
            local state = require("neo-tree.sources.manager").get_state("git_status")
            local node = state.tree:get_node()
            if node and node.path then
              vim.cmd("DiffviewFileHistory " .. node.path)
            else
              vim.cmd("DiffviewOpen")
            end
          end,
          
          -- VSCode風のEnterキー動作
          ["<cr>"] = function()
            local state = require("neo-tree.sources.manager").get_state("git_status")
            local node = state.tree:get_node()
            if node and node.path then
              -- 既存のDiffviewを安全に閉じてから新しいものを開く
              pcall(function() vim.cmd("DiffviewClose") end)
              vim.defer_fn(function()
                pcall(function() 
                  vim.cmd("DiffviewFileHistory " .. vim.fn.shellescape(node.path))
                end)
                -- さらに遅らせてファイルも開く
                vim.defer_fn(function()
                  vim.cmd("edit " .. vim.fn.fnameescape(node.path))
                end, 150)
              end, 100)
            end
          end,
        }
      }
    },
    
    -- Buffer表示の設定
    buffers = {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = false,
      },
      group_empty_dirs = true,
      show_unloaded = true,
      window = {
        mappings = {
          ["bd"] = "buffer_delete",
          ["<bs>"] = "navigate_up",
          ["."] = "set_root",
        }
      },
    },
  },
}
