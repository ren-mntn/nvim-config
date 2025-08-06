return {
  "Pocco81/auto-save.nvim",
  event = { "TextChanged", "InsertLeave" }, -- 遅延読み込み
  opts = {
    -- オートセーブを有効にする
    enabled = true,
    -- 保存を実行するタイミング
    trigger_events = { "TextChanged", "InsertLeave" },
    -- TextChangedイベントの遅延時間（ミリ秒）
    -- 最後のキー入力から1秒後に保存を実行し、入力のたびに保存が走るのを防ぐ
    debounce = 1000,
    -- 既存のファイルのみオートセーブの対象にする
    conditions = {
      exists = true,
      modifiable = true,
    },
  },
}
