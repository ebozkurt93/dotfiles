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

local criticalCommand = [[
~/bin/ble_battery corne | jq -r '
  def num: (tostring | sub("%$";"") | tonumber?);

  [ to_entries[]
    | select(.value | type == "object")
    | .value | to_entries[]
    | select((.value | num) != null and (.value | num) <= 10)
  ] | length
'
]]

local arguments = { "-c", batteryCommand }
local criticalArguments = { "-c", criticalCommand }

local batteryStatus = hs.menubar.new()

local function updateBatteryStatus()
  hs.task.new(shell, function(exitCode, stdOut, stdErr)
    local out = (stdOut or ""):gsub("%s+$", "")
    if exitCode == 0 and out ~= "" then
      local title = "󰌌  " .. out:gsub("\n+", " | ")
      -- check if any item is critically low (<= 10) to colorize red
      hs.task.new(shell, function(cExitCode, cStdOut, _)
        local criticalCount = tonumber((cStdOut or ""):match("%d+")) or 0
        if cExitCode == 0 and criticalCount > 0 then
          batteryStatus:setTitle(hs.styledtext.new(title, { color = { red = 0.9, green = 0.35, blue = 0.25 } }))
        else
          batteryStatus:setTitle(title)
        end
      end, criticalArguments):start()
      batteryStatus:returnToMenuBar()
    else
      batteryStatus:removeFromMenuBar()
    end
  end, arguments):start()
end

local timer = hs.timer.doEvery(60, updateBatteryStatus):start()
updateBatteryStatus()

return { timer, batteryStatus }
