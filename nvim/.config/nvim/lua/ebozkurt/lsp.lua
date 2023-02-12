-- Set up mason
require("mason").setup()
require("mason-lspconfig").setup()

-- Set up lspconfig.
-- todo: remove if solution below works, this should not be used anymore
-- local capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())
local capabilities = require("cmp_nvim_lsp").default_capabilities()
--local bufopts = { noremap = true, silent = true, buffer = 0 }
local my_on_attach = function()
	vim.api.nvim_exec_autocmds('User', { pattern = 'LspAttached' })
end
require("mason-lspconfig").setup_handlers {
	-- The first entry (without a key) will be the default handler
	-- and will be called for each installed server that doesn't have
	-- a dedicated handler.
	function(server_name) -- default handler (optional)
		local custom_configured_servers = { 'tsserver', 'eslint' }
		if vim.tbl_contains(custom_configured_servers, server_name) then
			return
		end
		require("lspconfig")[server_name].setup {
			capabilities = capabilities,
			on_attach = my_on_attach,
		}
	end,
	-- Next, you can provide a dedicated handler for specific servers.
	-- For example, a handler override for the `rust_analyzer`:
	-- ["rust_analyzer"] = function()
	-- 	require("rust-tools").setup {}
	-- end
}

require 'lspconfig'.tsserver.setup {
	capabilities = capabilities,
	on_attach = function(client)
		my_on_attach()
		-- disable formatter for tsserver, since prettier is already doing it
		client.server_capabilities.documentFormattingProvider = false
		client.server_capabilities.documentRangeFormattingProvider = false
	end,
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "typescript.tsx" },
	root_dir = function() return vim.loop.cwd() end
}
-- go install golang.org/x/tools/gopls@latest
require 'lspconfig'.gopls.setup {
	capabilities = capabilities,
	on_attach = my_on_attach,
}

-- local util = require('lspconfig/util')
-- local path = util.path
local path = require('lspconfig/util').path

-- npm install -g pyright
require 'lspconfig'.pyright.setup {
	capabilities = capabilities,
	--  settings = {
	--    python =  {
	--        analysis = {
	--        autoSearchPaths = false,
	--        useLibraryCodeForTypes = false,
	--        diagnosticMode = 'openFilesOnly',
	--      }
	--    }
	--  },
	before_init = function(_, config)
		config.settings.python.pythonPath = require('ebozkurt.helpers').get_python_path(config.root_dir)
	end,
	on_attach = my_on_attach,
}

-- -- pip install python-lsp-server
-- require 'lspconfig'.pylsp.setup {
-- 	capabilities = capabilities,
-- 	before_init = function(_, config)
-- 		config.settings.python.pythonPath = require('ebozkurt.helpers').get_python_path(config.root_dir)
-- 	end,
-- 	on_attach = my_on_attach,
-- }

-- brew install lua-language-server
require 'lspconfig'.lua_ls.setup {
	cmd = { "lua-language-server" },
	capabilities = capabilities,
	on_attach = my_on_attach,
	settings = { Lua = { diagnostics = { globals = { 'vim', 'exepath' } } } }
}

-- require 'lspconfig'.eslint.setup {}

-- Set up nvim-cmp.
local cmp = require 'cmp'
local lspkind = require 'lspkind'
lspkind.init({
	mode = 'symbol'
})
require("nvim-autopairs").setup {}
local cmp_autopairs = require('nvim-autopairs.completion.cmp')


cmp.setup({
	snippet = {
		-- REQUIRED - you must specify a snippet engine
		expand = function(args)
			--vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
			require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
		end,
	},
	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},
	mapping = cmp.mapping.preset.insert({
		['<C-b>'] = cmp.mapping.scroll_docs(-4),
		['<C-f>'] = cmp.mapping.scroll_docs(4),
		['<C-j>'] = cmp.mapping.select_next_item(),
		['<C-k>'] = cmp.mapping.select_prev_item(),
		['<C-Space>'] = cmp.mapping.complete(),
		['<C-e>'] = cmp.mapping.abort(),
		['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
	}),

	sources = cmp.config.sources({
		{ name = 'nvim_lua' },
		{ name = 'nvim_lsp' },
		{ name = 'luasnip' }, -- For luasnip users.
	}, {
		{ name = 'buffer' },
	}),
	formatting = {
		format = lspkind.cmp_format {
			with_text = true,
			menu = {
				buffer = '[buf]',
				nvim_lsp = '[LSP]',
				nvim_lua = '[api]',
				path = '[path]',
				luasnip = '[snip]',
			}
		}
	},
	experimental = {
		ghost_text = true
	},
})

cmp.event:on(
	'confirm_done',
	cmp_autopairs.on_confirm_done()
)

--[[
-- Set configuration for specific filetype.
cmp.setup.filetype('gitcommit', {
  sources = cmp.config.sources({
    { name = 'cmp_git' }, -- You can specify the `cmp_git` source if you were installed it.
  }, {
    { name = 'buffer' },
  })
})
]] --

-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline({ '/', '?' }, {
	mapping = cmp.mapping.preset.cmdline(),
	sources = {
		{ name = 'buffer' }
	}
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(':', {
	mapping = cmp.mapping.preset.cmdline(),
	sources = cmp.config.sources({
		{ name = 'path' }
	}, {
		{ name = 'cmdline' }
	})
})

-- Turn on lsp status information
require('fidget').setup()

