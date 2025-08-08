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
    event_handlers = {
      {
        event = "neo_tree_popup_buffer_ready",
        handler = function()
          print("DEBUG: Neo-tree opened from: " .. debug.traceback())
        end,
      },
    },
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
  },
}
