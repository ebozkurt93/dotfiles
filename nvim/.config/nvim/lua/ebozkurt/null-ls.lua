local null_ls = require("null-ls")

null_ls.setup({
	sources = {
		null_ls.builtins.diagnostics.eslint,
		null_ls.builtins.code_actions.eslint,
		null_ls.builtins.completion.luasnip,
		null_ls.builtins.completion.spell,
		null_ls.builtins.hover.dictionary,
		-- null_ls.builtins.formatting.stylua,
		null_ls.builtins.completion.luasnip,
		-- js
		-- null_ls.builtins.diagnostics.eslint_d,
		-- null_ls.builtins.code_actions.eslint_d,
		-- null_ls.builtins.formatting.eslint_d,
		null_ls.builtins.diagnostics.eslint,
		null_ls.builtins.code_actions.eslint,
		null_ls.builtins.formatting.eslint,
		null_ls.builtins.formatting.prettier,
		-- python
		null_ls.builtins.diagnostics.pycodestyle,
		null_ls.builtins.diagnostics.pydocstyle,
		-- null_ls.builtins.diagnostics.pylint,
		-- null_ls.builtins.formatting.black,
		null_ls.builtins.formatting.black.with({
			extra_args = { "--skip-string-normalization" },
		}),
		-- go
		null_ls.builtins.diagnostics.staticcheck,
		-- zsh
		null_ls.builtins.diagnostics.zsh,
		-- bazel
		null_ls.builtins.formatting.buildifier,
		-- proto
		null_ls.builtins.formatting.protolint,
		null_ls.builtins.diagnostics.protoc_gen_lint,
		-- terraform
		null_ls.builtins.formatting.terraform_fmt,
		-- sh
		null_ls.builtins.hover.printenv,
		null_ls.builtins.diagnostics.pylint,
	}
})
