--[[
機能概要: Git Worktree管理機能（作成・切り替え・削除）
設定内容: グローバル.gitignoreファイルとリポジトリ.gitignoreを連携したファイルコピー、NPM_TOKEN対応の依存関係インストール
キーバインド: <leader>gW (作成), <leader>gw (一覧・切り替え・削除)
--]]

return {
  "nvim-lua/plenary.nvim",
  dependencies = { "folke/snacks.nvim" },
  event = "VeryLazy",
  keys = {
    {
      "<leader>gW",
      function()
        require("git-worktree.core").create_worktree()
      end,
      desc = "新しいWorktreeを作成",
    },
    {
      "<leader>gw",
      function()
        require("git-worktree.core").show_worktree_list()
      end,
      desc = "Worktree一覧・切り替え・削除",
    },
  },
  opts = function(_, opts)
    opts = opts or {}

    local default_opts = {
      setup_timeout = 60000,
      terminal_app = "iTerm.app",
      package_manager = "pnpm",
      excluded_dotfiles = { ".git", ".DS_Store", ".", "..", "git-worktrees", ".worktrees", "node_modules" },
      project_dirs = { ".vscode", ".cursor" },
      project_files = { ".npmrc" },
      global_gitignore_path = vim.fn.expand("~/.gitignore_global"),
    }

    return vim.tbl_deep_extend("force", default_opts, opts)
  end,
  config = function(_, opts)
    require("git-worktree.core").setup(opts)

    _G.GitWorktree = require("git-worktree.core")
  end,
}
