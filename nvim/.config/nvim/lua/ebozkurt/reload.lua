function _G.ReloadConfig()
	for name, _ in pairs(package.loaded) do
		if name:match('^ebozkurt') then
			package.loaded[name] = nil
		end
	end

	dofile(vim.env.MYVIMRC)
	vim.api.nvim_exec_autocmds('User', { pattern = 'ReloadConfig' })
	vim.notify("Nvim configuration reloaded!", vim.log.levels.INFO)
end

function _G.ReloadTheme()
	for i = 0, 15 do
		vim.g["terminal_color_" .. i] = nil
	end
	vim.cmd([[ source ~/.config/nvim/lua/ebozkurt/themes.lua ]])
end
