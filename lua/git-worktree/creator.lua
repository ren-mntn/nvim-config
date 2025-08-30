--[[
機能概要: Git Worktree作成機能
設定内容: 非同期Git操作、Worktree作成、セットアップ処理、依存関係インストール
--]]

local M = {}

local function create_git_worktree_async(branch_name, worktree_path, callback)
  vim.notify("Creating worktree in background...", vim.log.levels.INFO)

  local cwd = vim.fn.getcwd()

  if vim.fn.isdirectory(worktree_path) == 1 then
    vim.fn.system("rm -rf " .. vim.fn.shellescape(worktree_path))
  end
  vim.fn.system("git branch -D " .. vim.fn.shellescape(branch_name) .. " 2>/dev/null")

  vim.system({ "git", "fetch", "origin", "main:main" }, {
    text = true,
    cwd = cwd,
  }, function(fetch_result)
    vim.system({
      "git",
      "worktree",
      "add",
      "-b",
      branch_name,
      worktree_path,
      "origin/main",
    }, {
      text = true,
      cwd = cwd,
    }, function(worktree_result)
      if worktree_result.code ~= 0 then
        vim.system({
          "git",
          "worktree",
          "add",
          "-b",
          branch_name,
          worktree_path,
          "HEAD",
        }, {
          text = true,
          cwd = cwd,
        }, function(head_result)
          vim.schedule(function()
            if head_result.code == 0 then
              callback(true, nil)
            else
              callback(false, head_result.stderr or "worktree作成に失敗")
            end
          end)
        end)
      else
        vim.schedule(function()
          callback(true, nil)
        end)
      end
    end)
  end)
end

local function setup_worktree(worktree_path, git_root, patch_file, dot_files)
  local sync = require("git-worktree.sync")
  local utils = require("git-worktree.utils")

  sync.sync_all_files(worktree_path, git_root, dot_files)
  utils.apply_patch_with_fallback(worktree_path, patch_file)
  utils.install_dependencies_async(worktree_path, function(success)
    if success then
      vim.notify("🎉 Worktree setup completed: " .. vim.fn.fnamemodify(worktree_path, ":t"), vim.log.levels.INFO)
    else
      vim.notify(
        "⚠️ Worktree setup completed with errors: " .. vim.fn.fnamemodify(worktree_path, ":t"),
        vim.log.levels.WARN
      )
    end
  end)
end

function M.create_worktree()
  local config = require("git-worktree.config")
  local sync = require("git-worktree.sync")
  local utils = require("git-worktree.utils")

  local git_root = config.get_git_root()
  if not git_root then
    vim.notify("Not a Git repository", vim.log.levels.ERROR)
    return
  end

  local worktree_base = config.get_worktree_base(git_root)

  if not config.create_worktree_directory(worktree_base) then
    vim.notify("Failed to create git-worktrees directory", vim.log.levels.ERROR)
    return
  end

  vim.schedule(function()
    vim.ui.input({
      prompt = "ブランチ名を入力: ",
      default = "",
    }, function(branch_name)
      if not branch_name or branch_name == "" then
        return
      end

      local safe_dir_name = branch_name:gsub("/", "-"):gsub("[^%w%-_]", "-")
      local worktree_path = worktree_base .. "/" .. safe_dir_name

      if vim.fn.isdirectory(worktree_path) == 1 then
        vim.notify("Worktree already exists: " .. worktree_path, vim.log.levels.ERROR)
        return
      end

      local patch_file = utils.create_patch_file()
      local dot_files = sync.collect_dotfiles()

      create_git_worktree_async(branch_name, worktree_path, function(success, error_msg)
        if not success then
          vim.notify("Failed to create worktree: " .. (error_msg or "unknown error"), vim.log.levels.ERROR)
          return
        end

        vim.fn.system(string.format("open -a %s %s", config.config.terminal_app, vim.fn.shellescape(worktree_path)))
        setup_worktree(worktree_path, git_root, patch_file, dot_files)
      end)
    end)
  end)
end

function M.create_worktree_for_branch(branch_name, callback)
  local config = require("git-worktree.config")
  local sync = require("git-worktree.sync")
  local utils = require("git-worktree.utils")

  local git_root = config.get_git_root()
  if not git_root then
    vim.notify("Not a Git repository", vim.log.levels.ERROR)
    if callback then
      callback(nil)
    end
    return
  end

  local worktree_base = config.get_worktree_base(git_root)

  if not config.create_worktree_directory(worktree_base) then
    vim.notify("Failed to create git-worktrees directory", vim.log.levels.ERROR)
    if callback then
      callback(nil)
    end
    return
  end

  local safe_dir_name = branch_name:gsub("/", "-"):gsub("[^%w%-_]", "-")
  local worktree_path = worktree_base .. "/" .. safe_dir_name

  if vim.fn.isdirectory(worktree_path) == 1 then
    if callback then
      callback(worktree_path)
    end
    return
  end

  local patch_file = utils.create_patch_file()
  local dot_files = sync.collect_dotfiles()

  create_git_worktree_async(branch_name, worktree_path, function(success, error_msg)
    if not success then
      vim.notify("Failed to create worktree: " .. (error_msg or "unknown error"), vim.log.levels.ERROR)
      if callback then
        callback(nil)
      end
      return
    end

    setup_worktree(worktree_path, git_root, patch_file, dot_files)

    if callback then
      callback(worktree_path)
    end
  end)
end

function M.execute_setup_directly(worktree_path, git_root, patch_file, dot_files)
  local sync = require("git-worktree.sync")
  local utils = require("git-worktree.utils")

  sync.sync_all_files(worktree_path, git_root, dot_files)
  utils.apply_patch_with_fallback(worktree_path, patch_file)
  utils.install_dependencies_async(worktree_path, function(success)
    if success then
      vim.notify("🎉 Worktree setup completed: " .. vim.fn.fnamemodify(worktree_path, ":t"), vim.log.levels.INFO)
    else
      vim.notify(
        "⚠️ Worktree setup completed with errors: " .. vim.fn.fnamemodify(worktree_path, ":t"),
        vim.log.levels.WARN
      )
    end
  end)
end

return M
