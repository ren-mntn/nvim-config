-- ~/.config/nvim/lua/plugins/dashboard.lua

return {
  {
    "nvimdev/dashboard-nvim",
    opts = function(_, opts)
      opts.config = opts.config or {}
      -- この header の部分を置き換えます
      opts.config.header = {
        "                                       ",
        "                      ░                ",
        "                     ▒▒▒               ",
        "                    ▓▓▓▓▓              ",
        "             ████████████████          ",
        "            ███████████████████╗       ",
        "            ███████████████████║       ",
        "             ████████████████╔╝        ",
        "   ▄████████████████████████████████▄   ",
        "  ▀▀████████████████████████████████▀▀  ",
        "                                       ",
      }
      return opts
    end,
  },
}