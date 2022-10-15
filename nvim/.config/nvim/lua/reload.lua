function _G.ReloadConfig()
  for name,_ in pairs(package.loaded) do
	package.loaded[name] = nil
  end

  dofile(vim.env.MYVIMRC)
  vim.notify("Nvim configuration reloaded!", vim.log.levels.INFO)
end
