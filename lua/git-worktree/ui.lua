--[[
機能概要: Git Worktree UI/UX機能
設定内容: Snacks picker UI、キーマッピング処理、ユーザー操作ハンドリング
--]]

local M = {}

function M.show_worktree_list()
  local manager = require("git-worktree.manager")

  local worktree_list = manager.get_worktree_list()

  if #worktree_list == 0 then
    vim.notify("No valid worktrees found", vim.log.levels.WARN)
    return
  end

  Snacks.picker({
    source = "static",
    items = worktree_list,
    title = "Git Worktrees [Enter: 切り替え | d: 削除 | D: 一括削除 | t: iTerm | ?: ヘルプ]",
    sort = false,
    format = function(item, picker)
      return { { item.display } }
    end,
    focus = "list",
    actions = {
      worktree_delete = function(picker)
        local item = picker:current()
        if not item then
          return
        end

        picker:close()

        vim.schedule(function()
          vim.notify("Delete worktree '" .. item.branch .. "'? [y/N]", vim.log.levels.WARN)

          local function cleanup_and_execute(should_delete)
            pcall(vim.keymap.del, "n", "y", { buffer = true })
            pcall(vim.keymap.del, "n", "N", { buffer = true })
            pcall(vim.keymap.del, "n", "<Esc>", { buffer = true })

            if should_delete then
              manager.delete_worktree(item)
            end
          end

          vim.keymap.set("n", "y", function()
            cleanup_and_execute(true)
          end, { buffer = true, nowait = true })
          vim.keymap.set("n", "N", function()
            cleanup_and_execute(false)
          end, { buffer = true, nowait = true })
          vim.keymap.set("n", "<Esc>", function()
            cleanup_and_execute(false)
          end, { buffer = true, nowait = true })
        end)
      end,
      worktree_delete_all = function(picker)
        picker:close()
        vim.schedule(function()
          manager.delete_all_worktrees_except_main()
        end)
      end,
      open_in_iterm = function(picker)
        local item = picker:current()
        if not item then
          vim.notify("No worktree selected", vim.log.levels.WARN)
          return
        end

        picker:close()

        vim.schedule(function()
          manager.open_in_terminal(item)
        end)
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-d>"] = {
            "worktree_delete",
            mode = { "n", "i" },
          },
          ["D"] = {
            "worktree_delete_all",
            mode = { "n", "i" },
          },
          ["<c-t>"] = {
            "open_in_iterm",
            mode = { "n", "i" },
          },
          ["?"] = {
            function(picker)
              vim.notify(
                "Git Worktree操作ヘルプ:\n\n⌨️  キー操作:\n  Enter      : 選択したWorktreeに切り替え\n  d          : 選択したWorktreeを削除 (確認あり)\n  D          : main以外の全Worktreeを削除 (確認あり)\n  t          : 選択したWorktreeでiTerm2タブを開く\n  Esc        : ピッカーを閉じる\n  ?          : このヘルプを表示\n\n🚀 機能:\n  • Worktree間の高速切り替え\n  • 個別・一括での安全な削除\n  • iTerm2タブでWorktree開く\n  • メインプロジェクトは削除不可\n\n💡 ヒント:\n  削除時は「y」で実行、「N」でキャンセル\n  Ctrl+d, Ctrl+tも利用可能",
                vim.log.levels.INFO
              )
            end,
            mode = { "n", "i" },
          },
        },
      },
      list = {
        keys = {
          ["d"] = { "worktree_delete", mode = "n" },
          ["D"] = { "worktree_delete_all", mode = "n" },
          ["t"] = { "open_in_iterm", mode = "n" },
        },
      },
    },
    confirm = function(picker)
      local item = picker:current()
      if not item then
        vim.notify("No worktree selected", vim.log.levels.WARN)
        return
      end
      manager.switch_worktree(item.path, item.branch)
    end,
  })
end

return M
