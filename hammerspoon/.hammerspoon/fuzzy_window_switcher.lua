local helpers = require('helpers')

local _fuzzyChoices = nil
local _fuzzyChooser = nil
local _appFilter = nil
local windows = {}

local function updateChooserChoices()
  local filter = hs.window.filter.new(true):setOverrideFilter({
    hasTitlebar = true,
  })

  windows = filter:getWindows(hs.window.sortByFocusedLast)
  _fuzzyChoices = {}
  for i, w in pairs(windows) do
    local title = w:title()
    local app = w:application():name()
    if (title ~= "Chooser" or app ~= "Hammerspoon") and (_appFilter == nil or app == _appFilter) then
      local bundleID = w:application():bundleID()
      local icon = hs.image.imageFromAppBundle(bundleID)
      local item = {
        ["text"] = title,
        ["subText"] = app,
        ["searchText"] = title .. ' ' .. app,
        ["image"] = icon,
        ["windowID"] = w:id(),
        ["window"] = w,
        ["app"] = app,
        index = i,
      }
      table.insert(_fuzzyChoices, item)
    end
  end
end

local function _fuzzyPickWindow(item)
  if item == nil then
    return
  end
  local window = item["window"]
  local app = item["app"]
  -- not exactly this, but fixes issue somehow https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-615535897
  app = hs.application.get(app)
  app:activate()
  hs.timer.doAfter(0.001, function()
    window:focus()
  end)
end

local function handleEscape()
  if _fuzzyChooser and _fuzzyChooser:isVisible() then
    _fuzzyChooser:cancel()
    _fuzzyChooser = nil
  end
end

local function handleAppClose()
  local item = _fuzzyChooser:selectedRowContents()
  if item == nil then
    return
  end
  local app = item["app"]
  app = hs.application.get(app)
  app:kill()
  hs.timer.doAfter(0.2, function()
    updateChooserChoices()
    if _fuzzyChooser then
      _fuzzyChooser:choices(_fuzzyChoices)
    end
  end)
end

-- Register a global hotkey for Escape, but it will only have effect when _fuzzyChooser is visible
local escapeHotkey = hs.hotkey.new({}, "escape", handleEscape)
local closeAppHotkey = hs.hotkey.new({ "cmd" }, "q", handleAppClose)
-- this is defined below due to avoid circular dependencies
local filterWindowHotkey = nil

local function windowFuzzySearch()
  updateChooserChoices()
  _fuzzyChooser = hs.chooser.new(_fuzzyPickWindow):choices(_fuzzyChoices):searchSubText(true)
  _fuzzyChooser:queryChangedCallback(helpers.queryChangedCallback(_fuzzyChooser, _fuzzyChoices, 'searchText'))

  _fuzzyChooser:showCallback(function()
    escapeHotkey:enable()
    closeAppHotkey:enable()
    if filterWindowHotkey then filterWindowHotkey:enable() end
  end)
  _fuzzyChooser:hideCallback(function()
    escapeHotkey:disable()
    closeAppHotkey:disable()
    if filterWindowHotkey then filterWindowHotkey:disable() end
    _fuzzyChooser = nil
  end)

  _fuzzyChooser:show()
end

hs.hotkey.bind({ "alt" }, "space", function()
  if _fuzzyChooser and _fuzzyChooser:isVisible() then
    handleEscape()
  else
    windowFuzzySearch()
  end
end)

local function handleAppFilter()
  if _appFilter then
    _appFilter = nil
  else
    local item = _fuzzyChooser:selectedRowContents()
    if item == nil then
      return
    end
    local app = item["app"]
    _appFilter = app
  end
  updateChooserChoices()
  if _fuzzyChooser then
    _fuzzyChooser:choices(_fuzzyChoices)
  end
end

filterWindowHotkey = hs.hotkey.new({ "cmd" }, "f", handleAppFilter)

return _fuzzyChooser
