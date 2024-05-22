local helpers = require("helpers")
local macos_helpers = require("macos_helpers")

local devices = {}
local previousBluetoothStatus = nil
local _, allowedNetworks = helpers.safeRequire("personal", {"privateNetworks"}, {})

local function isConnectedToAllowedNetwork()
  local currentNetwork = hs.wifi.currentNetwork()
  for _, network in ipairs(allowedNetworks) do
    if network == currentNetwork then
      return true
    end
  end
  return false
end

-- during initial setup: enable this temporarily to ask for location preferences for hammerspoon
-- after that enable location for hammerspoon for capturing current network
-- print(hs.location.get())
local caffeineWatcher = hs.caffeinate.watcher.new(function(event)
  if isConnectedToAllowedNetwork() then
    if event == hs.caffeinate.watcher.systemWillSleep then
      previousBluetoothStatus = macos_helpers.isBluetoothOn()
      macos_helpers.toggleBluetooth(false)
    elseif event == hs.caffeinate.watcher.systemDidWake and previousBluetoothStatus then
      macos_helpers.toggleBluetooth(true)
    end

    return
  end

  -- turning off bluetooth to disable unlock with apple watch when outside of "home"
  -- keep track of all the devices which were previously connected, and attempt to connect to them again
  if event == hs.caffeinate.watcher.screensDidLock then
    previousBluetoothStatus = macos_helpers.isBluetoothOn()
    if previousBluetoothStatus then
      devices = macos_helpers.getBluetoothDevices()
      macos_helpers.toggleBluetooth(false)
    end
  elseif event == hs.caffeinate.watcher.screensDidUnlock then
    if previousBluetoothStatus then
      macos_helpers.toggleBluetooth(true)
      hs.timer.doAfter(1, function()
        for _, deviceAddress in ipairs(devices) do
          macos_helpers.connectToBluetoothDevice(deviceAddress)
        end
      end)
    end
  end
end)

caffeineWatcher:start()

return { caffeineWatcher, allowedNetworks, devices }
