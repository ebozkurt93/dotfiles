local helpers = require('helpers')

hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "T", function()
  local result = helpers.sendBridgeCommand({ type = "getTabs" }, true) or ""
  local data = hs.json.decode(result)
  local tabsInfo = data and data.tabs or nil

  if not tabsInfo then
    hs.alert.show("Failed to get tabs from Firefox")
    return
  end

  local choices = hs.fnutils.imap(tabsInfo, function(tab)
    return {
      text       = tab.title ~= "" and tab.title or tab.url,
      subText    = " Window: " .. tab.windowIndex .. " | Tab: " .. tab.tabIndex .. " | " .. tab.url,
      searchText = tab.title .. ' ' .. tab.url,
      windowIndex = tab.windowIndex,
      tabIndex    = tab.tabIndex,
      tabId       = tab.tabId,
      windowId    = tab.windowId,
    }
  end)

  local chooser = hs.chooser.new(function(choice)
    if not choice then return end
    hs.application.launchOrFocus("Firefox Developer Edition")
    helpers.sendBridgeCommand({ type = "switch", tabId = choice.tabId, windowId = choice.windowId })
  end)

  chooser:choices(choices)
  chooser:queryChangedCallback(helpers.queryChangedCallback(chooser, choices, 'searchText'))
  chooser:show()
end)
