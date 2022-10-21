M = {}

function M.delete_session()
	require('telescope').load_extension('possession') -- Load telescope
	local items = require('possession.session').list()
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local pickers = require('telescope.pickers')
	local finders = require('telescope.finders')
	local sorters = require('telescope.sorters')

	local keys = vim.tbl_keys(items)
	local opts = {
		-- use this syntax if you do not need to display different
		-- content compared to value
		-- finder = finders.new_table(keys),
		finder = finders.new_table {
			results = keys,
			entry_maker = function (entry)
				P(vim.fs.basename(entry))
				return {
					value = entry,
					display = vim.fs.basename(entry),
					ordinal = entry,
				}
			end,
		},
		sorter = sorters.get_generic_fuzzy_sorter({}),
		prompt_title = 'Select sessions to delete',
		attach_mappings = function (prompt_bufnr, map)
			actions.select_default:replace(function ()
				local delete_item = function (name)
					local cmd = 'rm "' .. name .. '"'
					io.popen(cmd)
					print('Deleted '..name)
				end
				local marked_items = action_state.get_current_picker(prompt_bufnr)._multi._entries
				local marked_items_count = vim.tbl_count(marked_items)
				if marked_items_count == 0 then
					local selected = action_state.get_selected_entry()
					delete_item(selected['value'])
				else
					for k, v in pairs(marked_items) do
						delete_item(k['value'])
					end
				end
				actions.close(prompt_bufnr)
			end)
			return true
		end
	}
	local sessions = pickers.new(opts)
	sessions:find()
end

return M
