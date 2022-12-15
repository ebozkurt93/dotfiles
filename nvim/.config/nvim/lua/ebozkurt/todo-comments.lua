require("todo-comments").setup {
	signs = true, -- show icons in the signs column
	keywords = {
		fix = {
			icon = " ", -- icon used for the sign, and in search results
			color = "error", -- can be a hex color, or a named color (see below)
			alt = { "fixme", "bug", "fixit", "issue" }, -- a set of other keywords that all map to this FIX keywords
			-- signs = false, -- configure signs for some keywords individually
		},
		todo = { icon = " ", color = "info" },
		hack = { icon = " ", color = "warning" },
		warn = { icon = " ", color = "warning", alt = { "warning", "xxx" } },
		perf = { icon = " ", alt = { "optim", "performance", "optimize" } },
		note = { icon = " ", color = "hint", alt = { "info", "continue-from", "continue from" } },
		test = { icon = "⏲ ", color = "test", alt = { "testing", "passed", "failed" } },
	},
	highlight = {
		multiline_pattern = "^.",
		pattern = { [[.*<(KEYWORDS)\s*:]], [[.*<(KEYWORDS)\s*\(.+\)\s*:]] }
	},
	search = {
		command = "rg",
		args = {
			"--color=never",
			"--no-heading",
			"--with-filename",
			"--line-number",
			"--column",
			"-i" -- case insensitive search
		},
		-- regex that will be used to match keywords.
		-- don't replace the (KEYWORDS) placeholder
		-- pattern = [[\b(KEYWORDS):]], -- ripgrep regex
		pattern = [[\b(KEYWORDS)\b]], -- match without the extra colon. You'll likely get false positives
	},
}
