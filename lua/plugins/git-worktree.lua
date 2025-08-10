--[[
機能概要: Git Worktree管理機能（作成・切り替え・削除）
設定内容: グローバル.gitignoreファイルとリポジトリ.gitignoreを連携したファイルコピー、NPM_TOKEN対応の依存関係インストール
キーバインド: <leader>gW (作成), <leader>gw (一覧・切り替え・削除)
--]]

local M = {}

-- 設定
local CONFIG = {
  setup_timeout = 60000,
  terminal_app = "iTerm.app",
  package_manager = "pnpm",
  excluded_dotfiles = { ".git", ".DS_Store", ".", "..", "git-worktrees", ".worktrees", "node_modules" },
  project_dirs = { ".vscode", ".cursor" },
  project_files = { ".npmrc" },
  global_gitignore_path = vim.fn.expand("~/.gitignore_global"),
}

-- グローバル.gitignoreファイルから読み込み
local function read_global_gitignore()
  local gitignore_files = {}
  local gitignore_path = CONFIG.global_gitignore_path

  if vim.fn.filereadable(gitignore_path) == 1 then
    local content = vim.fn.readfile(gitignore_path)
    for _, line in ipairs(content) do
      line = vim.trim(line)
      if line ~= "" and not line:match("^#") and not line:match("/$") then
        -- パターンでないものとディレクトリでないものを追加
        if not line:match("%*") and not vim.tbl_contains(CONFIG.excluded_dotfiles, line) then
          table.insert(gitignore_files, line)
        end
      end
    end
  end

  return gitignore_files
end

-- リポジトリ内の.gitignoreファイルから読み込み（ルートのみ・高速版）
local function read_repo_gitignore(git_root)
  local gitignore_files = {}
  local gitignore_path = git_root .. "/.gitignore"

  if vim.fn.filereadable(gitignore_path) == 1 then
    local content = vim.fn.readfile(gitignore_path)
    for _, line in ipairs(content) do
      line = vim.trim(line)
      if line ~= "" and not line:match("^#") and not line:match("/$") then
        -- パターンでないものとディレクトリでないものを追加
        if not line:match("%*") and not vim.tbl_contains(CONFIG.excluded_dotfiles, line) then
          table.insert(gitignore_files, line)
        end
      end
    end
  end

  return gitignore_files
end

-- Worktree配置パスを生成（ベストプラクティス準拠）
local function get_worktree_base(git_root)
  local project_name = vim.fn.fnamemodify(git_root, ":t")
  return vim.fn.fnamemodify(git_root, ":h") .. "/" .. project_name .. "-worktrees"
end

-- Git関連のユーティリティ関数
local function get_git_root()
  local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
  return git_root ~= "" and git_root or nil
end

local function get_current_branch()
  return vim.fn.system("git branch --show-current"):gsub("\n", "")
end

local function has_uncommitted_changes()
  return vim.fn.system("git diff HEAD --name-only"):gsub("\n", "") ~= ""
end

local function create_patch_file()
  local has_changes = has_uncommitted_changes()
  if not has_changes then
    return nil
  end

  local patch_file = "/tmp/worktree-patch-" .. os.time() .. ".patch"

  -- 問題のあるファイルを除外してパッチ生成
  local exclude_files = { ".claude/settings.json", "claude.json" }
  local exclude_args = ""
  for _, file in ipairs(exclude_files) do
    if vim.fn.system("git diff HEAD --name-only | grep " .. vim.fn.shellescape(file)):gsub("\n", "") ~= "" then
      exclude_args = exclude_args .. " ':!" .. file .. "'"
    end
  end

  -- ステージされた変更とワーキングツリーの変更の両方を含める（問題ファイル除外）
  vim.fn.system(string.format("git diff HEAD%s > %s", exclude_args, patch_file))
  local patch_size = vim.fn.getfsize(patch_file)

  if patch_size > 0 then
    return patch_file
  end

  return nil
end

-- ファイル操作のユーティリティ関数
local function collect_dotfiles()
  local dot_files = {}
  local git_root = get_git_root()
  if not git_root then
    return {}
  end

  -- グローバルとリポジトリの.gitignoreを読み込み（エラーハンドリング付き）
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

  -- グローバルファイルからリポジトリで除外されているものを除く
  local all_files = {}
  for _, file in ipairs(global_files) do
    if not vim.tbl_contains(repo_ignore_files, file) then
      table.insert(all_files, file)
    end
  end

  -- 実際に存在するファイルのみを返す（.git, node_modules完全除外）
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

-- Worktreeディレクトリ作成
local function create_worktree_directory(worktree_base)
  vim.fn.system("mkdir -p " .. vim.fn.shellescape(worktree_base))
  return vim.v.shell_error == 0
end

-- ブランチの存在確認
local function branch_exists(branch_name)
  local output = vim.fn.system("git branch -a | grep -E '(^|/)(" .. vim.fn.shellescape(branch_name) .. ")$'")
  return vim.v.shell_error == 0 and output:match("%S") ~= nil
end

-- Git worktree作成（非同期版）
local function create_git_worktree_async(branch_name, worktree_path, callback)
  vim.notify("Creating worktree in background...", vim.log.levels.INFO)

  -- カレントディレクトリを事前に取得
  local cwd = vim.fn.getcwd()

  -- 準備処理（同期）
  if vim.fn.isdirectory(worktree_path) == 1 then
    vim.fn.system("rm -rf " .. vim.fn.shellescape(worktree_path))
  end
  vim.fn.system("git branch -D " .. vim.fn.shellescape(branch_name) .. " 2>/dev/null")

  -- 非同期でfetch実行
  vim.system({ "git", "fetch", "origin", "main:main" }, {
    text = true,
    cwd = cwd,
  }, function(fetch_result)
    -- fetch完了後、worktree作成を実行
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
        -- origin/mainで失敗した場合はHEADを試す
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

-- Worktree作成後のセットアップ
local function setup_worktree(worktree_path, git_root, patch_file, dot_files)
  -- ディレクトリ変更せずにセットアップを実行
  M.execute_setup_directly(worktree_path, git_root, patch_file, dot_files)
end

-- Worktree作成機能
local function create_worktree()
  local git_root = get_git_root()
  if not git_root then
    vim.notify("Not a Git repository", vim.log.levels.ERROR)
    return
  end

  local worktree_base = get_worktree_base(git_root)

  -- ディレクトリ作成
  if not create_worktree_directory(worktree_base) then
    vim.notify("Failed to create git-worktrees directory", vim.log.levels.ERROR)
    return
  end

  -- ブランチ名入力
  vim.schedule(function()
    vim.ui.input({
      prompt = "ブランチ名を入力: ",
      default = "",
    }, function(branch_name)
      if not branch_name or branch_name == "" then
        return
      end

      -- ディレクトリ名変換
      local safe_dir_name = branch_name:gsub("/", "-"):gsub("[^%w%-_]", "-")
      local worktree_path = worktree_base .. "/" .. safe_dir_name

      -- 重複チェック
      if vim.fn.isdirectory(worktree_path) == 1 then
        vim.notify("Worktree already exists: " .. worktree_path, vim.log.levels.ERROR)
        return
      end

      -- ファイル準備
      local patch_file = create_patch_file()
      local dot_files = collect_dotfiles()

      -- Git worktree作成（非同期）
      create_git_worktree_async(branch_name, worktree_path, function(success, error_msg)
        if not success then
          vim.notify("Failed to create worktree: " .. (error_msg or "unknown error"), vim.log.levels.ERROR)
          return
        end

        -- 重い処理の前にiTermタブを先に開く
        vim.fn.system(string.format("open -a %s %s", CONFIG.terminal_app, vim.fn.shellescape(worktree_path)))

        -- セットアップ処理
        setup_worktree(worktree_path, git_root, patch_file, dot_files)
      end)
    end)
  end)
end

-- diffview.nvim連携用: ブランチ指定でworktree作成
function M.create_worktree_for_branch(branch_name, callback)
  local git_root = get_git_root()
  if not git_root then
    vim.notify("Not a Git repository", vim.log.levels.ERROR)
    if callback then
      callback(nil)
    end
    return
  end

  local worktree_base = get_worktree_base(git_root)

  -- ディレクトリ作成
  if not create_worktree_directory(worktree_base) then
    vim.notify("Failed to create git-worktrees directory", vim.log.levels.ERROR)
    if callback then
      callback(nil)
    end
    return
  end

  -- ディレクトリ名変換
  local safe_dir_name = branch_name:gsub("/", "-"):gsub("[^%w%-_]", "-")
  local worktree_path = worktree_base .. "/" .. safe_dir_name

  -- 重複チェック
  if vim.fn.isdirectory(worktree_path) == 1 then
    -- 既存のworktreeがある場合は、そのパスを返す
    if callback then
      callback(worktree_path)
    end
    return
  end

  -- ファイル準備
  local patch_file = create_patch_file()
  local dot_files = collect_dotfiles()

  -- Git worktree作成（非同期）
  create_git_worktree_async(branch_name, worktree_path, function(success, error_msg)
    if not success then
      vim.notify("Failed to create worktree: " .. (error_msg or "unknown error"), vim.log.levels.ERROR)
      if callback then
        callback(nil)
      end
      return
    end

    -- セットアップ処理
    setup_worktree(worktree_path, git_root, patch_file, dot_files)

    -- コールバック実行
    if callback then
      callback(worktree_path)
    end
  end)
end

-- セットアップを直接実行（AppleScript不使用）
function M.execute_setup_directly(worktree_path, git_root, patch_file, dot_files)
  -- グローバルgitignore設定
  vim.fn.system(
    string.format("cd %s && git config core.excludesFile ~/.gitignore_global", vim.fn.shellescape(worktree_path))
  )

  -- .vscodeディレクトリコピー
  if vim.fn.isdirectory(git_root .. "/.vscode") == 1 then
    local vscode_dst = worktree_path .. "/.vscode"
    vim.fn.system(string.format("mkdir -p %s", vim.fn.shellescape(vscode_dst)))
    vim.fn.system(
      string.format(
        "cp -r %s/* %s/ 2>/dev/null || true",
        vim.fn.shellescape(git_root .. "/.vscode"),
        vim.fn.shellescape(vscode_dst)
      )
    )
    vim.fn.system(
      string.format(
        "cp -r %s/.* %s/ 2>/dev/null || true",
        vim.fn.shellescape(git_root .. "/.vscode"),
        vim.fn.shellescape(vscode_dst)
      )
    )
  end

  -- .cursorディレクトリコピー
  if vim.fn.isdirectory(git_root .. "/.cursor") == 1 then
    local cursor_dst = worktree_path .. "/.cursor"
    vim.fn.system(string.format("mkdir -p %s", vim.fn.shellescape(cursor_dst)))
    vim.fn.system(
      string.format(
        "cp -r %s/* %s/ 2>/dev/null || true",
        vim.fn.shellescape(git_root .. "/.cursor"),
        vim.fn.shellescape(cursor_dst)
      )
    )
    vim.fn.system(
      string.format(
        "cp -r %s/.* %s/ 2>/dev/null || true",
        vim.fn.shellescape(git_root .. "/.cursor"),
        vim.fn.shellescape(cursor_dst)
      )
    )
  end

  -- .npmrcファイルコピー
  if vim.fn.filereadable(git_root .. "/.npmrc") == 1 then
    vim.fn.system(
      string.format(
        "cp %s %s",
        vim.fn.shellescape(git_root .. "/.npmrc"),
        vim.fn.shellescape(worktree_path .. "/.npmrc")
      )
    )
  end

  -- ドットファイルコピー
  if dot_files and #dot_files > 0 then
    for _, file in ipairs(dot_files) do
      if file ~= "" then
        local src = git_root .. "/" .. file
        local dst = worktree_path .. "/" .. file

        if vim.fn.filereadable(src) == 1 then
          -- ファイルの場合：親ディレクトリを作成してからコピー
          local parent_dir = vim.fn.fnamemodify(dst, ":h")
          vim.fn.system(string.format("mkdir -p %s", vim.fn.shellescape(parent_dir)))
          vim.fn.system(string.format("cp %s %s", vim.fn.shellescape(src), vim.fn.shellescape(dst)))
        elseif vim.fn.isdirectory(src) == 1 then
          -- ディレクトリの場合：宛先の親ディレクトリを作成してから内容をコピー
          local parent_dir = vim.fn.fnamemodify(dst, ":h")
          vim.fn.system(string.format("mkdir -p %s", vim.fn.shellescape(parent_dir)))
          -- ディレクトリ自体を作成してから内容をコピー
          vim.fn.system(string.format("mkdir -p %s", vim.fn.shellescape(dst)))
          vim.fn.system(
            string.format("cp -r %s/* %s/ 2>/dev/null || true", vim.fn.shellescape(src), vim.fn.shellescape(dst))
          )
          -- 隠しファイルも確実にコピー
          vim.fn.system(
            string.format("cp -r %s/.* %s/ 2>/dev/null || true", vim.fn.shellescape(src), vim.fn.shellescape(dst))
          )
        end
      end
    end
  end

  -- パッチファイル適用（3way mergeで再試行）
  if patch_file then
    -- まず通常のパッチ適用を試行
    local patch_result = vim.fn.system(
      string.format("cd %s && git apply %s", vim.fn.shellescape(worktree_path), vim.fn.shellescape(patch_file))
    )

    if vim.v.shell_error == 0 then
      vim.fn.system("rm -f " .. patch_file)
    else
      -- 失敗時は3way mergeで再試行
      local merge_result = vim.fn.system(
        string.format("cd %s && git apply --3way %s", vim.fn.shellescape(worktree_path), vim.fn.shellescape(patch_file))
      )

      if vim.v.shell_error == 0 then
        vim.fn.system("rm -f " .. patch_file)
      else
        -- それでも失敗した場合はエラー表示
        vim.notify(
          "⚠️ Cannot apply uncommitted changes - manual merge required\nReason: " .. patch_result:gsub("\n", " "),
          vim.log.levels.WARN
        )
        vim.fn.system("rm -f " .. patch_file)
      end
    end
  end

  -- 依存関係インストール（NPM_TOKEN対応）
  if vim.fn.filereadable(worktree_path .. "/package.json") == 1 then
    -- NPM_TOKENの確認と設定
    local npm_token = vim.fn.getenv("NPM_TOKEN")
    local actual_token = ""

    if npm_token == vim.NIL or npm_token == "" then
      actual_token = "dummy"
    else
      actual_token = npm_token
    end

    -- .zshrcから直接読み込み
    local zshrc_token = vim.fn.system("source ~/.zshrc 2>/dev/null && echo $NPM_TOKEN"):gsub("\n", "")

    if zshrc_token ~= "" then
      actual_token = zshrc_token
    end

    -- NPM_TOKEN環境変数を設定
    local cmd = string.format(
      "cd %s && source ~/.zshrc 2>/dev/null ; NPM_TOKEN=${NPM_TOKEN:-%s} %s i",
      vim.fn.shellescape(worktree_path),
      actual_token,
      CONFIG.package_manager
    )

    -- 非同期実行（zshを使用）
    vim.system({ "zsh", "-c", cmd }, {}, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          -- エラー時のみ表示
          local error_msg = result.stderr or result.stdout or "unknown error"
          vim.notify(
            "❌ Failed to install dependencies: " .. vim.fn.fnamemodify(worktree_path, ":t") .. "\n" .. error_msg,
            vim.log.levels.ERROR
          )
        end
      end)
    end)
  end
end

-- Worktreeリスト取得・解析
local function get_worktree_list()
  local worktrees = vim.fn.system("git worktree list"):gsub("\n$", "")
  if worktrees == "" then
    return {}
  end

  local main_worktree = nil
  local other_worktrees = {}
  local git_root = get_git_root()
  local current_path = vim.fn.getcwd()

  -- worktreeリストを解析（順序を保持）
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
          -- メインプロジェクト（複数あっても最初のものを採用）
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
          -- その他のworktree（順番通りに追加）
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

  -- 結果を組み立て（mainを先頭に、他は元の順序のまま）
  local result = {}

  -- mainを先頭に追加
  if main_worktree then
    table.insert(result, main_worktree)
  end

  -- その他のworktreeを逆順で追加（新しいものが上に）
  for i = #other_worktrees, 1, -1 do
    table.insert(result, other_worktrees[i])
  end

  return result
end

-- Worktree切り替え
local function switch_worktree(target_path, branch_name)
  if vim.fn.isdirectory(target_path) == 0 then
    vim.notify("Directory not found: " .. target_path, vim.log.levels.ERROR)
    return
  end

  if vim.fn.getcwd() == target_path then
    return
  end

  -- 現在のバッファの状態を確認
  local current_bufnr = vim.api.nvim_get_current_buf()
  local is_modifiable = vim.api.nvim_get_option_value("modifiable", { buf = current_bufnr })

  if not is_modifiable then
    vim.api.nvim_set_option_value("modifiable", true, { buf = current_bufnr })
  end

  vim.cmd("cd " .. vim.fn.fnameescape(target_path))

  -- Neo-tree更新（エラーハンドリング強化）
  vim.schedule(function()
    vim.defer_fn(function()
      pcall(function()
        -- Neo-treeを閉じてから新しいディレクトリで開く
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

-- 3段階削除処理（ブランチも削除）
local function delete_worktree_async(path, branch_name)
  -- Stage 1: git worktree prune
  vim.system({ "git", "worktree", "prune" }, {}, function()
    -- Stage 2: git worktree remove --force
    vim.system({ "git", "worktree", "remove", "--force", path }, {}, function(result)
      vim.schedule(function()
        if result.code == 0 then
          -- Stage 3: ローカルブランチも削除
          vim.system({ "git", "branch", "-D", branch_name }, {}, function(branch_result)
            -- 削除完了（通知なし）
          end)
        else
          -- Stage 3: 強制削除 + ディレクトリ削除 + prune + ブランチ削除
          vim.system({ "rm", "-rf", path }, {}, function()
            vim.system({ "git", "worktree", "prune" }, {}, function()
              -- ブランチも削除
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

-- main以外のWorktree一括削除
local function delete_all_worktrees_except_main()
  local worktree_list = get_worktree_list()
  local git_root = get_git_root()

  if not git_root then
    vim.notify("Not a Git repository", vim.log.levels.ERROR)
    return
  end

  -- main以外のworktreeを収集（mainブランチを保護）
  local worktrees_to_delete = {}
  for _, worktree in ipairs(worktree_list) do
    -- mainブランチ、main、masterブランチは削除対象から除外
    local is_main_branch = worktree.branch == "main" or worktree.branch == "master"
    local is_main_project = worktree.path == git_root

    if not (is_main_branch or is_main_project) then
      table.insert(worktrees_to_delete, worktree)
    end
  end

  if #worktrees_to_delete == 0 then
    return
  end

  -- 削除確認リスト表示
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

  -- 確認処理
  local function cleanup_and_execute(should_delete)
    pcall(vim.keymap.del, "n", "y", { buffer = true })
    pcall(vim.keymap.del, "n", "Y", { buffer = true })
    pcall(vim.keymap.del, "n", "N", { buffer = true })
    pcall(vim.keymap.del, "n", "<Esc>", { buffer = true })

    if should_delete then
      -- 逐次削除実行
      for _, worktree in ipairs(worktrees_to_delete) do
        delete_worktree_async(worktree.path, worktree.branch)
      end
    end
  end

  -- キーマッピング設定
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

-- Worktree一覧・切り替え・削除UI
local function show_worktree_list()
  local worktree_list = get_worktree_list()

  if #worktree_list == 0 then
    vim.notify("No valid worktrees found", vim.log.levels.WARN)
    return
  end

  -- Snacks picker UI
  Snacks.picker({
    source = "static",
    items = worktree_list,
    title = "Git Worktrees [Enter: 切り替え | d: 削除 | D: 一括削除 | t: iTerm | ?: ヘルプ]",
    format = function(item, picker)
      return { { item.display, "Normal" } }
    end,
    layout = { preset = "select" }, -- selectプリセットを使用（中央表示、プレビューなし）
    matcher = { sort_empty = false }, -- 空の検索時はソートしない（元の順序を保持）
    sort = false, -- 完全にソートを無効化
    focus = "list", -- リストにフォーカス（ノーマルモード）
    actions = {
      worktree_delete = function(picker)
        local item = picker:current()
        if not item then
          return
        end

        -- メインプロジェクト・mainブランチ・masterブランチは削除不可
        local is_main_branch = item.branch == "main" or item.branch == "master"
        local is_main_project = item.path == get_git_root()

        if is_main_branch or is_main_project then
          vim.notify("Cannot delete main/master branch or main project", vim.log.levels.WARN)
          return
        end

        picker:close()

        -- 単一キー確認
        vim.schedule(function()
          vim.notify("Delete worktree '" .. item.branch .. "'? [y/N]", vim.log.levels.WARN)

          local function cleanup_and_execute(should_delete)
            pcall(vim.keymap.del, "n", "y", { buffer = true })
            pcall(vim.keymap.del, "n", "N", { buffer = true })
            pcall(vim.keymap.del, "n", "<Esc>", { buffer = true })

            if should_delete then
              delete_worktree_async(item.path, item.branch)
            end
          end

          vim.keymap.set("n", "y", function()
            cleanup_and_execute(true)
          end, { buffer = true, nowait = true })
          vim.keymap.set("n", "N", function()
            cleanup_and_execute(false)
          end, { buffer = true, nowait = true })
          vim.keymap.set("n", "<Esc>", function()
            cleanup_and_execute(false)
          end, { buffer = true, nowait = true })
        end)
      end,
      worktree_delete_all = function(picker)
        picker:close()
        vim.schedule(function()
          delete_all_worktrees_except_main()
        end)
      end,
      open_in_iterm = function(picker)
        local item = picker:current()
        if not item then
          vim.notify("No worktree selected", vim.log.levels.WARN)
          return
        end

        picker:close()

        vim.schedule(function()
          vim.fn.system(string.format("cd %s && open -a %s .", vim.fn.shellescape(item.path), CONFIG.terminal_app))
        end)
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-d>"] = {
            "worktree_delete",
            mode = { "n", "i" },
          },
          ["D"] = {
            "worktree_delete_all",
            mode = { "n", "i" },
          },
          ["<c-t>"] = {
            "open_in_iterm",
            mode = { "n", "i" },
          },
          ["?"] = {
            function(picker)
              vim.notify(
                "Git Worktree操作ヘルプ:\n\n⌨️  キー操作:\n  Enter      : 選択したWorktreeに切り替え\n  d          : 選択したWorktreeを削除 (確認あり)\n  D          : main以外の全Worktreeを削除 (確認あり)\n  t          : 選択したWorktreeでiTerm2タブを開く\n  Esc        : ピッカーを閉じる\n  ?          : このヘルプを表示\n\n🚀 機能:\n  • Worktree間の高速切り替え\n  • 個別・一括での安全な削除\n  • iTerm2タブでWorktree開く\n  • メインプロジェクトは削除不可\n\n💡 ヒント:\n  削除時は「y」で実行、「N」でキャンセル\n  Ctrl+d, Ctrl+tも利用可能",
                vim.log.levels.INFO
              )
            end,
            mode = { "n", "i" },
          },
        },
      },
      list = {
        keys = {
          ["d"] = { "worktree_delete", mode = "n" },
          ["D"] = { "worktree_delete_all", mode = "n" },
          ["t"] = { "open_in_iterm", mode = "n" },
        },
      },
    },
    confirm = function(picker)
      local item = picker:current()
      if not item then
        vim.notify("No worktree selected", vim.log.levels.WARN)
        return
      end
      switch_worktree(item.path, item.branch)
    end,
  })
end

-- プラグイン設定
return {
  {
    "nvim-lua/plenary.nvim",
    keys = {
      {
        "<leader>gW",
        create_worktree,
        desc = "新しいWorktreeを作成",
      },
      {
        "<leader>gw",
        show_worktree_list,
        desc = "Worktree一覧・切り替え・削除",
      },
    },
  },
}
