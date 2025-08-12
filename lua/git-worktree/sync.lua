--[[
機能概要: Git Worktreeファイル同期機能
設定内容: dotfileコレクション、.gitignore処理、プロジェクトファイル同期
--]]

local M = {}

local function read_global_gitignore()
  local config = require("git-worktree.config")
  local gitignore_files = {}
  local gitignore_path = config.config.global_gitignore_path

  if vim.fn.filereadable(gitignore_path) == 1 then
    local content = vim.fn.readfile(gitignore_path)
    for _, line in ipairs(content) do
      line = vim.trim(line)
      if line ~= "" and not line:match("^#") and not line:match("/$") then
        if not line:match("%*") and not vim.tbl_contains(config.config.excluded_dotfiles, line) then
          table.insert(gitignore_files, line)
        end
      end
    end
  end

  return gitignore_files
end

local function read_repo_gitignore(git_root)
  local config = require("git-worktree.config")
  local gitignore_files = {}
  local gitignore_path = git_root .. "/.gitignore"

  if vim.fn.filereadable(gitignore_path) == 1 then
    local content = vim.fn.readfile(gitignore_path)
    for _, line in ipairs(content) do
      line = vim.trim(line)
      if line ~= "" and not line:match("^#") and not line:match("/$") then
        if not line:match("%*") and not vim.tbl_contains(config.config.excluded_dotfiles, line) then
          table.insert(gitignore_files, line)
        end
      end
    end
  end

  return gitignore_files
end

function M.collect_dotfiles()
  local config = require("git-worktree.config")
  local dot_files = {}
  local git_root = config.get_git_root()
  if not git_root then
    return {}
  end

  local global_files = {}
  local repo_ignore_files = {}

  local success_global, result_global = pcall(read_global_gitignore)
  if success_global then
    global_files = result_global
  else
    vim.notify("Warning: Failed to read global .gitignore", vim.log.levels.WARN)
  end

  local success_repo, result_repo = pcall(read_repo_gitignore, git_root)
  if success_repo then
    repo_ignore_files = result_repo
  else
    vim.notify("Warning: Failed to read repository .gitignore", vim.log.levels.WARN)
  end

  local all_files = {}
  for _, file in ipairs(global_files) do
    if not vim.tbl_contains(repo_ignore_files, file) then
      table.insert(all_files, file)
    end
  end

  for _, file in ipairs(all_files) do
    if
      file ~= "node_modules"
      and file ~= ".git"
      and (vim.fn.filereadable(git_root .. "/" .. file) == 1 or vim.fn.isdirectory(git_root .. "/" .. file) == 1)
    then
      table.insert(dot_files, file)
    end
  end

  return dot_files
end

function M.sync_project_directories(worktree_path, git_root)
  local config = require("git-worktree.config")
  local utils = require("git-worktree.utils")

  for _, dir_name in ipairs(config.config.project_dirs) do
    local src_dir = git_root .. "/" .. dir_name
    local dst_dir = worktree_path .. "/" .. dir_name
    utils.safe_copy_directory(src_dir, dst_dir)
  end
end

function M.sync_project_files(worktree_path, git_root)
  local config = require("git-worktree.config")
  local utils = require("git-worktree.utils")

  for _, file_name in ipairs(config.config.project_files) do
    local src_file = git_root .. "/" .. file_name
    local dst_file = worktree_path .. "/" .. file_name
    utils.safe_copy_file(src_file, dst_file)
  end
end

function M.sync_dotfiles(worktree_path, git_root, dot_files)
  local utils = require("git-worktree.utils")

  if not dot_files or #dot_files == 0 then
    return
  end

  for _, file in ipairs(dot_files) do
    if file ~= "" then
      local src = git_root .. "/" .. file
      local dst = worktree_path .. "/" .. file

      if vim.fn.filereadable(src) == 1 then
        utils.safe_copy_file(src, dst)
      elseif vim.fn.isdirectory(src) == 1 then
        utils.safe_copy_directory(src, dst)
      end
    end
  end
end

function M.setup_git_config(worktree_path)
  local config = require("git-worktree.config")

  vim.fn.system(
    string.format(
      "cd %s && git config core.excludesFile %s",
      vim.fn.shellescape(worktree_path),
      config.config.global_gitignore_path
    )
  )
end

function M.sync_all_files(worktree_path, git_root, dot_files)
  M.setup_git_config(worktree_path)
  M.sync_project_directories(worktree_path, git_root)
  M.sync_project_files(worktree_path, git_root)
  M.sync_dotfiles(worktree_path, git_root, dot_files)
end

return M
