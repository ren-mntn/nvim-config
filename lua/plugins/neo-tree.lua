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
  opts = function(_, opts)
    -- テストファイル用ハイライトグループを定義
    vim.api.nvim_set_hl(0, "NeoTreeTestFile", { fg = "#F7768E", bold = true })

    -- 安全な初期化
    opts.filesystem = opts.filesystem or {}
    opts.window = opts.window or {}
    opts.default_component_configs = opts.default_component_configs or {}

    -- 既存設定のマージ（完全上書きではない）
    opts.filesystem = vim.tbl_deep_extend("force", opts.filesystem, {
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
    })

    -- ファイル詳細表示の無効化
    opts.default_component_configs = vim.tbl_deep_extend("force", opts.default_component_configs, {
      file_size = { enabled = false },
      type = { enabled = false },
      last_modified = { enabled = false },
      created = { enabled = false },
      icon = {
        folder_closed = "",
        folder_open = "",
        folder_empty = "󰜌",
        provider = function(icon, node, state)
          if node.type == "file" or node.type == "terminal" then
            local name = node.type == "terminal" and "terminal" or node.name

            -- .test.tsファイルに特別なアイコンを設定
            if name:match("%.test%.ts$") then
              icon.text = "󰙨" -- テストファイル用アイコン
              icon.highlight = "NeoTreeTestFile"
              return
            end

            -- 通常のアイコン処理
            local success, web_devicons = pcall(require, "nvim-web-devicons")
            if success then
              local devicon, hl = web_devicons.get_icon(name)
              icon.text = devicon or icon.text
              icon.highlight = hl or icon.highlight
            end
          end
        end,
        default = "*",
        highlight = "NeoTreeFileIcon",
      },
    })

    -- Neo-tree内でのキーマッピング
    opts.window = vim.tbl_deep_extend("force", opts.window, {
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
    })

    return opts
  end,
}
