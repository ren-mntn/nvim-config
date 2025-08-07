-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
-- LazyVimのMarkdownファイルでの自動スペルチェックを無効にする
vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- TypeScriptファイルの保存時にインポート整理を実行
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
  callback = function()
    local buf_clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
    if #buf_clients > 0 then
      -- インポート整理を実行
      local params = vim.lsp.util.make_range_params(0, "utf-16")
      params.context = {
        only = { "source.organizeImports" },
        diagnostics = vim.diagnostic.get(0),
      }
      
      local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 1000)
      if result then
        for _, res in pairs(result) do
          if res.result and #res.result > 0 then
            for _, action in ipairs(res.result) do
              if action.edit then
                vim.lsp.util.apply_workspace_edit(action.edit, "utf-8")
              elseif action.command then
                vim.lsp.buf.execute_command(action.command)
              end
            end
          end
        end
      end
    end
  end,
})

