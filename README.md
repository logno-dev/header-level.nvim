# header-level.nvim

A lightweight Neovim plugin that displays the current markdown header level in your statusline or as virtual text.

## Features

- 🎯 Shows the current header level based on cursor position
- 📊 Statusline integration support
- 👻 Optional virtual text display with multiple positioning options
- ⚡ Automatic updates on cursor movement
- 🎛️ Configurable update events
- 🔄 Toggle functionality

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

## Configuration

### Default Configuration

```lua
require("header-level").setup({
  enabled = true,
  show_in_statusline = true,
  show_virtual_text = false,
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
})
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `true` | Enable/disable the plugin |
| `show_in_statusline` | boolean | `true` | Make header level available for statusline |
| `show_virtual_text` | boolean | `false` | Show header level as virtual text |
| `virtual_text_position` | string | `"eol"` | Virtual text position: `"eol"` (end of line), `"right_align"` (right-aligned), `"overlay"` (overlay at column), `"fixed_corner"` (floating window in top-right) |
| `inverted_colors` | boolean | `true` | Use colored backgrounds with dark foregrounds instead of colored foregrounds |
| `colors` | table | See default | Color scheme for each header level using hex color codes |
| `update_events` | table | `{ "CursorMoved", "CursorMovedI", "BufEnter" }` | Events that trigger header level updates |

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

## Commands

| Command | Description |
|---------|-------------|
| `:MarkdownHeaderToggle` | Toggle the plugin on/off |
| `:MarkdownHeaderLevel` | Print the current header level |

## API

```lua
local header_level = require("header-level")

-- Get current header level
local level = header_level.get_header_level()

-- Toggle plugin
header_level.toggle()
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