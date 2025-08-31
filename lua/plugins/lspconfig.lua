--[[
機能概要: LSP統合設定 - ESLint・TypeScript・Tailwind・Biome LSPの統一管理
設定内容: 全てのnvim-lspconfig設定を一箇所で管理
キーバインド: LSP標準キーマップ
--]]

-- ESLint自動フォーマットの設定
vim.g.lazyvim_eslint_auto_format = true

return {
  -- 統合LSP設定
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- auto_format変数の定義（ESLint用）
      local auto_format = vim.g.lazyvim_eslint_auto_format ~= false

      -- 安全な初期化
      opts.servers = opts.servers or {}

      -- =====================================
      -- ESLint LSP設定
      -- =====================================
      opts.servers.eslint = {
        settings = {
          -- eslintrcがサブフォルダに配置された場合の検索補助
          workingDirectories = { mode = "auto" },
          format = auto_format,
        },
      }

      -- =====================================
      -- TypeScript設定（vtslsとtsserver無効化）
      -- =====================================
      -- vtslsを無効化（typescript-tools.nvimと競合を避ける）
      opts.servers.vtsls = false
      opts.servers.tsserver = false

      -- =====================================
      -- Tailwind CSS設定（tailwind.luaから統合）
      -- =====================================
      opts.servers.tailwindcss = {
        -- filetypeを指定
        filetypes = {
          "html",
          "css",
          "scss",
          "javascript",
          "javascriptreact",
          "typescript",
          "typescriptreact",
          "vue",
          "svelte",
        },
        settings = {
          tailwindCSS = {
            classAttributes = { "class", "className", "class:list", "classList", "ngClass" },
            lint = {
              cssConflict = "warning",
              invalidApply = "error",
              invalidConfigPath = "error",
              invalidScreen = "error",
              invalidTailwindDirective = "error",
              invalidVariant = "error",
              recommendedVariantOrder = "warning",
            },
            validate = true,
          },
        },
        filetypes_exclude = { "markdown" },
        filetypes_include = {},
        root_dir = function(...)
          return require("lspconfig.util").root_pattern(".git")(...)
        end,
      }

      -- =====================================
      -- Biome LSP設定（現在は無効化）
      -- =====================================
      -- 一時的にLSPを無効化し、CLIフォールバック方式のみ使用
      -- 将来的にBiome LSPを有効化する場合はここで設定

      -- =====================================
      -- ESLint setup設定
      -- =====================================
      opts.setup = opts.setup or {}
      opts.setup.eslint = function()
        if not auto_format then
          return
        end

        local function get_client(buf)
          return LazyVim.lsp.get_clients({ name = "eslint", bufnr = buf })[1]
        end

        local formatter = LazyVim.lsp.formatter({
          name = "eslint: lsp",
          primary = false,
          priority = 200,
          filter = "eslint",
        })

        -- Neovim < 0.10.0の場合はEslintFixAllを使用
        if not pcall(require, "vim.lsp._dynamic") then
          formatter.name = "eslint: EslintFixAll"
          formatter.sources = function(buf)
            local client = get_client(buf)
            return client and { "eslint" } or {}
          end
          formatter.format = function(buf)
            local client = get_client(buf)
            if client then
              local diag = vim.diagnostic.get(buf, { namespace = vim.lsp.diagnostic.get_namespace(client.id) })
              if #diag > 0 then
                vim.cmd("EslintFixAll")
              end
            end
          end
        end

        -- LazyVimフォーマッターとして登録
        LazyVim.format.register(formatter)
      end

      return opts
    end,
  },

  -- =====================================
  -- Oxlint統合設定（oxlint.luaから統合）
  -- =====================================
  {
    "neovim/nvim-lspconfig",
    config = function()
      -- Oxlintが利用可能かチェック
      local oxlint_available = vim.fn.executable("oxlint") == 1

      if not oxlint_available then
        vim.notify("Oxlint not found. Install with: npm i -g oxlint", vim.log.levels.WARN)
        return
      end

      -- デバウンス用タイマー管理
      local debounce_timers = {}
      local namespace = vim.api.nvim_create_namespace("oxlint")

      -- Oxlint診断を実行してインライン診断表示する関数
      local function run_oxlint(bufnr)
        bufnr = bufnr or vim.api.nvim_get_current_buf()

        -- バッファが無効な場合は処理しない
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        local current_file = vim.fn.expand("%:p")
        local file_type = vim.bo[bufnr].filetype

        -- 対象ファイルタイプのチェック
        if not vim.tbl_contains({ "javascript", "javascriptreact", "typescript", "typescriptreact" }, file_type) then
          return
        end

        -- ファイルが保存されていない場合はスキップ（構文エラー回避）
        if vim.bo[bufnr].modified then
          -- 未保存時は既存診断をクリアのみ
          vim.diagnostic.reset(namespace, bufnr)
          return
        end

        -- Oxlint実行
        local cmd = string.format("oxlint --format=unix %s", vim.fn.shellescape(current_file))
        local output = vim.fn.system(cmd)

        -- 既存の診断をクリア
        vim.diagnostic.reset(namespace, bufnr)

        if vim.v.shell_error == 0 and output == "" then
          -- エラーなし：診断とQuickfixをクリア
          vim.fn.setqflist({}, "r")
          return
        end

        -- 診断とQuickfixリストを作成
        local diagnostics = {}
        local qflist = {}

        for line in output:gmatch("[^\r\n]+") do
          local file, lnum, col, text = line:match("([^:]+):(%d+):(%d+): (.+)")
          if file and lnum and col and text then
            local is_error = text:match("error")
            local severity = is_error and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN

            -- インライン診断用
            table.insert(diagnostics, {
              lnum = tonumber(lnum) - 1, -- 0-indexed
              col = tonumber(col) - 1, -- 0-indexed
              message = text,
              severity = severity,
              source = "oxlint",
            })

            -- Quickfix用
            table.insert(qflist, {
              filename = file,
              lnum = tonumber(lnum),
              col = tonumber(col),
              text = text,
              type = is_error and "E" or "W",
            })
          end
        end

        -- インライン診断を設定
        if #diagnostics > 0 then
          vim.diagnostic.set(namespace, bufnr, diagnostics, {})
          -- Quickfixも更新（サイレント）
          vim.fn.setqflist(qflist, "r")
        end
      end

      -- デバウンス付きOxlint実行
      local function debounced_oxlint(bufnr, delay)
        bufnr = bufnr or vim.api.nvim_get_current_buf()
        delay = delay or 1000 -- 1秒デバウンス

        -- 既存のタイマーをキャンセル
        if debounce_timers[bufnr] then
          debounce_timers[bufnr]:stop()
          debounce_timers[bufnr]:close()
        end

        -- 新しいタイマーを設定
        debounce_timers[bufnr] = vim.loop.new_timer()
        debounce_timers[bufnr]:start(
          delay,
          0,
          vim.schedule_wrap(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
              run_oxlint(bufnr)
            end
            debounce_timers[bufnr] = nil
          end)
        )
      end

      local augroup = vim.api.nvim_create_augroup("OxlintDiagnostics", { clear = true })

      -- 保存時実行（即座に実行）
      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = { "*.js", "*.jsx", "*.ts", "*.tsx" },
        callback = function()
          run_oxlint()
        end,
        group = augroup,
      })

      -- テキスト変更時実行（デバウンス付き）
      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        pattern = { "*.js", "*.jsx", "*.ts", "*.tsx" },
        callback = function()
          local bufnr = vim.api.nvim_get_current_buf()
          debounced_oxlint(bufnr, 1500) -- 1.5秒デバウンス
        end,
        group = augroup,
      })

      -- ファイル切り替え時実行
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
        pattern = { "*.js", "*.jsx", "*.ts", "*.tsx" },
        callback = function()
          local bufnr = vim.api.nvim_get_current_buf()
          debounced_oxlint(bufnr, 500) -- 0.5秒デバウンス
        end,
        group = augroup,
      })

      -- インサートモード終了時実行（軽量）
      vim.api.nvim_create_autocmd("InsertLeave", {
        pattern = { "*.js", "*.jsx", "*.ts", "*.tsx" },
        callback = function()
          local bufnr = vim.api.nvim_get_current_buf()
          debounced_oxlint(bufnr, 300) -- 0.3秒デバウンス
        end,
        group = augroup,
      })

      -- 手動実行コマンド
      vim.api.nvim_create_user_command("OxlintCheck", function()
        run_oxlint()
      end, {
        desc = "Run Oxlint on current file",
      })
    end,
  },
}
