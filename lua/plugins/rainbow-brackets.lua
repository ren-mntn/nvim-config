-- 階層ごとに括弧の色を変更（レインボー括弧）
return {
  "HiPhish/rainbow-delimiters.nvim",
  event = "BufRead",
  config = function()
    local rainbow_delimiters = require('rainbow-delimiters')

    -- 階層ごとの色を設定
    vim.g.rainbow_delimiters = {
      strategy = {
        [''] = rainbow_delimiters.strategy['global'],
        vim = rainbow_delimiters.strategy['local'],
      },
      query = {
        [''] = 'rainbow-delimiters',
        lua = 'rainbow-blocks',
      },
      priority = {
        [''] = 110,
        lua = 210,
      },
      highlight = {
        'RainbowDelimiterYellow',   -- 階層1: 黄
        'RainbowDelimiterViolet',   -- 階層2: 紫
        'RainbowDelimiterBlue',     -- 階層3: 青
      },
    }
    
    -- カスタムハイライトグループを定義
    vim.api.nvim_set_hl(0, 'RainbowDelimiterYellow', { fg = '#FFD700' })   -- 黄
    vim.api.nvim_set_hl(0, 'RainbowDelimiterViolet', { fg = '#C678DD' })   -- 紫
    vim.api.nvim_set_hl(0, 'RainbowDelimiterBlue', { fg = '#61AFEF' })     -- 青
  end,
}