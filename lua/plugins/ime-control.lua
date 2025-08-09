-- IME制御プラグイン - 日本語入力の想定外動作を防止
return {
  "keaising/im-select.nvim",
  event = "VeryLazy", -- 必須：遅延読み込み設定（CLAUDE.md:242）
  opts = {
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
  },
}