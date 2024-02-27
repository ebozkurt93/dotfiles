local ls = require("luasnip")
local s = ls.snippet
-- local sn = ls.snippet_node
-- local isn = ls.indent_snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
-- local c = ls.choice_node
-- local d = ls.dynamic_node
-- local r = ls.restore_node
-- local events = require("luasnip.util.events")
-- local ai = require("luasnip.nodes.absolute_indexer")
local fmt = require("luasnip.extras.fmt").fmt
-- local extras = require("luasnip.extras")
-- local m = extras.m
-- local l = extras.l
-- local rep = extras.rep
-- local postfix = require("luasnip.extras.postfix").postfix

ls.config.set_config {
	history = true,
	updateevents = 'TextChanged,TextChangedI',
	enable_autosnippets = true,
	-- ext_opts = nil,
	-- ext_opts = {
	-- 	[types.choiceNode] = {
	-- 		active = {
	-- 			virt_text = {{ '<-', 'Error'}},
	-- 		}
	-- 	}
	-- },
}

vim.api.nvim_exec_autocmds('User', { pattern = 'luasnip' })

ls.add_snippets('all', {
	s("trig", { i(1), t "text", i(2), t "text again", i(3) }),
	ls.parser.parse_snippet('expand', 'asdsadasda'),
})
ls.add_snippets('lua', {
	s("todo", fmt("-- todo: {}", { i(1) })),
	s("cmd", fmt("'<cmd>{}<cr>'", { i(1) })),
	s('req', fmt([[local {} = require('{}')]], {
		f(function(import_name)
			local parts = vim.split(import_name[1][1], '.', true)
			return parts[#parts] or ''
		end, { 1 }), i(1),
	})),
})
local function copy(args) return args[1] end

ls.add_snippets('python', {
	s("pr", fmt("print({})", { i(1) })),
	s("pd", fmt("print('Debug - {}:', {})", { f(copy, 1), i(1) })),
	s("todo", fmt("# todo: {}", { i(1) })),
})
ls.add_snippets('javascript', {
	s("clg", fmt("console.log({})", { i(1) })),
	s("clgd", fmt("console.log('Debug - {}:', {})", { f(copy, 1), i(1) })),
	s("todo", fmt("// todo: {}", { i(1) })),
})

local date = function()
    return os.date("%Y-%m-%d")
end

ls.add_snippets('markdown', {
	 s("bdate", {
        f(function() return "[[" .. date() .. "]]" end, {})
    }),
})

require("luasnip.loaders.from_vscode").lazy_load()
