return {
  -- VSCode風のdiff表示とgit操作
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      -- VSCode風のキーバインド（Neo-treeと統合）
      { "<leader>gD", "<cmd>DiffviewFileHistory %<cr>", desc = "Git History (現在ファイル)" },
      { "<leader>gc", "<cmd>DiffviewClose<cr>", desc = "Diff View 閉じる" },
      
      -- ステージング操作（VSCode風）
      { "<leader>gv", "<cmd>DiffviewOpen HEAD~1<cr>", desc = "前回コミットとの差分" },
      
      -- Neo-tree Gitサイドバーとの連携用
      { "<leader>gdf", function()
        -- フォーカスされたファイルでDiffviewを開く
        local current_file = vim.fn.expand("%:p")
        if current_file and current_file ~= "" then
          vim.cmd("DiffviewFileHistory " .. current_file)
        else
          vim.cmd("DiffviewOpen")
        end
      end, desc = "Diff focused file" },
    },
    
    opts = {
      -- VSCode風の3ペインレイアウト
      view = {
        default = {
          layout = "diff2_horizontal", -- 横並び表示
        },
        file_history = {
          layout = "diff2_horizontal",
        },
      },
      
      -- ファイルパネルの設定
      file_panel = {
        listing_style = "tree", -- ツリー表示
        tree_options = {
          flatten_dirs = true,
          folder_statuses = "always", -- フォルダステータス表示
        },
        win_config = {
          position = "left",
          width = 35, -- VSCode風のサイドバー幅
          win_opts = {},
        },
      },
      
      -- デフォルトのキーマップ（VSCode風に調整）
      keymaps = {
        view = {
          -- Stage/Unstageファイル
          { "n", "s", function() 
            vim.cmd("Git add " .. vim.fn.expand("%:p"))
            vim.notify("Staged: " .. vim.fn.expand("%:t"))
          end, { desc = "Stage file" }},
          
          { "n", "u", function() 
            vim.cmd("Git reset HEAD " .. vim.fn.expand("%:p"))
            vim.notify("Unstaged: " .. vim.fn.expand("%:t"))
          end, { desc = "Unstage file" }},
          
          -- コミット
          { "n", "cc", "<cmd>Git commit<cr>", { desc = "Commit" }},
          { "n", "ca", "<cmd>Git commit --amend<cr>", { desc = "Commit --amend" }},
          
          -- リフレッシュ
          { "n", "<F5>", "<cmd>DiffviewRefresh<cr>", { desc = "Refresh" }},
          
          -- ファイルを開く
          { "n", "<cr>", function()
            local lib = require("diffview.lib")
            local view = lib.get_current_view()
            if view then
              local file = view:infer_cur_file()
              if file then
                vim.cmd("edit " .. file.absolute_path)
              end
            end
          end, { desc = "Open file" }},
        },
        
        file_panel = {
          -- VSCode風のファイル操作
          { "n", "<cr>", function()
            require("diffview.actions").select_entry()
          end, { desc = "Open file" }},
          
          { "n", "s", function()
            require("diffview.actions").toggle_stage_entry()
          end, { desc = "Stage/Unstage" }},
          
          { "n", "S", function()
            require("diffview.actions").stage_all()
          end, { desc = "Stage all" }},
          
          { "n", "U", function()
            require("diffview.actions").unstage_all()
          end, { desc = "Unstage all" }},
          
          -- ファイル操作
          { "n", "R", function()
            require("diffview.actions").refresh_files()
          end, { desc = "Refresh files" }},
          
          { "n", "d", function()
            require("diffview.actions").restore_entry()
          end, { desc = "Discard changes" }},
        },
      },
      
      -- ファイルアイコンとカラー
      icons = {
        folder_closed = "",
        folder_open = "",
      },
      
      -- Git情報の表示設定
      signs = {
        fold_closed = "",
        fold_open = "",
      },
    },
  },
}