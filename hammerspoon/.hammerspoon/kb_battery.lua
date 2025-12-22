-- battery status (show only when any side <= 20)
local shell = "/bin/bash"
local batteryCommand = [[
~/bin/ble_battery corne | jq -r '
  def num: (tostring | sub("%$";"") | tonumber?);

  to_entries[]
  | select(.value | type == "object")
  | .key as $device
  | (
      [ .value
        | to_entries[]
        | select((.value | num) != null and (.value | num) <= 20)
        | "\(.key | .[0:1] | ascii_upcase):\(.value | num | floor)"
      ] as $low
      | if ($low|length) > 0 then "\($device) \($low|join(" "))" else empty end
    )
'
]]

local arguments = { "-c", batteryCommand }

local batteryStatus = hs.menubar.new()

local function updateBatteryStatus()
  hs.task.new(shell, function(exitCode, stdOut, stdErr)
    local out = (stdOut or ""):gsub("%s+$", "")
    if exitCode == 0 and out ~= "" then
      -- single-line menubar title (if multiple devices, join with " | ")
      local title = out:gsub("\n+", " | ")
      batteryStatus:setTitle("󰌌  " .. title)
      batteryStatus:returnToMenuBar()
    else
      batteryStatus:removeFromMenuBar()
    end
  end, arguments):start()
end

local timer = hs.timer.doEvery(60, updateBatteryStatus):start()
updateBatteryStatus()

return { timer, batteryStatus }
