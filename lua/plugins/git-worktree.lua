-- Git Worktree管理機能 (リファクタリング版)

local M = {}

-- 設定
local CONFIG = {
  setup_timeout = 60000,
  terminal_app = "iTerm.app",
  package_manager = "pnpm",
  excluded_dotfiles = { ".git", ".DS_Store", ".", "..", "git-worktrees", ".worktrees" },
  project_dirs = { ".vscode", ".cursor" },
  project_files = { ".npmrc" },
  global_gitignore_path = vim.fn.expand("~/.gitignore_global"),
}

-- グローバルgitignoreファイルから読み込み
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
  vim.fn.system("git diff HEAD > " .. patch_file)
  local patch_size = vim.fn.getfsize(patch_file)

  if patch_size > 0 then
    vim.notify("📦 未コミット変更をパッチとして保存しました", vim.log.levels.INFO)
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

  -- グローバルgitignoreファイルから動的に読み込み
  local global_ignore_files = read_global_gitignore()
  local all_files = vim.tbl_extend("force", global_ignore_files, {})

  -- 通常のドットファイルも収集
  local exclude_pattern = table.concat(
    vim.tbl_map(function(item)
      return "grep -v '^" .. vim.pesc(item) .. "$'"
    end, CONFIG.excluded_dotfiles),
    " | "
  )

  local all_dotfiles =
    vim.fn.system(string.format("ls -a | grep '^\\.' | %s | grep -v '/$'", exclude_pattern)):gsub("\n", " ")

  if all_dotfiles ~= "" then
    local discovered_dots = vim.split(all_dotfiles, " ")
    -- 空文字列を除去
    discovered_dots = vim.tbl_filter(function(f)
      return f ~= ""
    end, discovered_dots)

    -- 重複を避けて追加
    for _, file in ipairs(discovered_dots) do
      if not vim.tbl_contains(all_files, file) then
        table.insert(all_files, file)
      end
    end
  end

  -- 実際に存在するファイルのみを返す
  for _, file in ipairs(all_files) do
    if vim.fn.filereadable(git_root .. "/" .. file) == 1 or vim.fn.isdirectory(git_root .. "/" .. file) == 1 then
      table.insert(dot_files, file)
    end
  end

  -- デバッグ情報
  if #dot_files > 0 then
    vim.notify("🔍 検出されたファイル: " .. table.concat(dot_files, ", "), vim.log.levels.INFO)
  end

  return dot_files
end

-- Worktree作成機能
local function create_worktree()
  vim.notify("🚀 Worktree作成を開始...", vim.log.levels.INFO)

  local git_root = get_git_root()
  if not git_root then
    vim.notify("❌ Gitリポジトリではありません", vim.log.levels.ERROR)
    return
  end

  local worktree_base = get_worktree_base(git_root)

  -- ディレクトリ作成
  vim.fn.system("mkdir -p " .. vim.fn.shellescape(worktree_base))
  if vim.v.shell_error ~= 0 then
    vim.notify("❌ git-worktreesディレクトリの作成に失敗", vim.log.levels.ERROR)
    return
  end

  -- ブランチ名入力
  vim.schedule(function()
    vim.cmd("startinsert")
    vim.ui.input({
      prompt = "🌿 ブランチ名を入力: ",
    }, function(branch_name)
      vim.schedule(function()
        vim.cmd("stopinsert")
      end)

      if not branch_name or branch_name == "" then
        vim.notify("❌ ブランチ名が必要です", vim.log.levels.ERROR)
        return
      end

      -- ディレクトリ名変換
      local safe_dir_name = branch_name:gsub("/", "-"):gsub("[^%w%-_]", "-")
      local worktree_path = worktree_base .. "/" .. safe_dir_name

      -- 重複チェック
      if vim.fn.isdirectory(worktree_path) == 1 then
        vim.notify("❌ 作業ツリーが既に存在します: " .. worktree_path, vim.log.levels.ERROR)
        return
      end

      -- Git worktree作成開始前にパッチとファイル準備
      vim.notify("📋 ファイル準備中...", vim.log.levels.INFO)

      -- 未コミット変更をチェック（追跡ファイルのみ）
      local patch_file = create_patch_file()

      -- プロジェクト固有のドットファイルのコピー準備
      local dot_files = collect_dotfiles()

      -- Git worktree作成

      -- mainブランチをfetch
      vim.fn.system("git fetch origin main:main 2>/dev/null")

      -- worktree作成コマンド
      local git_cmd = string.format(
        "git worktree add -b %s %s origin/main",
        vim.fn.shellescape(branch_name),
        vim.fn.shellescape(worktree_path)
      )
      local git_result = vim.fn.system(git_cmd)

      -- origin/mainで失敗した場合はHEADを試す
      if vim.v.shell_error ~= 0 then
        git_cmd = string.format(
          "git worktree add -b %s %s HEAD",
          vim.fn.shellescape(branch_name),
          vim.fn.shellescape(worktree_path)
        )
        git_result = vim.fn.system(git_cmd)
      end

      if vim.v.shell_error ~= 0 then
        vim.notify("❌ Git worktree作成に失敗しました: " .. git_result, vim.log.levels.ERROR)
        return
      end

      -- worktree作成成功を通知
      vim.notify("✅ Worktree作成完了: " .. branch_name, vim.log.levels.INFO)

      -- メインスレッドで安全に実行
      vim.schedule(function()
        -- 現在のディレクトリをworktreeに切り替え
        vim.cmd("cd " .. vim.fn.fnameescape(worktree_path))

        -- Neo-treeをリフレッシュ（新しいルートに変更）
        pcall(function()
          vim.cmd("Neotree close")
          vim.defer_fn(function()
            pcall(function()
              -- 新しいworktreeをneo-treeのルートとして開く
              vim.cmd("Neotree filesystem reveal dir=" .. vim.fn.fnameescape(worktree_path))
            end)
          end, 300)
        end)

        -- 先にiTerm2タブを開く
        vim.fn.system(string.format("cd %s && open -a %s .", vim.fn.shellescape(worktree_path), CONFIG.terminal_app))

        -- セットアップを直接実行（AppleScript不使用）
        M.execute_setup_directly(worktree_path, git_root, patch_file, dot_files)
      end)
    end)
  end)
end

-- 共通: パッチセクション生成
local function generate_patch_section(patch_file)
  if not patch_file then
    return ""
  end
  return string.format(
    [[

# パッチファイルを適用（追跡ファイルの変更のみ）
if [ -f "%s" ]; then
  echo "📝 未コミット変更を適用中..."
  git apply "%s"
  if [ $? -eq 0 ]; then
    echo "✅ 変更の適用完了"
    rm -f "%s"
  else
    echo "⚠️  パッチ適用に失敗（手動で適用してください: %s）"
  fi
fi
]],
    patch_file,
    patch_file,
    patch_file,
    patch_file
  )
end

-- 共通: ドットファイルセクション生成
local function generate_dotfiles_section(git_root, dot_files)
  if not dot_files or #dot_files == 0 then
    return ""
  end

  local copy_commands = {}
  for _, file in ipairs(dot_files) do
    if file ~= "" then
      table.insert(
        copy_commands,
        string.format(
          [[
if [ -f "%s/%s" ]; then
  echo "📋 %s をコピー中..."
  cp "%s/%s" "%s"
  echo "✅ %s をコピー完了"
fi]],
          git_root,
          file,
          file,
          git_root,
          file,
          file,
          file
        )
      )
    end
  end

  if #copy_commands == 0 then
    return ""
  end

  return "\n# プロジェクト固有のドットファイルをコピー\n" .. table.concat(copy_commands, "\n")
end

-- 共通: セットアップスクリプト生成
local function generate_setup_script(worktree_path, git_root, patch_file, dot_files)
  local patch_section = generate_patch_section(patch_file)
  local dot_files_section = generate_dotfiles_section(git_root, dot_files)

  return string.format(
    [[
#!/bin/bash
set -e

echo "⚙️ 環境セットアップ中..."
cd "%s"

# グローバルgitignore設定
echo "📋 グローバル.gitignore設定中..."
if [ -f ~/.gitignore_global ]; then
  # グローバル設定
  git config core.excludesFile ~/.gitignore_global
  # ローカルにも.gitignore_globalをコピー（参照用）
  cp ~/.gitignore_global .gitignore_global 2>/dev/null || true
  echo "✅ グローバル.gitignore設定完了"
else
  echo "⚠️ ~/.gitignore_global が見つかりません"
fi

# .vscode/.cursorディレクトリコピー
if [ -d "%s/.vscode" ]; then
  echo "📁 .vscode設定をコピー中..."
  cp -r "%s/.vscode" .vscode
  echo "✅ .vscode設定をコピー完了"
fi

if [ -d "%s/.cursor" ]; then
  echo "📁 .cursor設定をコピー中..."
  cp -r "%s/.cursor" .cursor
  echo "✅ .cursor設定をコピー完了"
fi

# .npmrcファイルをコピー
if [ -f "%s/.npmrc" ]; then
  echo "📋 .npmrcをコピー中..."
  cp "%s/.npmrc" .npmrc
  echo "✅ .npmrcをコピー完了"
fi

# 依存関係のインストール
if [ -f "package.json" ]; then
  echo "📦 依存関係をインストール中..."
  %s i
  echo "✅ 依存関係インストール完了"
fi

# Prisma生成（client側）
if [ -f "prisma/schema.prisma" ]; then
  echo "🔧 Prismaクライアントコードを生成中..."
  npx prisma generate
  echo "✅ Prismaクライアント生成完了"
fi

# server側のPrisma生成
if [ -d "server" ] && [ -f "server/package.json" ]; then
  echo "🔧 Server側のPrisma生成中..."
  cd server
  %s prisma:generate
  cd ..
  echo "✅ Server側のPrisma生成完了"
fi

echo "✅ セットアップ完了！"
echo "📂 移動先: %s"
%s%s
]],
    worktree_path,
    git_root,
    git_root,
    git_root,
    git_root,
    git_root,
    git_root,
    CONFIG.package_manager,
    CONFIG.package_manager,
    worktree_path,
    patch_section,
    dot_files_section
  )
end

-- セットアップスクリプト実行（ターミナル）
function M.execute_setup_script(worktree_path, git_root, patch_file, dot_files)
  local setup_script = generate_setup_script(worktree_path, git_root, patch_file, dot_files)

  local temp_script = "/tmp/nvim-worktree-setup-" .. os.time() .. ".sh"
  local file = io.open(temp_script, "w")
  if file then
    file:write(setup_script)
    file:close()

    vim.cmd("terminal bash " .. temp_script)

    vim.defer_fn(function()
      vim.fn.system("rm -f " .. temp_script)
    end, CONFIG.setup_timeout)
  else
    vim.notify("❌ セットアップスクリプトの作成に失敗", vim.log.levels.ERROR)
  end
end

-- セットアップを直接実行（AppleScript不使用）
function M.execute_setup_directly(worktree_path, git_root, patch_file, dot_files)
  vim.notify("⚙️ セットアップを実行中...", vim.log.levels.INFO)

  -- グローバルgitignore設定
  vim.fn.system(
    string.format("cd %s && git config core.excludesFile ~/.gitignore_global", vim.fn.shellescape(worktree_path))
  )

  -- .vscodeディレクトリコピー
  if vim.fn.isdirectory(git_root .. "/.vscode") == 1 then
    vim.notify("📁 .vscode設定をコピー中...", vim.log.levels.INFO)
    vim.fn.system(
      string.format(
        "cp -r %s %s",
        vim.fn.shellescape(git_root .. "/.vscode"),
        vim.fn.shellescape(worktree_path .. "/.vscode")
      )
    )
  end

  -- .cursorディレクトリコピー
  if vim.fn.isdirectory(git_root .. "/.cursor") == 1 then
    vim.notify("📁 .cursor設定をコピー中...", vim.log.levels.INFO)
    vim.fn.system(
      string.format(
        "cp -r %s %s",
        vim.fn.shellescape(git_root .. "/.cursor"),
        vim.fn.shellescape(worktree_path .. "/.cursor")
      )
    )
  end

  -- .npmrcファイルコピー
  if vim.fn.filereadable(git_root .. "/.npmrc") == 1 then
    vim.notify("📋 .npmrcをコピー中...", vim.log.levels.INFO)
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
    vim.notify(
      string.format("📋 プロジェクトファイルをコピー中... (%d個)", #dot_files),
      vim.log.levels.INFO
    )
    for _, file in ipairs(dot_files) do
      if file ~= "" then
        local src = git_root .. "/" .. file
        local dst = worktree_path .. "/" .. file
        if vim.fn.filereadable(src) == 1 then
          vim.fn.system(string.format("cp %s %s", vim.fn.shellescape(src), vim.fn.shellescape(dst)))
          vim.notify("✅ " .. file .. " をコピー完了", vim.log.levels.INFO)
        elseif vim.fn.isdirectory(src) == 1 then
          vim.fn.system(string.format("cp -r %s %s", vim.fn.shellescape(src), vim.fn.shellescape(dst)))
          vim.notify("✅ " .. file .. " ディレクトリをコピー完了", vim.log.levels.INFO)
        else
          vim.notify("⚠️ " .. file .. " が見つかりませんでした", vim.log.levels.WARN)
        end
      end
    end
  else
    vim.notify("ℹ️ コピー対象のプロジェクトファイルがありません", vim.log.levels.INFO)
  end

  -- パッチファイル適用
  if patch_file then
    vim.notify("📝 未コミット変更を適用中...", vim.log.levels.INFO)
    local patch_result = vim.fn.system(
      string.format("cd %s && git apply %s", vim.fn.shellescape(worktree_path), vim.fn.shellescape(patch_file))
    )
    if vim.v.shell_error == 0 then
      vim.notify("✅ 変更の適用完了", vim.log.levels.INFO)
      vim.fn.system("rm -f " .. patch_file)
    else
      vim.notify(
        "⚠️ パッチ適用に失敗（手動で適用してください: " .. patch_file .. "）",
        vim.log.levels.WARN
      )
    end
  end

  -- 依存関係インストールをバックグラウンドで実行
  if vim.fn.filereadable(worktree_path .. "/package.json") == 1 then
    vim.notify("📦 依存関係をバックグラウンドでインストール中...", vim.log.levels.INFO)
    vim.fn.system(
      string.format("cd %s && %s i > /dev/null 2>&1 &", vim.fn.shellescape(worktree_path), CONFIG.package_manager)
    )
  end

  vim.notify("✅ セットアップ完了！", vim.log.levels.INFO)
end

-- タブ内でセットアップスクリプト実行
function M.execute_setup_in_tab(worktree_path, git_root, patch_file, dot_files)
  local patch_section = ""
  if patch_file then
    patch_section = string.format(
      [[

# パッチファイルを適用（追跡ファイルの変更のみ）
if [ -f "%s" ]; then
  echo "📝 未コミット変更を適用中..."
  git apply "%s"
  if [ $? -eq 0 ]; then
    echo "✅ 変更の適用完了"
    rm -f "%s"
  else
    echo "⚠️  パッチ適用に失敗（手動で適用してください: %s）"
  fi
fi
]],
      patch_file,
      patch_file,
      patch_file,
      patch_file
    )
  end

  -- ドットファイルのコピーセクション
  local dot_files_section = ""
  if dot_files and #dot_files > 0 then
    local copy_commands = {}
    for _, file in ipairs(dot_files) do
      if file ~= "" then
        table.insert(
          copy_commands,
          string.format(
            [[
if [ -f "%s/%s" ]; then
  echo "📋 %s をコピー中..."
  cp "%s/%s" "%s"
  echo "✅ %s をコピー完了"
fi]],
            git_root,
            file,
            file,
            git_root,
            file,
            file,
            file
          )
        )
      end
    end
    if #copy_commands > 0 then
      dot_files_section = "\n# プロジェクト固有のドットファイルをコピー\n"
        .. table.concat(copy_commands, "\n")
    end
  end

  local setup_script = string.format(
    [[
#!/bin/bash
set -e

echo "⚙️ 環境セットアップ中..."
cd "%s"

# グローバルgitignore設定
echo "📋 グローバル.gitignore設定中..."
if [ -f ~/.gitignore_global ]; then
  # グローバル設定
  git config core.excludesFile ~/.gitignore_global
  # ローカルにも.gitignore_globalをコピー（参照用）
  cp ~/.gitignore_global .gitignore_global 2>/dev/null || true
  echo "✅ グローバル.gitignore設定完了"
else
  echo "⚠️ ~/.gitignore_global が見つかりません"
fi

# .vscode/.cursorディレクトリコピー
if [ -d "%s/.vscode" ]; then
  echo "📁 .vscode設定をコピー中..."
  cp -r "%s/.vscode" .vscode
  echo "✅ .vscode設定をコピー完了"
fi

if [ -d "%s/.cursor" ]; then
  echo "📁 .cursor設定をコピー中..."
  cp -r "%s/.cursor" .cursor
  echo "✅ .cursor設定をコピー完了"
fi

# .npmrcファイルをコピー
if [ -f "%s/.npmrc" ]; then
  echo "📋 .npmrcをコピー中..."
  cp "%s/.npmrc" .npmrc
  echo "✅ .npmrcをコピー完了"
fi

# 依存関係のインストール
if [ -f "package.json" ]; then
  echo "📦 依存関係をインストール中..."
  pnpm i
  echo "✅ 依存関係インストール完了"
fi

# Prisma生成（client側）
if [ -f "prisma/schema.prisma" ]; then
  echo "🔧 Prismaクライアントコードを生成中..."
  npx prisma generate
  echo "✅ Prismaクライアント生成完了"
fi

# server側のPrisma生成
if [ -d "server" ] && [ -f "server/package.json" ]; then
  echo "🔧 Server側のPrisma生成中..."
  cd server
  pnpm prisma:generate
  cd ..
  echo "✅ Server側のPrisma生成完了"
fi

echo "✅ セットアップ完了！"
echo "📂 移動先: %s"
%s%s
]],
    worktree_path,
    git_root,
    git_root,
    git_root,
    git_root,
    git_root,
    git_root,
    worktree_path,
    patch_section,
    dot_files_section
  )

  local temp_script = "/tmp/nvim-worktree-setup-" .. os.time() .. ".sh"
  local file = io.open(temp_script, "w")
  if file then
    file:write(setup_script)
    file:close()

    -- iTerm2の最前面のタブでスクリプトを実行するAppleScript
    local escaped_script = temp_script:gsub("'", "\\'")
    local applescript = string.format(
      [[
tell application "iTerm"
    if (count of windows) > 0 then
        tell current session of current tab of current window
            write text "bash '%s' && echo 'セットアップ完了' && rm -f '%s'"
        end tell
    end if
end tell
]],
      escaped_script,
      escaped_script
    )

    local applescript_file = "/tmp/nvim-iterm-script-" .. os.time() .. ".scpt"
    local script_file = io.open(applescript_file, "w")
    if script_file then
      script_file:write(applescript)
      script_file:close()

      -- AppleScriptを実行（少し遅延を入れてタブが確実に開かれてから実行）
      vim.defer_fn(function()
        local result = vim.system({ "osascript", applescript_file }, { timeout = 5000 })
        vim.schedule(function()
          -- AppleScriptファイルを削除
          vim.fn.system("rm -f " .. applescript_file)
          if result and result.code ~= 0 then
            vim.notify(
              "⚠️ AppleScript実行でエラーが発生しましたが、セットアップは完了しています",
              vim.log.levels.WARN
            )
          end
        end)
      end, 1500) -- 1.5秒待機
    else
      vim.notify("❌ AppleScript作成に失敗", vim.log.levels.ERROR)
      vim.fn.system("rm -f " .. temp_script)
    end
  else
    vim.notify("❌ セットアップスクリプトの作成に失敗", vim.log.levels.ERROR)
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
    vim.notify("❌ ディレクトリが見つかりません: " .. target_path, vim.log.levels.ERROR)
    return
  end

  if vim.fn.getcwd() == target_path then
    vim.notify("ℹ️ 既に " .. branch_name .. " にいます", vim.log.levels.INFO)
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
          vim.notify("⚠️ 修復モードで削除中...", vim.log.levels.WARN)
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
    vim.notify("❌ Gitリポジトリではありません", vim.log.levels.ERROR)
    return
  end

  -- main以外のworktreeを収集
  local worktrees_to_delete = {}
  for _, worktree in ipairs(worktree_list) do
    if worktree.path ~= git_root then
      table.insert(worktrees_to_delete, worktree)
    end
  end

  if #worktrees_to_delete == 0 then
    vim.notify("🌳 削除対象のWorktreeがありません", vim.log.levels.INFO)
    return
  end

  -- 削除確認リスト表示
  local delete_list = {}
  for _, worktree in ipairs(worktrees_to_delete) do
    table.insert(delete_list, "  🗑️ " .. worktree.branch .. " (" .. vim.fn.fnamemodify(worktree.path, ":t") .. ")")
  end

  local message = string.format(
    "🚨 main以外の全Worktreeを削除します:\n\n%s\n\n合計 %d個のWorktreeを削除します。\nこの操作は元に戻せません！\n\n続行しますか? [y/N]",
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
    else
      vim.notify("削除をキャンセルしました", vim.log.levels.INFO)
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
    vim.notify("❌ 有効なworktreeが見つかりません", vim.log.levels.WARN)
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

        -- メインプロジェクト（worktree以外）は削除不可
        if item.path == get_git_root() then
          vim.notify("⚠️ メインプロジェクトは削除できません", vim.log.levels.WARN)
          return
        end

        picker:close()

        -- 単一キー確認
        vim.schedule(function()
          vim.notify("🗑️ Worktree '" .. item.branch .. "' を削除しますか? [y/N]", vim.log.levels.WARN)

          local function cleanup_and_execute(should_delete)
            pcall(vim.keymap.del, "n", "y", { buffer = true })
            pcall(vim.keymap.del, "n", "N", { buffer = true })
            pcall(vim.keymap.del, "n", "<Esc>", { buffer = true })

            if should_delete then
              delete_worktree_async(item.path, item.branch)
            else
              vim.notify("削除をキャンセルしました", vim.log.levels.INFO)
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
          vim.notify("❌ Worktreeが選択されていません", vim.log.levels.WARN)
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
        vim.notify("❌ Worktreeが選択されていません", vim.log.levels.WARN)
        return
      end
      switch_worktree(item.path, item.branch)
    end,
  })
end

--[[
機能概要: Git Worktree管理機能（作成・切り替え・削除）
設定内容: plenary.nvimを使用したカスタムワークツリー機能
キーバインド: <leader>gW (作成), <leader>gw (一覧・切り替え・削除)
--]]
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
