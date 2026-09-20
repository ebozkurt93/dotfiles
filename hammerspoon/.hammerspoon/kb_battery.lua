-- Always show low keyboard batteries. Show healthy levels only while an
-- external display is connected.
local shell = "/bin/bash"
local batteryCommand = [[
~/bin/ble_battery corne | jq -c '
  def num: (tostring | sub("%$";"") | tonumber?);
  def level_text: "\(.side | .[0:1] | ascii_upcase):\(.level | floor)";

  [ to_entries[]
    | select(.value | type == "object")
    | .key as $device
    | [ .value
        | to_entries[]
        | select((.value | num) != null)
        | { side: .key, level: (.value | num) }
      ] as $levels
    | select(($levels | length) > 0)
    | { device: $device, levels: $levels }
  ] as $keyboards
  | {
      all: [
        $keyboards[]
        | ([.levels[] | level_text] | join(" ")) as $levels
        | if ($keyboards | length) == 1 then $levels else "\(.device) \($levels)" end
      ],
      low: [
        $keyboards[]
        | ([.levels[] | select(.level <= 20) | level_text] | join(" ")) as $levels
        | select($levels != "")
        | if ($keyboards | length) == 1 then $levels else "\(.device) \($levels)" end
      ]
    }
'
]]

local arguments = { "-c", batteryCommand }

local helpers = require("helpers")
local batteryStatus = nil

local function hasExternalDisplay()
  for _, screen in ipairs(hs.screen.allScreens()) do
    local name = (screen:name() or ""):lower()
    local isBuiltIn = name:find("built-in", 1, true) ~= nil or name == "color lcd"
    if not isBuiltIn then return true end
  end
  return false
end

local function hideBatteryStatus()
  if batteryStatus then
    batteryStatus:delete()
    batteryStatus = nil
  end
end

local function updateBatteryStatus()
  hs.task.new(shell, function(exitCode, stdOut, _)
    local out = (stdOut or ""):gsub("%s+$", "")
    local ok, readings = pcall(hs.json.decode, out)
    if exitCode ~= 0 or not ok or type(readings) ~= "table" then
      hideBatteryStatus()
      return
    end

    local hasLowBattery = type(readings.low) == "table" and #readings.low > 0
    local parts = hasExternalDisplay() and readings.all or readings.low
    if type(parts) ~= "table" or #parts == 0 then
      hideBatteryStatus()
      return
    end

    local title = "󰌌  " .. table.concat(parts, " | ")
    if not batteryStatus then
      batteryStatus = helpers.registerMenubar(hs.menubar.new(true, "eb-kb-battery"))
    end
    if hasLowBattery then
      batteryStatus:setTitle(hs.styledtext.new(title, { color = { red = 0.9, green = 0.35, blue = 0.25 } }))
    else
      batteryStatus:setTitle(title)
    end
  end, arguments):start()
end

local timer = hs.timer.doEvery(60, updateBatteryStatus):start()
local screenWatcher = hs.screen.watcher.new(updateBatteryStatus):start()
updateBatteryStatus()

return { timer, screenWatcher, refresh = updateBatteryStatus }
