# header-level.nvim

A lightweight Neovim plugin that displays the current markdown header level in your statusline, as virtual text, or shows a complete document outline tree.

## Features

- 🎯 Shows the current header level based on cursor position
- 📊 Statusline integration support
- 👻 Optional virtual text display with multiple positioning options
- 🌳 **NEW**: Header tree outline in top-right corner showing document structure
- 🎨 Color-coded header levels with current section highlighting
- ⚡ Automatic updates on cursor movement
- 🎛️ Configurable update events
- 🔄 Toggle functionality for all display modes

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "logno-dev/header-level.nvim",
  ft = { "markdown", "mdx" },
  config = function()
    require("header-level").setup()
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "logno-dev/header-level.nvim",
  ft = { "markdown", "mdx" },
  config = function()
    require("header-level").setup()
  end,
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'logno-dev/header-level.nvim'

" Add to your init.vim or init.lua
lua require("header-level").setup()
```

### [dein.vim](https://github.com/Shougo/dein.vim)

```vim
call dein#add('logno-dev/header-level.nvim')

" Add to your init.vim or init.lua
lua require("header-level").setup()
```

### Manual Installation

Clone the repository to your Neovim configuration directory:

```bash
git clone https://github.com/logno-dev/header-level.nvim ~/.config/nvim/pack/plugins/start/header-level.nvim
```

## Display Modes

The plugin offers three independent display modes that can be used separately or together:

### 1. Statusline Integration (`show_in_statusline`)
Shows the current header level (e.g., "H2") in your statusline. Always enabled by default.

### 2. Virtual Text (`show_virtual_text`) 
Shows the current header level as virtual text near your cursor with various positioning options.

### 3. Header Tree Outline (`show_header_tree`)
Shows a complete document outline in the top-right corner with:
- Hierarchical structure using dashes (-, --, ---, etc.)
- Color-coded header levels
- Current section highlighting
- Real-time updates as you navigate

**Example tree display:**
```
Main Title
-Secondary
--Sub Category 1  ← highlighted if cursor is here
--Sub Category 2
-Another Section
```

You can enable any combination of these modes. For example:
- **Minimal**: Only statusline (`show_in_statusline = true`)
- **Current focus**: Statusline + virtual text
- **Full overview**: All three modes enabled
- **Outline only**: Just the header tree for document navigation

## Configuration

### Default Configuration

```lua
require("header-level").setup({
  enabled = true,
  show_in_statusline = true,
  show_virtual_text = false,
  show_header_tree = false, -- Show document outline tree in top-right corner
  virtual_text_position = "eol", -- "eol", "right_align", "overlay", "fixed_corner"
  inverted_colors = true, -- Use colored backgrounds with dark foregrounds
  update_events = { "CursorMoved", "CursorMovedI", "BufEnter" },
  colors = {
    h1 = "#9d4edd", -- Purple
    h2 = "#f77f00", -- Orange
    h3 = "#0077be", -- Blue
    h4 = "#06d6a0", -- Teal/Cyan
    h5 = "#6c757d", -- Gray
    h6 = "#495057", -- Darker gray
  },
  -- Keymaps (set to false to disable, or provide custom mappings)
  keymaps = {
    toggle = "<leader>mh", -- Toggle plugin on/off
    toggle_tree = "<leader>mt", -- Toggle header tree outline
    toggle_virtual_text = "<leader>mv", -- Toggle virtual text display
  },
})
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `true` | Enable/disable the plugin |
| `show_in_statusline` | boolean | `true` | Make header level available for statusline |
| `show_virtual_text` | boolean | `false` | Show header level as virtual text |
| `show_header_tree` | boolean | `false` | Show document outline tree in top-right corner |
| `virtual_text_position` | string | `"eol"` | Virtual text position: `"eol"` (end of line), `"right_align"` (right-aligned), `"overlay"` (overlay at column), `"fixed_corner"` (floating window in top-right) |
| `inverted_colors` | boolean | `true` | Use colored backgrounds with dark foregrounds instead of colored foregrounds |
| `colors` | table | See default | Color scheme for each header level using hex color codes |
| `update_events` | table | `{ "CursorMoved", "CursorMovedI", "BufEnter" }` | Events that trigger header level updates |
| `keymaps` | table | See default | Buffer-local keymaps for markdown files. Set individual keys to `false` to disable or provide custom mappings |

## Statusline Integration

The plugin sets the global variable `vim.g.markdown_header_level` which you can use in your statusline configuration.

### lualine.nvim

Basic integration:
```lua
require('lualine').setup({
  sections = {
    lualine_c = {
      'filename',
      {
        function()
          return vim.g.markdown_header_level or ''
        end,
        cond = function()
          return vim.bo.filetype == 'markdown' and vim.g.markdown_header_level ~= ''
        end,
      }
    }
  }
})
```

With colors (using the plugin's color scheme):
```lua
require('lualine').setup({
  sections = {
    lualine_c = {
      'filename',
      {
        function()
          local header_info = require('header-level').get_colored_header_level()
          return header_info.text or ''
        end,
        color = function()
          local header_info = require('header-level').get_colored_header_level()
          return header_info.highlight and { fg = vim.g.markdown_header_level_hl } or nil
        end,
        cond = function()
          return vim.bo.filetype == 'markdown' and vim.g.markdown_header_level ~= ''
        end,
      }
    }
  }
})
```

### galaxyline.nvim

```lua
local gl = require('galaxyline')
gl.section.left[3] = {
  MarkdownHeader = {
    provider = function()
      return vim.g.markdown_header_level or ''
    end,
    condition = function()
      return vim.bo.filetype == 'markdown' and vim.g.markdown_header_level ~= ''
    end,
  }
}
```

### Built-in statusline

```vim
set statusline+=%{v:lua.vim.g.markdown_header_level}
```

## Keymaps

The plugin provides buffer-local keymaps for markdown files that you can use on-the-fly:

| Keymap | Command | Description |
|--------|---------|-------------|
| `<leader>mh` | `:MarkdownHeaderToggle` | Toggle the plugin on/off |
| `<leader>mt` | `:MarkdownHeaderTreeToggle` | Toggle the header tree outline display |
| `<leader>mv` | `:MarkdownHeaderVirtualTextToggle` | Toggle virtual text display |

### Customizing Keymaps

You can customize keymaps in your setup configuration:

```lua
require("header-level").setup({
  keymaps = {
    toggle = "<leader>th", -- Change toggle keymap
    toggle_tree = false, -- Disable tree toggle keymap
    toggle_virtual_text = "<leader>tv", -- Custom virtual text toggle
  },
})
```

To disable all keymaps:

```lua
require("header-level").setup({
  keymaps = false,
})
```

## Commands

All features are also available as commands:

| Command | Description |
|---------|-------------|
| `:MarkdownHeaderToggle` | Toggle the plugin on/off |
| `:MarkdownHeaderTreeToggle` | Toggle the header tree outline display |
| `:MarkdownHeaderVirtualTextToggle` | Toggle virtual text display |
| `:MarkdownHeaderLevel` | Print the current header level |

## API

```lua
local header_level = require("header-level")

-- Get current header level
local level = header_level.get_header_level()

-- Toggle plugin on/off
header_level.toggle()

-- Toggle header tree display
header_level.toggle_tree()

-- Toggle virtual text display
header_level.toggle_virtual_text()

-- Get colored header level info (for statusline integration)
local info = header_level.get_colored_header_level()
-- Returns: { text = "H2", highlight = "MarkdownHeaderLevel2", level = 2 }
```

## How It Works

The plugin analyzes your markdown file and determines which header section your cursor is currently in by:

1. Looking at the current cursor position
2. Searching backwards from the cursor to find the nearest header (lines starting with `#`)
3. Counting the number of `#` characters to determine the header level
4. Updating the display based on your configuration

## Examples

Given this markdown structure:

```markdown
# Main Title (Level 1)

Some content here...

## Subsection (Level 2)

More content...

### Details (Level 3)

Your cursor is here
```

When your cursor is on "Your cursor is here", the plugin will display "H3".

## Requirements

- Neovim 0.7+
- Works with `.md` and `.mdx` files

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.