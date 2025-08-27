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
        ["<C-q>"] = {
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
        -- 複数選択したファイルをClaudeに追加（視覚的選択をサポート）
        ["<C-Q>"] = {
          function(state)
            local node = state.tree:get_node()
            if node then
              local path = vim.fn.fnameescape(node:get_id())
              vim.cmd("ClaudeCodeAdd " .. path)
              vim.notify("Added " .. node.name .. " to Claude context")
            end
          end,
          desc = "Add current item to Claude (alternative)",
        },
      },
    })

    return opts
  end,
}
