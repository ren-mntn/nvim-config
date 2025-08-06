-- Telescope File Browserを無効化してNeo-treeのみ使用
return {
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    opts = function(_, opts)
      -- file_browserを無効化
      if opts.extensions then
        opts.extensions.file_browser = nil
      end
    end,
  },
  
  -- telescope-file-browser.nvimを無効化
  {
    "nvim-telescope/telescope-file-browser.nvim",
    enabled = false,
  },
}