--[[
機能概要: 検索結果の可視化とナビゲーションを強化
設定内容: 検索結果の位置表示、マッチ数表示、キーマッピング統合
キーバインド: n/N でのスムーズな検索移動
--]]
return {
  "kevinhwang91/nvim-hlslens",
  event = "CmdlineEnter",
  keys = {
    {
      "n",
      [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]],
      desc = "次の検索結果",
    },
    {
      "N",
      [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]],
      desc = "前の検索結果",
    }  
  },
  opts = function(_, opts)
    -- 安全な初期化
    opts = opts or {}

    -- 設定のマージ
    local config = vim.tbl_deep_extend("force", opts, {
      calm_down = true,
      nearest_only = true,
      nearest_float_when = "always",
      float_shadow_blend = 50,
      virt_priority = 100,
      override_lens = function(render, posList, nearest, idx, relIdx)
        local sfw = vim.v.searchforward == 1
        local indicator, text, chunks
        local absRelIdx = math.abs(relIdx)
        if absRelIdx > 1 then
          indicator = ("%d%s"):format(absRelIdx, sfw ~= (relIdx > 1) and "▲" or "▼")
        elseif absRelIdx == 1 then
          indicator = sfw ~= (relIdx == 1) and "▲" or "▼"
        else
          indicator = ""
        end

        local lnum, col = unpack(posList[idx])
        if nearest then
          local cnt = #posList
          if indicator ~= "" then
            text = ("[%s %d/%d]"):format(indicator, idx, cnt)
          else
            text = ("[%d/%d]"):format(idx, cnt)
          end
          chunks = { { " ", "Ignore" }, { text, "HlSearchLensNear" } }
        else
          text = ("[%s %d]"):format(indicator, idx)
          chunks = { { " ", "Ignore" }, { text, "HlSearchLens" } }
        end
        render.setVirt(0, lnum - 1, col - 1, chunks, nearest)
      end,
    })

    return config
  end,
  config = function(_, opts)
    require("hlslens").setup(opts)

    -- ハイライトグループの設定
    vim.api.nvim_set_hl(0, "HlSearchNear", { bg = "#ff9e64", fg = "#1a1b26", bold = true })
    vim.api.nvim_set_hl(0, "HlSearchLens", { bg = "#414868", fg = "#c0caf5" })
    vim.api.nvim_set_hl(0, "HlSearchLensNear", { bg = "#ff9e64", fg = "#1a1b26", bold = true })
  end,
}
