local notify = require("notify")

notify.setup({
  stages = "fade",
  timeout = 3000,
  render = "wrapped-compact",
  max_width = function()
    return math.min(math.floor(vim.o.columns * 0.6), 80)
  end,
})

vim.notify = notify
