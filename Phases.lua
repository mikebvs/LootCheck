--[[
    LootCheck - Phases.lua

    Content phase dates for TBC Anniversary, used by the graph's phase filter.

    These are dates, and they are a different thing from what the graph column
    has always called "this phase" - that number counts awards against the
    wishlist you currently have imported, and has never involved a date. The
    two live side by side on purpose: the wishlist-relative count is what a
    loot council usually wants, and the phase filter answers "what did they get
    during Black Temple?".

    Blizzard's roadmap numbers Zul'Aman as phase 3.5 and Sunwell as phase 4.
    The guild convention of P4 and P5 is used here instead. Neither has a
    confirmed date, so both sit on the placeholder until one is announced:

        /lchelp phase P4 2026-10-15

    which is remembered in LootCheckDB, so no addon update is needed when
    Blizzard says when.
]]

local LC = LootCheck
local Phases = {}
LC.Phases = Phases

-- A phase with this date has not been announced yet
Phases.PLACEHOLDER = "9999-01-01"

--- Announced dates for the Anniversary realms. Overridable per phase, see Set.
Phases.DEFAULTS = {
    { key = "P1", name = "Karazhan, Gruul, Magtheridon", date = "2026-02-05" },
    { key = "P2", name = "Serpentshrine Cavern, Tempest Keep", date = "2026-05-14" },
    { key = "P3", name = "Black Temple, Mount Hyjal", date = "2026-08-27" },
    { key = "P4", name = "Zul'Aman", date = Phases.PLACEHOLDER },
    { key = "P5", name = "Sunwell Plateau", date = Phases.PLACEHOLDER },
}

local function Overrides()
    LC.db = LC.db or LootCheckDB or {}
    if type(LC.db.phaseDates) ~= "table" then LC.db.phaseDates = {} end
    return LC.db.phaseDates
end

local function Now()
    return (GetServerTime and GetServerTime()) or time()
end

------------------------------------------------------------------------------
-- Dates
------------------------------------------------------------------------------

--- "2026-08-27" -> seconds since the epoch, or nil when it is not a date.
--- An unannounced phase returns math.huge, which compares correctly against
--- any real timestamp without asking the C library to handle the year 9999.
function Phases:Epoch(date)
    if type(date) ~= "string" then return nil end

    local y, m, d = date:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then return nil end
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if m < 1 or m > 12 or d < 1 or d > 31 then return nil end

    if y >= 9000 then return math.huge end

    local ok, stamp = pcall(time, { year = y, month = m, day = d, hour = 0, min = 0, sec = 0 })
    if ok and type(stamp) == "number" then return stamp end
    return nil
end

function Phases:IsAnnounced(date)
    return self:Epoch(date) ~= math.huge
end

--- Every phase, oldest first: { key, name, date, epoch, announced }
function Phases:List()
    local overrides = Overrides()
    local list = {}

    for _, spec in ipairs(self.DEFAULTS) do
        local date = overrides[spec.key] or spec.date
        local epoch = self:Epoch(date)
        if not epoch then -- a bad override should not hide the phase
            date, epoch = spec.date, self:Epoch(spec.date)
        end
        -- A date the client cannot turn into a timestamp sorts as unannounced
        -- rather than crashing the comparison below
        epoch = epoch or math.huge
        tinsert(list, {
            key = spec.key,
            name = spec.name,
            date = date,
            epoch = epoch,
            announced = epoch ~= math.huge,
            overridden = overrides[spec.key] ~= nil,
        })
    end

    table.sort(list, function(a, b)
        if a.epoch ~= b.epoch then return a.epoch < b.epoch end
        return a.key < b.key
    end)
    return list
end

function Phases:Get(key)
    for _, phase in ipairs(self:List()) do
        if phase.key == key then return phase end
    end
    return nil
end

--- The window a phase covers: from its start until the next announced phase.
--- The newest phase has no end, so `to` is nil.
function Phases:Bounds(key)
    local list = self:List()
    for i, phase in ipairs(list) do
        if phase.key == key then
            if not phase.announced then return nil, nil end
            local following = list[i + 1]
            local to = (following and following.announced) and following.epoch or nil
            return phase.epoch, to
        end
    end
    return nil, nil
end

--- The phase we are in now: the latest one that has actually started.
function Phases:Current()
    local now, current = Now(), nil
    for _, phase in ipairs(self:List()) do
        if phase.announced and phase.epoch <= now then current = phase end
    end
    return current
end

--- "P3 - Black Temple, Mount Hyjal"
function Phases:Label(key)
    local phase = self:Get(key)
    if not phase then return "All time" end
    return ("%s - %s"):format(phase.key, phase.name)
end

--- Set or clear a phase's date. `date` of nil or "reset" restores the default.
--- Returns ok, message.
function Phases:Set(key, date)
    local phase = self:Get(key)
    if not phase then
        return false, ("no such phase '%s'."):format(tostring(key))
    end

    if date == nil or date == "" or date:lower() == "reset" or date:lower() == "default" then
        Overrides()[phase.key] = nil
        LC.Data:Invalidate()
        return true, ("%s is back to its default date (%s)."):format(phase.key, self:Get(phase.key).date)
    end

    if not self:Epoch(date) then
        return false, ("'%s' is not a date. Use YYYY-MM-DD, for example 2026-10-15."):format(tostring(date))
    end

    Overrides()[phase.key] = date
    LC.Data:Invalidate()
    return true, ("%s (%s) now starts on %s."):format(phase.key, phase.name, date)
end

--- The keys the graph's phase stepper cycles through: all time, then each phase
function Phases:StepperKeys()
    local keys = { "" } -- "" is all time
    for _, phase in ipairs(self:List()) do
        tinsert(keys, phase.key)
    end
    return keys
end

--- Print the table to chat (/lchelp phase)
function Phases:Print()
    local current = self:Current()
    LC:Print("content phases (dates only affect the graph's phase filter):")

    for _, phase in ipairs(self:List()) do
        local marker = (current and current.key == phase.key) and " |cff40c040<- now|r" or ""
        local when = phase.announced and phase.date or "|cff7f7f7fnot announced|r"
        local tag = phase.overridden and " |cffffd100(set by you)|r" or ""
        print(("  |cffffffff%s|r  %-14s %s%s%s"):format(phase.key, when, phase.name, tag, marker))
    end

    LC:Print("set one with |cff33ccff/lchelp phase P4 2026-10-15|r, or |cff33ccff/lchelp phase P4 reset|r.")
end
