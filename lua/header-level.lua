-- A Neovim plugin to display current markdown header level

local M = {}

-- Configuration
local config = {
	enabled = true,
	show_in_statusline = true,
	show_virtual_text = false,
	update_events = { "CursorMoved", "CursorMovedI", "BufEnter" },
}

-- Global state
local header_level = ""
local namespace_id = vim.api.nvim_create_namespace("markdown_header_level")

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
			return "Header Level " .. level, level
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

	-- Show as virtual text if enabled
	if config.show_virtual_text then
		-- Clear existing virtual text
		vim.api.nvim_buf_clear_namespace(0, namespace_id, 0, -1)

		if text ~= "" then
			local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
			vim.api.nvim_buf_set_extmark(0, namespace_id, current_line, 0, {
				virt_text = { { " " .. text, "Comment" } },
				virt_text_pos = "eol",
			})
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
		end,
	})
end

-- Public API
function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
	setup_autocommands()
end

function M.get_header_level()
	return header_level
end

function M.toggle()
	config.enabled = not config.enabled
	if config.enabled then
		update_header_display()
	else
		header_level = ""
		vim.g.markdown_header_level = ""
		vim.api.nvim_buf_clear_namespace(0, namespace_id, 0, -1)
		vim.cmd("redrawstatus")
	end
end

-- Commands
vim.api.nvim_create_user_command("MarkdownHeaderToggle", M.toggle, {})
vim.api.nvim_create_user_command("MarkdownHeaderLevel", function()
	print(M.get_header_level())
end, {})

return M
