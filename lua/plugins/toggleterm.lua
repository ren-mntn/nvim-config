return {
  "akinsho/toggleterm.nvim",
  version = "*",
  event = "VeryLazy", -- 遅延読み込み（cmdではなくeventに変更）
  keys = {
    { "`", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
    { "<leader>tt", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
    { "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Toggle Horizontal Terminal" },
    { "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>", desc = "Toggle Vertical Terminal" },
    { "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", desc = "Toggle Float Terminal" },
    { "<leader>ta", "<cmd>ToggleTermToggleAll<cr>", desc = "Toggle All Terminals" },
    { "<leader>tN", "<cmd>ToggleTermSetName<cr>", desc = "Set Terminal Name" },
    { "<leader>ts", "<cmd>TermSelect<cr>", desc = "Select Terminal" },
    -- 特定のターミナルを開く（番号付き）
    { "<leader>t1", "<cmd>1ToggleTerm<cr>", desc = "Toggle Terminal 1" },
    { "<leader>t2", "<cmd>2ToggleTerm<cr>", desc = "Toggle Terminal 2" },
    { "<leader>t3", "<cmd>3ToggleTerm<cr>", desc = "Toggle Terminal 3" },
    { "<leader>t4", "<cmd>4ToggleTerm<cr>", desc = "Toggle Terminal 4" },
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
    { "<leader>tp", "<cmd>lua _python_toggle()<cr>", desc = "Toggle Python REPL" },
    { "<leader>tn", "<cmd>lua _node_toggle()<cr>", desc = "Toggle Node REPL" },
    { "<leader>tc", "<cmd>lua _htop_toggle()<cr>", desc = "Toggle htop" },
  },
  opts = {
    size = 80,
    open_mapping = [[`]],
    start_in_insert = true,
    direction = "vertical",
    persist_mode = false,
    shade_terminals = true,
  },
  opts = function(_, opts)
    -- カスタムターミナルとキーマップを設定
    opts.on_create = function()
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
        -- 明示的に環境変数を付与して起動（念のためenvオプションと二重指定）
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
          LAZYGIT_CONFIG_FILE = vim.fn.expand("~/.config/nvim/lua/plugins/lazygit.ui.yml"),
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

      function _lazygit_toggle()
        lazygit:toggle()
      end

      -- その他のカスタムターミナル
      local terminals = {
        node = Terminal:new({ cmd = "node", hidden = true, direction = "float" }),
        python = Terminal:new({ cmd = "python3", hidden = true, direction = "float" }),
        htop = Terminal:new({ cmd = "htop", hidden = true, direction = "float", float_opts = { border = "single" } }),
      }

      function _node_toggle() terminals.node:toggle() end
      function _python_toggle() terminals.python:toggle() end  
      function _htop_toggle() terminals.htop:toggle() end
    end
    
    return opts
  end,
}