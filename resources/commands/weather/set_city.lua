-- "установи город казань" -> запомнить город для погоды
local phrase = jarvis.context.phrase or ""
local city = phrase:match("город%s+(.+)") or phrase:match("city%s+(.+)")

if city then
    city = city:gsub("^%s*(.-)%s*$", "%1")
    jarvis.state.set("city", city)
    jarvis.log("info", "City set: " .. city)
    jarvis.speak("Город установлен: " .. city)
else
    jarvis.speak("Не расслышал город")
end
return false
