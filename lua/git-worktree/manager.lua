--[[
機能概要: Git Worktree管理機能
設定内容: Worktree一覧取得、切り替え、削除（単体・一括）機能
--]]

local M = {}

function M.get_worktree_list()
  local config = require("git-worktree.config")

  local worktrees = vim.fn.system("git worktree list"):gsub("\n$", "")
  if worktrees == "" then
    return {}
  end

  local main_worktree = nil
  local other_worktrees = {}
  local git_root = config.get_git_root()
  local current_path = vim.fn.getcwd()

  for line in worktrees:gmatch("[^\r\n]+") do
    if line ~= "" then
      local path, hash, branch = line:match("^(.-)%s+([%w%d]+)%s+%[(.-)%]")
      if not branch then
        path, hash = line:match("^(.-)%s+([%w%d]+)%s+%(")
        if path then
          local bare_branch = vim.fn
            .system("cd " .. vim.fn.shellescape(path) .. " && git branch --show-current 2>/dev/null")
            :gsub("\n", "")
          branch = bare_branch ~= "" and bare_branch or "main"
        end
      end

      if path and branch then
        path = path:gsub("^%s*", ""):gsub("%s*$", "")

        local current_mark = (current_path == path) and " 👈 current" or ""
        local is_main = path == git_root or (not path:match("%-worktrees/"))

        if is_main then
          if not main_worktree then
            main_worktree = {
              display = string.format(" %s (main project)%s", branch, current_mark),
              text = string.format(" %s (main project)%s", branch, current_mark),
              file = path,
              path = path,
              branch = branch,
            }
          end
        else
          local display_path = path:gsub("^" .. vim.pesc(git_root), ".")
          if display_path == path then
            display_path = vim.fn.fnamemodify(path, ":t")
          end

          table.insert(other_worktrees, {
            display = string.format(" %s (%s)%s", branch, display_path, current_mark),
            text = string.format(" %s (%s)%s", branch, display_path, current_mark),
            file = path,
            path = path,
            branch = branch,
          })
        end
      end
    end
  end

  local result = {}

  if main_worktree then
    table.insert(result, main_worktree)
  end

  for i = #other_worktrees, 1, -1 do
    table.insert(result, other_worktrees[i])
  end

  return result
end

function M.switch_worktree(target_path, branch_name)
  if vim.fn.isdirectory(target_path) == 0 then
    vim.notify("Directory not found: " .. target_path, vim.log.levels.ERROR)
    return
  end

  if vim.fn.getcwd() == target_path then
    return
  end

  local current_bufnr = vim.api.nvim_get_current_buf()
  local is_modifiable = vim.api.nvim_get_option_value("modifiable", { buf = current_bufnr })

  if not is_modifiable then
    vim.api.nvim_set_option_value("modifiable", true, { buf = current_bufnr })
  end

  vim.cmd("cd " .. vim.fn.fnameescape(target_path))

  vim.schedule(function()
    vim.defer_fn(function()
      pcall(function()
        vim.cmd("Neotree close")
        vim.defer_fn(function()
          pcall(function()
            vim.cmd("Neotree filesystem reveal dir=" .. vim.fn.fnameescape(target_path))
          end)
        end, 200)
      end)
    end, 300)
  end)
end

local function delete_worktree_async(path, branch_name)
  vim.system({ "git", "worktree", "prune" }, {}, function()
    vim.system({ "git", "worktree", "remove", "--force", path }, {}, function(result)
      vim.schedule(function()
        if result.code == 0 then
          vim.system({ "git", "branch", "-D", branch_name }, {}, function(branch_result)
            -- 削除完了（通知なし）
          end)
        else
          vim.system({ "rm", "-rf", path }, {}, function()
            vim.system({ "git", "worktree", "prune" }, {}, function()
              vim.system({ "git", "branch", "-D", branch_name }, {}, function(branch_result)
                -- 修復・削除完了（通知なし）
              end)
            end)
          end)
        end
      end)
    end)
  end)
end

function M.delete_worktree(worktree_item, callback)
  local config = require("git-worktree.config")

  local is_main_branch = worktree_item.branch == "main" or worktree_item.branch == "master"
  local is_main_project = worktree_item.path == config.get_git_root()

  if is_main_branch or is_main_project then
    vim.notify("Cannot delete main/master branch or main project", vim.log.levels.WARN)
    return false
  end

  delete_worktree_async(worktree_item.path, worktree_item.branch)
  if callback then
    callback()
  end
  return true
end

function M.delete_all_worktrees_except_main(callback)
  local config = require("git-worktree.config")

  local worktree_list = M.get_worktree_list()
  local git_root = config.get_git_root()

  if not git_root then
    vim.notify("Not a Git repository", vim.log.levels.ERROR)
    return
  end

  local worktrees_to_delete = {}
  for _, worktree in ipairs(worktree_list) do
    local is_main_branch = worktree.branch == "main" or worktree.branch == "master"
    local is_main_project = worktree.path == git_root

    if not (is_main_branch or is_main_project) then
      table.insert(worktrees_to_delete, worktree)
    end
  end

  if #worktrees_to_delete == 0 then
    return
  end

  local delete_list = {}
  for _, worktree in ipairs(worktrees_to_delete) do
    table.insert(delete_list, "  " .. worktree.branch .. " (" .. vim.fn.fnamemodify(worktree.path, ":t") .. ")")
  end

  local message = string.format(
    "Delete all worktrees except main:\n\n%s\n\nTotal: %d worktrees\nThis cannot be undone!\n\nContinue? [y/N]",
    table.concat(delete_list, "\n"),
    #worktrees_to_delete
  )

  vim.notify(message, vim.log.levels.WARN)

  local function cleanup_and_execute(should_delete)
    pcall(vim.keymap.del, "n", "y", { buffer = true })
    pcall(vim.keymap.del, "n", "Y", { buffer = true })
    pcall(vim.keymap.del, "n", "N", { buffer = true })
    pcall(vim.keymap.del, "n", "<Esc>", { buffer = true })

    if should_delete then
      for _, worktree in ipairs(worktrees_to_delete) do
        delete_worktree_async(worktree.path, worktree.branch)
      end
    end

    if callback then
      callback()
    end
  end

  vim.keymap.set("n", "y", function()
    cleanup_and_execute(true)
  end, { buffer = true, nowait = true })
  vim.keymap.set("n", "Y", function()
    cleanup_and_execute(true)
  end, { buffer = true, nowait = true })
  vim.keymap.set("n", "N", function()
    cleanup_and_execute(false)
  end, { buffer = true, nowait = true })
  vim.keymap.set("n", "<Esc>", function()
    cleanup_and_execute(false)
  end, { buffer = true, nowait = true })
end

function M.open_in_terminal(worktree_item)
  local config = require("git-worktree.config")

  if not worktree_item then
    vim.notify("No worktree selected", vim.log.levels.WARN)
    return
  end

  vim.fn.system(
    string.format("cd %s && open -a %s .", vim.fn.shellescape(worktree_item.path), config.config.terminal_app)
  )
end

function M.switch_to_main_branch()
  local config = require("git-worktree.config")
  local git_root = config.get_git_root()

  if not git_root then
    vim.notify("Not a Git repository", vim.log.levels.ERROR)
    return
  end

  -- mainブランチ名を取得（main or master）
  local main_branch_result =
    vim.fn.system("cd " .. vim.fn.shellescape(git_root) .. " && git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null")
  local main_branch = "main"

  if main_branch_result and main_branch_result ~= "" then
    main_branch = main_branch_result:match("refs/remotes/origin/(.-)%s*$") or "main"
  else
    -- フォールバック: main か master かチェック
    local has_main =
      vim.fn.system("cd " .. vim.fn.shellescape(git_root) .. " && git show-ref --verify --quiet refs/heads/main")
    local has_master =
      vim.fn.system("cd " .. vim.fn.shellescape(git_root) .. " && git show-ref --verify --quiet refs/heads/master")

    if vim.v.shell_error == 0 then
      main_branch = "main"
    elseif vim.fn.system(has_master) and vim.v.shell_error == 0 then
      main_branch = "master"
    end
  end

  local current_path = vim.fn.getcwd()
  local current_branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub("\n", "")

  -- 既にmainプロジェクトのmainブランチにいる場合
  if current_path == git_root and current_branch == main_branch then
    vim.notify("Already on " .. main_branch .. " branch in main project", vim.log.levels.INFO)
    return
  end

  -- mainプロジェクトに移動
  if current_path ~= git_root then
    M.switch_worktree(git_root, main_branch)
  end

  -- mainブランチに切り替え
  vim.schedule(function()
    vim.defer_fn(function()
      local checkout_result =
        vim.fn.system("cd " .. vim.fn.shellescape(git_root) .. " && git checkout " .. main_branch .. " 2>&1")

      if vim.v.shell_error == 0 then
        vim.notify("Switched to " .. main_branch .. " branch", vim.log.levels.INFO)
      else
        -- mainブランチが他のworktreeで使用中の場合の処理
        if checkout_result:match("is already checked out at") then
          -- 使用中のworktreeパスを抽出
          local worktree_path = checkout_result:match("is already checked out at '([^']+)'")
          if worktree_path then
            local worktree_name = vim.fn.fnamemodify(worktree_path, ":t")
            vim.notify(
              string.format(
                "%s branch is currently used in worktree '%s'.\nSwitching to that worktree instead.",
                main_branch,
                worktree_name
              ),
              vim.log.levels.WARN
            )
            -- 使用中のworktreeに切り替え
            M.switch_worktree(worktree_path, main_branch)
          else
            vim.notify(
              string.format(
                "%s branch is being used in another worktree.\nPlease check worktree list and switch to the correct one.",
                main_branch
              ),
              vim.log.levels.WARN
            )
          end
        else
          vim.notify("Failed to switch to " .. main_branch .. " branch: " .. checkout_result, vim.log.levels.ERROR)
        end
      end
    end, 500)
  end)
end

return M
