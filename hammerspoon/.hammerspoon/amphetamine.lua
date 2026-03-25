local menu = hs.menubar.new()
local scriptPath = os.getenv("HOME") .. "/bin/helpers/amphetamine.sh"
local onIcon = "󰹑"
local offIcon = "󰶐"
local defaultInterval = 5
local countdownInterval = 1
local timer = nil
local currentInterval = nil

local function shellQuote(value)
  local text = tostring(value)
  return "'" .. text:gsub("'", [['"'"']]) .. "'"
end

local function runScript(args)
  local command = shellQuote(scriptPath)

  if type(args) == "table" then
    for _, arg in ipairs(args) do
      command = command .. " " .. shellQuote(arg)
    end
  elseif type(args) == "string" and args ~= "" then
    command = command .. " " .. shellQuote(args)
  end

  return hs.execute(command, true)
end

local function getStatus()
  local output, success = runScript({ "status" })
  if not success then
    return { active = false, remaining = nil, flags = nil }
  end

  output = output or ""

  local activeRaw = output:match("active=([^\n]*)") or "0"
  local remainingRaw = output:match("remaining=([^\n]*)") or ""
  local flagsRaw = output:match("flags=([^\n]*)") or ""

  local status = {
    active = activeRaw == "1",
    remaining = nil,
    flags = nil,
  }

  local remainingValue = tonumber(remainingRaw)
  if remainingValue then
    status.remaining = remainingValue
  end

  local flagsValue = flagsRaw:gsub("%s+$", "")
  if flagsValue ~= "" then
    status.flags = flagsValue
  end

  return status
end

local function formatRemaining(seconds)
  if not seconds then
    return nil
  end

  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local secs = seconds % 60
  return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function parseDurationToSeconds(input)
  if not input then
    return nil
  end

  local normalized = input:lower():gsub("%s+", "")
  local count, unit = normalized:match("^(%d+)([smhd]?)$")
  if not count then
    return nil
  end

  local value = tonumber(count)
  if not value or value <= 0 then
    return nil
  end

  if unit == "" or unit == "m" then
    return value * 60
  elseif unit == "s" then
    return value
  elseif unit == "h" then
    return value * 60 * 60
  elseif unit == "d" then
    return value * 60 * 60 * 24
  end

  return nil
end

local function updateMenuTitle(active)
  if active then
    menu:setTitle(onIcon)
  else
    menu:setTitle(offIcon)
  end
end

local ensureTimer
local refreshAndReschedule

local function runAction(args, errorText)
  local _, success = runScript(args)
  if not success then
    hs.alert.show(errorText or "Command failed")
  end
  hs.timer.doAfter(0.05, function()
    refreshAndReschedule()
  end)
end

local function refreshMenu()
  local status = getStatus()
  updateMenuTitle(status.active)
  return status
end

local function promptProfileFlags(current)
  local button, text = hs.dialog.textPrompt(
    "Amphetamine Profile",
    "Set profile flags for now + future sessions (examples: -d -i -m, -i -m, -d)",
    current or "-d -i -m",
    "Apply",
    "Cancel"
  )

  if button ~= "Apply" then
    return
  end

  runAction({ "profile", text }, "Invalid flags")
end

local function buildMenu(status)
  local displaySeconds = status.remaining
  if displaySeconds and displaySeconds > 0 then
    displaySeconds = displaySeconds + 1
  end
  local remaining = formatRemaining(displaySeconds)
  local stateText = status.active and "Active" or "Inactive"
  local remainingText = (status.active and remaining) and remaining or "--"
  local flagsText = status.flags or "-d -i -m"

  local isFullProfile = flagsText == "-d -i -m"
  local isSystemProfile = flagsText == "-i -m"
  local isDisplayProfile = flagsText == "-d"

  local sessionColor = status.active and { red = 0.22, green = 0.75, blue = 0.36 } or { red = 0.82, green = 0.32, blue = 0.28 }
  local remainingColor = remaining and { red = 0.28, green = 0.55, blue = 0.9 } or { red = 0.55, green = 0.55, blue = 0.55 }
  local flagsColor = { red = 0.65, green = 0.65, blue = 0.65 }

  return {
    {
      title = hs.styledtext.new("Session: " .. stateText, { color = sessionColor }),
    },
    {
      title = hs.styledtext.new("Remaining: " .. remainingText, { color = remainingColor }),
    },
    {
      title = hs.styledtext.new("Flags: " .. flagsText, { color = flagsColor }),
    },
    { title = "-" },
    {
      title = "Toggle",
      fn = function()
        runAction({ "toggle" })
      end,
    },
    {
      title = "Start",
      fn = function()
        runAction({ "start" })
      end,
    },
    {
      title = "Stop",
      fn = function()
        runAction({ "stop" })
      end,
    },
    { title = "-" },
    {
      title = "Use profile: Full awake (-d -i -m)",
      checked = isFullProfile,
      fn = function()
        runAction({ "profile", "-d -i -m" })
      end,
    },
    {
      title = "Use profile: System only (-i -m)",
      checked = isSystemProfile,
      fn = function()
        runAction({ "profile", "-i -m" })
      end,
    },
    {
      title = "Use profile: Display only (-d)",
      checked = isDisplayProfile,
      fn = function()
        runAction({ "profile", "-d" })
      end,
    },
    {
      title = "Use custom profile...",
      fn = function()
        promptProfileFlags(status.flags)
      end,
    },
    { title = "-" },
    {
      title = "Start for 30m",
      fn = function()
        runAction({ "start", "30m" })
      end,
    },
    {
      title = "Start for 1h",
      fn = function()
        runAction({ "start", "1h" })
      end,
    },
    {
      title = "Start for 2h",
      fn = function()
        runAction({ "start", "2h" })
      end,
    },
    {
      title = "Start custom duration...",
      fn = function()
        local button, text = hs.dialog.textPrompt(
          "Amphetamine",
          "Enter duration (15m, 2h, 90m, 3600s)",
          "",
          "Start",
          "Cancel"
        )

        if button ~= "Start" then
          return
        end

        local seconds = parseDurationToSeconds(text)
        if not seconds then
          hs.alert.show("Invalid duration")
          return
        end

        runAction({ "start", tostring(seconds) .. "s" })
      end,
    },
  }
end

local function desiredInterval(status)
  if status.active and status.remaining ~= nil then
    return countdownInterval
  end
  return defaultInterval
end

ensureTimer = function(interval)
  if timer and currentInterval == interval then
    return
  end

  if timer then
    timer:stop()
  end

  timer = hs.timer.doEvery(interval, function()
    refreshAndReschedule()
  end)
  timer:start()
  currentInterval = interval
end

hs.hotkey.bind({ "cmd" }, "i", function()
  runAction({ "toggle" })
end)

refreshAndReschedule = function()
  local status = refreshMenu()
  menu:setMenu(buildMenu(status))
  ensureTimer(desiredInterval(status))
end

refreshAndReschedule()

return { menu = menu, getTimer = function() return timer end }
