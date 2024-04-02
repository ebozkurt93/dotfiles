local globals = require("globals")
local function browser(browserName)
  local function open()
    hs.application.launchOrFocus(browserName)
  end
  local function jump(url)
    local script = ([[(function() {
      var browser = Application('%s');
      browser.activate();

      for (win of browser.windows()) {
        var tabIndex =
          win.tabs().findIndex(tab => tab.url().match(/%s/));

        if (tabIndex != -1) {
          win.activeTabIndex = (tabIndex + 1);
          win.index = 1;
        }
      }
    })();
  ]]):format(browserName, url)
    hs.osascript.javascript(script)
  end
  return { open = open, jump = jump }
end

hs.hotkey.bind(globals.hyper, "l", function()
  local currentWindow = hs.window.focusedWindow()
  local chrome = browser("Google Chrome")
  chrome.jump("meet.google.com")
  hs.timer.doAfter(1, function()
    local newWindow = hs.window.focusedWindow()
    if string.match(newWindow:title(), "Meet - ") then
      hs.eventtap.keyStroke({ "cmd" }, "D")
      currentWindow:focus()
    end
  end)
end)
