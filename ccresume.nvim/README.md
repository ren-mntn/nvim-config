# ccresume.nvim

A Neovim plugin for browsing and resuming Claude Code conversation history with an intuitive UI.

## Features

- 🔍 Browse Claude Code conversation history with preview
- 📁 Filter conversations by current directory
- 🎨 Syntax highlighting for different message types (User, Assistant, Tools)
- ⚡ Fast search and navigation with Snacks.nvim picker
- 🔄 Resume conversations directly in ClaudeCode.nvim
- 📅 Chronological sorting (newest first)
- 🚀 Two modes: Recent (fast startup) and All (complete history)
- 📄 "Load More" functionality for browsing large histories

## Requirements

- Neovim >= 0.9.0
- [ClaudeCode.nvim](https://github.com/coder/claudecode.nvim) - Required for Claude Code integration
- [Snacks.nvim](https://github.com/folke/snacks.nvim) - Required for the picker interface

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/ccresume.nvim",
  dependencies = {
    "coder/claudecode.nvim",
    "folke/snacks.nvim",
  },
  config = true, -- Uses default configuration
}
```

## Usage

### Default Keymaps

- `<leader>ch` - Browse current directory conversations (recent)
- `<leader>cH` - Browse current directory conversations (all)
- `<leader>ca` - Browse all conversations (recent)
- `<leader>cA` - Browse all conversations (all)

### Commands

- `:CCResumeHere` - Browse current directory conversations (recent)
- `:CCResumeHereAll` - Browse current directory conversations (all)
- `:CCResume` - Browse all conversations (recent)
- `:CCResumeAll` - Browse all conversations (all)

### Picker Interface

Once opened, you can:
- Use `j/k` or arrow keys to navigate
- Type to search conversations by summary
- Press `Enter` to resume a conversation
- Press `Esc` or `q` to close
- Select "🆕 新しいセッションを開始" to start a new session
- Select "📄 もっと見る" to load additional conversations (recent mode)

### Color Coding

In the preview pane:
- **Blue lines** - User messages
- **Orange lines** - Tool/function calls
- **White lines** - Regular assistant responses

## Configuration

### Default Configuration

```lua
require("ccresume").setup({
  -- Keymapping configuration
  keys = {
    current_dir = "<leader>ch",      -- Current directory (recent)
    current_dir_all = "<leader>cH",  -- Current directory (all)
    all = "<leader>ca",              -- All conversations (recent)
    all_all = "<leader>cA",          -- All conversations (all)
  },
  
  -- Command configuration
  commands = true,  -- Set to false to disable commands
  
  -- Preview configuration
  preview = {
    reverse_order = false,  -- Set to true to show newest messages at the top
  },
})
```

### Advanced Configuration

```lua
require("ccresume").setup({
  preview = {
    reverse_order = true,  -- Show newest messages first (recommended)
  },
  
  -- Performance configuration
  performance = {
    recent_limit = 50,  -- Number of recent conversations to load initially (default: 30)
  },
})
```

### Performance Features

- **🚀 Two-Mode Design**: Recent mode for fast startup, All mode for complete access
- **🔄 Smart Caching**: 30-second cache to avoid repeated file scanning
- **⚡ Optimized I/O**: Safe file reading with error handling
- **📄 Progressive Loading**: "Load More" functionality for large histories
- **🛡️ Conservative**: Minimal impact on overall Neovim performance

**Note**: The plugin prioritizes Neovim performance while providing fast access to conversation history.

## API

### Functions

- `require("ccresume").show_conversations(filter_current_dir)` - Show conversation browser (recent mode)
- `require("ccresume").show_conversations_recent(filter_current_dir, limit)` - Show recent conversations with custom limit
- `require("ccresume").show_conversations_all(filter_current_dir)` - Show all conversations
- `require("ccresume").show_current_dir_conversations()` - Show current directory conversations (recent)
- `require("ccresume").show_current_dir_conversations_all()` - Show current directory conversations (all)
- `require("ccresume").setup(opts)` - Setup plugin with options

## How it Works

The plugin reads Claude Code conversation history from `~/.claude/projects/` directory, which is where Claude Code stores conversation data in JSONL format.

## License

MIT
