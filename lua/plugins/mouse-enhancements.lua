return {
  -- マウス操作の拡張設定
  {
    dir = vim.fn.stdpath("config"), -- ローカル設定として扱う
    name = "mouse-enhancements",
    priority = 100,
    config = function()
      -- マウスサポートを有効化
      vim.opt.mouse = "a"
      
      -- マウスクリックでのウィンドウフォーカス時の挙動
      vim.api.nvim_create_autocmd("WinEnter", {
        callback = function()
          local buftype = vim.bo.buftype
          local filetype = vim.bo.filetype
          
          -- ターミナルにフォーカスしたら自動的にインサートモード
          if buftype == "terminal" then
            vim.cmd("startinsert")
          end
          
          -- Neo-treeにフォーカスしたら現在のファイルを表示
          if filetype == "neo-tree" then
            -- 現在のファイルの位置を表示
            pcall(function()
              require("neo-tree.command").execute({ action = "focus" })
            end)
          end
        end,
      })
      
      -- マウスホイールでのスクロール速度調整
      vim.opt.scrolloff = 8 -- スクロール時の上下の余白
      vim.opt.sidescrolloff = 8 -- 横スクロール時の左右の余白
      
      -- マウスでのリサイズを滑らかに
      vim.opt.mousetime = 200 -- ダブルクリックの判定時間（ミリ秒）
      
      -- 右クリックメニューのカスタマイズ例
      -- vim.opt.mousemodel = "popup_setpos" -- 右クリックでポップアップメニュー表示
      
      -- マウスドラッグでのビジュアル選択を改善
      vim.api.nvim_create_autocmd("ModeChanged", {
        pattern = "*:v",
        callback = function()
          -- ビジュアルモードに入ったときの処理
          -- 例: ステータスラインの色を変える、など
        end,
      })
    end,
  },
}