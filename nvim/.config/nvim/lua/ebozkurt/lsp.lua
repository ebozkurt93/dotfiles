-- Set up mason
require("mason").setup()
require("mason-lspconfig").setup({
  -- some of the commented out in the list below should be installed, but mason only supports installing lsp's by default
  ensure_installed = {
    "cssls",
    -- "stylua",
    "gopls",
    -- "staticcheck", -- used in golang
    -- "prettier",
  },
})

-- Set up lspconfig.
local capabilities = require("blink.cmp").get_lsp_capabilities()
--local bufopts = { noremap = true, silent = true, buffer = 0 }
local my_on_attach = function(client, bufnr)
	if vim.lsp.inlay_hint then
		vim.lsp.inlay_hint.enable(false) -- disable by default
	end
	vim.api.nvim_exec_autocmds("User", { pattern = "LspAttached" })
end
require("mason-lspconfig").setup_handlers({
	-- The first entry (without a key) will be the default handler
	-- and will be called for each installed server that doesn't have
	-- a dedicated handler.
	function(server_name) -- default handler (optional)
		local custom_configured_servers = { "tsserver", "gopls" }
		if vim.tbl_contains(custom_configured_servers, server_name) then
			return
		end
		require("lspconfig")[server_name].setup({
			capabilities = capabilities,
			on_attach = my_on_attach,
		})
	end,
	-- Next, you can provide a dedicated handler for specific servers.
	-- For example, a handler override for the `rust_analyzer`:
	-- ["rust_analyzer"] = function()
	-- 	require("rust-tools").setup {}
	-- end
})

require("lspconfig").ts_ls.setup({
	capabilities = capabilities,
	on_attach = function(client, bufnr)
		my_on_attach(client, bufnr)
		-- disable formatter for tsserver, since prettier is already doing it
		client.server_capabilities.documentFormattingProvider = false
		client.server_capabilities.documentRangeFormattingProvider = false
	end,
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "typescript.tsx" },
	root_dir = function()
		return vim.loop.cwd()
	end,
	settings = {
    javascript = {
      inlayHints = {
        includeInlayEnumMemberValueHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayParameterNameHints = "all", -- 'none' | 'literals' | 'all';
        includeInlayParameterNameHintsWhenArgumentMatchesName = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayVariableTypeHints = true,
      },
    },
    typescript = {
      inlayHints = {
        includeInlayEnumMemberValueHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayParameterNameHints = "all", -- 'none' | 'literals' | 'all';
        includeInlayParameterNameHintsWhenArgumentMatchesName = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayVariableTypeHints = true,
      },
    },
  },
})
-- go install golang.org/x/tools/gopls@latest
require("lspconfig").gopls.setup({
	capabilities = capabilities,
	on_attach = my_on_attach,
	settings = {
		gopls = { hints = {
			rangeVariableTypes = true,
			parameterNames = true,
			constantValues = true,
			assignVariableTypes = true,
			compositeLiteralFields = true,
			compositeLiteralTypes = true,
			functionTypeParameters = true,
		} },
	}
})

require("lspconfig").nil_ls.setup({
   settings = {
      ['nil'] = {
         formatting = {
            command = { "alejandra" },
         },
      },
   },
})
require("lspconfig").nixd.setup({})

-- local util = require('lspconfig/util')
-- local path = util.path
local path = require("lspconfig/util").path

-- npm install -g pyright
require("lspconfig").pyright.setup({
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
		config.settings.python.pythonPath = require("ebozkurt.helpers").get_python_path(config.root_dir)
	end,
	on_attach = my_on_attach,
})

-- -- pip install python-lsp-server
-- require 'lspconfig'.pylsp.setup {
-- 	capabilities = capabilities,
-- 	before_init = function(_, config)
-- 		config.settings.python.pythonPath = require('ebozkurt.helpers').get_python_path(config.root_dir)
-- 	end,
-- 	on_attach = my_on_attach,
-- }

-- brew install lua-language-server
require("lspconfig").lua_ls.setup({
	cmd = { "lua-language-server" },
	capabilities = capabilities,
	on_attach = my_on_attach,
	settings = { Lua = {
		diagnostics = { globals = { "vim", "exepath", "hs" } },
		workspace = { library = {
			string.format('%s/.hammerspoon/Spoons/EmmyLua.spoon/annotations', os.getenv 'HOME'),
		} },
		hint = { enable = true }
	} },
})

-- require'lspconfig'.bashls.setup{}
require'lspconfig'.jsonls.setup{}
-- require'lspconfig'.java_language_server.setup({
-- 	cmd = { "java-language-server" },
-- 	capabilities = capabilities,
-- 	on_attach = my_on_attach,
-- 	-- https://github.com/georgewfraser/java-language-server/issues/267#issuecomment-2002482054
-- 	handlers = {
-- 		['client/registerCapability'] = function(err, result, ctx, config)
-- 			local registration = {
-- 			  registrations = { result },
-- 			}
-- 			return vim.lsp.handlers['client/registerCapability'](err, registration, ctx, config)
-- 		end
--     },
-- })

require'lspconfig'.jdtls.setup({
	capabilities = capabilities,
	on_attach = my_on_attach,
})
require 'lspconfig'.eslint.setup {}

-- Set up blink.cmp.
local blink = require("blink.cmp")
local copilot_ok = pcall(require, "copilot.api")

require("nvim-autopairs").setup({})

local function filter_gitignored(items)
	local cwd = vim.fn.getcwd()
	local git_dir = vim.fs.find(".git", { upward = true, path = cwd })[1]
	if not git_dir then
		return items
	end

	local git_root = vim.fs.dirname(git_dir)
	local relative_paths = {}
	for _, item in ipairs(items) do
		local full_path = item.data and item.data.full_path or nil
		if full_path and vim.startswith(full_path, git_root .. "/") then
			local relative_path = full_path:sub(#git_root + 2)
			relative_paths[#relative_paths + 1] = relative_path
		end
	end

	if #relative_paths == 0 then
		return items
	end

	local input = table.concat(relative_paths, "\n") .. "\n"
	local output = vim.fn.system({ "git", "-C", git_root, "check-ignore", "-z", "--stdin" }, input)
	if vim.v.shell_error ~= 0 or output == "" then
		return items
	end

	local ignored = {}
	for _, path in ipairs(vim.split(output, "\0", { trimempty = true })) do
		ignored[path] = true
	end

	local filtered = {}
	for _, item in ipairs(items) do
		local full_path = item.data and item.data.full_path or nil
		if not full_path or not vim.startswith(full_path, git_root .. "/") then
			filtered[#filtered + 1] = item
		else
			local relative_path = full_path:sub(#git_root + 2)
			if not ignored[relative_path] then
				filtered[#filtered + 1] = item
			end
		end
	end

	return filtered
end

local sources_default = { "snippets", "lsp", "at_path", "path", "buffer" }
local sources_providers = {
	lsp = { async = true, timeout_ms = 200 },
	snippets = { score_offset = 8 },
	-- @path: triggers on "@" (non-word), lists repo/cwd files via git ls-files
	-- (includes untracked) or rg --files fallback, cached per root, hidden files
	-- enabled by default and capped by max_entries.
	at_path = {
		name = "@path",
		module = "ebozkurt.blink_at_path",
		opts = {
			show_hidden_files_by_default = true,
			get_cwd = function()
				return vim.fn.getcwd()
			end,
		},
	},
	path = {
		opts = {
			show_hidden_files_by_default = true,
			get_cwd = function()
				return vim.fn.getcwd()
			end,
		},
		transform_items = function(_, items)
			return filter_gitignored(items)
		end,
	},
	dadbod = { module = "vim_dadbod_completion.blink" },
	obsidian = { name = "obsidian", module = "blink.compat.source" },
	obsidian_new = { name = "obsidian_new", module = "blink.compat.source" },
	obsidian_tags = { name = "obsidian_tags", module = "blink.compat.source" },
}

if copilot_ok then
	table.insert(sources_default, 1, "copilot")
	sources_providers.copilot = {
		name = "copilot",
		module = "blink-cmp-copilot",
		score_offset = 100,
		async = true,
	}
end

blink.setup({
	snippets = { preset = "luasnip" },
	completion = {
		menu = {
			auto_show = true,
			auto_show_delay_ms = 0,
		},
		trigger = {
			show_on_keyword = true,
			show_on_insert = true,
			prefetch_on_insert = true,
		},
	},
	keymap = {
		preset = "none",
		["<C-b>"] = { "scroll_documentation_up", "fallback" },
		["<C-f>"] = { "scroll_documentation_down", "fallback" },
		["<C-j>"] = { "select_next", "fallback" },
		["<C-k>"] = { "select_prev", "fallback" },
		["<Down>"] = { "select_next", "fallback" },
		["<Up>"] = { "select_prev", "fallback" },
		["<C-Space>"] = { "show", "fallback" },
		["<C-e>"] = { "hide", "fallback" },
		["<CR>"] = { "select_and_accept", "fallback" },
	},
	sources = {
		default = sources_default,
		per_filetype = {
			markdown = { inherit_defaults = true, "obsidian", "obsidian_new", "obsidian_tags" },
			sql = { inherit_defaults = true, "dadbod" },
			mysql = { inherit_defaults = true, "dadbod" },
			plsql = { inherit_defaults = true, "dadbod" },
		},
		providers = sources_providers,
	},
	cmdline = {
		keymap = { preset = "cmdline" },
		sources = function()
			local cmd_type = vim.fn.getcmdtype()
			if cmd_type == "/" or cmd_type == "?" then
				return { "buffer" }
			end
			if cmd_type == ":" or cmd_type == "@" then
				return { "path", "cmdline" }
			end
			return {}
		end,
	},
})

-- Turn on lsp status information
-- window/blend 0 is needed for transparency
require("fidget").setup({ window = { blend = 0 } })
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.server_capabilities.semanticTokensProvider then
      client.server_capabilities.semanticTokensProvider = nil
    end
  end,
})
