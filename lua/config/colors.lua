-- 共通の色定義
local M = {}

-- 基本色
M.colors = {
  white = "#E8E8E8", -- 旧FFFFFF
  black = "#000000",
  gray = "#a0aec0",
  dark_gray = "#2d3748",
  green = "#38a169",
  blue = "#3182ce",
  yellow = "#d69e2e",
  red = "#e53e3e",
  background = "#1E1E1E",
  comment_bg = "#444444",
}

-- ステータス用の色セット
M.status_colors = {
  disconnected = { bg = M.colors.dark_gray, fg = M.colors.gray },
  connected = { bg = M.colors.green, fg = M.colors.white },
  processing = { bg = M.colors.blue, fg = M.colors.white },
  waiting = { bg = M.colors.yellow, fg = M.colors.white },
  error = { bg = M.colors.red, fg = M.colors.white },
}

return M
