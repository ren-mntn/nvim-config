return {
  -- マウス操作の拡張設定
  {
    dir = vim.fn.stdpath("config"), -- ローカル設定として扱う
    name = "mouse-enhancements",
    event = "VeryLazy", -- 遅延読み込み
    priority = 100,
    opts = {
      -- マウス設定をoptsで管理
      mouse = "a",
      scrolloff = 8,
      sidescrolloff = 8,
      mousetime = 200,
    },
    config = function(_, opts)
      -- optsからマウス設定を適用
      vim.opt.mouse = opts.mouse
      vim.opt.scrolloff = opts.scrolloff
      vim.opt.sidescrolloff = opts.sidescrolloff
      vim.opt.mousetime = opts.mousetime
      
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