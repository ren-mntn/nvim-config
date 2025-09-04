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

    -- ファイル表示形式の設定（ファイル名先頭表示）
    opts.picker.formatters = vim.tbl_deep_extend("force", opts.picker.formatters or {}, {
      file = {
        filename_only = false, -- フルパス表示（階層を省略しない）
        filename_first = true, -- ファイル名を先頭に表示（重要）
        truncate = 100, -- パス省略を調整（デフォルト40→100）
        show_dirname = true, -- ディレクトリ名も表示
        relative = "cwd", -- 現在のワーキングディレクトリからの相対パス
      },
    })

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
      -- プロジェクトルートから検索（モノレポ対応）
      cwd = function()
        -- .gitがあるルートディレクトリを検索
        local root = vim.fn.finddir(".git", ".;")
        if root ~= "" then
          return vim.fn.fnamemodify(root, ":h")
        end
        return vim.fn.getcwd()
      end,
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
      -- vim.api.nvim_set_hl(0, "GitSignsAdd", {
      --   bg = "#4d8900",
      --   fg =  "#E8E8E8"     })
      --
      -- vim.api.nvim_set_hl(0, "GitSignsChange", {
      --   bg = "#6a8bff",
      --   fg = "#E8E8E8"
      -- })
      --
      -- vim.api.nvim_set_hl(0, "GitSignsDelete", {
      --   bg = "#f34b50",
      --   fg =  "#E8E8E8",
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
  -- キーマップはkeymaps.luaで管理
}
