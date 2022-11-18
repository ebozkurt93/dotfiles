-- Disable virtual_text since it's redundant due to lsp_lines.
vim.diagnostic.config({ virtual_text = false })
require("lsp_lines").setup()
vim.api.nvim_exec_autocmds('User', { pattern = 'lsplines', data = { enabled = true } })
