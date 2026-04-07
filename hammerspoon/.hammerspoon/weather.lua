local weatherConfig = {
  command = os.getenv("HOME") .. "/bin/weather",
  refreshIntervalSeconds = 60,
  precipitationAlertWindowHours = 3,
}

local symbolToIcon = {
  clearsky_day = "☼",
  clearsky_night = "☾",
  fair_day = "☼",
  fair_night = "☾",
  partlycloudy_day = "☁",
  partlycloudy_night = "☁",
  cloudy = "☁",
  fog = "≋",
  lightrain = "☂",
  rain = "☂",
  heavyrain = "☂",
  rainshowers_day = "☂",
  rainshowers_night = "☂",
  sleet = "✳",
  snow = "❄",
  lightsnow = "✳",
  heavysnow = "❄",
  thunderstorm = "☇",
}

local symbolToDescription = {
  clearsky_day = "Clear sky",
  clearsky_night = "Clear sky",
  fair_day = "Fair",
  fair_night = "Fair",
  partlycloudy_day = "Partly cloudy",
  partlycloudy_night = "Partly cloudy",
  cloudy = "Cloudy",
  fog = "Fog",
  rain = "Rain",
  rainshowers_day = "Rain showers",
  rainshowers_night = "Rain showers",
  sleet = "Sleet",
  snow = "Snow",
  thunderstorm = "Thunderstorm",
}

local weatherMenu = hs.menubar.new()
local lastWeather = nil
local updateWeather

local function trim(s)
  return (s or ""):gsub("%s+$", "")
end

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function parseUtcTimestamp(value)
  if not value or value == "" then
    return nil
  end

  local year, month, day, hour, minute, second = value:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)Z$")
  if not year then
    return nil
  end

  return os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(minute),
    sec = tonumber(second),
    isdst = false,
  })
end

local function canonicalSymbolCode(symbolCode)
  local code = symbolCode or "cloudy"
  local dayNightSuffix = code:match("_(day)$") or code:match("_(night)$") or "day"

  if code:find("thunder", 1, true) then
    return "thunderstorm"
  end
  if code:find("snow", 1, true) then
    return "snow"
  end
  if code:find("sleet", 1, true) then
    return "sleet"
  end
  if code:find("rainshowers", 1, true) then
    return "rainshowers_" .. dayNightSuffix
  end
  if code:find("rain", 1, true) then
    return "rain"
  end
  if code:find("fog", 1, true) then
    return "fog"
  end
  if code:find("partlycloudy", 1, true) then
    return "partlycloudy_" .. dayNightSuffix
  end
  if code:find("fair", 1, true) then
    return "fair_" .. dayNightSuffix
  end
  if code:find("clearsky", 1, true) then
    return "clearsky_" .. dayNightSuffix
  end

  return "cloudy"
end

local function iconFor(symbolCode)
  return symbolToIcon[canonicalSymbolCode(symbolCode)] or "☁"
end

local function descriptionFor(symbolCode)
  return symbolToDescription[canonicalSymbolCode(symbolCode)] or "Cloudy"
end

local function roundedTemperature(data)
  return math.floor((tonumber(data.temperature_c) or 0) + 0.5)
end

local function roundedFeelsLike(data)
  if not data or data.feels_like_c == nil then
    return nil
  end

  return math.floor((tonumber(data.feels_like_c) or 0) + 0.5)
end

local function formatUpdatedAt(updatedAt)
  if not updatedAt or updatedAt == "" then
    return nil
  end

  local utcTimestamp = parseUtcTimestamp(updatedAt)
  if not utcTimestamp then
    return updatedAt
  end

  local localTimestamp = utcTimestamp - os.difftime(os.time(os.date("!*t", utcTimestamp)), os.time(os.date("*t", utcTimestamp)))
  return os.date("%Y-%m-%d %H:%M", localTimestamp)
end

local function formatRainNotice(data)
  if not data or not data.next_rain_at then
    return "Rain soon: no"
  end

  local when = formatUpdatedAt(data.next_rain_at) or data.next_rain_at
  local amount = tonumber(data.next_rain_amount_mm or 0)
  return string.format("Rain soon: %s (%.1f mm)", when, amount)
end

local function hasPrecipSoon(data)
  if not data or not data.next_rain_at then
    return false
  end

  local amount = tonumber(data.next_rain_amount_mm or 0)
  if amount <= 0 then
    return false
  end

  local nextRainTimestamp = parseUtcTimestamp(data.next_rain_at)
  if not nextRainTimestamp then
    return false
  end

  local now = os.time()
  local alertWindowSeconds = weatherConfig.precipitationAlertWindowHours * 60 * 60
  return nextRainTimestamp >= now and (nextRainTimestamp - now) <= alertWindowSeconds
end

local function formatTitle(data)
  local title = string.format("%s %s°", iconFor(data.symbol_code), roundedTemperature(data))

  if hasPrecipSoon(data) then
    return hs.styledtext.new(title, {
      color = { red = 0.42, green = 0.72, blue = 0.97 },
    })
  end

  return title
end

local function menuSummary(data)
  return string.format("%s: %s°", descriptionFor(data.symbol_code), roundedTemperature(data))
end

local function yrSearchUrlFor(data)
  if not data or data.latitude == nil or data.longitude == nil then
    return nil
  end

  return string.format(
    "https://www.yr.no/en/search?q=%s,%s",
    tostring(data.latitude),
    tostring(data.longitude)
  )
end

local function yrForecastUrlFromSearchHtml(body)
  if not body or body == "" then
    return nil
  end

  local path = body:match('href="(/en/forecast/daily%-table/[^"]+)"')
  if not path then
    return nil
  end

  return "https://www.yr.no" .. path
end

local function openYrForecastFor(data)
  local searchUrl = yrSearchUrlFor(data)
  if not searchUrl then
    return
  end

  hs.http.asyncGet(searchUrl, nil, function(status, body)
    if status >= 200 and status < 300 then
      local forecastUrl = yrForecastUrlFromSearchHtml(body)
      if forecastUrl then
        hs.urlevent.openURL(forecastUrl)
        return
      end
    end

    hs.urlevent.openURL(searchUrl)
  end)
end

local function updateMenu()
  local menu = {
    {
      title = lastWeather and menuSummary(lastWeather) or "Weather: Unavailable",
      disabled = true,
    }
  }

  if lastWeather and lastWeather.label and lastWeather.label ~= "" then
    table.insert(menu, {
      title = "Location: " .. tostring(lastWeather.label),
      disabled = true,
    })
  end

  if lastWeather and lastWeather.fetched_at then
    table.insert(menu, {
      title = "Fetched at: " .. formatUpdatedAt(lastWeather.fetched_at),
      disabled = true,
    })
  end

  if lastWeather and lastWeather.updated_at then
    table.insert(menu, {
      title = "Forecast updated: " .. formatUpdatedAt(lastWeather.updated_at),
      disabled = true,
    })
  end

  if lastWeather and roundedFeelsLike(lastWeather) ~= nil then
    table.insert(menu, {
      title = "Feels like: " .. tostring(roundedFeelsLike(lastWeather)) .. "°",
      disabled = true,
    })
  end

  if lastWeather then
    table.insert(menu, {
      title = formatRainNotice(lastWeather),
      disabled = true,
    })
  end

  table.insert(menu, { title = "-" })

  if yrSearchUrlFor(lastWeather) then
    table.insert(menu, {
      title = "Open in Yr",
      fn = function() openYrForecastFor(lastWeather) end,
    })
  end

  table.insert(menu, {
    title = "Refresh now",
    fn = function() hs.timer.doAfter(0, function() updateWeather(true) end) end,
  })
  weatherMenu:setMenu(menu)
end

updateWeather = function(force)
  local commandParts = { shellQuote(weatherConfig.command) }

  if force then
    table.insert(commandParts, "--force")
  end

  local shellCommand = "exec " .. table.concat(commandParts, " ")

  hs.task.new("/bin/zsh", function(exitCode, stdOut, stdErr)
    if exitCode ~= 0 then
      local errorOutput = trim(stdErr)
      weatherMenu:setTitle("Wx ?")
      updateMenu()
      if errorOutput ~= "" then
        print("weather.lua:", errorOutput)
      end
      return
    end

    local decoded = hs.json.decode(stdOut or "")
    if not decoded or decoded.temperature_c == nil then
      weatherMenu:setTitle("Wx ?")
      updateMenu()
      return
    end

    lastWeather = decoded
    weatherMenu:setTitle(formatTitle(decoded))
    updateMenu()
  end, { "-lic", shellCommand }):start()
end

local timer = hs.timer.doEvery(weatherConfig.refreshIntervalSeconds, updateWeather):start()
updateWeather(false)

return {
  timer = timer,
  menubar = weatherMenu,
  update = updateWeather,
}
