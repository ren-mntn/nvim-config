-- Git Worktree管理機能 (リファクタリング版)

local M = {}

-- 設定
local CONFIG = {
  setup_timeout = 60000, -- スクリプト削除タイムアウト
}

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

      -- 未コミット変更をチェック（追跡ファイルのみ）
      local has_changes = vim.fn.system("git diff HEAD --name-only"):gsub("\n", "") ~= ""
      local patch_file = nil

      if has_changes then
        vim.notify("📦 未コミット変更をパッチとして保存中...", vim.log.levels.INFO)
        -- 現在の変更をパッチファイルに保存（追跡ファイルのみ）
        patch_file = "/tmp/worktree-patch-" .. os.time() .. ".patch"
        -- ステージングされた変更と未ステージの変更を両方含める（追跡ファイルのみ）
        vim.fn.system("git diff HEAD > " .. patch_file)
        local patch_size = vim.fn.getfsize(patch_file)
        if patch_size > 0 then
          vim.notify("✅ パッチファイル作成完了", vim.log.levels.INFO)
        else
          patch_file = nil
        end
      end

      -- プロジェクト固有のドットファイルのコピー準備
      local dot_files = {}
      -- .gitignoreされているが、プロジェクトルートにあるすべてのドットファイルを収集
      -- （ただし、.gitと.DS_Storeは除外）
      local all_dotfiles = vim.fn
        .system([[
        ls -a | grep '^\.' | grep -v '^\.git$' | grep -v '^\.DS_Store' | grep -v '^\.$' | grep -v '^\.\.$' | grep -v '/$'
      ]])
        :gsub("\n", " ")

      if all_dotfiles ~= "" then
        dot_files = vim.split(all_dotfiles, " ")
        -- 空文字列を除去
        dot_files = vim.tbl_filter(function(f)
          return f ~= ""
        end, dot_files)
      end

      -- Git worktree作成
      vim.notify("⚙️ Git worktree作成中...", vim.log.levels.INFO)

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

      vim.notify("✅ Git worktree作成完了", vim.log.levels.INFO)

      -- 先にiTerm2タブを開く
      vim.notify("📱 iTerm2タブを開いています...", vim.log.levels.INFO)
      vim.fn.system(string.format("cd %s && open -a iTerm.app .", vim.fn.shellescape(worktree_path)))

      -- セットアップスクリプト作成・タブ内実行
      M.execute_setup_in_tab(worktree_path, git_root, patch_file, dot_files)
    end)
  end)
end

-- セットアップスクリプト実行
function M.execute_setup_script(worktree_path, git_root, patch_file, dot_files)
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
    dot_files_section,
    worktree_path
  )

  local temp_script = "/tmp/nvim-worktree-setup-" .. os.time() .. ".sh"
  local file = io.open(temp_script, "w")
  if file then
    file:write(setup_script)
    file:close()

    vim.notify("🚀 セットアップスクリプトを実行中...", vim.log.levels.INFO)
    vim.cmd("terminal bash " .. temp_script)

    -- スクリプト削除
    vim.defer_fn(function()
      vim.fn.system("rm -f " .. temp_script)
    end, CONFIG.setup_timeout)
  else
    vim.notify("❌ セットアップスクリプトの作成に失敗", vim.log.levels.ERROR)
  end
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
    local applescript = string.format(
      [[
tell application "iTerm"
    if (count of windows) > 0 then
        tell current session of current tab of current window
            write text "bash %s && echo 'スクリプト実行完了' && rm -f %s"
        end tell
    end if
end tell
]],
      temp_script,
      temp_script
    )

    local applescript_file = "/tmp/nvim-iterm-script-" .. os.time() .. ".scpt"
    local script_file = io.open(applescript_file, "w")
    if script_file then
      script_file:write(applescript)
      script_file:close()

      vim.notify("🚀 iTerm2タブでセットアップスクリプトを実行中...", vim.log.levels.INFO)

      -- AppleScriptを実行（少し遅延を入れてタブが確実に開かれてから実行）
      vim.defer_fn(function()
        vim.system({ "osascript", applescript_file }, {}, function()
          vim.schedule(function()
            -- AppleScriptファイルを削除
            vim.fn.system("rm -f " .. applescript_file)
          end)
        end)
      end, 1000) -- 1秒待機
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
              display = string.format("🌿 %s (main project)%s", branch, current_mark),
              text = string.format("🌿 %s (main project)%s", branch, current_mark),
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
            display = string.format("🌿 %s (%s)%s", branch, display_path, current_mark),
            text = string.format("🌿 %s (%s)%s", branch, display_path, current_mark),
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

  vim.cmd("cd " .. vim.fn.fnameescape(target_path))
  vim.notify("✅ 切り替え完了: " .. branch_name, vim.log.levels.INFO)

  -- Neo-tree更新
  vim.schedule(function()
    vim.defer_fn(function()
      pcall(function()
        vim.cmd("Neotree filesystem refresh")
      end)
    end, 200)
  end)
end

-- 3段階削除処理（ブランチも削除）
local function delete_worktree_async(path, branch_name)
  vim.notify("🔄 バックグラウンドで削除処理中...", vim.log.levels.INFO)

  -- Stage 1: git worktree prune
  vim.system({ "git", "worktree", "prune" }, {}, function()
    -- Stage 2: git worktree remove --force
    vim.system({ "git", "worktree", "remove", "--force", path }, {}, function(result)
      vim.schedule(function()
        if result.code == 0 then
          -- Stage 3: ローカルブランチも削除
          vim.system({ "git", "branch", "-D", branch_name }, {}, function(branch_result)
            vim.schedule(function()
              if branch_result.code == 0 then
                vim.notify("🗑️ Worktreeとブランチ削除完了: " .. branch_name, vim.log.levels.INFO)
              else
                vim.notify(
                  "🗑️ Worktree削除完了（ブランチ削除スキップ）: " .. branch_name,
                  vim.log.levels.INFO
                )
              end
            end)
          end)
        else
          vim.notify("⚠️ 修復モードで削除中...", vim.log.levels.WARN)
          -- Stage 3: 強制削除 + ディレクトリ削除 + prune + ブランチ削除
          vim.system({ "rm", "-rf", path }, {}, function()
            vim.system({ "git", "worktree", "prune" }, {}, function()
              -- ブランチも削除
              vim.system({ "git", "branch", "-D", branch_name }, {}, function(branch_result)
                vim.schedule(function()
                  if branch_result.code == 0 then
                    vim.notify(
                      "🗑️ 修復・削除完了（ブランチ含む）: " .. branch_name,
                      vim.log.levels.INFO
                    )
                  else
                    vim.notify(
                      "🗑️ 修復・削除完了（ブランチ削除スキップ）: " .. branch_name,
                      vim.log.levels.INFO
                    )
                  end
                end)
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
      vim.notify("🔄 " .. #worktrees_to_delete .. "個のWorktreeを削除中...", vim.log.levels.INFO)

      -- 逐次削除実行
      local completed = 0
      for _, worktree in ipairs(worktrees_to_delete) do
        delete_worktree_async(worktree.path, worktree.branch)
        completed = completed + 1
      end

      vim.notify("✅ " .. completed .. "個のWorktree削除処理を開始しました", vim.log.levels.INFO)
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
    title = "🌳 Git Worktrees [Enter: 切り替え | Ctrl-d: 削除 | D: 一括削除 | ?: ヘルプ]",
    format = function(item, picker)
      return { { item.display, "Normal" } }
    end,
    layout = { preset = "select" }, -- selectプリセットを使用（中央表示、プレビューなし）
    matcher = { sort_empty = false }, -- 空の検索時はソートしない（元の順序を保持）
    sort = false, -- 完全にソートを無効化
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
          ["?"] = {
            function(picker)
              vim.notify(
                "🌳 Git Worktree操作ヘルプ:\n\n⌨️  キー操作:\n  Enter      : 選択したWorktreeに切り替え\n  Ctrl-d     : 選択したWorktreeを削除 (確認あり)\n  d          : 選択したWorktreeを削除 (確認あり)\n  D          : main以外の全Worktreeを削除 (確認あり)\n  Esc        : ピッカーを閉じる\n  ?          : このヘルプを表示\n\n🚀 機能:\n  • Worktree間の高速切り替え\n  • 個別・一括での安全な削除\n  • メインプロジェクトは削除不可\n\n💡 ヒント:\n  削除時は「y」で実行、「N」でキャンセル",
                vim.log.levels.INFO
              )
            end,
            mode = { "n", "i" },
          },
        },
      },
      list = {
        keys = {
          ["d"] = "worktree_delete",
          ["D"] = "worktree_delete_all",
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
