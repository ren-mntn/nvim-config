--[[
機能概要: 数値・日付・論理値などのインクリメント/デクリメント機能を拡張
設定内容: 様々な形式の値の増減機能、カスタムキーバインド設定
キーバインド: <C-a> (増加), <C-x> (減少), Visual modeでも対応
--]]
return {
  "monaqa/dial.nvim",
  event = "VeryLazy",
  keys = {
    {
      "<C-a>",
      function()
        require("dial.map").manipulate("increment", "normal")
      end,
      desc = "インクリメント",
    },
    {
      "<C-x>",
      function()
        require("dial.map").manipulate("decrement", "normal")
      end,
      desc = "デクリメント",
    },
    {
      "<C-a>",
      function()
        require("dial.map").manipulate("increment", "visual")
      end,
      mode = "v",
      desc = "インクリメント (Visual)",
    },
    {
      "<C-x>",
      function()
        require("dial.map").manipulate("decrement", "visual")
      end,
      mode = "v",
      desc = "デクリメント (Visual)",
    },
    {
      "g<C-a>",
      function()
        require("dial.map").manipulate("increment", "gnormal")
      end,
      desc = "連続インクリメント",
    },
    {
      "g<C-x>",
      function()
        require("dial.map").manipulate("decrement", "gnormal")
      end,
      desc = "連続デクリメント",
    },
  },
  config = function()
    local augend = require("dial.augend")

    require("dial.config").augends:register_group({
      default = {
        augend.integer.alias.decimal,
        augend.integer.alias.hex,
        augend.integer.alias.octal,
        augend.integer.alias.binary,
        augend.date.alias["%Y/%m/%d"],
        augend.date.alias["%Y-%m-%d"],
        augend.date.alias["%m/%d"],
        augend.date.alias["%H:%M"],
        augend.constant.alias.bool,
        augend.constant.alias.alpha,
        augend.constant.alias.Alpha,
        augend.constant.new({
          elements = { "true", "false" },
          word = true,
          cyclic = true,
        }),
        augend.constant.new({
          elements = { "True", "False" },
          word = true,
          cyclic = true,
        }),
        augend.constant.new({
          elements = { "&&", "||" },
          word = false,
          cyclic = true,
        }),
        augend.constant.new({
          elements = { "and", "or" },
          word = true,
          cyclic = true,
        }),
        augend.constant.new({
          elements = { "yes", "no" },
          word = true,
          cyclic = true,
        }),
        augend.constant.new({
          elements = { "on", "off" },
          word = true,
          cyclic = true,
        }),
        augend.constant.new({
          elements = { "left", "right" },
          word = true,
          cyclic = true,
        }),
        augend.constant.new({
          elements = { "up", "down" },
          word = true,
          cyclic = true,
        }),
        augend.constant.new({
          elements = { "width", "height" },
          word = true,
          cyclic = true,
        }),
        augend.hexcolor.new({
          case = "lower",
        }),
        augend.semver.alias.semver,
      },
    })

    -- ファイルタイプ別の設定例
    require("dial.config").augends:register_group({
      typescript = {
        augend.integer.alias.decimal,
        augend.integer.alias.hex,
        augend.constant.new({ elements = { "let", "const" } }),
        augend.constant.new({ elements = { "&&", "||" } }),
      },
      python = {
        augend.integer.alias.decimal,
        augend.constant.new({ elements = { "True", "False" } }),
        augend.constant.new({ elements = { "and", "or" } }),
      },
      markdown = {
        augend.integer.alias.decimal,
        augend.date.alias["%Y/%m/%d"],
        augend.date.alias["%Y-%m-%d"],
        augend.constant.new({ elements = { "[ ]", "[x]" } }),
      },
    })
  end,
}
