return {
  -- Git操作の拡張（Telescopeとsnacks併用）
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      -- VSCode風のGitキーバインド
      { "<C-S-g>", "<cmd>DiffviewOpen<cr>", desc = "Git Changes (VSCode style)" },
      {
        "<leader>gh",
        function()
          Snacks.picker.git_log({ focus = "list" })
        end,
        desc = "Git History (all commits)",
      },
      {
        "<leader>gH",
        function()
          Snacks.picker.git_log_file({ focus = "list" })
        end,
        desc = "Git History (current file)",
      },
      -- メイン機能：未マージブランチ + main/master
      {
        "<leader>gb",
        function()
          -- 現在のリポジトリがmainブランチを持っているか確認
          local has_main = vim.fn.system("git branch --list main"):gsub("%s+", "") ~= ""
          local base_branch = has_main and "main" or "master"

          -- git branch --no-merged でベースブランチにマージされていないブランチのみ表示
          local cmd = "git branch --no-merged " .. base_branch .. " | sed 's/^[ *]*//g'"
          local branches = vim.fn.system(cmd)
          local branch_list = {}

          -- ベースブランチを最初に追加
          table.insert(branch_list, base_branch)

          -- 未マージブランチを追加
          for branch in branches:gmatch("[^\r\n]+") do
            branch = branch:gsub("^%s*", ""):gsub("%s*$", "") -- 空白除去
            if branch ~= "" and branch ~= base_branch then
              table.insert(branch_list, branch)
            end
          end

          -- 空の場合はベースブランチのみ
          if #branch_list == 1 then
            vim.notify("Only " .. base_branch .. " branch exists or all branches are merged", vim.log.levels.INFO)
          end

          -- Snacksで表示
          local items = {}
          for _, branch in ipairs(branch_list) do
            table.insert(items, {
              text = branch,
              file = vim.fn.getcwd(), -- 現在のディレクトリをfileとして設定
              branch = branch,
            })
          end

          Snacks.picker({
            source = "static",
            items = items,
            title = "Git Branches (unmerged + " .. base_branch .. ")",
            format = function(item, picker)
              return { { item.text, "Normal" } }
            end,
            confirm = function(picker)
              local item = picker:current()
              if item then
                vim.cmd("Git checkout " .. item.branch)
                vim.notify("Switched to " .. item.branch, vim.log.levels.INFO)
              end
            end,
          })
        end,
        desc = "Git Branches (main + unmerged)",
      },

      -- 全ローカルブランチ（たまに使う）
      {
        "<leader>gB",
        function()
          Snacks.picker.git_branches({ focus = "list" })
        end,
        desc = "Git Branches (all local)",
      },
      {
        "<leader>gs",
        function()
          Snacks.picker.git_status({ focus = "list" })
        end,
        desc = "Git Status",
      },
      {
        "<leader>gS",
        function()
          Snacks.picker.git_stash({ focus = "list" })
        end,
        desc = "Git Stash",
      },

      -- リモートブランチ操作
      {
        "<leader>gr",
        function()
          Snacks.picker.git_branches({ focus = "list" })
        end,
        desc = "Remote Branches",
      },

      -- mainブランチへのクイック切り替え
      {
        "<leader>gm",
        function()
          vim.cmd("Git checkout main")
          vim.notify("Switched to main branch", vim.log.levels.INFO)
        end,
        desc = "Switch to main branch",
      },

      -- リモート最新を取得してからブランチ一覧
      {
        "<leader>gf",
        function()
          vim.cmd("Git fetch --all")
          vim.defer_fn(function()
            Snacks.picker.git_branches({ focus = "list" })
          end, 1000)
        end,
        desc = "Fetch & Show Branches",
      },
    },
  },

  -- fugitive.vimでGitコマンドを強化
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "Gwrite", "Gread", "Gdiffthis", "Gvdiffsplit", "Gblame" },
    keys = {
      -- VSCode風のコミット操作
      {
        "<C-Enter>",
        function()
          -- ステージされた変更をコミット（VSCode風）
          local staged_changes = vim.fn.system("git diff --cached --name-only")
          if staged_changes:gsub("%s+", "") == "" then
            vim.notify("No staged changes to commit", vim.log.levels.WARN)
            return
          end
          vim.cmd("Git commit")
        end,
        desc = "Commit Staged Changes (VSCode)",
      },

      {
        "<C-S-Enter>",
        function()
          -- 全変更をステージしてコミット（VSCode風）
          vim.cmd("Git add .")
          vim.cmd("Git commit")
        end,
        desc = "Stage All & Commit (VSCode)",
      },

      -- 従来のキーバインド（残しておく）
      { "<leader>gg", "<cmd>Git<cr>", desc = "Git Status (fugitive)" },
      { "<leader>gd", "<cmd>Gvdiffsplit<cr>", desc = "Git Diff Split" },
      { "<leader>gp", "<cmd>Git push<cr>", desc = "Git Push" },
      { "<leader>gP", "<cmd>Git pull<cr>", desc = "Git Pull" },
      { "<leader>ga", "<cmd>Git add %<cr>", desc = "Git Add Current File" },
      { "<leader>gA", "<cmd>Git add .<cr>", desc = "Git Add All" },
      { "<leader>go", "<cmd>Git commit<cr>", desc = "Git Commit" },
      { "<leader>gx", "<cmd>Gwrite<cr>", desc = "Git Stage (write)" },
      { "<leader>gl", "<cmd>Git blame<cr>", desc = "Git Blame (line history)" },
    },
  },

  -- GitSigns（行レベルのGit情報）
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = function(_, opts)
      -- LazyVimの既存設定を継承してGitSigns設定を拡張
      opts = vim.tbl_deep_extend("force", opts or {}, {
        signs = {
          add = { text = "▎" },
          change = { text = "▎" },
          delete = { text = "" },
          topdelete = { text = "" },
          changedelete = { text = "▎" },
          untracked = { text = "▎" },
        },
      })

      -- on_attachをラップして既存の設定を保持
      local original_on_attach = opts.on_attach
      opts.on_attach = function(buffer)
        -- LazyVimの既存on_attachを実行
        if original_on_attach then
          original_on_attach(buffer)
        end

        -- カスタムキーマップを追加
        local gs = package.loaded.gitsigns
        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

        -- Hunk移動
        map("n", "]h", gs.next_hunk, "Next Hunk")
        map("n", "[h", gs.prev_hunk, "Prev Hunk")

        -- Hunk操作
        map("n", "<leader>hs", gs.stage_hunk, "Stage Hunk")
        map("n", "<leader>hr", gs.reset_hunk, "Reset Hunk")
        map("v", "<leader>hs", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage Hunk")
        map("v", "<leader>hr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset Hunk")

        -- バッファ操作
        map("n", "<leader>hS", gs.stage_buffer, "Stage Buffer")
        map("n", "<leader>hR", gs.reset_buffer, "Reset Buffer")
        map("n", "<leader>hp", gs.preview_hunk, "Preview Hunk")
        map("n", "<leader>hb", function()
          gs.blame_line({ full = true })
        end, "Blame Line")
        map("n", "<leader>hd", gs.diffthis, "Diff This")
        map("n", "<leader>hD", function()
          gs.diffthis("~")
        end, "Diff This ~")

        -- Text object
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")
      end

      return opts
    end,
  },

  -- 高度なGit操作用
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    cmd = "Neogit",
    keys = {
      { "<leader>gn", "<cmd>Neogit<cr>", desc = "Neogit" },
    },
    config = true,
  },
}
