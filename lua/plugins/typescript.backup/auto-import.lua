--[[
TypeScript自動インポート機能
目的: 不足しているインポートの自動追加
基盤: tsserver専用の自動インポート機能
--]]

return {
	-- 自動インポート専用キーマップ
	{
		"folke/which-key.nvim",
		optional = true,
		opts = {
			spec = {
				{ "<leader>;", group = "📥 TypeScript Auto Import", mode = { "n", "v" } },

				-- 自動インポート（全エラー対象）
				{
					"<leader>;i",
					function()
						vim.lsp.buf.code_action({
							context = {
								only = { "source.addMissingImports" },
								diagnostics = {},
							},
							apply = true,
						})
						vim.notify("📥 自動インポート実行", vim.log.levels.INFO, {
							title = "Auto Import",
							timeout = 1500,
						})
					end,
					desc = "📥 自動インポート",
				},

				-- カーソル下の自動インポート
				{
					"<leader>;I",
					function()
						local bufnr = vim.api.nvim_get_current_buf()
						local cursor = vim.api.nvim_win_get_cursor(0)

						vim.lsp.buf.code_action({
							context = {
								only = { "quickfix", "source.addMissingImports" },
								diagnostics = vim.diagnostic.get(bufnr, { lnum = cursor[1] - 1 }),
							},
							apply = true,
						})
						vim.notify("📥 カーソル下自動インポート実行", vim.log.levels.INFO, {
							title = "Auto Import",
							timeout = 1500,
						})
					end,
					desc = "📥 カーソル下の自動インポート",
				},

				-- 瞬間自動インポート（gAキー）
				{
					"gA",
					function()
						vim.lsp.buf.code_action({
							context = {
								only = { "quickfix" },
								diagnostics = {},
							},
							apply = true,
						})
					end,
					desc = "⚡ 瞬間自動インポート",
					mode = "n",
				},
			},
		},
	},
}
