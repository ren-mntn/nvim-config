# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Configuration Architecture

This is a **LazyVim-based** Neovim configuration with Japanese language support. The configuration follows LazyVim's modular architecture:

- `init.lua` - Entry point that bootstraps lazy.nvim
- `lua/config/` - Core configuration files that extend LazyVim defaults:
  - `lazy.lua` - Plugin manager setup with TypeScript, Python, Docker language extras
  - `options.lua` - Japanese locale settings and startup behavior
  - `keymaps.lua` - Custom keybindings for navigation and terminal management
  - `autocmds.lua` - Disabled LazyVim's spell checking
- `lua/plugins/` - Plugin-specific configurations that override or extend LazyVim defaults

## Key Configuration Details

### Language and Locale
- **Japanese language support** enabled with `helplang = { "ja", "en" }` and `language messages ja_JP.UTF-8`
- Spell checking is **globally disabled** for all file types
- LazyVim's markdown spell checking is explicitly removed

### Plugin Management
- Uses **lazy.nvim** with LazyVim as base
- LuaRocks support is **disabled** (`rocks.enabled = false`)
- Automatic plugin update checking enabled but notifications disabled
- Performance optimizations: several default vim plugins disabled (gzip, tarPlugin, etc.)

### Terminal Integration (ToggleTerm)
- Default terminal opens in **vertical split** (80 columns width)
- Custom terminal functions for lazygit, python3, node, and htop
- Comprehensive keybinding scheme under `<leader>t*` prefix
- Terminal-specific keymaps: `<Esc>` for normal mode, numbered terminal access

### Claude Code Integration
- Plugin: `coder/claudecode.nvim` 
- Keybindings under `<leader>c*` prefix:
  - `<leader>cc` - Start chat
  - `<leader>cr` - Reset chat
  - `<leader>ca` - Ask about visual selection (visual mode)
  - `<leader>ca`/`<leader>cd` - Accept/deny diffs

### Custom Keybindings
- **Neo-tree toggle**: `<Leader>e`
- **Buffer navigation**: `<C-PageDown>`/`<C-PageUp>` (next/previous)
- **Buffer close**: `<F15>` (mapped from iTerm2)
- **Live grep**: `<F16>` maps to `<leader>/` (iTerm2 integration)
- **Terminal toggle**: `<C-`>` and `<leader>tt`

### Keyball User Configuration Notes
The user uses **Keyball** (advanced keyboard with trackball and many thumb keys), enabling extensive shortcut key usage and seamless mouse operations.

#### Keyboard Features
1. **Feel free to suggest complex key combinations**
   - Multi-modifier combinations (e.g., `<C-S-A-key>`)
   - Function keys with modifiers
   - Extensive use of Leader key combinations

2. **Layer-friendly suggestions**
   - Thumb cluster keys are easily accessible
   - Can utilize more aggressive keybinding schemes
   - No need to limit to simple/ergonomic defaults

3. **Keybinding Strategy**
   - Group related functions under consistent prefixes
   - Use mnemonic key choices liberally
   - Can assign shortcuts to less frequently used features

#### Mouse Integration Features
Since Keyball provides seamless mouse control:

1. **Click-based Context Switching**
   - Clicking on different areas should optimize the interface
   - Window focus should trigger appropriate mode changes
   - Consider implementing smart click zones

2. **Suggested Mouse Enhancements**
   ```lua
   -- Enable mouse support
   vim.opt.mouse = "a"
   
   -- Example: Click on Neo-tree to focus and expand
   -- Example: Click on terminal to auto-enter insert mode
   -- Example: Click on split borders to resize
   ```

3. **Hybrid Operations**
   - Design for keyboard-mouse combination workflows
   - Quick mouse positioning + keyboard commands
   - Gesture-like operations with modifier keys

## Common Development Commands

### Code Formatting
```bash
# LazyVim uses conform.nvim for formatting
# Format current buffer: <leader>cf (LazyVim default)
```

### Linting and Style
```bash
# Code formatting with StyLua (configuration in stylua.toml)
stylua --check .
stylua .
```

### Plugin Management
```bash
# Update plugins (in Neovim)
:Lazy update

# View plugin status
:Lazy

# Clean unused plugins
:Lazy clean
```

### Terminal Operations
- Multiple terminal instances supported (1-4 via `<leader>t1-t4`)
- Floating terminals for specific tools (lazygit, python, node, htop)
- Code execution: send lines/selections to terminal via `<leader>tl`/`<leader>tr`

## File Structure Patterns

- **Plugin configurations** in `lua/plugins/*.lua` follow lazy.nvim spec format
- Each plugin file returns a table with plugin specification
- Custom keybindings defined in `keys` section of plugin specs
- Configuration in `config` function with `setup()` calls

## Japanese-Specific Features

- Help system prioritizes Japanese documentation
- UI messages displayed in Japanese
- Neo-tree opens automatically on startup when no files specified
- Spell checking completely disabled to avoid conflicts with Japanese text

## Plugin Configuration Standards

### Unified Configuration Pattern

All plugin configurations in `lua/plugins/` follow these patterns for consistency and performance:

1. **Basic Pattern with `opts`** (Preferred for simple configs):
```lua
return {
  "plugin/name",
  opts = {
    -- configuration options
  },
}
```

2. **Pattern with `opts` function** (For extending LazyVim defaults):
```lua
return {
  "plugin/name",
  opts = function(_, opts)
    -- modify opts
    return opts
  end,
}
```

3. **Pattern with `config` function** (Only when complex setup needed):
```lua
return {
  "plugin/name",
  config = function(_, opts)
    require("plugin").setup(opts)
    -- additional setup code
  end,
}
```

### Performance Optimization Guidelines

1. **Lazy Loading** - Always specify loading conditions:
   - `event` - Load on specific events (e.g., "TextChanged", "BufRead")
   - `cmd` - Load when command is used
   - `keys` - Load when key mapping is triggered
   - `ft` - Load for specific file types

2. **Dependencies** - Specify only required dependencies

3. **Priority** - Set `priority = 1000` only for essential plugins (colorschemes)

4. **Keys Definition** - Define keymaps in the plugin spec:
```lua
keys = {
  { "<leader>xx", "<cmd>Command<cr>", desc = "Description" },
  { "<leader>xy", function() ... end, desc = "Description", mode = "v" },
}
```

### Example: Well-Configured Plugin
```lua
return {
  "author/plugin-name",
  dependencies = { "required/dependency" },
  event = { "BufRead", "BufNewFile" }, -- or cmd/keys/ft
  keys = {
    { "<leader>p", "<cmd>PluginCommand<cr>", desc = "Plugin action" },
  },
  opts = {
    setting1 = true,
    setting2 = "value",
  },
}
```

### Configuration Rules

1. Use `opts` instead of `config = function()` when possible
2. Add lazy loading triggers (`event`, `cmd`, `keys`, `ft`)
3. Define keymaps in the plugin spec, not in keymaps.lua
4. Keep configurations focused and minimal
5. Comment in Japanese for clarity
6. Follow existing patterns in the codebase

### Adding New Plugins

When adding new plugins, always:

1. **Research Popular Configurations**
   - Check the plugin's README for recommended settings
   - Look for popular dotfiles using the plugin
   - Review LazyVim extras if available

2. **Document Key Features**
   - Add comments explaining what each option does
   - Include popular/useful configurations as comments
   - Provide examples of advanced usage

3. **Example Template**:
```lua
return {
  "author/new-plugin",
  -- 遅延読み込みの設定
  event = "BufRead", -- or appropriate trigger
  
  -- よく使われるキーバインド
  keys = {
    { "<leader>np", "<cmd>PluginCommand<cr>", desc = "Plugin description" },
  },
  
  opts = {
    -- 基本設定
    enable = true,
    
    -- 人気のある設定例（コメントで説明）
    -- feature_x = false, -- この機能を有効にすると〇〇ができる
    -- feature_y = "value", -- 一般的な値: "value1", "value2"
    
    -- 高度な設定例
    -- advanced = {
    --   option1 = true, -- プロ向け: パフォーマンスが向上
    --   option2 = 100,  -- デフォルト: 50, 大きくすると〇〇
    -- },
  },
  
  -- 設定のヒント
  -- config = function(_, opts)
  --   -- 複雑な設定が必要な場合のみ使用
  --   -- 例: 他のプラグインとの連携設定など
  -- end,
}
```

4. **Performance Considerations**
   - Always consider lazy loading options
   - Document performance impact of features
   - Suggest lightweight alternatives when applicable