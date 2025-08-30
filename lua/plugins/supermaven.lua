--[[
機能概要: Supermaven AI コード補完プラグイン（LazyVim公式準拠）
設定内容: LazyVim extras準拠、最適な読み込みタイミング、公式推奨設定
キーバインド: LazyVim標準（他の補完プラグインと連携）
APIコマンド: :SupermavenUseFree, :SupermavenUsePro, :SupermavenToggle
--]]
return {
  {
    "supermaven-inc/supermaven-nvim",
    event = "InsertEnter",
    cmd = {
      "SupermavenUseFree",
      "SupermavenUsePro",
    },
    opts = function(_, opts)
      -- 安全な初期化
      opts = opts or {}

      -- LazyVim公式準拠設定
      return vim.tbl_deep_extend("force", opts, {
        -- キーマッピング設定（LazyVim公式）
        keymaps = {
          accept_suggestion = nil, -- 他の補完プラグインに委譲
          accept_word = "<C-j>",
          clear_suggestion = "<C-]>",
        },

        -- LazyVim公式ファイルタイプ除外 + 追加
        ignore_filetypes = {
          "bigfile",
          "snacks_input",
          "snacks_notif",
          "gitcommit",
          "help",
        },

        -- 表示色設定
        color = {
          suggestion_color = "#6c7086",
          cterm = 245,
        },

        -- ログ設定
        log_level = "warn",

        -- LazyVim公式準拠のインライン補完制御（LazyVimはblink.cmp使用）
        disable_inline_completion = false,
        disable_keymaps = false,

        -- 条件付き制御（パフォーマンス最適化）
        condition = function()
          local file_size = vim.fn.getfsize(vim.fn.expand("%"))
          if file_size > 1000000 then
            return true
          end

          if vim.bo.buftype ~= "" then
            return true
          end

          return false
        end,
      })
    end,
    config = function(_, opts)
      require("supermaven-nvim").setup(opts)

      -- ハイライトグループを確実に設定
      vim.api.nvim_set_hl(0, "SupermavenSuggestion", {
        fg = "#6c7086",
        italic = true,
      })
    end,
  },
  {
    -- blink.cmp統合（LazyVim公式）
    "saghen/blink.cmp",
    optional = true,
    dependencies = { "supermaven-nvim", "saghen/blink.compat" },
    opts = {
      sources = {
        compat = { "supermaven" },
        providers = {
          supermaven = {
            kind = "Supermaven",
            score_offset = 100,
            async = true,
          },
        },
      },
    },
  },
  {
    -- nvim-cmp統合（LazyVimデフォルト補完との連携）
    "hrsh7th/nvim-cmp",
    optional = true,
    dependencies = { "supermaven-nvim" },
    opts = function(_, opts)
      if vim.g.ai_cmp then
        table.insert(opts.sources, 1, {
          name = "supermaven",
          group_index = 1,
          priority = 100,
        })
      end
    end,
  },
  {
    -- lualine.nvim統合（ステータスバーにSupermaven状態を表示）
    "nvim-lualine/lualine.nvim",
    optional = true,
    event = "VeryLazy",
    opts = function(_, opts)
      if opts.sections and opts.sections.lualine_x then
        table.insert(opts.sections.lualine_x, 2, {
          function()
            local ok, supermaven = pcall(require, "supermaven-nvim.api")
            if ok and supermaven.is_running() then
              return "󰚩 SM"
            else
              return ""
            end
          end,
          color = { fg = "#6c7086" },
        })
      end
    end,
  },
  {
    -- noice.nvim統合（Supermavenの通知を制御）
    "folke/noice.nvim",
    optional = true,
    opts = function(_, opts)
      opts.routes = opts.routes or {}
      vim.list_extend(opts.routes, {
        {
          filter = {
            event = "msg_show",
            any = {
              { find = "Supermaven" },
              { find = "supermaven" },
            },
          },
          opts = { skip = true },
        },
      })
    end,
  },
}
