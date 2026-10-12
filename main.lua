-- Run HUD: the numbers of a run, drawn in a corner and kept with the save.
-- It only watches: every filter here answers nil, so the game's numbers are untouched.

local S, P, G = cleria.settings, cleria.player, cleria.game

local show = S.get("Show", true)
local corner = S.get("Corner", 2)             -- 1 top left, 2 top right, 3 bottom right
local show_dps = S.get("ShowDps", true)

-- What is kept with the save (cleria.save, key "run"): a new game starts at zero, a load brings its own.
local function fresh()
    return {ticks = 0, kills = 0, deaths = 0, dealt = 0, taken = 0, hits = 0, best = 0, rooms = 0, bosses = 0}
end
local run = fresh()
local room_ticks = 0
local window = {}                             -- {tick, damage} of the last 5 seconds, for the DPS
local now = 0                                 -- ticks since the mod started (the window's clock)

local function store() if cleria.save.ready() then cleria.save.set("run", run) end end
local function restore()
    local t = cleria.save.get("run")
    run = fresh()
    if type(t) == "table" then for k in pairs(run) do if type(t[k]) == "number" then run[k] = t[k] end end end
    window = {}
end
-- Continuing after a death can reload the save's storage as it was before the death: the count is carried over.
local carry = nil
cleria.events.on("new_game", function() carry = nil restore() run.rooms = 1 end)    -- the first room is entered before new_game
cleria.events.on("load", function()
    restore()
    if carry then run.deaths = math.max(run.deaths, carry) carry = nil store() end
end)

cleria.events.on("room_enter", function(e)
    room_ticks = 0
    if e.prev_room and e.prev_room ~= "" and e.prev_room ~= e.room then     -- a door or a warp, not a load
        run.rooms = run.rooms + 1
        store()
    end
end)
cleria.events.on("tick", function()
    if not G.in_game() then return end
    now = now + 1
    if G.frozen() then return end             -- a cutscene or a box: the clocks wait
    run.ticks = run.ticks + 1
    room_ticks = room_ticks + 1
    if run.ticks % 60 == 0 then store() end
end)
cleria.events.on("enemy_killed", function() run.kills = run.kills + 1 store() end)
cleria.events.on("death", function() run.deaths = run.deaths + 1 carry = run.deaths store() end)

local function clock(ticks)
    local s = ticks // 60
    if s >= 3600 then return string.format("%d:%02d:%02d", s // 3600, s // 60 % 60, s % 60) end
    return string.format("%d:%02d", s // 60, s % 60)
end
local function recap()
    return string.format("%s  -  %d kills  -  %d deaths  -  %d damage dealt, %d taken  -  best hit %d  -  %d rooms",
                         clock(run.ticks), run.kills, run.deaths, run.dealt, run.taken, run.best, run.rooms)
end
cleria.events.on("boss_defeated", function(e)
    run.bosses = run.bosses + 1
    store()
    if e.flag == 226 or e.flag == 227 then    -- Dalles (Yunica, Hugo) or Darm (Toal): the run is over
        cleria.notice(recap(), "Run complete")
        cleria.log("recap: " .. recap())
    end
end)

cleria.combat.add_filter("damage", function(q)
    local v = math.floor(q.value)
    if q.dir == "dealt" then
        run.dealt = run.dealt + v
        if v > run.best then run.best = v end
        window[#window + 1] = {now, v}
    elseif q.dir == "taken" then
        run.taken = run.taken + v
        if v > 0 then run.hits = run.hits + 1 end
    end
    return nil                                -- pass: this mod changes nothing
end)

local function dps()
    local sum, first = 0, now
    local keep = {}
    for _, h in ipairs(window) do
        if now - h[1] < 300 then keep[#keep + 1] = h sum = sum + h[2] if h[1] < first then first = h[1] end end
    end
    window = keep
    if #keep == 0 then return 0 end
    return sum / math.max(1, (now - first) / 60)       -- over the time since the window's first hit, at least 1 s
end

cleria.hud.layer("runhud", function(d)
    if not show or not G.in_game() then return end
    local s = d.scale
    local rows = {{"Room", clock(room_ticks)}, {"Run", clock(run.ticks)}, {"Kills", tostring(run.kills)},
                  {"Deaths", tostring(run.deaths)}}
    if show_dps then rows[#rows + 1] = {"DPS", string.format("%.0f", dps())} end
    local w, lh = 190 * s, 26 * s
    local h = #rows * lh + 16 * s
    local x = corner == 1 and 14 * s or d.w - w - 14 * s
    local y = corner == 3 and d.h - h - 14 * s or 14 * s
    d:rect(x, y, w, h, {color = 0x100F0B, alpha = 0.7, rounding = 5 * s})
    for i, r in ipairs(rows) do
        local ry = y + 8 * s + (i - 1) * lh
        d:text(x + 12 * s, ry, r[1], {size = 19 * s, color = "label", font = "cond"})
        local vw = d:text_size(r[2], {size = 19 * s, font = "cond_medium"})
        d:text(x + w - 12 * s - vw, ry, r[2], {size = 19 * s, color = "value", font = "cond_medium"})
    end
end)

cleria.ui.page("Run HUD", function(p)
    p:section("Panel")
    local v, ch = p:toggle("Show the panel", show, "Room and run time, kills, deaths and damage per second, in a corner.")
    if ch then show = v S.set("Show", v) end
    v, ch = p:choice("Corner", corner, {"Top left", "Top right", "Bottom right"}, "Where the panel is drawn.")
    if ch then corner = v S.set("Corner", v) end
    v, ch = p:toggle("Damage per second", show_dps, "Your damage over the last five seconds.")
    if ch then show_dps = v S.set("ShowDps", v) end
    p:section("This save")
    p:info("Time played", clock(run.ticks), "Cutscenes and text boxes do not count.")
    p:info("Kills", tostring(run.kills))
    p:info("Deaths", tostring(run.deaths))
    p:info("Bosses beaten", tostring(run.bosses))
    p:info("Damage dealt", tostring(run.dealt), "Best single hit: " .. run.best)
    p:info("Damage taken", tostring(run.taken), run.hits .. " hits")
    p:info("Rooms entered", tostring(run.rooms))
end)

cleria.command("hud", function()
    cleria.log(string.format("run ticks %d room %d kills %d deaths %d dealt %d taken %d hits %d best %d rooms %d dps %.0f",
                             run.ticks, room_ticks, run.kills, run.deaths, run.dealt, run.taken, run.hits, run.best, run.rooms, dps()))
end)
cleria.log("Run HUD loaded")
