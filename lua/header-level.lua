-- A Neovim plugin to display current markdown header level

local M = {}

-- Configuration
local config = {
	enabled = true,
	show_in_statusline = true,
	show_virtual_text = false,
	show_header_tree = false, -- Show header tree in top right corner
	virtual_text_position = "eol", -- "eol", "right_align", "overlay", "fixed_corner"
	update_events = { "CursorMoved", "CursorMovedI", "BufEnter" },
	inverted_colors = true, -- Use colored backgrounds with dark foregrounds
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
}

-- Global state
local header_level = ""
local namespace_id = vim.api.nvim_create_namespace("markdown_header_level")
local floating_win_id = nil
local tree_win_id = nil
local tree_buf_id = nil

-- Setup custom highlight groups
local function setup_highlights()
	for i = 1, 6 do
		local hl_name = "MarkdownHeaderLevel" .. i
		local color = config.colors["h" .. i]
		
		if config.inverted_colors then
			-- Dark foreground with colored background
			vim.api.nvim_set_hl(0, hl_name, {
				fg = "#000000",
				bg = color,
				bold = true,
			})
		else
			-- Colored foreground with default background
			vim.api.nvim_set_hl(0, hl_name, {
				fg = color,
				bold = true,
			})
		end
	end
	
	-- Highlight for current section in tree
	vim.api.nvim_set_hl(0, "MarkdownHeaderTreeCurrent", {
		fg = "#ffffff",
		bg = "#444444",
		bold = true,
	})
end

-- Function to get highlight group for header level
local function get_header_highlight(level)
	return "MarkdownHeaderLevel" .. (level or 1)
end

-- Function to find the current header level
local function get_current_header_level()
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	local lines = vim.api.nvim_buf_get_lines(0, 0, current_line, false)

	-- Search backwards from current line to find the nearest header
	for i = #lines, 1, -1 do
		local line = lines[i]
		local header_match = line:match("^(#+)%s+")

		if header_match then
			local level = #header_match
			return "H" .. level, level
		end
	end

	return "", 0
end

-- Function to extract all headers from the document
local function get_all_headers()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local headers = {}
	
	for i, line in ipairs(lines) do
		local header_match, title = line:match("^(#+)%s+(.*)")
		if header_match then
			local level = #header_match
			table.insert(headers, {
				level = level,
				title = title,
				line_number = i,
			})
		end
	end
	
	return headers
end

-- Function to build header tree display lines
local function build_header_tree()
	local headers = get_all_headers()
	if #headers == 0 then
		return {}
	end
	
	local tree_lines = {}
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	local current_header_line = 0
	
	-- Find which header section we're currently in
	for i = #headers, 1, -1 do
		if headers[i].line_number <= current_line then
			current_header_line = headers[i].line_number
			break
		end
	end
	
	for _, header in ipairs(headers) do
		local prefix = string.rep("-", header.level - 1)
		local line_text = prefix .. header.title
		local is_current = header.line_number == current_header_line
		
		table.insert(tree_lines, {
			text = line_text,
			level = header.level,
			is_current = is_current,
			line_number = header.line_number,
		})
	end
	
	return tree_lines
end

-- Function to update header tree display
local function update_header_tree()
	if not config.show_header_tree then
		-- Close tree window if it exists
		if tree_win_id and vim.api.nvim_win_is_valid(tree_win_id) then
			vim.api.nvim_win_close(tree_win_id, true)
			tree_win_id = nil
		end
		return
	end
	
	local tree_lines = build_header_tree()
	if #tree_lines == 0 then
		-- Close tree window if no headers
		if tree_win_id and vim.api.nvim_win_is_valid(tree_win_id) then
			vim.api.nvim_win_close(tree_win_id, true)
			tree_win_id = nil
		end
		return
	end
	
	-- Create or reuse buffer
	if not tree_buf_id or not vim.api.nvim_buf_is_valid(tree_buf_id) then
		tree_buf_id = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(tree_buf_id, "buftype", "nofile")
		vim.api.nvim_buf_set_option(tree_buf_id, "swapfile", false)
	end
	
	-- Find current header index for scrolling
	local current_header_idx = 1
	for i, line_info in ipairs(tree_lines) do
		if line_info.is_current then
			current_header_idx = i
			break
		end
	end
	
	-- Calculate scrolling with 3-line padding
	local max_display_height = math.min(vim.api.nvim_win_get_height(0) - 2, 20) -- Limit to window height or 20 lines
	local total_lines = #tree_lines
	local padding = 3
	
	local start_line, end_line, display_height
	
	if total_lines <= max_display_height then
		-- Show all lines if they fit
		start_line = 1
		end_line = total_lines
		display_height = total_lines
	else
		-- Calculate scroll position to keep current header centered with padding
		local target_position = current_header_idx
		local half_display = math.floor(max_display_height / 2)
		
		-- Try to center current header
		start_line = math.max(1, target_position - half_display)
		end_line = math.min(total_lines, start_line + max_display_height - 1)
		
		-- Adjust if we're at the end
		if end_line == total_lines then
			start_line = math.max(1, total_lines - max_display_height + 1)
		end
		
		-- Ensure current header has padding (at least 3 lines from top/bottom when possible)
		if target_position - start_line < padding and start_line > 1 then
			start_line = math.max(1, target_position - padding)
			end_line = math.min(total_lines, start_line + max_display_height - 1)
		end
		
		if end_line - target_position < padding and end_line < total_lines then
			end_line = math.min(total_lines, target_position + padding)
			start_line = math.max(1, end_line - max_display_height + 1)
		end
		
		display_height = end_line - start_line + 1
	end
	
	-- Prepare visible lines and highlights
	local display_lines = {}
	local highlights = {}
	
	for i = start_line, end_line do
		local line_info = tree_lines[i]
		table.insert(display_lines, line_info.text)
		
		local hl_group = line_info.is_current and "MarkdownHeaderTreeCurrent" or get_header_highlight(line_info.level)
		table.insert(highlights, {
			line = #display_lines - 1, -- Adjust for 0-based indexing in display
			col_start = 0,
			col_end = #line_info.text,
			hl_group = hl_group,
		})
	end
	
	-- Update buffer content
	vim.api.nvim_buf_set_lines(tree_buf_id, 0, -1, false, display_lines)
	
	-- Calculate window dimensions
	local max_width = 0
	for _, line in ipairs(display_lines) do
		max_width = math.max(max_width, #line)
	end
	
	local width = math.min(max_width + 2, 50) -- Max 50 chars wide
	local win_width = vim.api.nvim_win_get_width(0)
	
	-- Create or update window
	if not tree_win_id or not vim.api.nvim_win_is_valid(tree_win_id) then
		tree_win_id = vim.api.nvim_open_win(tree_buf_id, false, {
			relative = "win",
			width = width,
			height = display_height,
			row = 0,
			col = win_width - width - 1,
			style = "minimal",
			border = "none",
			focusable = false,
		})
		
		-- Set transparent background
		vim.api.nvim_win_set_option(tree_win_id, "winhl", "Normal:Normal")
	else
		-- Update existing window size and position
		vim.api.nvim_win_set_config(tree_win_id, {
			relative = "win",
			width = width,
			height = display_height,
			row = 0,
			col = win_width - width - 1,
		})
	end
	
	-- Clear existing highlights and apply new ones
	vim.api.nvim_buf_clear_namespace(tree_buf_id, namespace_id, 0, -1)
	for _, hl in ipairs(highlights) do
		vim.api.nvim_buf_add_highlight(tree_buf_id, namespace_id, hl.hl_group, hl.line, hl.col_start, hl.col_end)
	end
end

-- Function to update the display
local function update_header_display()
	if not config.enabled then
		return
	end

	local text, level = get_current_header_level()
	header_level = text

	-- Update statusline (will be picked up by statusline if configured)
	vim.g.markdown_header_level = text
	vim.g.markdown_header_level_hl = level > 0 and get_header_highlight(level) or ""

	-- Show as virtual text if enabled
	if config.show_virtual_text then
		-- Clear existing virtual text and floating window
		vim.api.nvim_buf_clear_namespace(0, namespace_id, 0, -1)
		if floating_win_id and vim.api.nvim_win_is_valid(floating_win_id) then
			vim.api.nvim_win_close(floating_win_id, true)
			floating_win_id = nil
		end

		if text ~= "" then
			local highlight = get_header_highlight(level)
			
			if config.virtual_text_position == "fixed_corner" then
				-- Create floating window in top-right corner
				local buf = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
				
				local width = #text
				local height = 1
				local win_width = vim.api.nvim_win_get_width(0)
				
				floating_win_id = vim.api.nvim_open_win(buf, false, {
					relative = "win",
					width = width,
					height = height,
					row = 0,
					col = win_width - width - 1,
					style = "minimal",
					border = "none",
					focusable = false,
				})
				
				-- Set highlight with level-specific color
				vim.api.nvim_win_set_option(floating_win_id, "winhl", "Normal:" .. highlight)
			else
				-- Use regular virtual text
				local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
				local line_count = vim.api.nvim_buf_line_count(0)
				
				-- Ensure current_line is within valid range
				if current_line >= 0 and current_line < line_count then
					local current_line_text = vim.api.nvim_buf_get_lines(0, current_line, current_line + 1, false)[1] or ""
					local line_length = #current_line_text
					
					local virt_text_opts = {
						virt_text = { { " " .. text, highlight } },
						virt_text_pos = config.virtual_text_position,
					}
					
					-- Add overlay column if using overlay position
					if config.virtual_text_position == "overlay" then
						local win_width = vim.api.nvim_win_get_width(0)
						local text_width = #text + 1 -- +1 for the space
						local overlay_col = math.max(0, win_width - text_width - 5)
						virt_text_opts.virt_text_win_col = overlay_col
					end
					
					-- Safely set extmark with bounds checking
					local ok, err = pcall(vim.api.nvim_buf_set_extmark, 0, namespace_id, current_line, 0, virt_text_opts)
					if not ok then
						-- Fallback to end-of-line position if overlay fails
						virt_text_opts.virt_text_pos = "eol"
						virt_text_opts.virt_text_win_col = nil
						pcall(vim.api.nvim_buf_set_extmark, 0, namespace_id, current_line, 0, virt_text_opts)
					end
				end
			end
		end
	end
	
	-- Update header tree
	update_header_tree()

	-- Trigger statusline update
	vim.cmd("redrawstatus")
end

-- Function to setup keymaps
local function setup_keymaps()
	if not config.keymaps then
		return
	end
	
	local group = vim.api.nvim_create_augroup("MarkdownHeaderLevelKeymaps", { clear = true })
	
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = { "markdown", "mdx" },
		callback = function()
			local opts = { buffer = true, silent = true }
			
			if config.keymaps.toggle then
				vim.keymap.set("n", config.keymaps.toggle, function()
					require("header-level").toggle()
					local status = config.enabled and "enabled" or "disabled"
					vim.notify("Header level display " .. status, vim.log.levels.INFO)
				end, vim.tbl_extend("force", opts, { desc = "Toggle header level display" }))
			end
			
			if config.keymaps.toggle_tree then
				vim.keymap.set("n", config.keymaps.toggle_tree, function()
					require("header-level").toggle_tree()
					local status = config.show_header_tree and "shown" or "hidden"
					vim.notify("Header tree " .. status, vim.log.levels.INFO)
				end, vim.tbl_extend("force", opts, { desc = "Toggle header tree outline" }))
			end
			
			if config.keymaps.toggle_virtual_text then
				vim.keymap.set("n", config.keymaps.toggle_virtual_text, function()
					require("header-level").toggle_virtual_text()
					local status = config.show_virtual_text and "shown" or "hidden"
					vim.notify("Virtual text " .. status, vim.log.levels.INFO)
				end, vim.tbl_extend("force", opts, { desc = "Toggle virtual text display" }))
			end
		end,
	})
end

-- Function to setup autocommands
local function setup_autocommands()
	local group = vim.api.nvim_create_augroup("MarkdownHeaderLevel", { clear = true })

	vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
		group = group,
		pattern = { "*.md", "*.mdx" },
		callback = function()
			-- Set up buffer-local autocommands for cursor movement
			local buf_group = vim.api.nvim_create_augroup("MarkdownHeaderLevelBuffer", { clear = true })

			vim.api.nvim_create_autocmd(config.update_events, {
				group = buf_group,
				buffer = 0,
				callback = update_header_display,
			})

			-- Initial update
			update_header_display()
		end,
	})

	-- Clean up when leaving markdown files
	vim.api.nvim_create_autocmd("BufLeave", {
		group = group,
		pattern = { "*.md", "*.mdx" },
		callback = clear_display,
	})

	-- Clean up when entering non-markdown buffers
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
		group = group,
		callback = function()
			local filetype = vim.bo.filetype
			if filetype ~= "markdown" and filetype ~= "mdx" then
				clear_display()
			end
		end,
	})
end

-- Function to clear display state
local function clear_display()
	header_level = ""
	vim.g.markdown_header_level = ""
	vim.g.markdown_header_level_hl = ""
	vim.api.nvim_buf_clear_namespace(0, namespace_id, 0, -1)
	if floating_win_id and vim.api.nvim_win_is_valid(floating_win_id) then
		vim.api.nvim_win_close(floating_win_id, true)
		floating_win_id = nil
	end
	if tree_win_id and vim.api.nvim_win_is_valid(tree_win_id) then
		vim.api.nvim_win_close(tree_win_id, true)
		tree_win_id = nil
	end
	vim.cmd("redrawstatus")
end

-- Function to clear all cached state
local function clear_cache()
	-- Close and clear tree window
	if tree_win_id and vim.api.nvim_win_is_valid(tree_win_id) then
		vim.api.nvim_win_close(tree_win_id, true)
	end
	tree_win_id = nil
	
	-- Clear tree buffer
	if tree_buf_id and vim.api.nvim_buf_is_valid(tree_buf_id) then
		vim.api.nvim_buf_delete(tree_buf_id, { force = true })
	end
	tree_buf_id = nil
	
	-- Close floating window
	if floating_win_id and vim.api.nvim_win_is_valid(floating_win_id) then
		vim.api.nvim_win_close(floating_win_id, true)
	end
	floating_win_id = nil
	
	-- Clear namespace
	vim.api.nvim_buf_clear_namespace(0, namespace_id, 0, -1)
end

-- Public API
function M.setup(opts)
	-- Clear any existing state first
	clear_cache()
	
	config = vim.tbl_deep_extend("force", config, opts or {})
	setup_highlights()
	setup_autocommands()
	setup_keymaps()
end

function M.get_header_level()
	return header_level
end

-- Get header level with color information for statusline integration
function M.get_colored_header_level()
	if header_level == "" then
		return ""
	end
	
	local _, level = get_current_header_level()
	local hl_group = get_header_highlight(level)
	
	return {
		text = header_level,
		highlight = hl_group,
		level = level,
	}
end

function M.toggle()
	config.enabled = not config.enabled
	if config.enabled then
		update_header_display()
	else
		clear_display()
	end
end

function M.toggle_tree()
	config.show_header_tree = not config.show_header_tree
	update_header_tree()
end

function M.toggle_virtual_text()
	config.show_virtual_text = not config.show_virtual_text
	if config.show_virtual_text then
		update_header_display()
	else
		-- Clear virtual text and floating window
		vim.api.nvim_buf_clear_namespace(0, namespace_id, 0, -1)
		if floating_win_id and vim.api.nvim_win_is_valid(floating_win_id) then
			vim.api.nvim_win_close(floating_win_id, true)
			floating_win_id = nil
		end
	end
end

-- Commands
vim.api.nvim_create_user_command("MarkdownHeaderToggle", M.toggle, { desc = "Toggle header level display" })
vim.api.nvim_create_user_command("MarkdownHeaderTreeToggle", M.toggle_tree, { desc = "Toggle header tree outline" })
vim.api.nvim_create_user_command("MarkdownHeaderVirtualTextToggle", M.toggle_virtual_text, { desc = "Toggle virtual text display" })
vim.api.nvim_create_user_command("MarkdownHeaderLevel", function()
	print(M.get_header_level())
end, { desc = "Print current header level" })

return M
