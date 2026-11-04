-- Remember the current video and position for Jarvis "play video".
-- State file (two lines: path, seconds) is given via
--   --script-opts=jarvis_resume-file=/path/to/state
-- Saved every 5 s, on pause, on file change and on quit, so it also
-- survives a power cut. On start, if the first loaded file is the saved
-- one, playback jumps to the saved position (minus a few seconds).

local opts = { file = "" }
require("mp.options").read_options(opts, "jarvis_resume")
if opts.file == "" then return end

local restored = false
local finished = false

local function read_state()
    local f = io.open(opts.file, "r")
    if not f then return nil end
    local path = f:read("*l")
    local pos = tonumber(f:read("*l") or "")
    f:close()
    return path, pos
end

local function save()
    if finished then return end
    local path = mp.get_property("path")
    local pos = mp.get_property_number("time-pos")
    if not path or not pos then return end
    local tmp = opts.file .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then return end
    f:write(path, "\n", string.format("%.1f", pos), "\n")
    f:close()
    os.rename(tmp, opts.file)
end

mp.register_event("file-loaded", function()
    finished = false
    if not restored then
        restored = true
        local path, pos = read_state()
        if path == mp.get_property("path") and pos and pos > 5 then
            mp.commandv("seek", tostring(pos - 3), "absolute")
            return
        end
    end
    save()
end)

mp.register_event("end-file", function(ev)
    if ev.reason ~= "eof" then return end
    local count = mp.get_property_number("playlist-count", 0)
    local pos = mp.get_property_number("playlist-pos", -1)
    if pos < 0 or pos >= count - 1 then
        -- whole playlist watched: start from the beginning next time
        finished = true
        os.remove(opts.file)
    end
end)

mp.observe_property("pause", "bool", function(_, paused)
    if paused then save() end
end)
mp.add_periodic_timer(5, save)
mp.register_event("shutdown", save)
