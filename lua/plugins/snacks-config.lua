-- ~/.config/nvim/lua/plugins/snacks-config.lua
-- Snacks.nvim設定（高速検索・node_modules除外）
return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    -- 既存のpicker設定を安全に拡張
    opts.picker = opts.picker or {}

    -- 人気設定：VSCode風レイアウトをデフォルトに
    opts.picker.layout = opts.picker.layout or {}
    opts.picker.layout.preset = "ivy_split" -- おすすめ：ivyレイアウト（下部表示・プレビュー付き）

    -- 他のプリセット選択肢：
    -- "vscode"    - VSCode風（コンパクト・プレビューなし）
    -- "ivy"       - 下部表示・プレビュー付き（おすすめ）
    -- "ivy_split" - ivy + メイン画面プレビュー
    -- "vertical"  - 縦長レイアウト
    -- "select"    - 選択用小レイアウト

    -- 人気設定：頻度追跡（Frecency）
    opts.picker.matcher = vim.tbl_deep_extend("force", opts.picker.matcher or {}, {
      frecency = true, -- 頻度ベース検索
      cwd_bonus = true, -- 現在ディレクトリのファイルを優先
      sort_empty = true, -- 空文字でもソート
    })

    -- 人気設定：アイコン表示
    opts.picker.icons = vim.tbl_deep_extend("force", opts.picker.icons or {}, {
      files = {
        enabled = true, -- ファイルアイコン有効
        dir = "📁 ",
        file = "📄 ",
      },
      git = {
        enabled = true, -- Gitアイコン有効
      },
    })

    -- LazyVimの既存設定を継承してファイル検索設定を拡張
    opts.picker.files = vim.tbl_deep_extend("force", opts.picker.files or {}, {
      hidden = false,
      ignored = true, -- gitignoreを尊重（最重要）
      exclude = {
        "node_modules/**",
        "dist/**",
        "build/**",
        ".git/**",
        "target/**",
        "coverage/**",
      },
    })

    -- LazyVimの既存設定を継承してテキスト検索設定を拡張
    opts.picker.grep = vim.tbl_deep_extend("force", opts.picker.grep or {}, {
      hidden = false,
      ignored = true, -- gitignoreを尊重（最重要）
      exclude = {
        "node_modules/**",
        "dist/**",
        "build/**",
        ".git/**",
        "target/**",
        "coverage/**",
      },
    })

    -- インデントガイドのアニメーションを無効化
    opts.indent = vim.tbl_deep_extend("force", opts.indent or {}, {
      animate = {
        enabled = false, -- アニメーション無効化
      },
    })

    -- statuscolumn無効化（statuscolプラグインを使用するため）
    opts.statuscolumn = vim.tbl_deep_extend("force", opts.statuscolumn or {}, {
      enabled = false, -- snacks.nvimのstatuscolumnを無効化
    })

    -- Zen Mode設定
    opts.zen = vim.tbl_deep_extend("force", opts.zen or {}, {
      enabled = true, -- Zenモード有効
      toggles = {
        dim = false, -- 周りのウィンドウを暗転
        git_signs = false, -- Git表示を隠す
        mini_diff_signs = false, -- MiniDiff表示を隠す
        diagnostics = false, -- 診断を隠す
        inlay_hints = false, -- インレイヒントを隠す
      },
      show = {
        statusline = false, -- ステータスライン非表示
        tabline = false, -- タブライン非表示
      },
      win = { style = "zen" }, -- zenスタイル使用
      -- Zenモード開始時のコールバック
      on_open = function(win)
        -- 必要に応じてカスタム処理
      end,
      -- Zenモード終了時のコールバック
      on_close = function(win)
        -- 必要に応じてカスタム処理
      end,
      -- ズームモード設定
      zoom = {
        toggles = {}, -- ズーム時はトグルしない
        show = {
          statusline = true, -- ステータスライン表示維持
          tabline = true, -- タブライン表示維持
        },
        win = {
          backdrop = true, -- 背景暗転しない
          width = 0, -- 全画面幅
        },
      },
    })

    return opts
  end,
  config = function(_, opts)
    require("snacks").setup(opts)

    -- カスタムハイライトグループを定義する関数
    local function set_snacks_highlights()
      -- Dashboard（スタートスクリーン）のハイライト設定
      vim.api.nvim_set_hl(0, "SnacksDashboardHeader", {
        fg = "#a07145", -- ヘッダー（NEOVIM）の色：ライトグレー（統一感のため）
      })

      vim.api.nvim_set_hl(0, "SnacksDashboardKey", {
        fg = "#a07145", -- キー（f, n, p など）の色：ライトグレー
      })

      vim.api.nvim_set_hl(0, "SnacksDashboardDesc", {
        fg = "#ACAAA2", -- 説明文（Find File, New File など）の色：ライトグレー
      })

      vim.api.nvim_set_hl(0, "SnacksDashboardIcon", {
        fg = "#a07145", -- アイコンの色：ライトグレー
      })

      vim.api.nvim_set_hl(0, "SnacksDashboardFooter", {
        fg = "#ACAAA2", -- フッター（プラグイン数など）の色：グレー
      })

      -- Picker関連のハイライト
      vim.api.nvim_set_hl(0, "SnacksPickerInput", {
        bg = "#1E1E1E", -- 入力欄の背景色
        fg = "#f7fafc", -- 白い文字色
      })

      vim.api.nvim_set_hl(0, "SnacksPickerList", {
        bg = "#1E1E1E", -- リストの背景色
        fg = "#f7fafc", -- ライトグレー文字
      })

      vim.api.nvim_set_hl(0, "SnacksPickerPreview", {
        bg = "#1E1E1E", -- プレビューの背景色
        fg = "#f7fafc", -- ほぼ白の文字
      })

      vim.api.nvim_set_hl(0, "SnacksPickerBorder", {
        bg = "#1E1E1E",
        fg = "#bcbcbc", -- 境界線の色
      })

      -- Git差分のハイライト強化（テキスト色調整）
      vim.api.nvim_set_hl(0, "DiffAdd", {
        bg = "#2d5a3d", -- 追加行：緑背景
        fg = "#a7e87c", -- 明るい緑文字（よく見える）
      })

      vim.api.nvim_set_hl(0, "DiffDelete", {
        bg = "#5a2d2d", -- 削除行：赤背景
        fg = "#ff9999", -- 明るい赤文字（よく見える）
      })

      vim.api.nvim_set_hl(0, "DiffChange", {
        bg = "#5a5a2d", -- 変更行：黄背景
        fg = "#ffff99", -- 明るい黄文字（よく見える）
      })

      vim.api.nvim_set_hl(0, "DiffText", {
        bg = "#804020", -- 変更部分：茶色背景
        fg = "#ffcc99", -- 明るいオレンジ文字（よく見える）
      })

      -- -- GitSigns用ハイライトも設定
      -- local colors = require("config.colors")
      -- vim.api.nvim_set_hl(0, "GitSignsAdd", {
      --   bg = "#4C5A2C",
      --   fg = colors.colors.white
      -- })

      -- vim.api.nvim_set_hl(0, "GitSignsChange", {
      --   bg = "#4d4d00",
      --   fg = "#000000"
      -- })

      -- vim.api.nvim_set_hl(0, "GitSignsDelete", {
      --   bg = "#4d0000",
      --   fg = colors.colors.white
      -- })
    end

    -- 初回設定
    set_snacks_highlights()

    -- ColorScheme変更後にも再適用（テーマ変更で上書きされるのを防ぐ）
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = set_snacks_highlights,
      desc = "Re-apply Snacks picker highlights after colorscheme change",
    })
  end,
  keys = {
    -- VSCode風ショートカット追加
    {
      "<S-D-f>",
      function()
        require("snacks").picker.grep()
      end,
      desc = "Live Grep (Snacks)",
    },
    {
      "<D-S-f>",
      function()
        require("snacks").picker.grep()
      end,
      desc = "Live Grep (Snacks Alt)",
    },

    -- 基本のファイル検索
    {
      "<leader>ff",
      function()
        require("snacks").picker.files()
      end,
      desc = "Find Files",
    },
    {
      "<leader>fg",
      function()
        require("snacks").picker.grep()
      end,
      desc = "Live Grep",
    },
    {
      "<leader>fb",
      function()
        require("snacks").picker.buffers()
      end,
      desc = "Buffers",
    },
    {
      "<leader>fr",
      function()
        require("snacks").picker.recent()
      end,
      desc = "Recent Files",
    },

    -- 超便利な機能追加
    {
      "<leader>fc",
      function()
        require("snacks").picker.colorschemes()
      end,
      desc = "Colorschemes",
    },
    {
      "<leader>fh",
      function()
        require("snacks").picker.help()
      end,
      desc = "Help Tags",
    },
    {
      "<leader>fk",
      function()
        require("snacks").picker.keymaps()
      end,
      desc = "Keymaps",
    },
    {
      "<leader>fl",
      function()
        require("snacks").picker.lines()
      end,
      desc = "Lines in Buffer",
    },
    {
      "<leader>fs",
      function()
        require("snacks").picker.smart()
      end,
      desc = "Smart Picker",
    },
    {
      "<leader>fu",
      function()
        require("snacks").picker.undo()
      end,
      desc = "Undo History",
    },

    -- Git関連（競合回避のため一部キー変更）
    {
      "<leader>gF",
      function()
        require("snacks").picker.git_files()
      end,
      desc = "Git Files (All)",
    },
    {
      "<leader>gs",
      function()
        require("snacks").picker.git_status({
          preview = "git_status", -- Git差分プレビュー強化
          win = {
            input = {
              keys = {
                -- ステージング操作
                ["<Tab>"] = { "git_stage", mode = { "n", "i" }, desc = "Stage/Unstage file" },
                ["<S-Tab>"] = { "git_unstage", mode = { "n", "i" }, desc = "Unstage file" },
                ["<C-a>"] = { "git_stage_all", mode = { "n", "i" }, desc = "Stage all files" },
                ["<C-r>"] = { "git_reset", mode = { "n", "i" }, desc = "Reset file" },
              },
            },
            preview = {
              wo = {
                number = true,
                relativenumber = false, -- 行番号表示
                wrap = false, -- 行の折り返しなし
              },
            },
          },
          -- プレビュー時のハイライト強制設定
          on_show = function(picker)
            -- 即座にグローバルにハイライトを適用
            vim.cmd([[
            highlight! DiffAdd guibg=#2d5a3d guifg=#f4f7f7 gui=NONE
            highlight! DiffDelete guibg=#5a2d2d guifg=#f4f7f7 gui=NONE
            highlight! DiffChange guibg=#5a5a2d guifg=#f4f7f7 gui=NONE
            highlight! DiffText guibg=#804020 guifg=#f4f7f7 gui=NONE
            highlight! @diff.plus guibg=#2d5a3d guifg=#f4f7f7 gui=NONE
            highlight! @diff.minus guibg=#5a2d2d guifg=#f4f7f7 gui=NONE
            highlight! @diff.delta guibg=#5a5a2d guifg=#f4f7f7 gui=NONE
          ]])

            -- プレビューウィンドウ特有の設定
            if picker.preview and picker.preview.win then
              local preview_buf = vim.api.nvim_win_get_buf(picker.preview.win.win)
              vim.api.nvim_buf_set_option(preview_buf, "filetype", "diff")
            end
          end,
        })
      end,
      desc = "Git Status (Changed Files)",
    },
    {
      "<leader>gS",
      function()
        require("snacks").picker.git_stash()
      end,
      desc = "Git Stash",
    },

    -- 特定の変更タイプのみ
    {
      "<leader>gm",
      function()
        require("snacks").picker.git_status({
          filter = function(item)
            return item.status and item.status:match("^[MA]") -- Modified or Added のみ
          end,
        })
      end,
      desc = "Git Modified/Added Files",
    },

    -- 差分表示が見やすいGit機能
    {
      "<leader>gd",
      function()
        -- ファイルを選んでdiff表示
        require("snacks").picker.git_status({
          confirm = function(picker, item)
            if item and item.file then
              -- 新しいタブで差分を表示
              vim.cmd("tabnew")
              vim.cmd("Gvdiffsplit HEAD -- " .. item.file)
            end
          end,
        })
      end,
      desc = "Git Diff (Visual Split)",
    },

    -- 部分的ステージング用
    {
      "<leader>gp",
      function()
        -- ファイルを選んで部分的ステージング
        require("snacks").picker.git_status({
          confirm = function(picker, item)
            if item and item.file then
              picker:close()
              -- Fugitiveでインタラクティブステージング
              vim.cmd("Git add --patch " .. item.file)
            end
          end,
        })
      end,
      desc = "Git Patch Add (Partial Staging)",
    },

    -- インタラクティブGit
    {
      "<leader>gi",
      function()
        vim.cmd("Git")
      end,
      desc = "Git Interactive (Fugitive)",
    },

    -- クイックコミット機能
    {
      "<leader>gC",
      function()
        -- ステージ済みファイルがあるかチェック
        local staged = vim.fn.system("git diff --cached --name-only"):gsub("%s+", "")
        if staged == "" then
          vim.notify("No staged changes to commit", vim.log.levels.WARN)
          return
        end

        -- コミットメッセージを入力
        vim.ui.input({ prompt = "Commit message: " }, function(msg)
          if msg and msg ~= "" then
            vim.cmd("Git commit -m '" .. msg .. "'")
            vim.notify("Committed: " .. msg, vim.log.levels.INFO)
          end
        end)
      end,
      desc = "Quick Commit (with message)",
    },

    -- ステージ＋コミット
    {
      "<leader>gA",
      function()
        vim.ui.input({ prompt = "Commit message (will stage all): " }, function(msg)
          if msg and msg ~= "" then
            vim.cmd("Git add .")
            vim.cmd("Git commit -m '" .. msg .. "'")
            vim.notify("Staged all & committed: " .. msg, vim.log.levels.INFO)
          end
        end)
      end,
      desc = "Stage All & Commit",
    },

    -- プロジェクト・セッション
    {
      "<leader>fp",
      function()
        require("snacks").picker.projects()
      end,
      desc = "Projects",
    },

    -- 診断・LSP関連
    {
      "<leader>fd",
      function()
        require("snacks").picker.diagnostics()
      end,
      desc = "Diagnostics (All)",
    },
    {
      "<leader>fD",
      function()
        require("snacks").picker.diagnostics_buffer()
      end,
      desc = "Diagnostics (Buffer)",
    },
    {
      "<leader>ft",
      function()
        require("snacks").picker.treesitter()
      end,
      desc = "Treesitter Symbols",
    },

    -- Zen Mode関連
    {
      "<leader>z",
      function()
        require("snacks").zen()
      end,
      desc = "Toggle Zen Mode",
    },
    {
      "<leader>Z",
      function()
        require("snacks").zen.zoom()
      end,
      desc = "Toggle Zoom Mode",
    },

    -- その他便利機能（通知履歴は一時的に無効化 - Snacksのバグ回避）
    -- { "<leader>fn", function() require("snacks").notifier.show_history() end, desc = "Notification History" },
    {
      "<leader>fn",
      function()
        vim.cmd("messages")
      end,
      desc = "Messages History",
    }, -- 代替：Vimの標準メッセージ履歴
  },
}
