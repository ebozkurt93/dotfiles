local helpers = require("helpers")
M = {}

function M.restartSystemEvents()
  hs.execute(
    [[
osascript -e 'tell application "Finder" restart'
  ]],
    true
  )
end


function M.isBluetoothOn()
  local output, _success, _exitCode = hs.execute(
    [=[
/opt/homebrew/bin/blueutil -p
  ]=],
    false
  )
  return output == '1'
end

function M.toggleBluetooth(enabled)
  if enabled ~= nil then
    local c = 0
    if enabled then
      c = 1
    end
    hs.execute(string.format("/opt/homebrew/bin/blueutil -p %s", c), true)
  else
    hs.execute(
      [=[
/opt/homebrew/bin/blueutil -p $(( ! $(/opt/homebrew/bin/blueutil -p) ))
  ]=],
      true
    )
  end
end

function M.getBluetoothDevices()
  local output, _success, _exitCode = hs.execute(
    [=[
/opt/homebrew/bin/blueutil --connected | awk '{print $2}' | tr -d ',' | tr '\n' ' ' | xargs
  ]=],
    false
  )
  local result = {}
  for word in output:gmatch("%S+") do
    table.insert(result, word)
  end
  return result
end

function M.connectToBluetoothDevice(address)
  hs.execute(string.format("/opt/homebrew/bin/blueutil --connect '%s'", address), true)
end

function M.clearNotifications()
  local source = [[

function run(input, parameters) {

  const appNames = [];
  const skipAppNames = [];
  const verbose = true;

  const scriptName = "close_notifications_applescript";

  const CLEAR_ALL_ACTION = "Clear All";
  const CLEAR_ALL_ACTION_TOP = "Clear";
  const CLOSE_ACTION = "Close";

  const notNull = (val) => {
    return val !== null && val !== undefined;
  };

  const isNull = (val) => {
    return !notNull(val);
  };

  const notNullOrEmpty = (val) => {
    return notNull(val) && val.length > 0;
  };

  const isNullOrEmpty = (val) => {
    return !notNullOrEmpty(val);
  };

  const isError = (maybeErr) => {
    return notNull(maybeErr) && (maybeErr instanceof Error || maybeErr.message);
  };

  const systemVersion = () => {
    return Application("Finder").version().split(".").map(val => parseInt(val));
  };

  const systemVersionGreaterThanOrEqualTo = (vers) => {
    return systemVersion()[0] >= vers;
  };

  const isBigSurOrGreater = () => {
    return systemVersionGreaterThanOrEqualTo(11);
  };

  const V11_OR_GREATER = isBigSurOrGreater();
  const V12 = systemVersion()[0] === 12;
  const APP_NAME_MATCHER_ROLE = V11_OR_GREATER ? "AXStaticText" : "AXImage";
  const hasAppNames = notNullOrEmpty(appNames);
  const hasSkipAppNames = notNullOrEmpty(skipAppNames);
  const hasAppNameFilters = hasAppNames || hasSkipAppNames;
  const appNameForLog = hasAppNames ? ` [${appNames.join(",")}]` : "";

  const logs = [];
  const log = (message, ...optionalParams) => {
    let message_with_prefix = `${new Date().toISOString().replace("Z", "").replace("T", " ")} [${scriptName}]${appNameForLog} ${message}`;
    console.log(message_with_prefix, optionalParams);
    logs.push(message_with_prefix);
  };

  const logError = (message, ...optionalParams) => {
    if (isError(message)) {
      let err = message;
      message = `${err}${err.stack ? (" " + err.stack) : ""}`;
    }
    log(`ERROR ${message}`, optionalParams);
  };

  const logErrorVerbose = (message, ...optionalParams) => {
    if (verbose) {
      logError(message, optionalParams);
    }
  };

  const logVerbose = (message) => {
    if (verbose) {
      log(message);
    }
  };

  const getLogLines = () => {
    return logs.join("\n");
  };

  const getSystemEvents = () => {
    let systemEvents = Application("System Events");
    systemEvents.includeStandardAdditions = true;
    return systemEvents;
  };

  const getNotificationCenter = () => {
    try {
      return getSystemEvents().processes.byName("NotificationCenter");
    } catch (err) {
      logError("Could not get NotificationCenter");
      throw err;
    }
  };

  const getNotificationCenterGroups = (retryOnError = false) => {
    try {
      let notificationCenter = getNotificationCenter();
      if (notificationCenter.windows.length <= 0) {
        return [];
      }
      if (!V11_OR_GREATER) {
        return notificationCenter.windows();
      }
      if (V12) {
        return notificationCenter.windows[0].uiElements[0].uiElements[0].uiElements();
      }
      return notificationCenter.windows[0].uiElements[0].uiElements[0].uiElements[0].uiElements();
    } catch (err) {
      logError("Could not get NotificationCenter groups");
      if (retryOnError) {
        logError(err);
        log("Retrying getNotificationCenterGroups...");
        return getNotificationCenterGroups(false);
      } else {
        throw err;
      }
    }
  };

  const isClearButton = (description, name) => {
    return description === "button" && name === CLEAR_ALL_ACTION_TOP;
  };

  const matchesAnyAppNames = (value, checkValues) => {
    if (isNullOrEmpty(checkValues)) {
      return false;
    }
    let lowerAppName = value.toLowerCase();
    for (let checkValue of checkValues) {
      if (lowerAppName === checkValue.toLowerCase()) {
        return true;
      }
    }
    return false;
  };

  const matchesAppName = (role, value) => {
    if (role !== APP_NAME_MATCHER_ROLE) {
      return false;
    }
    if (hasAppNames) {
      return matchesAnyAppNames(value, appNames);
    }
    return !matchesAnyAppNames(value, skipAppNames);
  };

  const notificationGroupMatches = (group) => {
    try {
      let description = group.description();
      if (V11_OR_GREATER && isClearButton(description, group.name())) {
        return true;
      }
      if (V11_OR_GREATER && description !== "group") {
        return false;
      }
      if (!V11_OR_GREATER) {
        let matchedAppName = !hasAppNameFilters;
        if (!matchedAppName) {
          for (let elem of group.uiElements()) {
            if (matchesAppName(elem.role(), elem.description())) {
              matchedAppName = true;
              break;
            }
          }
        }
        if (matchedAppName) {
          return notNull(findCloseActionV10(group, -1));
        }
        return false;
      }
      if (!hasAppNameFilters) {
        return true;
      }
      let firstElem = group.uiElements[0];
      return matchesAppName(firstElem.role(), firstElem.value());
    } catch (err) {
      logErrorVerbose(`Caught error while checking window, window is probably closed: ${err}`);
      logErrorVerbose(err);
    }
    return false;
  };

  const findCloseActionV10 = (group, closedCount) => {
    try {
      for (let elem of group.uiElements()) {
        if (elem.role() === "AXButton" && elem.title() === CLOSE_ACTION) {
          return elem.actions["AXPress"];
        }
      }
    } catch (err) {
      logErrorVerbose(`(group_${closedCount}) Caught error while searching for close action, window is probably closed: ${err}`);
      logErrorVerbose(err);
      return null;
    }
    log("No close action found for notification");
    return null;
  };

  const findCloseAction = (group, closedCount) => {
    try {
      if (!V11_OR_GREATER) {
        return findCloseActionV10(group, closedCount);
      }
      let checkForPress = isClearButton(group.description(), group.name());
      let clearAllAction;
      let closeAction;
      for (let action of group.actions()) {
        let description = action.description();
        if (description === CLEAR_ALL_ACTION) {
          clearAllAction = action;
          break;
        } else if (description === CLOSE_ACTION) {
          closeAction = action;
        } else if (checkForPress && description === "press") {
          clearAllAction = action;
          break;
        }
      }
      if (notNull(clearAllAction)) {
        return clearAllAction;
      } else if (notNull(closeAction)) {
        return closeAction;
      }
    } catch (err) {
      logErrorVerbose(`(group_${closedCount}) Caught error while searching for close action, window is probably closed: ${err}`);
      logErrorVerbose(err);
      return null;
    }
    log("No close action found for notification");
    return null;
  };

  const closeNextGroup = (groups, closedCount) => {
    try {
      for (let group of groups) {
        if (notificationGroupMatches(group)) {
          let closeAction = findCloseAction(group, closedCount);

          if (notNull(closeAction)) {
            try {
              closeAction.perform();
              return [true, 1];
            } catch (err) {
              logErrorVerbose(`(group_${closedCount}) Caught error while performing close action, window is probably closed: ${err}`);
              logErrorVerbose(err);
            }
          }
          return [true, 0];
        }
      }
      return false;
    } catch (err) {
      logError("Could not run closeNextGroup");
      throw err;
    }
  };

  try {
    let groupsCount = getNotificationCenterGroups(true).filter(group => notificationGroupMatches(group)).length;

    if (groupsCount > 0) {
      logVerbose(`Closing ${groupsCount}${appNameForLog} notification group${(groupsCount > 1 ? "s" : "")}`);

      let startTime = new Date().getTime();
      let closedCount = 0;
      let maybeMore = true;
      let maxAttempts = 2;
      let attempts = 1;
      while (maybeMore && ((new Date().getTime() - startTime) <= (1000 * 30))) {
        try {
          let closeResult = closeNextGroup(getNotificationCenterGroups(), closedCount);
          maybeMore = closeResult[0];
          if (maybeMore) {
            closedCount = closedCount + closeResult[1];
          }
        } catch (innerErr) {
          if (maybeMore && closedCount === 0 && attempts < maxAttempts) {
            log(`Caught an error before anything closed, trying ${maxAttempts - attempts} more time(s).`)
            attempts++;
          } else {
            throw innerErr;
          }
        }
      }
    } else {
      throw Error(`No${appNameForLog} notifications found...`);
    }
  } catch (err) {
    logError(err);
    logError(err.message);
    getLogLines();
    throw err;
  }

  return getLogLines();
}

]]
  hs.osascript.javascript(source)
end

local function findHiddenWindowIds()
  local allWindows = hs.window.filter
    .new(true)
    :setOverrideFilter({
      allowRoles = "*",
    })
    :getWindows()

  local hiddenWindowIds = {}

  for i, window in ipairs(allWindows) do
    if not window:isVisible() then
      table.insert(hiddenWindowIds, window:id())
    end
  end

  return hiddenWindowIds
end

local function minimizeWindowsWithIds(hiddenWindowIds)
  for i, wId in ipairs(hiddenWindowIds) do
    local window = hs.window.get(wId)
    window:minimize()
  end
end

-- Minimizing previously minimized windows after dock related actions since `killall Dock` unminimizes them
function M.dockClearRecentApps()
  local hiddenWindowIds = findHiddenWindowIds()
  hs.execute(
    [[
#!/bin/sh

defaults delete com.apple.dock recent-apps
killall Dock
]],
    true
  )
  minimizeWindowsWithIds(hiddenWindowIds)
end

function M.dockMovePosition()
  local hiddenWindowIds = findHiddenWindowIds()
  hs.execute(
    [[
#!/bin/sh

app='com.apple.dock'
setting='orientation'

current_setting=`defaults read $app $setting`

if test "$current_setting" = 'left'; then
  new_setting='bottom'
else
  new_setting='left'
fi
defaults write $app $setting $new_setting

defaults read $app $setting

killall Dock

  ]],
    false
  )
  minimizeWindowsWithIds(hiddenWindowIds)
end

function M.toggleGrayscale()
  local commandString = [[
shortcuts run 'Toggle grayscale'
  ]]
  helpers.runShellCommandInBackground(commandString)
end

function M.toggleBrightness()
  hs.execute("~/bin/helpers/toggle-brightness.sh", true)
end

function M.restartBitBar()
  hs.execute([[
ps -ef | grep "BitBar.app" | awk '{print $2}' | xargs kill 2> /dev/null;
  ]])
  hs.timer.doAfter(2, function()
    hs.application.open("BitBar")
  end)
end


function M.isDarkMode()
    local script = 'tell application "System Events"\nreturn dark mode of appearance preferences\nend tell'
    local ok, result = hs.osascript.applescript(script)
    if ok then
        return result
    else
        return false
    end
end

return M
