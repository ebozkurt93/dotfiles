local macos_helpers = require("macos_helpers")
local cornerThreshold = 20
local sideThreshold = 5
local minAllowedDragDuration = 500
local minDragDurationBypassVelocity = 80
local cornerHighlight = nil
local lastDetectedCorner = nil
local dragStartTime = nil

-- Used for calculating max mouse velocity, to determine if we should ignore minAllowedDragDuration
local dragTimer = nil
local mousePoint = nil
local prevMousePoint = nil
local maxVelocity = 0

local function resizeAndMoveWindow(win, screen, corner)
  local max = screen:frame()
  local animationDuration = 0.001 -- default value is `hs.window.animationDuration`

  if corner == "topLeft" then
    win:setFrame(hs.geometry.rect(max.x, max.y, max.w / 2, max.h / 2), animationDuration)
  elseif corner == "topRight" then
    win:setFrame(hs.geometry.rect(max.x + (max.w / 2), max.y, max.w / 2, max.h / 2), animationDuration)
  elseif corner == "bottomLeft" then
    win:setFrame(hs.geometry.rect(max.x, max.y + (max.h / 2), max.w / 2, max.h / 2), animationDuration)
  elseif corner == "bottomRight" then
    win:setFrame(hs.geometry.rect(max.x + (max.w / 2), max.y + (max.h / 2), max.w / 2, max.h / 2), animationDuration)
  elseif corner == "left" then
    win:setFrame(hs.geometry.rect(max.x, max.y, max.w / 2, max.h), animationDuration)
  elseif corner == "right" then
    win:setFrame(hs.geometry.rect(max.x + (max.w / 2), max.y, max.w / 2, max.h), animationDuration)
  elseif corner == "top" then
    win:setFrame(hs.geometry.rect(max.x, max.y, max.w, max.h / 2), animationDuration)
  elseif corner == "bottom" then
    win:setFrame(hs.geometry.rect(max.x, max.y + (max.h / 2), max.w, max.h / 2), animationDuration)
  end
end

local function deleteHighlight()
  if cornerHighlight then
    cornerHighlight:delete()
    cornerHighlight = nil
  end
end

local function createHighlight(screen, corner)
  local mode = macos_helpers.isDarkMode()
  deleteHighlight()

  local rect
  local max = screen:frame()
  local size = cornerThreshold -- Make the highlight size equal to the corner threshold

  if corner == "topLeft" then
    rect = hs.geometry.rect(max.x, max.y, size, size)
  elseif corner == "topRight" then
    rect = hs.geometry.rect(max.x + max.w - size, max.y, size, size)
  elseif corner == "bottomLeft" then
    rect = hs.geometry.rect(max.x, max.y + max.h - size, size, size)
  elseif corner == "bottomRight" then
    rect = hs.geometry.rect(max.x + max.w - size, max.y + max.h - size, size, size)
  elseif corner == "left" then
    rect = hs.geometry.rect(max.x, max.y, sideThreshold, max.h)
  elseif corner == "right" then
    rect = hs.geometry.rect(max.x + max.w - sideThreshold, max.y, sideThreshold, max.h)
  elseif corner == "top" then
    rect = hs.geometry.rect(max.x, max.y, max.w, sideThreshold)
  elseif corner == "bottom" then
    rect = hs.geometry.rect(max.x, max.y + max.h - sideThreshold, max.w, sideThreshold)
  end

  cornerHighlight = hs.drawing.rectangle(rect)
  local color = mode and 1 or 0
  cornerHighlight:setFillColor({ red = color, green = color, blue = color, alpha = 0.5 })
  cornerHighlight:setRoundedRectRadii(3, 3)
  cornerHighlight:setStroke(false)
  cornerHighlight:show()
end

local function isNearCorner(point, screen)
  local max = screen:frame()
  local nearCorner = nil

  if math.abs(point.x - max.x) <= cornerThreshold and math.abs(point.y - max.y) <= cornerThreshold then
    nearCorner = "topLeft"
  elseif math.abs(point.x - (max.x + max.w)) <= cornerThreshold and math.abs(point.y - max.y) <= cornerThreshold then
    nearCorner = "topRight"
  elseif math.abs(point.x - max.x) <= cornerThreshold and math.abs(point.y - (max.y + max.h)) <= cornerThreshold then
    nearCorner = "bottomLeft"
  elseif math.abs(point.x - (max.x + max.w)) <= cornerThreshold
      and math.abs(point.y - (max.y + max.h)) <= cornerThreshold
  then
    nearCorner = "bottomRight"
  elseif math.abs(point.x - max.x) <= sideThreshold then
    nearCorner = "left"
  elseif math.abs(point.x - (max.x + max.w)) <= sideThreshold then
    nearCorner = "right"
  elseif math.abs(point.y - max.y) <= sideThreshold then
    nearCorner = "top"
  elseif math.abs(point.y - (max.y + max.h)) <= sideThreshold then
    nearCorner = "bottom"
  end

  return nearCorner
end

local function dragDurationLongerThanMinAllowed()
  local dragDuration = hs.timer.absoluteTime() - dragStartTime
  -- Convert duration from nanoseconds to milliseconds
  dragDuration = dragDuration / 1e6
  return dragDuration >= minAllowedDragDuration
end

local function mouseVelocityHighEnough()
  return maxVelocity > minDragDurationBypassVelocity
end

local function calculateDistance(p1, p2)
  local xDiff = p2.x - p1.x
  local yDiff = p2.y - p1.y
  return math.sqrt(xDiff ^ 2 + yDiff ^ 2)
end

local function updateMouseVelocity()
  local currentVelocity = nil
  if (prevMousePoint == nil) then
    currentVelocity = 0
  else
    currentVelocity = calculateDistance(prevMousePoint, mousePoint)
  end
  prevMousePoint = mousePoint
  maxVelocity = math.max(maxVelocity, currentVelocity)
end

local function windowDragging(event)
  mousePoint = hs.mouse.absolutePosition()
  local screen = hs.mouse.getCurrentScreen()

  if event:getType() == hs.eventtap.event.types.leftMouseDown then
    dragStartTime = hs.timer.absoluteTime()
    dragTimer = hs.timer.doEvery(0.1, updateMouseVelocity)
  elseif event:getType() == hs.eventtap.event.types.leftMouseDragged then
    lastDetectedCorner = isNearCorner(mousePoint, screen)
    if lastDetectedCorner and (dragDurationLongerThanMinAllowed() or mouseVelocityHighEnough()) then
      createHighlight(screen, lastDetectedCorner)
    else
      deleteHighlight()
    end
  elseif event:getType() == hs.eventtap.event.types.leftMouseUp then
    if (dragDurationLongerThanMinAllowed() or mouseVelocityHighEnough()) then
      local win = hs.window.focusedWindow()
      if win and lastDetectedCorner then
        resizeAndMoveWindow(win, screen, lastDetectedCorner)
      end
    end
    lastDetectedCorner = nil
    dragStartTime = nil
    dragTimer:stop()
    dragTimer = nil
    prevMousePoint = nil
    maxVelocity = 0
    hs.timer.doAfter(0.05, deleteHighlight)
  end
end

local eventtap = hs.eventtap.new({
  hs.eventtap.event.types.leftMouseDown,
  hs.eventtap.event.types.leftMouseUp,
  hs.eventtap.event.types.leftMouseDragged,
}, windowDragging)
eventtap:start()
return eventtap
