-- Set up lspconfig.
local capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())
--local bufopts = { noremap = true, silent = true, buffer = 0 }
local my_on_attach = function ()
  vim.api.nvim_exec_autocmds('User', {pattern = 'LspAttached'})
end

-- go install golang.org/x/tools/gopls@latest
require'lspconfig'.gopls.setup{
  capabilities = capabilities,
  on_attach = my_on_attach,
}

-- local util = require('lspconfig/util')
-- local path = util.path
local path = require('lspconfig/util').path

local function get_python_path(workspace)
  -- Use activated virtualenv.
  if vim.env.VIRTUAL_ENV then
    return path.join(vim.env.VIRTUAL_ENV, 'bin', 'python')
  end

--  local default_pyenv_path = vim.fn.system('pyenv which python')
--  local current_pyenv_path = vim.fn.system(workspace .. 'cd %s && pyenv which python')
--  if default_pyenv_path ~= current_pyenv_path then
--	  return path.join(current_pyenv_path, 'bin', 'python')
--  end

--  -- try to find pipenv environment
--  local ppath = vim.fn.system('pipenv --venv | head -n 1 | xargs echo'):gsub("^%s*(.-)%s*$", "%1")
--  if string.find(ppath, '.local/share') then
--	  return path.join(ppath, 'bin', 'python')
--  end

  -- Find and use virtualenv from pipenv in workspace directory.
  local match = vim.fn.glob(path.join(workspace, 'Pipfile'))
  if match ~= '' then
    local venv = vim.fn.trim(vim.fn.system('PIPENV_PIPFILE=' .. match .. ' pipenv --venv'))
    return path.join(venv, 'bin', 'python')
  end

  -- Find and use virtualenv in workspace directory.
  for _, pattern in ipairs({'*', '.*'}) do
    local match = vim.fn.glob(path.join(workspace, pattern, 'pyvenv.cfg'))
    if match ~= '' then
      return path.join(path.dirname(match), 'bin', 'python')
    end
  end

  -- Fallback to system Python.
  return exepath('python3') or exepath('python') or 'python'
end


-- npm install -g pyright
require'lspconfig'.pyright.setup{
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
    config.settings.python.pythonPath = get_python_path(config.root_dir)

  end,
  on_attach = my_on_attach,
}

-- brew install lua-language-server
require'lspconfig'.sumneko_lua.setup {
  cmd = {"lua-language-server"},
  capabilities = capabilities,
  on_attach = my_on_attach,
}


-- Set up nvim-cmp.
local cmp = require'cmp'

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
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'luasnip' }, -- For luasnip users.
  }, {
    { name = 'buffer' },
  })
})

--[[
-- Set configuration for specific filetype.
cmp.setup.filetype('gitcommit', {
  sources = cmp.config.sources({
    { name = 'cmp_git' }, -- You can specify the `cmp_git` source if you were installed it.
  }, {
    { name = 'buffer' },
  })
})
]]--

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


