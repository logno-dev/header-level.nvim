-- A Neovim plugin to display current markdown header level

local M = {}

-- Configuration
local config = {
	enabled = true,
	show_in_statusline = true,
	show_virtual_text = false,
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
}

-- Global state
local header_level = ""
local namespace_id = vim.api.nvim_create_namespace("markdown_header_level")
local floating_win_id = nil

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
				local virt_text_opts = {
					virt_text = { { " " .. text, highlight } },
					virt_text_pos = config.virtual_text_position,
				}
				
				-- Add overlay column if using overlay position
				if config.virtual_text_position == "overlay" then
					virt_text_opts.virt_text_win_col = vim.api.nvim_win_get_width(0) - #text - 5
				end
				
				vim.api.nvim_buf_set_extmark(0, namespace_id, current_line, 0, virt_text_opts)
			end
		end
	end

	-- Trigger statusline update
	vim.cmd("redrawstatus")
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
		callback = function()
			header_level = ""
			vim.g.markdown_header_level = ""
			vim.api.nvim_buf_clear_namespace(0, namespace_id, 0, -1)
			if floating_win_id and vim.api.nvim_win_is_valid(floating_win_id) then
				vim.api.nvim_win_close(floating_win_id, true)
				floating_win_id = nil
			end
		end,
	})
end

-- Public API
function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
	setup_highlights()
	setup_autocommands()
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
		header_level = ""
		vim.g.markdown_header_level = ""
		vim.api.nvim_buf_clear_namespace(0, namespace_id, 0, -1)
		if floating_win_id and vim.api.nvim_win_is_valid(floating_win_id) then
			vim.api.nvim_win_close(floating_win_id, true)
			floating_win_id = nil
		end
		vim.cmd("redrawstatus")
	end
end

-- Commands
vim.api.nvim_create_user_command("MarkdownHeaderToggle", M.toggle, {})
vim.api.nvim_create_user_command("MarkdownHeaderLevel", function()
	print(M.get_header_level())
end, {})

return M
