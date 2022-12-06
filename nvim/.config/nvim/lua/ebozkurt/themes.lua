local selected_theme = 'rose-pine-moon-dark'

-- default is also gruvbox
-- gruvbox
vim.opt.background = 'dark'
vim.cmd [[ colorscheme gruvbox ]]

-- nord
-- vim.cmd [[ colorscheme nord ]]

-- tokyonight
-- vim.cmd[[colorscheme tokyonight]]
-- vim.cmd[[colorscheme tokyonight-moon]]

-- vim.g.catppuccin_flavour = "macchiato" -- latte, frappe, macchiato, mocha
-- require("catppuccin").setup()
-- vim.api.nvim_command "colorscheme catppuccin"

if selected_theme == 'mellow' then
	vim.cmd [[colorscheme mellow]]
elseif selected_theme == 'rose-pine-moon-dark' then
	require('rose-pine').setup({
		dark_variant = 'moon',
	})
	vim.cmd('colorscheme rose-pine')
elseif selected_theme == 'rose-pine-dawn-light' then
	vim.opt.background = 'light'
	require('rose-pine').setup({
		dark_variant = 'dawn',
	})
	vim.cmd('colorscheme rose-pine')
elseif selected_theme == 'gruvbox-dark' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme gruvbox ]]
elseif selected_theme == 'gruvbox-light' then
	vim.opt.background = 'light'
	vim.cmd [[ colorscheme gruvbox ]]
elseif selected_theme == 'ayu-dark' then
	vim.cmd [[ 
	let ayucolor="dark"  " for light version of theme
	colorscheme ayu
	]]
	vim.cmd [[ colorscheme ayu ]]
elseif selected_theme == 'ayu-light' then
	vim.cmd [[ 
	let ayucolor="light"  " for light version of theme
	colorscheme ayu
	]]
elseif selected_theme == 'everforest-dark' then
	vim.opt.background = 'dark'
	vim.g.everforest_background = 'hard'
	vim.cmd [[ colorscheme everforest ]]
elseif selected_theme == 'oxocarbon' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme oxocarbon-lua ]]
elseif selected_theme == 'tokyonight-storm' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme tokyonight-storm ]]
elseif selected_theme == 'oh-lucy' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme oh-lucy ]]
elseif selected_theme == 'oh-lucy-evening' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme oh-lucy-evening ]]
elseif selected_theme == 'nord' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme nord ]]
elseif selected_theme == 'nightfox' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme nightfox ]]
elseif selected_theme == 'dawnfox' then
	vim.opt.background = 'light'
	vim.cmd [[ colorscheme dawnfox ]]
elseif selected_theme == 'duskfox' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme duskfox ]]
elseif selected_theme == 'terafox' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme terafox ]]
elseif selected_theme == 'carbonfox' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme carbonfox ]]
end
