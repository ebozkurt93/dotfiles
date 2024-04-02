local M = {}
local timer = nil
local menuBarItem
local isPomodoro = true
local pomodoroTime = 25 * 60 -- default 25 minutes
local breakTime = 5 * 60 -- default 5 minutes

local function updateMenuBarItem()
  if timer and timer:running() then
    local remainingTime = math.floor(timer:nextTrigger())
    menuBarItem:setTitle(string.format("%02d:%02d", remainingTime // 60, remainingTime % 60))
  else
    menuBarItem:setTitle("Start Pomodoro")
  end
end

local function startTimer(seconds)
  if timer then
    timer:stop()
  end
  timer = hs.timer
    .doAfter(seconds, function()
      hs.notify
        .new({ title = "Pomodoro Timer", informativeText = isPomodoro and "Time for a break!" or "Back to work!" })
        :send()
      isPomodoro = not isPomodoro
      startTimer(isPomodoro and pomodoroTime or breakTime)
    end)
    :start()
  updateMenuBarItem()
end

local function setTimeFromInput(input)
  local times = hs.fnutils.split(input, ",", true)
  if #times == 2 then
    pomodoroTime = tonumber(times[1]) * 60
    breakTime = tonumber(times[2]) * 60
  end
end

local function promptForTimes()
  local button, input = hs.dialog.textPrompt(
    "Set Times",
    "Enter Pomodoro and Break times in minutes (separated by a comma):",
    tostring(pomodoroTime / 60) .. "," .. tostring(breakTime / 60),
    "OK",
    "Cancel"
  )

  if button == "OK" then
    setTimeFromInput(input)
  end
end

function M.start()
  menuBarItem = hs.menubar.new()
  menuBarItem:setTitle("Start Pomodoro")
  menuBarItem:setMenu({
    {
      title = "Start Pomodoro",
      fn = function()
        startTimer(pomodoroTime)
      end,
    },
    { title = "Set Times", fn = promptForTimes },
    {
      title = "Stop Pomodoro",
      fn = function()
        if timer then
          timer:stop()
        end
      end,
    },
  })

  hs.timer.doEvery(1, updateMenuBarItem)
end

return M
