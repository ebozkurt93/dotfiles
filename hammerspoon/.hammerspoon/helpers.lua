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
  if M.isModuleAvailable(name) then
    return require(name)
  end
  return {}
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
