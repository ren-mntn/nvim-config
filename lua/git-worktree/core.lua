--[[
機能概要: Git Worktree統合API
設定内容: 各モジュールの統合、公開API定義、初期化処理
--]]

local M = {}

function M.setup(opts)
  local config = require("git-worktree.config")
  config.setup(opts)
end

function M.create_worktree()
  local creator = require("git-worktree.creator")
  creator.create_worktree()
end

function M.show_worktree_list()
  local ui = require("git-worktree.ui")
  ui.show_worktree_list()
end

function M.create_worktree_for_branch(branch_name, callback)
  local creator = require("git-worktree.creator")
  creator.create_worktree_for_branch(branch_name, callback)
end

function M.execute_setup_directly(worktree_path, git_root, patch_file, dot_files)
  local creator = require("git-worktree.creator")
  creator.execute_setup_directly(worktree_path, git_root, patch_file, dot_files)
end

function M.get_worktree_list()
  local manager = require("git-worktree.manager")
  return manager.get_worktree_list()
end

function M.switch_worktree(target_path, branch_name)
  local manager = require("git-worktree.manager")
  manager.switch_worktree(target_path, branch_name)
end

function M.delete_worktree(worktree_item, callback)
  local manager = require("git-worktree.manager")
  return manager.delete_worktree(worktree_item, callback)
end

function M.delete_all_worktrees_except_main(callback)
  local manager = require("git-worktree.manager")
  manager.delete_all_worktrees_except_main(callback)
end

function M.collect_dotfiles()
  local sync = require("git-worktree.sync")
  return sync.collect_dotfiles()
end

function M.sync_all_files(worktree_path, git_root, dot_files)
  local sync = require("git-worktree.sync")
  sync.sync_all_files(worktree_path, git_root, dot_files)
end

return M
