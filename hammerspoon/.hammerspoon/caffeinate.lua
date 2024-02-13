local helpers = require("helpers")
local macos_helpers = require("macos_helpers")

local allowedNetworks = {}
local devices = {}
if helpers.isModuleAvailable("personal") then
  local personal = require("personal")
  allowedNetworks = personal.privateNetworks
end

local function isConnectedToAllowedNetwork()
  local currentNetwork = hs.wifi.currentNetwork()
  for _, network in ipairs(allowedNetworks) do
    if network == currentNetwork then
      return true
    end
  end
  return false
end

local caffeineWatcher = hs.caffeinate.watcher.new(function(event)
  if isConnectedToAllowedNetwork() then
    -- Do nothing if connected to an allowed network
    return
  end

  -- turning off bluetooth to disable unlock with apple watch when outside of "home"
  -- keep track of all the devices which were previously connected, and attempt to connect to them again
  if event == hs.caffeinate.watcher.screensDidLock then
    devices = macos_helpers.getBluetoothDevices()
    macos_helpers.toggleBluetooth(false)
  elseif event == hs.caffeinate.watcher.screensDidUnlock then
    macos_helpers.toggleBluetooth(true)
    hs.timer.doAfter(1, function()
      for _, deviceAddress in ipairs(devices) do
        macos_helpers.connectToBluetoothDevice(deviceAddress)
      end
    end)
  end
end)

caffeineWatcher:start()

return { caffeineWatcher, allowedNetworks, devices }
