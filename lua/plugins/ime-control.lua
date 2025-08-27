-- IME制御プラグイン - 日本語入力の想定外動作を防止
--
-- 機能概要:
-- 1. モード切り替え時の自動IME制御 (InsertLeave/CmdlineLeave時に英数切替)
-- 2. neo-tree、Buffer等のフォーカス時に英数切替
-- 3. 全角スペース「　」誤入力時の自動処理
--    - ノーマルモード: 全角スペース → IME英数切替 + Leaderキーメニュー表示
--    - Insertモード: 全角スペース → Escape + IME英数切替 + Leaderキーメニュー表示
--    - コマンドモード: 全角スペース → キャンセル + IME英数切替 + Leaderキーメニュー表示
--
-- 依存: macism (macOS用IME切り替えツール)
return {
  "keaising/im-select.nvim",
  event = "VeryLazy", -- 必須：遅延読み込み設定（CLAUDE.md:242）
  keys = {
    -- Escキーでの確実なIME切り替え（日本語入力時に英数に切り替え）
    {
      "<Esc>",
      function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
        vim.schedule(function()
          vim.fn.system("macism com.apple.keylayout.ABC")
        end)
      end,
      mode = "i",
      desc = "Escape + IME英数切り替え",
    },
    {
      "<Esc>",
      function()
        vim.schedule(function()
          vim.fn.system("macism com.apple.keylayout.ABC")
        end)
      end,
      mode = "n",
      desc = "ノーマルモードでEscape + IME英数切り替え",
    },
    -- 全角スペースマッピング（CLAUDE.md:統合ルール準拠）
    {
      "　",
      function()
        vim.fn.system("macism com.apple.keylayout.ABC")
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>", true, false, true), "m", false)
      end,
      mode = "n",
      desc = "全角スペース→IME切り替え + Leader",
    },
    {
      "　",
      function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
        vim.schedule(function()
          vim.fn.system("macism com.apple.keylayout.ABC")
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>", true, false, true), "m", false)
        end)
      end,
      mode = "i",
      desc = "全角スペース→Escape + IME切り替え + Leader",
    },
    {
      "　",
      function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
        vim.schedule(function()
          vim.fn.system("macism com.apple.keylayout.ABC")
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>", true, false, true), "m", false)
        end)
      end,
      mode = "c",
      desc = "全角スペース→コマンドキャンセル + IME切り替え + Leader",
    },
  },
  opts = function(_, opts)
    -- デバッグ（実装時のみ、完了時削除）
    -- print("=== DEBUG: Initial ime-control opts ===")
    -- print(vim.inspect(opts))

    -- 安全な初期化
    opts = opts or {}

    -- 設定のマージ（完全上書きではない）
    opts = vim.tbl_deep_extend("force", opts, {
      -- macOSでmacismを使用（既存環境で確認済み）
      default_im_select = "com.apple.keylayout.ABC",
      default_command = "macism", -- macOS用コマンド
      -- InsertLeaveでIMEオフ、CmdlineLeaveでもIMEオフ
      set_default_events = { "InsertLeave", "CmdlineLeave" },
      -- InsertEnterで以前のIME状態を復元しない（常に英数で開始）
      set_previous_events = {},
      -- 非同期切り替えでパフォーマンス向上
      async_switch_im = true,
      keep_quiet_on_no_binary = false,
    })

    return opts
  end,
  config = function(_, opts)
    -- im-select.nvimの初期化
    require("im_select").setup(opts)

    -- macismが利用可能かチェック
    local function has_macism()
      return vim.fn.executable("macism") == 1
    end

    -- 英数入力に切り替える関数
    local function switch_to_abc()
      if has_macism() then
        -- pcallでエラーハンドリング
        local success, error = pcall(function()
          vim.fn.system("macism com.apple.keylayout.ABC")
        end)

        if not success then
          vim.notify("macism error: " .. tostring(error), vim.log.levels.WARN)
        end
      end
    end

    -- neo-tree、Buffer等のフォーカス時にIMEを英数に切り替え
    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
      group = vim.api.nvim_create_augroup("IMEControlBufferFocus", { clear = true }),
      pattern = "*",
      callback = function()
        local buftype = vim.bo.buftype
        local filetype = vim.bo.filetype

        -- 特殊バッファ（neo-tree、help、qf、terminal等）で英数切替
        if
          buftype == "help"
          or buftype == "quickfix"
          or buftype == "terminal"
          or buftype == "nofile"
          or filetype == "neo-tree"
          or filetype == "help"
          or filetype == "qf"
          or filetype == "telescope"
        then
          switch_to_abc()
        -- 通常のファイルバッファ（buftype=""）でも英数切替
        elseif buftype == "" then
          switch_to_abc()
        end
      end,
    })
  end,
}
