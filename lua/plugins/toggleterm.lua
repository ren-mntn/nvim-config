return {
  "akinsho/toggleterm.nvim",
  version = "*",
  event = "VeryLazy",
  keys = {
    { "`", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
    { "<leader>tt", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
    { "<leader>tH", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Toggle Horizontal Terminal" },
    { "<leader>tV", "<cmd>ToggleTerm direction=vertical<cr>", desc = "Toggle Vertical Terminal" },
    { "<leader>tF", "<cmd>ToggleTerm direction=float<cr>", desc = "Toggle Float Terminal" },
    { "<leader>ta", "<cmd>ToggleTermToggleAll<cr>", desc = "Toggle All Terminals" },
    { "<leader>tN", "<cmd>ToggleTermSetName<cr>", desc = "Set Terminal Name" },

    -- 現在の行や選択範囲をターミナルに送信
    { "<leader>tl", "<cmd>ToggleTermSendCurrentLine<cr>", desc = "Send Current Line to Terminal" },
    { "<leader>tl", "<cmd>ToggleTermSendVisualLines<cr>", mode = "v", desc = "Send Visual Lines to Terminal" },
    { "<leader>tr", "<cmd>ToggleTermSendVisualSelection<cr>", mode = "v", desc = "Send Visual Selection to Terminal" },
    -- カスタムターミナル
    { "<leader>tg", "<cmd>lua _lazygit_toggle()<cr>", desc = "Toggle LazyGit" },
    -- 代替LazyGitコマンド（ターミナル環境でのフォールバック）
    { "<leader>tG", function()
      vim.cmd("!lazygit")
    end, desc = "LazyGit (external)" },
    -- フロートターミナル（位置別）
    { "<leader>ts", "<cmd>lua _terminal_top_left_toggle()<cr>", desc = "Terminal Top Left" },
    { "<leader>td", "<cmd>lua _terminal_top_toggle()<cr>", desc = "Terminal Top Center" },
    { "<leader>tf", "<cmd>lua _terminal_top_right_toggle()<cr>", desc = "Terminal Top Right" },
    { "<leader>tx", "<cmd>lua _terminal_bottom_left_toggle()<cr>", desc = "Terminal Bottom Left" },
    { "<leader>tc", "<cmd>lua _terminal_bottom_toggle()<cr>", desc = "Terminal Bottom Center" },
    { "<leader>tv", "<cmd>lua _terminal_bottom_right_toggle()<cr>", desc = "Terminal Bottom Right" },
    -- 他のツール
    { "<leader>tp", "<cmd>lua _python_toggle()<cr>", desc = "Toggle Python REPL" },
    { "<leader>tn", "<cmd>lua _node_toggle()<cr>", desc = "Toggle Node REPL" },
    { "<leader>th", "<cmd>lua _htop_toggle()<cr>", desc = "Toggle htop" },
    -- 直接実行バージョン
    { "<leader>tD", "<cmd>lua _ssm_port_forward_toggle()<cr>", desc = "Run SSM Port Forward" },
  },
  config = function()
    require("toggleterm").setup({
      size = 80,
      open_mapping = [[`]],
      start_in_insert = true,
      direction = "vertical",
      persist_mode = false,
      shade_terminals = true,
    })

    -- ターミナルモードのキーマップ設定
    function _G.set_terminal_keymaps()
      vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { noremap = true })
      vim.keymap.set("t", "<S-CR>", [[<CR>]], { noremap = true })
    end
    vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

    -- カスタムターミナルの定義
    local Terminal = require("toggleterm.terminal").Terminal

    -- lazygit（VSCode風の大きめフロートウィンドウ）
    local config_path = vim.fn.expand("~/.config/nvim/lua/plugins/lazygit.ui.yml")
    local lazygit = Terminal:new({
      cmd = "env LAZYGIT_CONFIG_FILE=" .. vim.fn.shellescape(config_path) .. " lazygit",
      hidden = true,
      direction = "float",
      float_opts = {
        border = "rounded",
        width = function()
          return math.floor(vim.o.columns * 0.9)
        end,
        height = function()
          return math.floor(vim.o.lines * 0.9)
        end,
        row = function()
          return math.floor((vim.o.lines - math.floor(vim.o.lines * 0.9)) / 2)
        end,
        col = function()
          return math.floor((vim.o.columns - math.floor(vim.o.columns * 0.9)) / 2)
        end,
        winblend = 0,
      },
      env = {
        TERM = "xterm-256color",
        LAZYGIT_CONFIG_FILE = config_path,
      },
      on_open = function(term)
        vim.cmd("startinsert!")
        vim.keymap.set("t", "<C-q>", "<cmd>close<CR>", { silent = true, buffer = term.bufnr })
        vim.keymap.set("t", "<Esc>", "<cmd>close<CR>", { silent = true, buffer = term.bufnr })
      end,
      on_exit = function(term)
        vim.cmd("checktime")
      end,
    })

    function _G._lazygit_toggle()
      lazygit:toggle()
    end

    -- ターミナルキーマップとサイズ変更の共通関数
    local function setup_terminal_keymaps(term)
      vim.cmd("startinsert!")
      -- 基本的なキーマップ
      vim.keymap.set("t", "<C-c>", "<C-c>", { silent = true, buffer = term.bufnr, desc = "Stop process" })
      vim.keymap.set("t", "<C-q>", "<cmd>close<CR>", { silent = true, buffer = term.bufnr, desc = "Close terminal" })
      
      -- シンプルなキーマップ
      vim.keymap.set("t", "q", function() 
        -- 完全に終了させる（プロセスとバッファを削除）
        term:shutdown()
        if vim.api.nvim_buf_is_valid(term.bufnr) then
          vim.api.nvim_buf_delete(term.bufnr, { force = true })
        end
      end, { silent = true, buffer = term.bufnr, desc = "Close terminal" })
      
      vim.keymap.set("t", "<Esc>", function() 
        term:toggle()  -- 常に隠すだけ
      end, { silent = true, buffer = term.bufnr, desc = "Hide terminal" })
      
      -- サイズ変更キーマップ
      vim.keymap.set("t", "<C-+>", function()
        local win = term.window
        if win then
          vim.api.nvim_win_set_width(win, math.min(vim.api.nvim_win_get_width(win) + 10, vim.o.columns - 10))
        end
      end, { silent = true, buffer = term.bufnr, desc = "Increase width" })
      
      vim.keymap.set("t", "<C-->", function()
        local win = term.window
        if win then
          vim.api.nvim_win_set_width(win, math.max(vim.api.nvim_win_get_width(win) - 10, 40))
        end
      end, { silent = true, buffer = term.bufnr, desc = "Decrease width" })
      
      vim.keymap.set("t", "<C-S-+>", function()
        local win = term.window
        if win then
          vim.api.nvim_win_set_height(win, math.min(vim.api.nvim_win_get_height(win) + 5, vim.o.lines - 5))
        end
      end, { silent = true, buffer = term.bufnr, desc = "Increase height" })
      
      vim.keymap.set("t", "<C-S-->", function()
        local win = term.window
        if win then
          vim.api.nvim_win_set_height(win, math.max(vim.api.nvim_win_get_height(win) - 5, 10))
        end
      end, { silent = true, buffer = term.bufnr, desc = "Decrease height" })
    end

    -- 6つの位置別フロートターミナル
    local terminal_width = 80
    local terminal_height = 20
    local margin = 5

    -- 左上
    local terminal_top_left = Terminal:new({
      hidden = true,
      direction = "float",
      float_opts = {
        border = "rounded",
        width = terminal_width,
        height = terminal_height,
        row = margin,
        col = margin,
        winblend = 10,
      },
      on_open = setup_terminal_keymaps,
      close_on_exit = false,
    })

    -- 上中央
    local terminal_top = Terminal:new({
      hidden = true,
      direction = "float",
      float_opts = {
        border = "rounded",
        width = terminal_width,
        height = terminal_height,
        row = margin,
        col = function() return math.floor((vim.o.columns - terminal_width) / 2) end,
        winblend = 10,
      },
      on_open = setup_terminal_keymaps,
      close_on_exit = false,
    })

    -- 右上
    local terminal_top_right = Terminal:new({
      hidden = true,
      direction = "float",
      float_opts = {
        border = "rounded",
        width = terminal_width,
        height = terminal_height,
        row = margin,
        col = function() return vim.o.columns - terminal_width - margin end,
        winblend = 10,
      },
      on_open = setup_terminal_keymaps,
      close_on_exit = false,
    })

    -- 左下
    local terminal_bottom_left = Terminal:new({
      hidden = true,
      direction = "float",
      float_opts = {
        border = "rounded",
        width = terminal_width,
        height = terminal_height,
        row = function() return vim.o.lines - terminal_height - margin - 2 end,
        col = margin,
        winblend = 10,
      },
      on_open = setup_terminal_keymaps,
      close_on_exit = false,
    })

    -- 下中央
    local terminal_bottom = Terminal:new({
      hidden = true,
      direction = "float",
      float_opts = {
        border = "rounded",
        width = terminal_width,
        height = terminal_height,
        row = function() return vim.o.lines - terminal_height - margin - 2 end,
        col = function() return math.floor((vim.o.columns - terminal_width) / 2) end,
        winblend = 10,
      },
      on_open = setup_terminal_keymaps,
      close_on_exit = false,
    })

    -- 右下
    local terminal_bottom_right = Terminal:new({
      hidden = true,
      direction = "float",
      float_opts = {
        border = "rounded",
        width = terminal_width,
        height = terminal_height,
        row = function() return vim.o.lines - terminal_height - margin - 2 end,
        col = function() return vim.o.columns - terminal_width - margin end,
        winblend = 10,
      },
      on_open = setup_terminal_keymaps,
      close_on_exit = false,
    })

    -- SSMポートフォワード用小さなターミナル（右上）
    local ssm_port_forward = Terminal:new({
      cmd = "./start_ssm_port_forward.sh",
      hidden = true,
      direction = "float",
      float_opts = {
        border = "rounded",
        width = 100,  -- 100文字幅（2倍）
        height = 2,   -- 3行高さ
        row = 1,      -- 最上部
        col = function() return vim.o.columns - 105 end, -- 右上（マージン5文字）
        winblend = 15, -- 少し透明
      },
      on_open = function(term)
        vim.cmd("startinsert!")
        -- 小さなターミナル用のキーマップ
        vim.keymap.set("t", "<C-q>", "<cmd>close<CR>", { silent = true, buffer = term.bufnr, desc = "Close terminal" })
        vim.keymap.set("t", "q", function() term:close() end, { silent = true, buffer = term.bufnr, desc = "Close terminal" })
        vim.keymap.set("t", "<Esc>", function() term:toggle() end, { silent = true, buffer = term.bufnr, desc = "Hide terminal" })
      end,
      close_on_exit = false,
    })

    -- 開発サーバー専用（小さめのフロートウィンドウ）
    local dev_server = Terminal:new({ 
      hidden = true, 
      direction = "float",
      float_opts = {
        border = "rounded",
        width = 80,   -- 固定幅（文字数）
        height = 20,  -- 固定高さ（行数）
        row = 5,      -- 上から5行目に配置
        col = 10,     -- 左から10文字目に配置
        winblend = 10, -- 少し透明
      },
      on_open = function(term)
        vim.cmd("startinsert!")
        -- 開発サーバー用のカスタムキーマップ
        vim.keymap.set("t", "<C-c>", "<C-c>", { silent = true, buffer = term.bufnr, desc = "Stop dev server" })
        vim.keymap.set("t", "<C-q>", "<cmd>close<CR>", { silent = true, buffer = term.bufnr, desc = "Close terminal" })
        vim.keymap.set("t", "q", function() term:close() end, { silent = true, buffer = term.bufnr, desc = "Close terminal" })
        vim.keymap.set("t", "<Esc>", function() term:toggle() end, { silent = true, buffer = term.bufnr, desc = "Hide terminal" })
        
        -- ウィンドウサイズ変更キーマップ
        vim.keymap.set("t", "<C-+>", function()
          local win = term.window
          if win then
            vim.api.nvim_win_set_width(win, math.min(vim.api.nvim_win_get_width(win) + 10, vim.o.columns - 10))
          end
        end, { silent = true, buffer = term.bufnr, desc = "Increase width" })
        
        vim.keymap.set("t", "<C-->", function()
          local win = term.window
          if win then
            vim.api.nvim_win_set_width(win, math.max(vim.api.nvim_win_get_width(win) - 10, 40))
          end
        end, { silent = true, buffer = term.bufnr, desc = "Decrease width" })
        
        vim.keymap.set("t", "<C-S-+>", function()
          local win = term.window
          if win then
            vim.api.nvim_win_set_height(win, math.min(vim.api.nvim_win_get_height(win) + 5, vim.o.lines - 5))
          end
        end, { silent = true, buffer = term.bufnr, desc = "Increase height" })
        
        vim.keymap.set("t", "<C-S-->", function()
          local win = term.window
          if win then
            vim.api.nvim_win_set_height(win, math.max(vim.api.nvim_win_get_height(win) - 5, 10))
          end
        end, { silent = true, buffer = term.bufnr, desc = "Decrease height" })
        
        -- フルスクリーン切り替え
        vim.keymap.set("t", "<C-f>", function()
          local win = term.window
          if win then
            local current_width = vim.api.nvim_win_get_width(win)
            local current_height = vim.api.nvim_win_get_height(win)
            
            -- 現在がフルスクリーンかチェック（大体の値で判断）
            if current_width > vim.o.columns * 0.8 and current_height > vim.o.lines * 0.8 then
              -- 小さく戻す
              vim.api.nvim_win_set_width(win, 80)
              vim.api.nvim_win_set_height(win, 20)
              -- 位置も調整
              local config = vim.api.nvim_win_get_config(win)
              config.row = 5
              config.col = 10
              vim.api.nvim_win_set_config(win, config)
            else
              -- フルスクリーンにする
              vim.api.nvim_win_set_width(win, math.floor(vim.o.columns * 0.9))
              vim.api.nvim_win_set_height(win, math.floor(vim.o.lines * 0.9))
              -- 中央に配置
              local config = vim.api.nvim_win_get_config(win)
              config.row = math.floor((vim.o.lines - math.floor(vim.o.lines * 0.9)) / 2)
              config.col = math.floor((vim.o.columns - math.floor(vim.o.columns * 0.9)) / 2)
              vim.api.nvim_win_set_config(win, config)
            end
          end
        end, { silent = true, buffer = term.bufnr, desc = "Toggle fullscreen" })
      end,
      close_on_exit = false, -- プロセス終了時もターミナルを閉じない
    })

    -- その他のターミナル
    local node = Terminal:new({ cmd = "node", hidden = true, direction = "float" })
    local python = Terminal:new({ cmd = "python3", hidden = true, direction = "float" })
    local htop = Terminal:new({ cmd = "htop", hidden = true, direction = "float", float_opts = { border = "single" } })

    -- グローバル関数として定義
    function _G._node_toggle()
      node:toggle()
    end

    function _G._python_toggle()
      python:toggle()
    end  

    function _G._htop_toggle()
      htop:toggle()
    end

    function _G._dev_server_toggle()
      dev_server:toggle()
    end

    function _G._ssm_port_forward_toggle()
      ssm_port_forward:toggle()
    end

    -- 6つの位置別ターミナル関数（リセット機能付き）
    function _G._terminal_top_left_toggle()
      if terminal_top_left and not terminal_top_left:is_open() and terminal_top_left.job_id == -1 then
        -- 終了済みの場合は新しいインスタンスを作成
        terminal_top_left = Terminal:new({
          hidden = true,
          direction = "float",
          float_opts = {
            border = "rounded",
            width = terminal_width,
            height = terminal_height,
            row = margin,
            col = margin,
            winblend = 10,
          },
          on_open = setup_terminal_keymaps,
          close_on_exit = false,
        })
      end
      terminal_top_left:toggle()
    end

    function _G._terminal_top_toggle()
      if terminal_top and not terminal_top:is_open() and terminal_top.job_id == -1 then
        terminal_top = Terminal:new({
          hidden = true,
          direction = "float",
          float_opts = {
            border = "rounded",
            width = terminal_width,
            height = terminal_height,
            row = margin,
            col = function() return math.floor((vim.o.columns - terminal_width) / 2) end,
            winblend = 10,
          },
          on_open = setup_terminal_keymaps,
          close_on_exit = false,
        })
      end
      terminal_top:toggle()
    end

    function _G._terminal_top_right_toggle()
      if terminal_top_right and not terminal_top_right:is_open() and terminal_top_right.job_id == -1 then
        terminal_top_right = Terminal:new({
          hidden = true,
          direction = "float",
          float_opts = {
            border = "rounded",
            width = terminal_width,
            height = terminal_height,
            row = margin,
            col = function() return vim.o.columns - terminal_width - margin end,
            winblend = 10,
          },
          on_open = setup_terminal_keymaps,
          close_on_exit = false,
        })
      end
      terminal_top_right:toggle()
    end

    function _G._terminal_bottom_left_toggle()
      if terminal_bottom_left and not terminal_bottom_left:is_open() and terminal_bottom_left.job_id == -1 then
        terminal_bottom_left = Terminal:new({
          hidden = true,
          direction = "float",
          float_opts = {
            border = "rounded",
            width = terminal_width,
            height = terminal_height,
            row = function() return vim.o.lines - terminal_height - margin - 2 end,
            col = margin,
            winblend = 10,
          },
          on_open = setup_terminal_keymaps,
          close_on_exit = false,
        })
      end
      terminal_bottom_left:toggle()
    end

    function _G._terminal_bottom_toggle()
      if terminal_bottom and not terminal_bottom:is_open() and terminal_bottom.job_id == -1 then
        terminal_bottom = Terminal:new({
          hidden = true,
          direction = "float",
          float_opts = {
            border = "rounded",
            width = terminal_width,
            height = terminal_height,
            row = function() return vim.o.lines - terminal_height - margin - 2 end,
            col = function() return math.floor((vim.o.columns - terminal_width) / 2) end,
            winblend = 10,
          },
          on_open = setup_terminal_keymaps,
          close_on_exit = false,
        })
      end
      terminal_bottom:toggle()
    end

    function _G._terminal_bottom_right_toggle()
      if terminal_bottom_right and not terminal_bottom_right:is_open() and terminal_bottom_right.job_id == -1 then
        terminal_bottom_right = Terminal:new({
          hidden = true,
          direction = "float",
          float_opts = {
            border = "rounded",
            width = terminal_width,
            height = terminal_height,
            row = function() return vim.o.lines - terminal_height - margin - 2 end,
            col = function() return vim.o.columns - terminal_width - margin end,
            winblend = 10,
          },
          on_open = setup_terminal_keymaps,
          close_on_exit = false,
        })
      end
      terminal_bottom_right:toggle()
    end
  end,
}