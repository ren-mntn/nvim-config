return {
  -- LazyVimのデフォルトステータスライン設定を拡張（パフォーマンス最適化版）
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy", -- 遅延読み込み
    opts = function(_, opts)
      -- パフォーマンス最適化：ブランチ変更時のみ更新
      local git_info_cache = {}
      
      local function update_git_info()
        local git_dir = vim.fn.system("git rev-parse --git-dir 2>/dev/null"):gsub('\n', '')
        local branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub('\n', '')
        local cwd = vim.fn.getcwd()
        
        git_info_cache = {
          branch = branch,
          is_worktree = git_dir:match("%.git/worktrees") ~= nil,
          worktree_name = vim.fn.fnamemodify(cwd, ":t"),
          git_root = git_dir ~= ""
        }
      end
      
      local function get_git_info()
        -- 初回またはキャッシュが空の場合のみ実行
        if not git_info_cache.branch then
          update_git_info()
        end
        return git_info_cache
      end
      
      -- ブランチ変更時にキャッシュを更新
      vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "DirChanged" }, {
        callback = function()
          update_git_info()
        end,
        desc = "Update git info cache when branch might change"
      })
      
      -- 最適化されたブランチ表示
      local git_branch = {
        "branch",
        fmt = function(str)
          local info = get_git_info()
          if info.is_worktree then
            return "🌳 " .. str .. " (" .. info.worktree_name .. ")"
          else
            return "🌿 " .. str
          end
        end,
        color = { fg = "#98be65", gui = "bold" },
      }
      
      -- 最適化されたworktree情報
      local worktree_info = {
        function()
          local info = get_git_info()
          if info.git_root then
            if info.is_worktree then
              return "📁 " .. info.worktree_name
            else
              return "📁 main"
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