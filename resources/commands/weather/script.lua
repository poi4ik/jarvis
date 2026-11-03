-- погода через wttr.in, ответ голосом
local lang = jarvis.context.language
local city = jarvis.state.get("city") or "Москва"

local url = "https://wttr.in/" .. city:gsub(" ", "+") .. "?format=%C+%t&lang=" .. lang
jarvis.log("info", "Fetching weather: " .. url)

local response = jarvis.http.get(url)
if not response.ok then
    jarvis.log("error", "Weather request failed: " .. (response.error or "unknown"))
    jarvis.speak("Не удалось узнать погоду")
    return false
end

-- ответ вида "Слабый снег +2°C"
local body = response.body
local temp = body:match("([%+%-]?%d+)°C")
local cond = body:gsub("%s*[%+%-]?%d+°C.*$", ""):lower()

local text = city .. ", " .. cond
if temp then
    local sign = ""
    if temp:sub(1, 1) == "-" then sign = "минус " elseif temp ~= "0" and temp ~= "+0" then sign = "плюс " end
    text = text .. ", " .. sign .. temp:gsub("^[%+%-]", "") .. " по цельсию"
end

jarvis.log("info", text)
jarvis.speak(text)
return false
