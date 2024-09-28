local helpers = require("helpers")
local macos_helpers = require("macos_helpers")

local items = {}
local function refetchItems()
  local devices = {}
  items = {}


  local data, success = hs.execute('blueutil --paired --format json')
  if (success) then
    devices = hs.json.decode(data)
  else
    devices = {}
  end
  P(devices)

  for _, item in ipairs(devices) do
    table.insert(items, {
      text = item.connected and '✅ ' or '❌ ' .. item.name,
      subText = item.address,
      name = item.name,
      address = item.address
    })
  end
end

local function showMenu()
  refetchItems()
  local isBtOn = macos_helpers.isBluetoothOn()
  if (not isBtOn) then
    hs.alert.show("Bluetooth off")
    return
  end
  local chooser = hs.chooser.new(function(choice)
    if not choice then
      return
    end
    local selected = helpers.findTableArrayItemByField(items, "address", choice.address)
    hs.execute(([=[
(
if [[ "$(blueutil --is-connected %s)" == '1' ]]; then
  blueutil --disconnect %s --wait-disconnect %s
else
  blueutil --connect %s --wait-connect %s
fi) &
]=]  ):format(selected.address,
      selected.address,
      selected.address,
      selected.address,
      selected.address))

  end)

  chooser:choices(items)
  chooser:queryChangedCallback(helpers.queryChangedCallback(chooser, items))
  chooser:show()
end

hs.hotkey.bind({ "ctrl", "shift", "alt" }, "b", showMenu)

return { items }
