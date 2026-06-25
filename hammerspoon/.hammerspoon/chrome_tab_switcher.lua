local helpers = require('helpers')

hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "T", function()
  local chrome = hs.application.find("Google Chrome")
  if not chrome then
    hs.alert.show("Chrome not found")
    return
  end

  local script = [[
    var chrome = Application('Google Chrome');
    var tabsInfo = [];
    chrome.windows().forEach(function(window, windowIndex) {
        window.tabs().forEach(function(tab, tabIndex) {
            tabsInfo.push({
                title: tab.title(),
                url: tab.url(),
                windowIndex: windowIndex + 1,
                tabIndex: tabIndex + 1
            });
        });
    });
    tabsInfo;
  ]]

  local ok, tabsInfo = hs.osascript.javascript(script)
  if not ok then
    hs.alert.show("Failed to get tabs from Chrome")
    return
  end

  local choices = hs.fnutils.imap(tabsInfo, function(tab)
    return {
      text       = tab.title ~= "" and tab.title or tab.url,
      subText    = " Window: " .. tab.windowIndex .. " | Tab: " .. tab.tabIndex .. " | " .. tab.url,
      searchText = tab.title .. ' ' .. tab.url,
      windowIndex = tab.windowIndex,
      tabIndex    = tab.tabIndex,
    }
  end)

  local chooser = hs.chooser.new(function(choice)
    if not choice then return end
    hs.application.launchOrFocus("Google Chrome")
    hs.osascript.javascript(string.format([[
      var chrome = Application('Google Chrome');
      var window = chrome.windows()[%d - 1];
      window.activeTabIndex = %d;
      window.index = 1;
      chrome.activate();
    ]], choice.windowIndex, choice.tabIndex))
  end)

  chooser:choices(choices)
  chooser:queryChangedCallback(helpers.queryChangedCallback(chooser, choices, 'searchText'))
  chooser:show()
end)
