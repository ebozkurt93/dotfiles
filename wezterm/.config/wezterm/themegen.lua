local M = {}

local kitty_theme_path = os.getenv("HOME") .. "/.config/kitty/current-theme.conf"

-- Function to parse the Kitty theme .conf file
local function parse_kitty_theme()
  local colors = {}
  local file = io.open(kitty_theme_path, "r")

  if file then
    for line in file:lines() do
      -- Match key-value pairs (e.g., background #1e1e2e)
      local key, value = line:match("^(%w+)%s+(#%x+)")
      if key and value then
        colors[key] = value
      end
    end
    file:close()
  end

  return colors
end

local kitty_colors = parse_kitty_theme()

-- Function to generate WezTerm-compatible color table
function M.generate_wezterm_colors()
  return {
    foreground = kitty_colors.foreground or "#ffffff",
    background = kitty_colors.background or "#000000",
    cursor_bg = kitty_colors.cursor or "#ffffff",
    cursor_border = kitty_colors.cursor or "#ffffff",
    cursor_fg = kitty_colors.foreground or "#ffffff",
    selection_bg = kitty_colors.selection_background or "#444444",
    selection_fg = kitty_colors.selection_foreground or "#ffffff",
    ansi = {
      kitty_colors.color0 or "#000000",
      kitty_colors.color1 or "#ff5555",
      kitty_colors.color2 or "#50fa7b",
      kitty_colors.color3 or "#f1fa8c",
      kitty_colors.color4 or "#bd93f9",
      kitty_colors.color5 or "#ff79c6",
      kitty_colors.color6 or "#8be9fd",
      kitty_colors.color7 or "#bbbbbb"
    },
    brights = {
      kitty_colors.color8 or "#44475a",
      kitty_colors.color9 or "#ff6e6e",
      kitty_colors.color10 or "#69ff94",
      kitty_colors.color11 or "#ffffa5",
      kitty_colors.color12 or "#d6acff",
      kitty_colors.color13 or "#ff92df",
      kitty_colors.color14 or "#a4ffff",
      kitty_colors.color15 or "#ffffff"
    },
  }
end


return M
