return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  cmd = "Neotree",
  keys = {
    { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Neo-tree" },
    { "<leader>E", "<cmd>Neotree reveal<cr>", desc = "Neo-tree Reveal" },
  },
  opts = {
    filesystem = {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
      },
      follow_current_file = {
        enabled = true,
        leave_dirs_open = false,
      },
      use_libuv_file_watcher = true,
    },
    -- Neo-tree内でのキーマッピング
    window = {
      mappings = {
        -- ClaudeにファイルまたはディレクトリをContext追加
        ["<C-a>"] = {
          function(state)
            local node = state.tree:get_node()
            if node then
              local path = vim.fn.fnameescape(node:get_id())
              vim.cmd("ClaudeCodeAdd " .. path)
            end
          end,
          desc = "Add to Claude Context",
        },
        -- ディレクトリを再帰的にClaudeに追加
        ["A"] = {
          function(state)
            local node = state.tree:get_node()
            if node then
              local path = vim.fn.fnameescape(node:get_id())
              vim.cmd("ClaudeCodeAdd " .. path)
            end
          end,
          desc = "Add to Claude (recursive for dirs)",
        },
        -- 複数選択したファイルをClaudeに追加（スペースで選択後）
        ["<C-A>"] = {
          function(state)
            local selected_nodes = state.tree:get_checked_nodes()
            local added_count = 0

            -- 選択されたノードがある場合
            if selected_nodes and #selected_nodes > 0 then
              for _, node in ipairs(selected_nodes) do
                local path = vim.fn.fnameescape(node:get_id())
                vim.cmd("ClaudeCodeAdd " .. path)
                added_count = added_count + 1
              end
            else
              -- 選択がない場合は現在のノードを追加
              local node = state.tree:get_node()
              if node then
                local path = vim.fn.fnameescape(node:get_id())
                vim.cmd("ClaudeCodeAdd " .. path)
                added_count = 1
              end
            end

            -- フィードバック
            if added_count > 0 then
              vim.notify(string.format("Added %d item(s) to Claude context", added_count))
            end
          end,
          desc = "Add selected items to Claude",
        },
      },
    },
  },
}
