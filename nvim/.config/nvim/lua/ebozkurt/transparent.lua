require("transparent").setup({
  -- not sure if all these groups are really needed
  extra_groups = {
    "NormalFloat",
    "NvimTreeNormal",
    "NvimTreeNormalNC",
    "NvimTreeNormalFloat",
    "NvimTreeEndOfBuffer",
    "BufferLineTabClose",
    "BufferlineBufferSelected",
    "BufferLineFill",
    "BufferLineBackground",
    "BufferLineSeparator",
    "BufferLineIndicatorSelected",

    "IndentBlanklineChar",

    -- make floating windows transparent
    "LspFloatWinNormal",
    "Normal",
    "NormalFloat",
    "FloatBorder",
    "TelescopeNormal",
    "TelescopeBorder",
    "TelescopePromptBorder",
    "SagaBorder",
    "SagaNormal",
  },
  exclude_groups = {
    "StatusLine",
    "StatusLineNC",
  },
})

-- for some reason there are weird issues if transparency is enabled when neovim starts, toggling it back and forth fixes it
vim.defer_fn(function ()
  vim.cmd [[ TransparentToggle ]]
end, 50)

vim.defer_fn(function ()
  vim.cmd [[ TransparentToggle ]]
end, 55)
