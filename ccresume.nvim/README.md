# ccresume.nvim

A Neovim plugin for browsing and resuming Claude Code conversation history with an intuitive UI.

## Features

- 🔍 Browse all Claude Code conversation history with preview
- 📁 Filter conversations by current directory
- 🎨 Syntax highlighting for different message types (User, Assistant, Tools)
- ⚡ Fast search and navigation with Snacks.nvim picker
- 🔄 Resume conversations directly in ClaudeCode.nvim
- 📅 Chronological sorting (newest first)

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

- `<leader>ch` - Browse current directory conversations
- `<leader>cH` - Browse all conversations

### Commands

- `:CCResumeHere` - Browse current directory conversations
- `:CCResume` - Browse all conversations

### Picker Interface

Once opened, you can:
- Use `j/k` or arrow keys to navigate
- Type to search conversations by summary
- Press `Enter` to resume a conversation
- Press `Esc` or `q` to close
- Select "🆕 新しいセッションを開始" to start a new session

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
    current_dir = "<leader>ch",  -- Current directory conversations
    all = "<leader>cH",          -- All conversations
  },
  
  -- Command configuration
  commands = true,  -- Set to false to disable commands
})
```

## API

### Functions

- `require("ccresume").show_conversations(filter_current_dir)` - Show conversation browser
- `require("ccresume").show_current_dir_conversations()` - Show current directory conversations only
- `require("ccresume").setup(opts)` - Setup plugin with options

## How it Works

The plugin reads Claude Code conversation history from `~/.claude/projects/` directory, which is where Claude Code stores conversation data in JSONL format.

## License

MIT
EOF < /dev/null