hs.loadSpoon("MenubarFlag")

local function hexToHammerspoonColor(hex)
  hex = hex:gsub("#", "")

  local r, g, b = hex:match("(..)(..)(..)")
  r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)

  return { red = r / 255, green = g / 255, blue = b / 255 }
end

spoon.MenubarFlag.colors = {
  Swedish = { hexToHammerspoonColor("#005BAA") },
  ["Turkish Q"] = { hexToHammerspoonColor("#E30A17") },
}

spoon.MenubarFlag:start()
