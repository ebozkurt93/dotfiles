-- Fuzzy Window Switcher

local _fuzzyChoices = nil
local _fuzzyChooser = nil
local _appFilter = nil
local windows = {}

local function resetChooser(keepFilter)
  _fuzzyChooser:cancel()
  _fuzzyChooser = nil
  _fuzzyChoices = nil
  if not keepFilter then
    _appFilter = nil
  end
end

local function fuzzyQuery(s, m)
  local s_len = s:len()
  local m_len = m:len()
  local s_index, m_index = 1, 1
  local match_start = nil

  while s_index <= s_len and m_index <= m_len do
    if s:sub(s_index, s_index) == m:sub(m_index, m_index) then
      match_start = match_start or s_index
      m_index = m_index + 1
    end
    s_index = s_index + 1
  end

  if m_index <= m_len then
    return -1
  end
  local match_end = s_index - 1
  return m_len / (match_end - match_start + 1)
end

local function _fuzzyFilterChoices(query)
  _query = query
  if query:len() == 0 then
    _fuzzyChooser:choices(_fuzzyChoices)
    return
  end
  local pickedChoices = {}
  for i, j in pairs(_fuzzyChoices) do
    -- this is to support queries where app name is given at start or end while query contains partial window title
    local fullText = (j["subText"] .. " " .. j["text"] .. " " .. j["subText"]):lower()
    -- local fullText = (j["text"] .. " " .. j["subText"]):lower()
    local score = fuzzyQuery(fullText, query:lower())
    if score > 0 then
      j["fzf_score"] = score
      table.insert(pickedChoices, j)
    end
  end
  local sort_func = function(a, b)
    return a["fzf_score"] > b["fzf_score"]
  end
  table.sort(pickedChoices, sort_func)
  _fuzzyChooser:choices(pickedChoices)
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
  _fuzzyChooser = nil
end

local function handleEscape()
  if _fuzzyChooser and _fuzzyChooser:isVisible() then
    _fuzzyChooser:cancel()
    _fuzzyChooser = nil
    _fuzzyChoices = nil
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
  resetChooser()
end

-- Register a global hotkey for Escape, but it will only have effect when _fuzzyChooser is visible
local escapeHotkey = hs.hotkey.new({}, "escape", handleEscape)
local closeAppHotkey = hs.hotkey.new({ "cmd" }, "q", handleAppClose)
-- this is defined below due to avoid circular dependencies
local filterWindowHotkey = nil

local function windowFuzzySearch()
  local filter = hs.window.filter.new(true):setOverrideFilter({
    hasTitlebar = true,
    -- allowRoles = "AXStandardWindow"
  })

  windows = filter:getWindows(hs.window.sortByFocusedLast)
  _fuzzyChoices = {}
  for i, w in pairs(windows) do
    local title = w:title()
    local app = w:application():name()
    -- attempted to create a conditional filter earlier, but doesn't
    -- work as expected, therefore this manual filtering here
    -- also lua has no continue statement, therefore the nesting...
    if _appFilter == nil or app == _appFilter then
      local bundleID = w:application():bundleID()
      local icon = hs.image.imageFromAppBundle(bundleID)
      local item = {
        ["text"] = title,
        ["subText"] = app,
        ["image"] = icon,
        ["windowID"] = w:id(),
        ["window"] = w,
        ["app"] = app,
        index = i,
      }
      table.insert(_fuzzyChoices, item)
    end
  end
  _fuzzyChooser = hs.chooser.new(_fuzzyPickWindow):choices(_fuzzyChoices):searchSubText(true)
  _fuzzyChooser:queryChangedCallback(_fuzzyFilterChoices) -- Enable true fuzzy find

  _fuzzyChooser:showCallback(function()
    escapeHotkey:enable()
    closeAppHotkey:enable()
    filterWindowHotkey:enable()
  end)
  _fuzzyChooser:hideCallback(function()
    escapeHotkey:disable()
    closeAppHotkey:disable()
    filterWindowHotkey:disable()
  end)

  _fuzzyChooser:show()
end

hs.hotkey.bind({ "alt" }, "space", function()
  if _fuzzyChooser then
    resetChooser()
  else
    windowFuzzySearch()
  end
end)

-- toggle window filter for selected window's app
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

  resetChooser(true)
  windowFuzzySearch()
end

filterWindowHotkey = hs.hotkey.new({ "cmd" }, "f", handleAppFilter)

return _fuzzyChooser
