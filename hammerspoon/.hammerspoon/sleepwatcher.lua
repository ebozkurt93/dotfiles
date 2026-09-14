local helpers = require("helpers")
local macos_helpers = require("macos_helpers")
local kb_battery = require("kb_battery")
local weather = require("weather")
local now_playing = require("now-playing")

local btConnectedDevices = {}
local previousBluetoothStatus = nil
local _, allowedNetworks = helpers.safeRequire("personal", { "privateNetworks" }, {})


-- during initial setup: enable this temporarily to ask for location preferences for hammerspoon
-- after that enable location for hammerspoon for capturing current network
-- print(hs.location.get())
local function isConnectedToAllowedNetwork()
  local currentNetwork = hs.wifi.currentNetwork()
  for _, network in ipairs(allowedNetworks) do
    if network == currentNetwork then
      return true
    end
  end
  return false
end

hs.urlevent.bind('sleepWatcher', function(eventName, params)
  print('handling event: ' .. eventName)
  P(params)

  local event = params.event
  local onAllowedNetwork = isConnectedToAllowedNetwork()

  if not onAllowedNetwork then
    previousBluetoothStatus = nil
    btConnectedDevices = {}
  elseif event == 'onSleep' then
    previousBluetoothStatus = macos_helpers.isBluetoothOn()
    if previousBluetoothStatus then
      btConnectedDevices = macos_helpers.getBluetoothDevices()
      macos_helpers.toggleBluetooth(false)
    end
  elseif event == 'onWake' and previousBluetoothStatus then
    macos_helpers.toggleBluetooth(previousBluetoothStatus)
    hs.timer.doAfter(1, function()
      for _, deviceAddress in ipairs(btConnectedDevices) do
        macos_helpers.connectToBluetoothDevice(deviceAddress)
      end
    end)
  end

  if event == 'onWake' then
    -- BitBar and our own hs.timer-driven menubar widgets have no wake
    -- handling of their own, so their refresh timers can silently stop
    -- firing after the system sleeps. Refresh content in place (rather
    -- than relaunching BitBar or hs.reload()) so menubar item order
    -- doesn't get shuffled. Unlike Bluetooth, this isn't network-scoped.
    macos_helpers.refreshBitBarPlugins()
    kb_battery.refresh()
    weather.update(false)
    now_playing.refresh()
  end
end)

return { previousBluetoothStatus, allowedNetworks, btConnectedDevices }
