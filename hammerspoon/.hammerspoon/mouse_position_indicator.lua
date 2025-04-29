local globals = require("globals")

local function colorFromHue(hue)
    return { hue = hue, saturation = 0.7, brightness = 0.7, alpha = 1 }
end

local isIndicatorActive = false
local activeIndicator = nil
local colorTimer = nil
local eventtapEvents = nil
local removalTimer = nil
local screenIndicator = nil
local screenColorTimer = nil

-- Function to create the indicator at the mouse position
local function createIndicator()
    local mousePos = hs.mouse.absolutePosition()

    local radius = 80
    activeIndicator = hs.drawing.circle(hs.geometry.rect(mousePos.x - radius, mousePos.y - radius, radius * 2, radius * 2))
    activeIndicator:setFill(true)
    activeIndicator:setStroke(false)
    activeIndicator:setStrokeWidth(0)
    activeIndicator:show()

    local hue = 0
    local hueStep = 0.02

    colorTimer = hs.timer.doEvery(0.05, function()
        hue = (hue + hueStep) % 1
        if activeIndicator then
            activeIndicator:setFillColor(colorFromHue(hue))
        end
    end)
end

local function createScreenIndicator()
    if #hs.screen.allScreens() == 1 then
        return
    end

    local screen = hs.mouse.getCurrentScreen()
    local screenFrame = screen:frame()

    screenIndicator = hs.drawing.rectangle(screenFrame)
    screenIndicator:setFill(false)
    screenIndicator:setStroke(true)
    screenIndicator:setStrokeWidth(50)
    screenIndicator:show()

    local hue = 0
    local hueStep = 0.02

    screenColorTimer = hs.timer.doEvery(0.05, function()
        hue = (hue + hueStep) % 1
        if screenIndicator then
            screenIndicator:setStrokeColor(colorFromHue(hue))
        end
    end)
end

local function removeIndicator()
    if activeIndicator then
        activeIndicator:delete()
        activeIndicator = nil
    end
    if screenIndicator then
        screenIndicator:delete()
        screenIndicator = nil
    end
    if colorTimer then
        colorTimer:stop()
        colorTimer = nil
    end
    if screenColorTimer then
        screenColorTimer:stop()
        screenColorTimer = nil
    end
    if eventtapEvents then
        eventtapEvents:stop()
        eventtapEvents = nil
    end
    if removalTimer then
        removalTimer:stop()
        removalTimer = nil
    end
    isIndicatorActive = false
end

local function startEvents()
    eventtapEvents = hs.eventtap.new({
        hs.eventtap.event.types.mouseMoved,
        -- this also captures scroll on trackpad
        hs.eventtap.event.types.scrollWheel,
        hs.eventtap.event.types.keyDown
    },
        function(event)
            removeIndicator()
            return false
        end)
    eventtapEvents:start()
end

hs.hotkey.bind(globals.hyper, "m", function()
    if isIndicatorActive then return end
    isIndicatorActive = true

    createIndicator()
    createScreenIndicator()
    startEvents()

    removalTimer = hs.timer.doAfter(7, function()
        removeIndicator()
    end)
end)
