--[[
機能概要: Git Worktree共通ユーティリティ関数
設定内容: エラーハンドリング、非同期処理、パッチ作成ヘルパー
--]]

local M = {}

function M.create_patch_file()
  local config = require("git-worktree.config")

  local has_changes = config.has_uncommitted_changes()
  if not has_changes then
    return nil
  end

  local patch_file = "/tmp/worktree-patch-" .. os.time() .. ".patch"

  local exclude_files = { ".claude/settings.json", "claude.json" }
  local exclude_args = ""
  for _, file in ipairs(exclude_files) do
    if vim.fn.system("git diff HEAD --name-only | grep " .. vim.fn.shellescape(file)):gsub("\n", "") ~= "" then
      exclude_args = exclude_args .. " ':!" .. file .. "'"
    end
  end

  vim.fn.system(string.format("git diff HEAD%s > %s", exclude_args, patch_file))
  local patch_size = vim.fn.getfsize(patch_file)

  if patch_size > 0 then
    return patch_file
  end

  return nil
end

function M.apply_patch_with_fallback(worktree_path, patch_file)
  if not patch_file then
    return
  end

  local patch_result = vim.fn.system(
    string.format("cd %s && git apply %s", vim.fn.shellescape(worktree_path), vim.fn.shellescape(patch_file))
  )

  if vim.v.shell_error == 0 then
    vim.fn.system("rm -f " .. patch_file)
  else
    local merge_result = vim.fn.system(
      string.format("cd %s && git apply --3way %s", vim.fn.shellescape(worktree_path), vim.fn.shellescape(patch_file))
    )

    if vim.v.shell_error == 0 then
      vim.fn.system("rm -f " .. patch_file)
    else
      vim.notify(
        "⚠️ Cannot apply uncommitted changes - manual merge required\nReason: " .. patch_result:gsub("\n", " "),
        vim.log.levels.WARN
      )
      vim.fn.system("rm -f " .. patch_file)
    end
  end
end

function M.safe_copy_file(src, dst)
  if vim.fn.filereadable(src) == 1 then
    local parent_dir = vim.fn.fnamemodify(dst, ":h")
    vim.fn.system(string.format("mkdir -p %s", vim.fn.shellescape(parent_dir)))
    vim.fn.system(string.format("cp %s %s", vim.fn.shellescape(src), vim.fn.shellescape(dst)))
    return true
  end
  return false
end

function M.safe_copy_directory(src, dst)
  if vim.fn.isdirectory(src) == 1 then
    local parent_dir = vim.fn.fnamemodify(dst, ":h")
    vim.fn.system(string.format("mkdir -p %s", vim.fn.shellescape(parent_dir)))
    vim.fn.system(string.format("mkdir -p %s", vim.fn.shellescape(dst)))
    vim.fn.system(string.format("cp -r %s/* %s/ 2>/dev/null || true", vim.fn.shellescape(src), vim.fn.shellescape(dst)))
    vim.fn.system(
      string.format("cp -r %s/.* %s/ 2>/dev/null || true", vim.fn.shellescape(src), vim.fn.shellescape(dst))
    )
    return true
  end
  return false
end

function M.create_symlink(source_path, target_path)
  -- 既存のnode_modulesを削除
  if vim.fn.isdirectory(target_path) == 1 then
    vim.fn.system(string.format("rm -rf %s", vim.fn.shellescape(target_path)))
  end

  -- シンボリックリンクを作成
  local symlink_result =
    vim.fn.system(string.format("ln -s %s %s", vim.fn.shellescape(source_path), vim.fn.shellescape(target_path)))

  return vim.v.shell_error == 0, symlink_result
end

function M.find_package_json_dirs(base_path)
  local package_dirs = {}

  -- package.jsonがあるディレクトリを検索（node_modules除く）
  local find_cmd =
    string.format("find %s -name 'package.json' -not -path '*/node_modules/*' -type f", vim.fn.shellescape(base_path))
  local result = vim.fn.system(find_cmd)

  for line in result:gmatch("[^\n]+") do
    local dir = vim.fn.fnamemodify(line, ":h")
    table.insert(package_dirs, dir)
  end

  return package_dirs
end

function M.is_expo_project(pkg_dir, git_root)
  local config = require("git-worktree.config")

  -- 明示的にExpoプロジェクトとして指定されている場合
  local relative_path = pkg_dir:sub(#git_root + 2)
  for _, expo_path in ipairs(config.config.expo_projects or {}) do
    if relative_path == expo_path then
      return true
    end
  end

  -- 自動検出が無効の場合はfalse
  if not config.config.auto_detect_expo then
    return false
  end

  -- package.jsonをチェック
  local package_json_path = pkg_dir .. "/package.json"
  if vim.fn.filereadable(package_json_path) == 1 then
    local ok, package_content = pcall(vim.fn.readfile, package_json_path)
    if ok and package_content then
      local content = table.concat(package_content, "\n")

      -- Expo/React Nativeの依存関係をチェック
      if content:match('"expo"') or content:match('"react%-native"') then
        return true
      end

      -- mainフィールドでexpo-routerをチェック
      if content:match('"main":%s*"expo%-router/entry"') then
        return true
      end
    end
  end

  -- metro.config.jsの存在をチェック
  if
    vim.fn.filereadable(pkg_dir .. "/metro.config.js") == 1
    or vim.fn.filereadable(pkg_dir .. "/metro.config.ts") == 1
  then
    return true
  end

  return false
end

function M.setup_node_modules_symlink(worktree_path, git_root)
  local config = require("git-worktree.config")

  if not config.config.share_node_modules then
    return false
  end

  local success_count = 0
  local expo_project_count = 0
  local package_dirs = M.find_package_json_dirs(worktree_path)

  for _, pkg_dir in ipairs(package_dirs) do
    -- 対応するmainディレクトリのnode_modulesパスを構築
    local relative_path = pkg_dir:sub(#worktree_path + 2) -- worktree_pathからの相対パス
    local main_pkg_dir = git_root .. "/" .. relative_path
    local main_node_modules = main_pkg_dir .. "/node_modules"
    local worktree_node_modules = pkg_dir .. "/node_modules"

    -- Expoプロジェクトかどうかをチェック
    if M.is_expo_project(pkg_dir, git_root) then
      expo_project_count = expo_project_count + 1
      local short_path = relative_path == "" and "root" or relative_path
      vim.notify(
        string.format(
          "⚠️ Skipping Expo/RN project: %s (%s) - will use regular npm install",
          vim.fn.fnamemodify(worktree_path, ":t"),
          short_path
        ),
        vim.log.levels.INFO
      )
    elseif vim.fn.isdirectory(main_node_modules) == 1 then
      -- Expoプロジェクトでなく、mainのnode_modulesが存在する場合のみシンボリックリンクを作成
      local success, error_msg = M.create_symlink(main_node_modules, worktree_node_modules)

      if success then
        success_count = success_count + 1
        local short_path = relative_path == "" and "root" or relative_path
        vim.notify(
          string.format(
            "✅ node_modules symlink created: %s (%s)",
            vim.fn.fnamemodify(worktree_path, ":t"),
            short_path
          ),
          vim.log.levels.INFO
        )
      else
        local short_path = relative_path == "" and "root" or relative_path
        vim.notify(
          string.format(
            "⚠️ Failed to create node_modules symlink: %s (%s) - %s",
            vim.fn.fnamemodify(worktree_path, ":t"),
            short_path,
            error_msg:gsub("\n", " ")
          ),
          vim.log.levels.WARN
        )
      end
    end
  end

  return success_count > 0
end

function M.install_single_project_dependencies(pkg_dir, callback)
  local config = require("git-worktree.config")

  if vim.fn.filereadable(pkg_dir .. "/package.json") ~= 1 then
    if callback then
      callback(true)
    end
    return
  end

  local npm_token = vim.fn.getenv("NPM_TOKEN")
  local actual_token = ""

  if npm_token == vim.NIL or npm_token == "" then
    actual_token = "dummy"
  else
    actual_token = npm_token
  end

  local zshrc_token = vim.fn.system("source ~/.zshrc 2>/dev/null && echo $NPM_TOKEN"):gsub("\n", "")
  if zshrc_token ~= "" then
    actual_token = zshrc_token
  end

  local cmd = string.format(
    "cd %s && source ~/.zshrc 2>/dev/null ; NPM_TOKEN=${NPM_TOKEN:-%s} %s i",
    vim.fn.shellescape(pkg_dir),
    actual_token,
    config.config.package_manager
  )

  vim.system({ "zsh", "-c", cmd }, {}, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local error_msg = result.stderr or result.stdout or "unknown error"
        vim.notify(
          "❌ Failed to install dependencies: " .. vim.fn.fnamemodify(pkg_dir, ":t") .. "\n" .. error_msg,
          vim.log.levels.ERROR
        )
        if callback then
          callback(false)
        end
      else
        vim.notify("✅ Dependencies installed: " .. vim.fn.fnamemodify(pkg_dir, ":t"), vim.log.levels.INFO)
        if callback then
          callback(true)
        end
      end
    end)
  end)
end

function M.install_dependencies_async(worktree_path, callback)
  local config = require("git-worktree.config")
  local git_root = require("git-worktree.config").get_git_root()

  -- 全てのpackage.jsonを持つディレクトリを取得
  local package_dirs = M.find_package_json_dirs(worktree_path)

  if #package_dirs == 0 then
    if callback then
      callback(true)
    end
    return
  end

  -- まずシンボリックリンク設定を試行
  M.setup_node_modules_symlink(worktree_path, git_root)

  -- Expoプロジェクトやシンボリックリンクされなかったプロジェクトの依存関係をインストール
  local install_queue = {}
  for _, pkg_dir in ipairs(package_dirs) do
    -- Expoプロジェクトまたはシンボリックリンクが作成されなかった場合はインストールが必要
    if M.is_expo_project(pkg_dir, git_root) or not vim.fn.isdirectory(pkg_dir .. "/node_modules") == 1 then
      table.insert(install_queue, pkg_dir)
    end
  end

  if #install_queue == 0 then
    -- インストール不要の場合、Prisma generateのみ実行
    M.run_prisma_generate_if_needed(worktree_path, callback)
    return
  end

  -- 各プロジェクトの依存関係を順次インストール
  local install_index = 1
  local function install_next()
    if install_index > #install_queue then
      -- 全てのインストールが完了したらPrisma generateを実行
      M.run_prisma_generate_if_needed(worktree_path, callback)
      return
    end

    local current_pkg_dir = install_queue[install_index]
    install_index = install_index + 1

    M.install_single_project_dependencies(current_pkg_dir, function(success)
      if success then
        install_next()
      else
        if callback then
          callback(false)
        end
      end
    end)
  end

  install_next()
end

function M.run_prisma_generate_if_needed(worktree_path, callback)
  local config = require("git-worktree.config")

  local server_dir = worktree_path .. "/server"
  if vim.fn.isdirectory(server_dir) == 1 then
    local prisma_schema = server_dir .. "/prisma/schema.prisma"
    if vim.fn.filereadable(prisma_schema) == 1 or vim.fn.isdirectory(server_dir .. "/prisma") == 1 then
      local prisma_cmd = string.format(
        "cd %s && source ~/.zshrc 2>/dev/null ; %s prisma generate",
        vim.fn.shellescape(server_dir),
        config.config.package_manager
      )
      vim.system({ "zsh", "-c", prisma_cmd }, {}, function(gen_result)
        vim.schedule(function()
          if gen_result.code ~= 0 then
            local err = gen_result.stderr or gen_result.stdout or "unknown error"
            vim.notify(
              "❌ Failed to run prisma generate in server: " .. vim.fn.fnamemodify(worktree_path, ":t") .. "\n" .. err,
              vim.log.levels.ERROR
            )
          end
          if callback then
            callback(gen_result.code == 0)
          end
        end)
      end)
      return
    end
  end

  if callback then
    callback(true)
  end
end

return M
