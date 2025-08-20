-- Supertab設定: Tabキーで賢い補完を実現
-- Tab: 補完候補選択 → スニペット展開/ジャンプ → 通常のTab
-- Shift-Tab: 逆方向の動作

return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    "L3MON4D3/LuaSnip",
  },
  ---@param opts cmp.ConfigSchema
  opts = function(_, opts)
    local has_words_before = function()
      unpack = unpack or table.unpack
      local line, col = unpack(vim.api.nvim_win_get_cursor(0))
      return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
    end

    local cmp = require("cmp")
    local luasnip = require("luasnip")

    opts.mapping = vim.tbl_extend("force", opts.mapping, {
      ["<Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          -- 補完メニューが表示されている場合は次の候補を選択
          cmp.select_next_item()
        elseif luasnip.expand_or_jumpable() then
          -- スニペットが展開可能またはジャンプ可能な場合
          luasnip.expand_or_jump()
        elseif has_words_before() then
          -- カーソル前に文字がある場合は補完を起動
          cmp.complete()
        else
          -- それ以外は通常のTabを挿入
          fallback()
        end
      end, { "i", "s" }), -- Insert mode と Select mode で有効

      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          -- 補完メニューが表示されている場合は前の候補を選択
          cmp.select_prev_item()
        elseif luasnip.jumpable(-1) then
          -- スニペットで前の位置にジャンプ可能な場合
          luasnip.jump(-1)
        else
          -- それ以外は通常のShift-Tabの動作
          fallback()
        end
      end, { "i", "s" }),
    })
  end,
}