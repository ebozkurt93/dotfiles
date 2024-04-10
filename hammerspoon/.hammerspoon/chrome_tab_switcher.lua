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
                    windowIndex: windowIndex + 1, // JavaScript is 0-indexed, AppleScript is 1-indexed
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

    -- Creating chooser entries with tab titles and their window/tab indices
    local choices = hs.fnutils.imap(tabsInfo, function(tabInfo)
        return {
            text = tabInfo.title,
            subText = "Window: " .. tabInfo.windowIndex .. " | Tab: " .. tabInfo.tabIndex,
            windowIndex = tabInfo.windowIndex,
            tabIndex = tabInfo.tabIndex
        }
    end)

    local chooser = hs.chooser.new(function(choice)
        if not choice then return end
        -- This is sometimes needed especially when there are several windows open
        hs.application.launchOrFocus("Google Chrome")
        -- Switch to the selected tab and focus on the window
        local switchScript = string.format([[
            var chrome = Application('Google Chrome');
            var window = chrome.windows()[%d - 1]; // Adjusting index back to 0-based
            window.activeTabIndex = %d;
            window.index = 1; // Make it the frontmost window
            chrome.activate(); // Bring Chrome to the front
        ]], choice.windowIndex, choice.tabIndex)

        hs.osascript.javascript(switchScript)
    end)

    chooser:choices(choices)
    chooser:show()
end)
