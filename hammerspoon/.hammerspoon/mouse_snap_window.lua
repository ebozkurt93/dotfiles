local cornerThreshold = 20
local sideThreshold = 5
local cornerHighlight = nil
local lastDetectedCorner = nil -- Variable to store the last detected corner

local function resizeAndMoveWindow(win, screen, corner)
  local max = screen:frame()

  if corner == "topLeft" then
    win:setFrame(hs.geometry.rect(max.x, max.y, max.w / 2, max.h / 2))
  elseif corner == "topRight" then
    win:setFrame(hs.geometry.rect(max.x + (max.w / 2), max.y, max.w / 2, max.h / 2))
  elseif corner == "bottomLeft" then
    win:setFrame(hs.geometry.rect(max.x, max.y + (max.h / 2), max.w / 2, max.h / 2))
  elseif corner == "bottomRight" then
    win:setFrame(hs.geometry.rect(max.x + (max.w / 2), max.y + (max.h / 2), max.w / 2, max.h / 2))
  elseif corner == "left" then
    win:setFrame(hs.geometry.rect(max.x, max.y, max.w / 2, max.h))
  elseif corner == "right" then
    win:setFrame(hs.geometry.rect(max.x + (max.w / 2), max.y, max.w / 2, max.h))
  elseif corner == "top" then
    win:setFrame(hs.geometry.rect(max.x, max.y, max.w, max.h / 2))
  elseif corner == "bottom" then
    win:setFrame(hs.geometry.rect(max.x, max.y + (max.h / 2), max.w, max.h / 2))
  end
end

local function createHighlight(screen, corner)
  if cornerHighlight then
    cornerHighlight:delete()
  end

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
  cornerHighlight:setFillColor({ red = 1, green = 1, blue = 1, alpha = 0.3 })
  cornerHighlight:setRoundedRectRadii(3, 3)
  cornerHighlight:setStroke(false)
  cornerHighlight:show()
end

local function deleteHighlight()
  if cornerHighlight then
    cornerHighlight:delete()
    cornerHighlight = nil
  end
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
  elseif
    math.abs(point.x - (max.x + max.w)) <= cornerThreshold
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

local function windowDragging(event)
  local mousePoint = hs.mouse.absolutePosition()
  local screen = hs.mouse.getCurrentScreen()

  if event:getType() == hs.eventtap.event.types.leftMouseDragged then
    lastDetectedCorner = isNearCorner(mousePoint, screen)
    if lastDetectedCorner then
      createHighlight(screen, lastDetectedCorner)
    else
      deleteHighlight()
    end
  elseif event:getType() == hs.eventtap.event.types.leftMouseUp then
    deleteHighlight()
    local win = hs.window.focusedWindow()
    if win and lastDetectedCorner then
      resizeAndMoveWindow(win, screen, lastDetectedCorner)
      lastDetectedCorner = nil -- Reset the corner detection after resizing
    end
  end
end

local eventtap =
  hs.eventtap.new({ hs.eventtap.event.types.leftMouseUp, hs.eventtap.event.types.leftMouseDragged }, windowDragging)
eventtap:start()
return eventtap
