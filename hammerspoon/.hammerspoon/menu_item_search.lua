local helpers = require("helpers")

local _chooser = nil

-- AXChildren is always {[1] = actual_items_array}, so we unwrap one level
local function subItems(item)
  return item.AXChildren and item.AXChildren[1]
end

local function flattenMenuItems(items, path, result)
  path   = path   or {}
  result = result or {}
  for _, item in ipairs(items) do
    local title = item.AXTitle
    local children = subItems(item)
    if not title or title == "-" or title == "" or item.AXEnabled == false then
      -- skip separators, unnamed wrappers, and disabled items
    else
      local itemPath = {}
      for _, p in ipairs(path) do table.insert(itemPath, p) end
      table.insert(itemPath, title)
      if children then
        flattenMenuItems(children, itemPath, result)
      else
        table.insert(result, {
          text       = table.concat(itemPath, " › "),
          subText    = "",
          searchText = table.concat(itemPath, " "),
          path       = itemPath,
        })
      end
    end
  end
  return result
end

local function openChooser(app, choices)
  _chooser = hs.chooser.new(function(choice)
    _chooser = nil
    if not choice then return end
    hs.timer.doAfter(0.05, function()
      app:selectMenuItem(choice.path)
    end)
  end)

  _chooser:choices(choices)
  _chooser:queryChangedCallback(helpers.queryChangedCallback(_chooser, choices, "searchText"))
  _chooser:searchSubText(true)
  _chooser:placeholderText("Search menu items…")

  local escHotkey = hs.hotkey.new({}, "escape", function()
    if _chooser then
      _chooser:cancel()
      _chooser = nil
    end
  end)

  _chooser:showCallback(function() escHotkey:enable() end)
  _chooser:hideCallback(function()
    escHotkey:disable()
    _chooser = nil
  end)

  _chooser:show()
end

local function showMenuItemSearch()
  local app = hs.application.frontmostApplication()
  if not app then
    hs.alert.show("No frontmost application")
    return
  end

  -- Use async callback form — the sync version times out on Chrome and similar apps
  app:getMenuItems(function(rawItems)
    if not rawItems then
      hs.alert.show("getMenuItems returned nil for " .. app:name())
      return
    end
    local choices = flattenMenuItems(rawItems)
    if #choices == 0 then
      hs.alert.show("No menu items found for " .. app:name())
      return
    end
    openChooser(app, choices)
  end)
end

hs.hotkey.bind({ "ctrl", "cmd" }, "m", function()
  if _chooser and _chooser:isVisible() then
    _chooser:cancel()
    _chooser = nil
  else
    showMenuItemSearch()
  end
end)
