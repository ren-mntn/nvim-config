-- ~/.config/nvim/lua/plugins/tools.lua
return {
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      -- ensure_installedのリストに"typos-cli"を追加
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "typos" })
    end,
  },
}
