return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    dependencies = {
      "github/copilot.vim", -- 補完機能はこちらが担当
      "nvim-lua/plenary.nvim", -- 多くのプラグインが必要とするユーティリティ
    },
    cmd = { "CopilotChat", "CopilotChatExplain", "CopilotChatTests" }, -- 遅延読み込み
    keys = {
      -- 選択したコードの説明を生成する
      { "<leader>ce", "<cmd>CopilotChatExplain<CR>", desc = "CopilotChat - Explain" },
      -- 選択したコードのテストを生成する
      { "<leader>ct", "<cmd>CopilotChatTests<CR>", desc = "CopilotChat - Generate Tests" },
    },
    opts = {
      model = "Claude Sonnet 4",
    },
  },
}
