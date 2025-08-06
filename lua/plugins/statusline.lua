return {
  -- LazyVimのデフォルトステータスライン設定を拡張
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      -- ブランチ情報をより詳細に表示
      local git_branch = {
        "branch",
        fmt = function(str)
          -- worktreeの場合の表示改善
          local git_dir = vim.fn.system("git rev-parse --git-dir 2>/dev/null"):gsub('\n', '')
          if git_dir:match("%.git/worktrees") then
            local worktree_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
            return "🌳 " .. str .. " (" .. worktree_name .. ")"
          else
            return "🌿 " .. str .. " (main)"
          end
        end,
        color = { fg = "#98be65", gui = "bold" },
      }
      
      -- 現在のブランチとworktree情報
      local worktree_info = {
        function()
          local cwd = vim.fn.getcwd()
          local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub('\n', '')
          
          if git_root ~= "" then
            if cwd:match("%.worktrees") then
              local worktree_name = vim.fn.fnamemodify(cwd, ":t")
              return "📁 " .. worktree_name
            else
              return "📁 main-project"
            end
          end
          return ""
        end,
        color = { fg = "#61afef", gui = "italic" },
      }
      
      -- 左側のセクションにブランチ情報を追加
      if not opts.sections then opts.sections = {} end
      if not opts.sections.lualine_b then opts.sections.lualine_b = {} end
      
      -- 既存のブランチ表示を置き換え
      for i, section in ipairs(opts.sections.lualine_b) do
        if type(section) == "string" and section == "branch" then
          opts.sections.lualine_b[i] = git_branch
          break
        elseif type(section) == "table" and section[1] == "branch" then
          opts.sections.lualine_b[i] = git_branch
          break
        end
      end
      
      -- worktree情報を追加
      table.insert(opts.sections.lualine_b, worktree_info)
      
      return opts
    end,
  },
  
  -- worktreeとブランチ情報をタイトルに表示
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      -- Neo-treeのタイトルにworktree情報を追加
      if not opts.window then opts.window = {} end
      
      opts.window.position = "left"
      opts.window.width = 35
      
      -- カスタムタイトル
      local function get_neo_tree_title()
        local cwd = vim.fn.getcwd()
        local branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub('\n', '')
        
        if cwd:match("%.worktrees") then
          local worktree_name = vim.fn.fnamemodify(cwd, ":t")
          return "Neo-tree 🌳 " .. branch .. " (" .. worktree_name .. ")"
        else
          return "Neo-tree 🌿 " .. (branch ~= "" and branch or "main")
        end
      end
      
      -- Neo-treeの表示を更新するautocmd
      vim.api.nvim_create_autocmd({ "DirChanged", "BufEnter" }, {
        callback = function()
          -- タイトルを更新（実際の実装はNeo-treeの制限により難しい）
          -- 代わりにステータスラインで表示
        end,
      })
      
      return opts
    end,
  },
}