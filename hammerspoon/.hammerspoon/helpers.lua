local fzy = require('fzy')

P = function(v)
  print(hs.inspect.inspect(v))
  return v
end

local function getTimestamp()
  return os.date("%Y-%m-%d %H:%M:%S") -- YYYY-MM-DD HH:MM:SS
end

local function writeTextToFile(path, text)
  local file = io.open(path, "a")
  if file then
    file:write(getTimestamp() .. " - " .. text .. "\n")
    file:close()
  else
    hs.alert("Failed to open file.")
  end
end

DebugLog = function(value)
  local path = os.getenv("HOME") .. "/hs-debug.txt"
  if (type(value) == "table") then
    value = hs.inspect.inspect(value)
  end
  writeTextToFile(path, tostring(value))
  return value
end

M = {}

function M.escape_magic(s)
  return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1"))
end

function M.safeRequire(moduleName, fieldPath, defaultValue)
  local ok, module = pcall(require, moduleName)
  if not ok then return nil, defaultValue end

  local field = module
  for _, key in ipairs(fieldPath) do
    field = field[key]
    if field == nil then return module, defaultValue end
  end

  return module, field
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

function M.mergeTables(...)
  local mergedTable = {}
  for _, array in ipairs({ ... }) do
    for _, value in ipairs(array) do
      table.insert(mergedTable, value)
    end
  end
  return mergedTable
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

-- Single shared app watcher that dispatches to a per-app handler registry,
-- replacing the previous pattern of one watcher per hotkeyScopedToApp call.
local _appHandlers = {}
_G.helpers_sharedAppWatcher = hs.application.watcher.new(function(appName_, eventType, _)
  local handlers = _appHandlers[appName_]
  if handlers then
    local callbacks = handlers[eventType]
    if callbacks then
      for _, cb in ipairs(callbacks) do cb() end
    end
  end
end)
_G.helpers_sharedAppWatcher:start()

local function registerAppHandler(appName, eventType, callback)
  if not _appHandlers[appName] then _appHandlers[appName] = {} end
  if not _appHandlers[appName][eventType] then _appHandlers[appName][eventType] = {} end
  table.insert(_appHandlers[appName][eventType], callback)
end

function M.hotkeyScopedToApp(mods, key, appName, func)
  local hotkey = hs.hotkey.new(mods, key, function()
    local app = hs.application.frontmostApplication()
    if app and app:name() == appName then
      func(app)
    end
  end)

  registerAppHandler(appName, hs.application.watcher.activated, function() hotkey:enable() end)
  registerAppHandler(appName, hs.application.watcher.deactivated, function() hotkey:disable() end)
end

function M.hotkeyExcludingApp(mods, key, appName, func)
  local hotkey = hs.hotkey.new(mods, key, func)

  registerAppHandler(appName, hs.application.watcher.activated, function() hotkey:disable() end)
  registerAppHandler(appName, hs.application.watcher.deactivated, function() hotkey:enable() end)
end

-- Shared keyDown dispatcher — one eventtap for all keyDown handlers in this config.
-- Returns a handle with :start()/:stop() to pause/resume a specific handler.
local _keyDownHandlers = {}
_G.helpers_sharedKeyDownTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  for _, entry in ipairs(_keyDownHandlers) do
    if entry.enabled and entry.fn(event) then
      return true
    end
  end
  return false
end)
_G.helpers_sharedKeyDownTap:start()

local function registerKeyDownHandler(fn)
  local entry = { fn = fn, enabled = true }
  table.insert(_keyDownHandlers, entry)
  return {
    start = function() entry.enabled = true end,
    stop  = function() entry.enabled = false end,
  }
end

M.registerKeyDownHandler = registerKeyDownHandler

function M.isCurrentTabUrlStartingWith(startsWith)
  local _, currentUrl =
    hs.osascript.applescript('tell application "Google Chrome" to return URL of active tab of front window')

  return currentUrl:sub(1, #startsWith) == startsWith
end

-- For these to work executing javascript from applescript must be enabled
-- View > Developer > Allow JavaScript from Apple Events
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

  local status, _, output = hs.osascript.javascript(script:format(jsScript))
  if (status == false) then
    P(output)
  end
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
  local currentFrontmost = hs.application.frontmostApplication()
  local appActive = currentFrontmost and currentFrontmost:title() == app

  registerAppHandler(app, hs.application.watcher.activated, function()
    appActive = true
    keystrokeBuffer = ""
  end)
  registerAppHandler(app, hs.application.watcher.deactivated, function()
    appActive = false
    keystrokeBuffer = ""
  end)

  local handle = registerKeyDownHandler(function(event)
    if not appActive then return false end

    local character = event:getCharacters()
    if not character or character == "" then return false end

    keystrokeBuffer = keystrokeBuffer .. character
    if #keystrokeBuffer > #target then
      keystrokeBuffer = keystrokeBuffer:sub(-#target)
    end

    if keystrokeBuffer == target then
      keystrokeBuffer = ""
      hs.timer.doAfter(0, func)
    end

    return false
  end)

  return handle, keystrokeBuffer
end

function M.isCurrentWindowInFullScreen()
  local focusedWindow = hs.window.focusedWindow()
  if focusedWindow then
    return focusedWindow:isFullScreen()
  end
  return false
end

function M.runShellCommandInBackground(command)
  local shell = "/bin/bash"
  local arguments = { "-c", command }
  local task = hs.task.new(shell, nil, arguments)
  task:start()
end

function M.debounce(func, delay)
  local timer = nil
  return function(...)
    local args = { ... }
    if timer then timer:stop() end
    timer = hs.timer.doAfter(delay, function()
      func(table.unpack(args))
    end)
  end
end

local function chooserFuzzyFilter(chooser, choices, key, query)
  if query:len() == 0 then
    chooser:choices(choices)
    return
  end
  local filtered = fzy.filter_table(query, choices, key)
  local results = {}
  for _, item in ipairs(filtered) do
    table.insert(results, item.item)
  end
  chooser:choices(results)
end

function M.queryChangedCallback(chooser, choices, key)
  key = key or 'text'
  return function(query)
    chooserFuzzyFilter(chooser, choices, key, query)
  end
end

-- This attempts to speed up/fix slowness in hs.window.filter
-- https://github.com/Hammerspoon/hammerspoon/issues/2943#issuecomment-2105644391
local function _wf_ignoreWebContent()
    for _, app in pairs(hs.application.runningApplications()) do
        local name = app:name()
        if name and (name:match(" Web Content$") or app:bundleID() == "com.apple.WebKit.WebContent") then
            hs.window.filter.ignoreAlways[name] = true
        end
    end
end
_G.window_filter_ignore_web_content_timer = hs.timer.doEvery(15, _wf_ignoreWebContent)
_wf_ignoreWebContent()

return M
