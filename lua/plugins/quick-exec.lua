-- ~/.config/nvim/lua/plugins/quick-exec.lua
--[
-- 機能概要: VSCode拡張「Quick Execute Commands」をNeovim向けに再現する最小機能
-- 設定内容: Snacksのpicker + ToggleTermで「コマンド登録→検索→実行→履歴→JSON保存」を提供
-- キーバインド: <leader>qq(一覧) / <leader>qa(追加) / <leader>qh(履歴) / <leader>qe(設定編集)
--]
return {
  {
    name = "quick-exec-commands-nvim",
    -- ローカルプラグイン（設定ディレクトリをプラグインrootとして追加）
    dir = vim.fn.stdpath("config"),
    dependencies = {
      "folke/snacks.nvim",
      "akinsho/toggleterm.nvim",
    },
    event = "VeryLazy",
    keys = {
      { "<leader>qq", function() require("quick_exec").open_picker() end, desc = "Quick Exec: コマンド一覧" },
      { "<leader>qa", function() require("quick_exec").add_command_interactive() end, desc = "Quick Exec: コマンド追加" },
      { "<leader>qh", function() require("quick_exec").open_history() end, desc = "Quick Exec: 実行履歴" },
      { "<leader>qe", function() require("quick_exec").open_storage_files() end, desc = "Quick Exec: 設定ファイルを開く" },
    },
    opts = function(_, opts)
      opts = opts or {}
      -- 既存optsとマージ（完全上書き禁止）
      return vim.tbl_deep_extend("force", opts, {
        storage = {
          scope_preference = "workspace_first", -- workspace優先 or global_first
          global_path = vim.fn.stdpath("data") .. "/quick-exec/commands.json",
          workspace_relpath = ".nvim/quick-exec-commands.json",
        },
        history = {
          path = vim.fn.stdpath("data") .. "/quick-exec/history.json",
          max = 100,
        },
        terminals = {
          direction = "float", -- float | vertical | horizontal
        },
      })
    end,
    config = function(_, opts)
      -- pcallで安全にセットアップ
      local ok, mod = pcall(require, "quick_exec")
      if not ok then
        vim.notify("quick_exec の読み込みに失敗しました", vim.log.levels.ERROR)
        return
      end
      mod.setup(opts)
    end,
  },
}


