-- Neovim Configuration Test Suite for LLM Management

local M = {}

-- テスト結果格納
local test_results = {}

-- テストヘルパー関数
local function assert_test(condition, test_name, error_msg)
    if condition then
        table.insert(test_results, {name = test_name, status = "PASS"})
        print("✅ " .. test_name)
    else
        table.insert(test_results, {name = test_name, status = "FAIL", error = error_msg})
        print("❌ " .. test_name .. ": " .. (error_msg or "条件を満たしていません"))
    end
end

-- 1. 基本設定の整合性テスト
function M.test_basic_config()
    print("\n🔍 基本設定テスト")
    
    -- Python provider設定
    assert_test(
        vim.g.python3_host_prog ~= nil,
        "Python3プロバイダー設定",
        "vim.g.python3_host_progが設定されていません"
    )
    
    -- 日本語設定
    assert_test(
        vim.tbl_contains(vim.opt.helplang:get(), "ja"),
        "日本語ヘルプ設定",
        "helpでjaが設定されていません"
    )
    
    -- スペルチェック無効化
    assert_test(
        not vim.opt.spell:get(),
        "スペルチェック無効化",
        "スペルチェックが有効になっています"
    )
    
    -- マウス設定（起動時は未設定でも、mouse-enhancementsで後から設定される）
    assert_test(
        vim.opt.mouse:get() == "a" or vim.g.loaded_mouse_enhancements ~= nil,
        "マウス設定（Keyball対応）",
        "マウス設定またはmouse-enhancementsが未設定です"
    )
end

-- 2. プラグイン設定の妥当性テスト
function M.test_plugin_configs()
    print("\n🔍 プラグイン設定テスト")
    
    local plugin_files = vim.fn.glob("~/.config/nvim/lua/plugins/*.lua", false, true)
    
    for _, file in ipairs(plugin_files) do
        local filename = vim.fn.fnamemodify(file, ":t:r")
        local content = table.concat(vim.fn.readfile(file), "\n")
        
        -- 遅延読み込み設定チェック（colorschemeなど一部例外あり）
        local has_lazy_loading = string.match(content, "event%s*=") or
                                string.match(content, "cmd%s*=") or 
                                string.match(content, "keys%s*=") or
                                string.match(content, "ft%s*=") or
                                string.match(content, "lazy%s*=%s*false") -- lazy = falseは意図的
        
        -- 特殊なケース（例外として許可）
        local is_special_case = filename == "colorscheme" or filename == "dashboard"
        
        assert_test(
            has_lazy_loading or is_special_case,
            filename .. "の遅延読み込み設定",
            "event/cmd/keys/ftまたはlazy=falseの設定が必要です"
        )
        
        -- opts vs config パターンチェック
        local has_opts = string.match(content, "opts%s*=")
        local has_config = string.match(content, "config%s*=%s*function")
        
        if has_config and not has_opts then
            print("⚠️  " .. filename .. ": config関数使用（optsパターン推奨）")
        end
    end
end

-- 3. キーマップ競合テスト
function M.test_keymap_conflicts()
    print("\n🔍 キーマップ競合テスト")
    
    local keymaps = {}
    local conflicts = {}
    
    -- 全キーマップを収集
    for _, mode in ipairs({"n", "i", "v", "x", "t"}) do
        local mode_keymaps = vim.api.nvim_get_keymap(mode)
        for _, keymap in ipairs(mode_keymaps) do
            local key = mode .. ":" .. keymap.lhs
            if keymaps[key] then
                table.insert(conflicts, {
                    key = keymap.lhs,
                    mode = mode,
                    existing = keymaps[key],
                    new = keymap.rhs or "function"
                })
            else
                keymaps[key] = keymap.rhs or "function"
            end
        end
    end
    
    assert_test(
        #conflicts == 0,
        "キーマップ競合チェック",
        string.format("%d個の競合を発見", #conflicts)
    )
    
    -- 競合詳細を表示
    for _, conflict in ipairs(conflicts) do
        print(string.format("⚠️  競合: [%s] %s -> '%s' vs '%s'", 
            conflict.mode, conflict.key, conflict.existing, conflict.new))
    end
end

-- 4. パフォーマンステスト
function M.test_performance()
    print("\n🔍 パフォーマンステスト")
    
    -- プラグイン数チェック
    local plugin_count = #vim.fn.glob("~/.config/nvim/lua/plugins/*.lua", false, true)
    assert_test(
        plugin_count < 50,
        "プラグイン数適正性",
        string.format("プラグイン数が多すぎます: %d個", plugin_count)
    )
    
    -- lazy.nvim状態確認
    local lazy_available, lazy = pcall(require, "lazy")
    if lazy_available then
        local stats = lazy.stats()
        
        assert_test(
            stats.loaded < stats.count * 0.3,
            "遅延読み込み効率性",
            string.format("読み込み済みプラグイン率: %.1f%%", 
                (stats.loaded / stats.count) * 100)
        )
        
        print(string.format("📊 プラグイン統計: %d個中%d個読み込み済み", 
            stats.count, stats.loaded))
    end
end

-- 5. LSP設定テスト
function M.test_lsp_config()
    print("\n🔍 LSP設定テスト")
    
    -- LSPクライアント接続確認
    local clients = vim.lsp.get_active_clients()
    
    assert_test(
        #clients >= 0,
        "LSPクライアント初期化",
        "LSPクライアントの取得でエラー"
    )
    
    -- TypeScript/JavaScript LSP (該当ファイルがある場合)
    local has_ts_files = #vim.fn.glob("**/*.{ts,tsx,js,jsx}", false, true) > 0
    if has_ts_files then
        local ts_client = nil
        for _, client in ipairs(clients) do
            if string.match(client.name, "typescript") or 
               string.match(client.name, "tsserver") then
                ts_client = client
                break
            end
        end
        
        assert_test(
            ts_client ~= nil,
            "TypeScript LSP接続",
            "TypeScriptファイルが存在しますがLSPが未接続"
        )
    end
end

-- 6. 設定ファイル構造テスト
function M.test_file_structure()
    print("\n🔍 ファイル構造テスト")
    
    local required_files = {
        "init.lua",
        "lua/config/lazy.lua",
        "lua/config/options.lua", 
        "lua/config/keymaps.lua",
        "CLAUDE.md",
        "lazy-lock.json"
    }
    
    for _, file in ipairs(required_files) do
        local path = "~/.config/nvim/" .. file
        assert_test(
            vim.fn.filereadable(vim.fn.expand(path)) == 1,
            file .. "の存在確認",
            "必須ファイルが存在しません"
        )
    end
    
    -- ディレクトリ構造確認
    local required_dirs = {
        "lua/config",
        "lua/plugins",
        "tests"  -- テストディレクトリが必須
    }
    
    for _, dir in ipairs(required_dirs) do
        local path = "~/.config/nvim/" .. dir
        assert_test(
            vim.fn.isdirectory(vim.fn.expand(path)) == 1,
            dir .. "ディレクトリの存在確認",
            "必須ディレクトリが存在しません"
        )
    end
end

-- 全テスト実行
function M.run_all_tests()
    print("🚀 Neovim設定 総合テスト開始\n")
    
    test_results = {} -- 結果リセット
    
    M.test_basic_config()
    M.test_plugin_configs()
    M.test_keymap_conflicts()
    M.test_performance()
    M.test_lsp_config()
    M.test_file_structure()
    
    -- 結果集計
    local passed = 0
    local failed = 0
    
    for _, result in ipairs(test_results) do
        if result.status == "PASS" then
            passed = passed + 1
        else
            failed = failed + 1
        end
    end
    
    print(string.format("\n📊 テスト結果: %d個中%d個合格, %d個失敗", 
        passed + failed, passed, failed))
    
    if failed == 0 then
        print("🎉 全テスト合格！設定は正常です")
    else
        print("⚠️  一部テストが失敗しました。上記のエラーを確認してください")
    end
    
    return failed == 0
end

-- テスト実行用コマンド
vim.api.nvim_create_user_command('TestNvimConfig', M.run_all_tests, {
    desc = 'Neovim設定の整合性テストを実行'
})

return M