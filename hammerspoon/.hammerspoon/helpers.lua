P = function(v)
  print(hs.inspect.inspect(v))
  return v
end

M = {}

function M.escape_magic(s)
  return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1"))
end

function M.isModuleAvailable(name)
  if package.loaded[name] then
    return true
  else
    for _, searcher in ipairs(package.searchers or package.loaders) do
      local loader = searcher(name)
      if type(loader) == "function" then
        package.preload[name] = loader
        return true
      end
    end
    return false
  end
end

function M.loadModuleIfAvailable(name)
  local function requiref(m)
    require(m)
  end

  local res = pcall(requiref, name)
  if not res then
    return {}
  end
end

-- merges two or more tables
function M.merge(...)
  local result = {}
  for _, t in ipairs({ ... }) do
    for k, v in pairs(t) do
      result[k] = v
    end
    local mt = getmetatable(t)
    if mt then
      setmetatable(result, mt)
    end
  end
  return result
end

function M.removeKeyFromTableArray(tableArray, keyToRemove)
  local newArray = {}
  for _, item in ipairs(tableArray) do
    local newItem = {}
    for key, value in pairs(item) do
      if key ~= keyToRemove then
        newItem[key] = value
      end
    end
    table.insert(newArray, newItem)
  end
  return newArray
end

function M.findTableArrayItemByField(tableArray, key, value)
  for _, item in ipairs(tableArray) do
    if item[key] == value then
      return item
    end
  end
  return nil
end

function M.hotkeyScopedToApp(mods, key, appName, func)
  local yourHotkey = hs.hotkey.new(mods, key, function()
    local app = hs.application.frontmostApplication()
    if app then
      func(app)
    end
  end)

  local appFilter = hs.window.filter.new(appName)

  appFilter
    :subscribe(hs.window.filter.windowFocused, function()
      yourHotkey:enable()
    end)
    :subscribe(hs.window.filter.windowUnfocused, function()
      yourHotkey:disable()
    end)
end

function M.isCurrentTabUrlStartingWith(startsWith)
  local _, currentUrl =
    hs.osascript.applescript('tell application "Google Chrome" to return URL of active tab of front window')

  return currentUrl:sub(1, #startsWith) == startsWith
end

function M.runJsOnCurrentBrowserTab(jsScript)
  local script = [[
var chrome = Application("Google Chrome");

var command = `
    (function() {
%s
})()
`

chrome.windows[0].activeTab.execute({javascript:command})
]]

  hs.osascript.javascript(script:format(jsScript))
end

function M.runJsOnFirstBrowserTabThatMatchesUrl(urlPattern, jsScript)
  local script = [[

var chrome = Application('Google Chrome');
var windows = chrome.windows();

var pattern = new RegExp('%s');
var foundTabs = [];

var command = `
    (function() {
%s
    })();

`

windows.forEach(function(window) {
    window.tabs().forEach(function(tab) {
        if (pattern.test(tab.url())) {
            foundTabs.push(tab);
        }
    });
});
foundTabs[0].execute({javascript:command})

]]

  hs.osascript.javascript(script:format(urlPattern, jsScript))
end

function M.keystrokesScopedToApp(target, app, func)
  local keystrokeBuffer = ""

  local function handleKeystrokes(event)
    local currentApp = hs.application.frontmostApplication()

    if currentApp:title() == app then
      local character = event:getCharacters()
      keystrokeBuffer = keystrokeBuffer .. character

      if #keystrokeBuffer > #target then
        keystrokeBuffer = keystrokeBuffer:sub(-#target)
      end

      if keystrokeBuffer == target then
        keystrokeBuffer = ""
        func()
      end
    end
  end

  local keystrokeTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, handleKeystrokes)
  keystrokeTap:start()
  return keystrokeTap, keystrokeBuffer
end

function M.hotkeyExcludingApp(mods, key, appName, func)
  local yourHotkey = hs.hotkey.new(mods, key, func)

  local appFilter = hs.window.filter.new()
  appFilter = appFilter:rejectApp(appName)
  P(appFilter)

  appFilter
    :subscribe(hs.window.filter.windowFocused, function()
      yourHotkey:enable()
    end)
    :subscribe(hs.window.filter.windowUnfocused, function()
      yourHotkey:disable()
    end)
end

function M.isCurrentWindowInFullScreen()
  local focusedWindow = hs.window.focusedWindow()
  if focusedWindow then
    return focusedWindow:isFullScreen()
  end
  return false
end

return M
