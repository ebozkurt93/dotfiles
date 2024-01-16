-- Fuzzy Window Switcher

local _fuzzyChoices = nil
local _fuzzyChooser = nil
-- local _fuzzyLastWindow = nil
local windows = {}

local function fuzzyQuery(s, m)
	local s_index = 1
	local m_index = 1
	local match_start = nil
	while true do
		if s_index > s:len() or m_index > m:len() then
			return -1
		end
		local s_char = s:sub(s_index, s_index)
		local m_char = m:sub(m_index, m_index)
		if s_char == m_char then
			if match_start == nil then
				match_start = s_index
			end
			s_index = s_index + 1
			m_index = m_index + 1
			if m_index > m:len() then
				local match_end = s_index
				local s_match_length = match_end-match_start
				local score = m:len()/s_match_length
				return score
			end
		else
			s_index = s_index + 1
		end
	end
end

local function _fuzzyFilterChoices(query)
	if query:len() == 0 then
		_fuzzyChooser:choices(_fuzzyChoices)
		return
	end
	local pickedChoices = {}
	for i, j in pairs(_fuzzyChoices) do
		-- this is to support queries where app name is given at start or end while query contains partial window title
		local fullText = (j["subText"] ..  " " .. j["text"] .. " " .. j["subText"]):lower()
		-- local fullText = (j["text"] .. " " .. j["subText"]):lower()
		local score = fuzzyQuery(fullText, query:lower())
		if score > 0 then
			j["fzf_score"] = score
			table.insert(pickedChoices, j)
		end
	end
	local sort_func = function( a,b ) return a["fzf_score"] > b["fzf_score"] end
	table.sort( pickedChoices, sort_func )
	_fuzzyChooser:choices(pickedChoices)
end

local function _fuzzyPickWindow(item)
    if item == nil then return end
	local index = item["index"]
    local window = windows[index]
	window:focus()
	_fuzzyChooser = nil
end

local function windowFuzzySearch()
    windows = hs.window.filter.new(true):getWindows(hs.window.sortByFocusedLast)
	_fuzzyChoices = {}
	for i,w in pairs(windows) do
		local title = w:title()
		local app = w:application():name()
		local bundleID = w:application():bundleID()
        local icon = hs.image.imageFromAppBundle(bundleID)
		local item = {
			["text"] = title,
			["subText"] = app,
			["image"] = icon,
			["windowID"] = w:id(),
            index = i
		}
        table.insert(_fuzzyChoices, item)
	end
	_fuzzyChooser = hs.chooser.new(_fuzzyPickWindow):choices(_fuzzyChoices):searchSubText(true)
	_fuzzyChooser:queryChangedCallback(_fuzzyFilterChoices) -- Enable true fuzzy find
	_fuzzyChooser:show()
end

hs.hotkey.bind({ "alt" }, "space", function()
	if _fuzzyChooser then
		_fuzzyChooser:cancel()
		_fuzzyChooser = nil
	else
		windowFuzzySearch()
	end
end)
