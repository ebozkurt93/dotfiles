M = {}
-- M.font_size = 19
M.font = 'JetBrains Mono'
-- M.window_background_opacity = 0.85

-- local notch_enabled = true
-- local slack_padding_enabled = true

local top_padding = (notch_enabled and 36) or (slack_padding_enabled and 7) or 0
local padding = (slack_padding_enabled and 7) or 0
M.window_padding = { left = padding, right = padding, top = top_padding, bottom = padding }
return M
