local selected_theme = 'nordic'

-- default is also gruvbox
-- gruvbox
vim.opt.background = 'dark'
vim.cmd [[ colorscheme gruvbox ]]

-- nord
-- vim.cmd [[ colorscheme nord ]]

-- tokyonight
-- vim.cmd[[colorscheme tokyonight]]
-- vim.cmd[[colorscheme tokyonight-moon]]

local function reloadPackages(pattern)
	for name, _ in pairs(package.loaded) do
		if name:match(pattern) then
			package.loaded[name] = nil
		end
	end
end

if selected_theme == 'mellow' then
	local variants = require("mellow.colors")
	local cfg = require("mellow.config").config
	local c = variants[cfg.variant]
	vim.g.mellow_highlight_overrides = {
		["NeogitDiffAddHighlight"] = { bg = c.bright_green, fg = cfg.transparent and c.none or c.bg },
		["NeogitDiffDeleteHighlight"] = { bg = c.bright_red, fg = cfg.transparent and c.none or c.bg },
		["NeogitDiffAdd"] = { bg = c.green, fg = cfg.transparent and c.none or c.bg },
		["NeogitDiffDelete"] = { bg = c.red, fg = cfg.transparent and c.none or c.bg },
	}
	reloadPackages('^mellow')
	vim.cmd [[colorscheme mellow]]
elseif selected_theme == 'rose-pine' then
	require('rose-pine').setup({
		dark_variant = 'main',
	})
	vim.cmd('colorscheme rose-pine')
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
elseif selected_theme == 'everforest-light' then
	vim.opt.background = 'light'
	vim.g.everforest_background = 'medium'
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
elseif selected_theme == 'melange-dark' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme melange ]]
elseif selected_theme == 'melange-light' then
	vim.opt.background = 'light'
	vim.cmd [[ colorscheme melange ]]
elseif selected_theme == 'kanagawa' then
	vim.opt.background = 'dark'
	require('kanagawa').setup({ background = { dark = "wave" } })
	vim.cmd [[ colorscheme kanagawa ]]
elseif selected_theme == 'kanagawa-dragon' then
	vim.opt.background = 'dark'
	require('kanagawa').setup({ background = { dark = "dragon" } })
	vim.cmd [[ colorscheme kanagawa-dragon ]]
elseif selected_theme == 'kanagawa-lotus' then
	vim.opt.background = 'light'
	vim.cmd [[ colorscheme kanagawa-lotus ]]
elseif selected_theme == 'catppuccin-latte' then
	vim.cmd [[ colorscheme catppuccin-latte ]]
elseif selected_theme == 'catppuccin-frappe' then
	vim.cmd [[ colorscheme catppuccin-frappe ]]
elseif selected_theme == 'catppuccin-mocha' then
	vim.cmd [[ colorscheme catppuccin-mocha ]]
elseif selected_theme == 'catppuccin-macchiato' then
	vim.cmd [[ colorscheme catppuccin-macchiato ]]
elseif selected_theme == 'night-owl' then
	vim.cmd [[ colorscheme night-owl ]]
elseif selected_theme == 'nordic' then
	vim.cmd [[ colorscheme nordic ]]
elseif selected_theme == 'poimandres' then
	vim.cmd [[ colorscheme poimandres ]]
elseif selected_theme == 'moonbow' then
	vim.cmd [[ colorscheme moonbow ]]
elseif selected_theme == 'github-light' then
	vim.cmd [[ colorscheme github_light ]]
elseif selected_theme == 'github-dark' then
	vim.cmd [[ colorscheme github_dark ]]
elseif selected_theme == 'caret-dark' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme caret ]]
elseif selected_theme == 'caret-light' then
	vim.opt.background = 'light'
	vim.cmd [[ colorscheme caret ]]
elseif selected_theme == 'miasma' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme miasma ]]
elseif selected_theme == 'monet-dark' then
	vim.opt.background = 'dark'
	reloadPackages('^monet')
	require("monet").setup {
		dark_mode = true,
	}
	vim.cmd [[ colorscheme monet ]]
elseif selected_theme == 'monet-light' then
	vim.opt.background = 'light'
	reloadPackages('^monet')
	require("monet").setup {
		dark_mode = false,
	}
	vim.cmd [[ colorscheme monet ]]
elseif selected_theme == 'neofusion' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme neofusion ]]
elseif selected_theme == 'seoul256-dark' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme seoul256 ]]
elseif selected_theme == 'seoul256-light' then
	vim.opt.background = 'light'
	vim.cmd [[ colorscheme seoul256-light ]]
elseif selected_theme == 'zenbones-light' then
	vim.opt.background = 'light'
	vim.cmd [[ colorscheme zenbones ]]
elseif selected_theme == 'zenbones-dark' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme zenbones ]]
elseif selected_theme == 'neobones-light' then
	vim.opt.background = 'light'
	vim.cmd [[ colorscheme neobones ]]
elseif selected_theme == 'neobones-dark' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme neobones ]]
elseif selected_theme == 'kanso-zen' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme kanso-zen ]]
elseif selected_theme == 'kanso-ink' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme kanso-ink ]]
elseif selected_theme == 'kanso-pearl' then
	vim.opt.background = 'light'
	vim.cmd [[ colorscheme kanso-pearl ]]
elseif selected_theme == 'teide-darker' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme teide-darker ]]
elseif selected_theme == 'teide-dark' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme teide-dark ]]
elseif selected_theme == 'teide-dimmed' then
	vim.opt.background = 'dark'
	vim.cmd [[ colorscheme teide-dimmed ]]
elseif selected_theme == 'teide-light' then
	vim.opt.background = 'light'
	vim.cmd [[ colorscheme teide-light ]]
end
