local helpers = require("helpers")
local macos_helpers = require("macos_helpers")

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

  if not isConnectedToAllowedNetwork() then
    return
  end

  local event = params.event
  if event == 'onSleep' then
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
end)

return { previousBluetoothStatus, allowedNetworks, btConnectedDevices }
