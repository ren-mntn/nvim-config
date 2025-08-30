--[[
機能概要: Git Worktree設定管理とGitユーティリティ関数
設定内容: デフォルト設定、Git操作関数、パス生成ヘルパー
--]]

local M = {}

M.DEFAULT_CONFIG = {
  setup_timeout = 60000,
  terminal_app = "iTerm.app",
  package_manager = "pnpm",
  excluded_dotfiles = { ".git", ".DS_Store", ".", "..", "git-worktrees", ".worktrees", "node_modules" },
  project_dirs = { ".vscode", ".cursor" },
  project_files = { ".npmrc" },
  global_gitignore_path = vim.fn.expand("~/.gitignore_global"),
  share_node_modules = true, -- mainのnode_modulesをシンボリックリンクで共有
  auto_detect_expo = true, -- Expo/React Nativeプロジェクトの自動検出
  expo_projects = {}, -- 明示的にExpoプロジェクトとして扱うパス（相対パス）
}

M.config = {}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.DEFAULT_CONFIG, opts or {})
end

function M.get_git_root()
  local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
  return git_root ~= "" and git_root or nil
end

function M.get_current_branch()
  return vim.fn.system("git branch --show-current"):gsub("\n", "")
end

function M.has_uncommitted_changes()
  return vim.fn.system("git diff HEAD --name-only"):gsub("\n", "") ~= ""
end

function M.get_worktree_base(git_root)
  local project_name = vim.fn.fnamemodify(git_root, ":t")
  return vim.fn.fnamemodify(git_root, ":h") .. "/" .. project_name .. "-worktrees"
end

function M.branch_exists(branch_name)
  local output = vim.fn.system("git branch -a | grep -E '(^|/)(" .. vim.fn.shellescape(branch_name) .. ")$'")
  return vim.v.shell_error == 0 and output:match("%S") ~= nil
end

function M.create_worktree_directory(worktree_base)
  vim.fn.system("mkdir -p " .. vim.fn.shellescape(worktree_base))
  return vim.v.shell_error == 0
end

return M
