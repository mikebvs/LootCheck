-- Content phase dates and the graph's phase filter.
-- These dates are a different thing from the graph's "current wishlist" count,
-- and the tests below hold that line: the two must not become one number.
local function section(t) print("\n=== " .. t .. " ===") end
local function click(button) button._scripts.OnClick(button) end
local Phases = LootCheck.Phases

local realPrint = print
local function capture(fn)
    local out = {}
    print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
        tinsert(out, table.concat(parts, " "))
    end
    local ok, err = pcall(fn)
    print = realPrint
    assert(ok, err)
    return table.concat(out, "\n")
end

section("the table has five phases, oldest first, with P4 and P5 undated")
LootCheckDB.phaseDates = {}
local list = Phases:List()
assert(#list == 5, "five phases, got " .. #list)
assert(list[1].key == "P1" and list[5].key == "P5", "sorted oldest first")
assert(list[1].announced and list[2].announced and list[3].announced, "P1-P3 have dates")
assert(not list[4].announced and not list[5].announced, "P4 and P5 do not")
assert(list[4].name:find("Zul'Aman", 1, true), "P4 is Zul'Aman: " .. list[4].name)
assert(list[5].name:find("Sunwell", 1, true), "P5 is Sunwell: " .. list[5].name)
assert(list[4].date == Phases.PLACEHOLDER, "the placeholder date is used: " .. list[4].date)

section("dates parse, and an unannounced one sorts after every real date")
assert(Phases:Epoch("2026-08-27"), "a real date parses")
assert(Phases:Epoch("9999-01-01") == math.huge, "the placeholder is effectively infinite")
assert(Phases:Epoch("27/08/2026") == nil, "only YYYY-MM-DD is accepted")
assert(Phases:Epoch("2026-13-01") == nil, "month 13 is refused")
assert(Phases:Epoch("2026-08-32") == nil, "day 32 is refused")
assert(Phases:Epoch(nil) == nil and Phases:Epoch(42) == nil, "junk is refused")
assert(Phases:Epoch("2026-05-14") > Phases:Epoch("2026-02-05"), "later dates are larger")

section("a phase runs until the next announced one")
local p1From, p1To = Phases:Bounds("P1")
local p2From = Phases:Bounds("P2")
assert(p1From and p1To and p1To == p2From, "P1 ends where P2 begins")

local _, p3To = Phases:Bounds("P3")
assert(p3To == nil, "the newest announced phase has no end yet")

local p4From, p4To = Phases:Bounds("P4")
assert(p4From == nil and p4To == nil, "an unannounced phase has no window at all")

section("the current phase is the latest one that has started")
local current = Phases:Current()
assert(current and current.announced, "there is a current phase")
assert(current.epoch <= GetServerTime(), "and it has actually started")

section("a date can be set by hand, and reset")
local ok, message = Phases:Set("P4", "2026-10-15")
assert(ok and message:find("2026-10-15", 1, true), message)
assert(Phases:Get("P4").announced, "P4 now has a date")
assert(Phases:Get("P4").overridden, "and is marked as set by you")

-- with P4 dated, P3 now ends where P4 starts
local _, newP3To = Phases:Bounds("P3")
assert(newP3To == Phases:Get("P4").epoch, "P3 now ends at P4")

ok, message = Phases:Set("P4", "nonsense")
assert(not ok and message:find("YYYY-MM-DD", 1, true), message)
assert(Phases:Get("P4").date == "2026-10-15", "a rejected date leaves the old one alone")

ok, message = Phases:Set("P9", "2026-10-15")
assert(not ok and message:find("no such phase", 1, true), message)

ok = Phases:Set("P4", "reset")
assert(ok and not Phases:Get("P4").announced, "reset puts the placeholder back")
assert(not Phases:Get("P4").overridden, "and clears the override")

section("/lchelp phase prints the table and sets dates")
local out = capture(function() SlashCmdList.LOOTCHECK("phase") end)
assert(out:find("P1", 1, true) and out:find("P5", 1, true), "every phase is listed")
assert(out:find("not announced", 1, true), "undated phases say so")
assert(out:find("<- now", 1, true), "the current phase is marked")

out = capture(function() SlashCmdList.LOOTCHECK("phase p4 2026-10-15") end)
assert(Phases:Get("P4").date == "2026-10-15", "a lowercase key works: " .. out)
capture(function() SlashCmdList.LOOTCHECK("phase P4 reset") end)

section("the graph filters by phase, and a phase beats the day count")
LootCheck.db.settings.graphPhase = ""
LootCheck.db.settings.graphDays = 0
LootCheck.Graph:Open()
local page = LootCheckGraphFrame
assert(page.phaseLabel:GetText():find("All time", 1, true), page.phaseLabel:GetText())
assert(page.header2:GetText():find("wishlist", 1, true),
    "the default column still says wishlist, not phase: " .. page.header2:GetText())
assert(not page.header2:GetText():find("phase", 1, true),
    "and must not call the wishlist count a phase: " .. page.header2:GetText())

local allTimeTotal = 0
for _, row in ipairs(LootCheck.Graph._rows) do
    if row:IsShown() and row.data then allTimeTotal = allTimeTotal + row.data.count end
end

-- step to P1, which cannot contain awards that landed after it ended
click(page.nextPhase)
assert(LootCheck.db.settings.graphPhase == "P1", "stepped to P1")
assert(page.phaseLabel:GetText():find("P1", 1, true), page.phaseLabel:GetText())
assert(page.header2:GetText():find("P1", 1, true), "the column follows the phase")
assert(page.header2:GetText():find("T4", 1, true),
    "and names the tier that phase drops: " .. page.header2:GetText())

-- Only P1's own tier counts towards its token column
for _, row in ipairs(LootCheck.Graph._rows) do
    if row:IsShown() and row.data then
        for _, item in ipairs(row.data.tokenItems or {}) do
            assert(LootCheck:TokenTier(item.itemID) == "T4",
                ("%s counted towards P1"):format(tostring(item.itemName)))
        end
    end
end

local p1Total = 0
for _, row in ipairs(LootCheck.Graph._rows) do
    if row:IsShown() and row.data then p1Total = p1Total + row.data.count end
end
assert(p1Total <= allTimeTotal, "a phase cannot hold more than everything")

-- an undated phase shows nothing rather than everything
LootCheck.db.settings.graphPhase = "P5"
LootCheck.Graph:Refresh()
local p5Total = 0
for _, row in ipairs(LootCheck.Graph._rows) do
    if row:IsShown() and row.data then p5Total = p5Total + row.data.count end
end
assert(p5Total == 0, "a phase with no date has no awards, got " .. p5Total)
assert(page.phaseLabel:GetText():find("no date yet", 1, true), page.phaseLabel:GetText())

-- a day count must not quietly narrow a chosen phase as well
LootCheck.db.settings.graphPhase = "P1"
LootCheck.db.settings.graphDays = 1
LootCheck.Graph:Refresh()
local withDays = 0
for _, row in ipairs(LootCheck.Graph._rows) do
    if row:IsShown() and row.data then withDays = withDays + row.data.count end
end
assert(withDays == p1Total, "the phase window wins over the day count")
assert(page.subtitle:GetText():find("during P1", 1, true), page.subtitle:GetText())

section("the stepper wraps around")
LootCheck.db.settings.graphPhase = ""
LootCheck.db.settings.graphDays = 0
LootCheck.Graph:Refresh()
click(page.prevPhase)
assert(LootCheck.db.settings.graphPhase == "P5", "stepping back from All time wraps to the last phase")
click(page.nextPhase)
assert(LootCheck.db.settings.graphPhase == "", "and forward again wraps to All time")

section("cleanup")
LootCheck.Window:Hide()
LootCheck.db.settings.graphPhase = ""
LootCheck.db.settings.graphDays = 0
LootCheckDB.phaseDates = {}

print("\nPHASE TESTS PASSED")
