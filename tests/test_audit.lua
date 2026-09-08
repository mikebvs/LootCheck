-- Audit page: chronological awards + command log, wishlist-only filter.
local function section(t) print("\n=== " .. t .. " ===") end
local function link(itemID, name)
    return ("|cffa335ee|Hitem:%d::::::::70::::::::::|h[%s]|h|r"):format(itemID, name or ("item" .. itemID))
end
local function click(button) button._scripts.OnClick(button) end

section("audit entries: every Gargul award, newest first")
LootCheck.Window:Hide()
LootCheckDB.auditLog = {} -- earlier suites ran manual-edit commands; start from a clean log
local entries = LootCheck.Audit:Entries({})
local gargulCount = 0
for _ in pairs(GargulDB.AwardHistory) do gargulCount = gargulCount + 1 end
local awards, commands = 0, 0
for _, e in ipairs(entries) do
    if e.kind == "award" then awards = awards + 1 else commands = commands + 1 end
end
assert(awards == gargulCount, ("expected %d award entries, got %d"):format(gargulCount, awards))
assert(commands == 0, "no commands logged yet")
for i = 2, #entries do
    assert(entries[i - 1].t >= entries[i].t, "entries must be sorted newest first")
end
print(("%d awards, newest: %s %s"):format(awards, date("%Y-%m-%d", entries[1].t), tostring(entries[1].itemName)))

section("wishlist-only filter keeps only awards that were on the winner's wishlist")
local only = LootCheck.Audit:Entries({ wishlistOnly = true })
assert(#only < #entries and #only > 0, ("filter: %d of %d"):format(#only, #entries))
for _, e in ipairs(only) do
    assert(e.kind ~= "award" or e.wishlisted, "non-wishlist award slipped through")
end
local allTime = 0
for _, r in ipairs(LootCheck.Data:WishlistAwardCounts({})) do allTime = allTime + r.history end
assert(#only >= allTime, "wishlisted awards must cover the all-time count")
print(("%d wishlisted of %d (all-time count %d)"):format(#only, #entries, allTime))

section("giveitem / removeitem / addwlitem / removewlitem are logged")
local before = #LootCheck.Audit:Entries({})
SlashCmdList.LOOTCHECK("addwlitem Auditguy Tsunami Talisman #2")
SlashCmdList.LOOTCHECK("giveitem Auditguy " .. link(30627, "Tsunami Talisman"))
SlashCmdList.LOOTCHECK("removeitem Auditguy " .. link(30627, "Tsunami Talisman"))
SlashCmdList.LOOTCHECK("removewlitem Auditguy Tsunami Talisman")
entries = LootCheck.Audit:Entries({})
assert(#entries == before + 4, ("expected %d entries, got %d"):format(before + 4, #entries))
local seen = {}
for i = 1, 4 do
    assert(entries[i].kind == "command", "the newest entries must be the commands")
    seen[entries[i].cmd] = true
    print("   " .. entries[i].cmd .. ": " .. tostring(entries[i].display) .. " " .. tostring(entries[i].itemName) .. " " .. tostring(entries[i].detail))
end
assert(seen.addwlitem and seen.giveitem and seen.removeitem and seen.removewlitem, "all four commands logged")
assert(#LootCheckDB.auditLog == 4, "command log persisted")
assert(LootCheckDB.auditLog[1].cmd == "addwlitem", "oldest first in the log")

section("page renders rows, check box filters, /lchelp audit toggles")
LootCheck.Audit:Open()
assert(LootCheckAuditFrame and LootCheckAuditFrame:IsShown(), "audit page shown")
assert(LootCheck.Window:Current() == "audit", "window on the audit page")
assert(LootCheckWindow.back:IsShown(), "Back button visible")
local first = LootCheck.Audit._rows[1]
assert(first:IsShown() and first.text:GetText():find("/lchelp", 1, true), "first row: " .. tostring(first.text:GetText()))
for i = 1, 6 do
    local row = LootCheck.Audit._rows[i]
    if row:IsShown() then print(("   %s  %s"):format(row.time:GetText(), row.text:GetText())) end
end
assert(LootCheckAuditFrame.count:GetText():find(#entries .. " entries", 1, true), LootCheckAuditFrame.count:GetText())
LootCheckAuditFrame.wishlistOnly:SetChecked(true); click(LootCheckAuditFrame.wishlistOnly)
assert(LootCheck.db.settings.auditWishlistOnly == true, "setting stored")
assert(LootCheckAuditFrame.count:GetText():find((#only + 4) .. " entries", 1, true), "filtered count: " .. LootCheckAuditFrame.count:GetText())
LootCheckAuditFrame.wishlistOnly:SetChecked(false); click(LootCheckAuditFrame.wishlistOnly)
assert(LootCheck.db.settings.auditWishlistOnly == false)
SlashCmdList.LOOTCHECK("audit")
assert(not LootCheckAuditFrame:IsShown() and not LootCheckWindow:IsShown(), "toggled off")
SlashCmdList.LOOTCHECK("audit")
assert(LootCheckAuditFrame:IsShown(), "toggled on")
LootCheck.Window:Back()
assert(LootCheckConfigFrame:IsShown() and not LootCheckAuditFrame:IsShown(), "Back goes home")
LootCheck.Window:Hide()

section("command log is capped")
local saved = LootCheck.Audit.MAX_LOG
LootCheck.Audit.MAX_LOG = 3
for i = 1, 4 do
    LootCheck.Audit:Log("giveitem", { norm = "cap", character = "Cap", itemID = i, itemName = "Item " .. i })
end
assert(#LootCheckDB.auditLog == 3, "log capped at MAX_LOG")
assert(LootCheckDB.auditLog[3].itemName == "Item 4", "newest kept")
LootCheck.Audit.MAX_LOG = saved
LootCheckDB.auditLog = {}

section("the time range dropdown narrows the list")
LootCheck.db.settings.auditRange = "all"
LootCheck.db.settings.auditWishlistOnly = false
LootCheck.Audit:Open()
local page = LootCheckAuditFrame

assert(page.range, "the dropdown exists")
assert(page.range:GetText() == "All", "it shows the current range: " .. tostring(page.range:GetText()))
local allCount = #LootCheck.Audit._entries

-- Every range is offered, in the order asked for
local wanted = { "Past week", "Past month", "This phase", "Last phase", "All" }
assert(#LootCheck.Audit.RANGES == #wanted, "five ranges, got " .. #LootCheck.Audit.RANGES)
for i, text in ipairs(wanted) do
    assert(LootCheck.Audit.RANGES[i].text == text,
        ("range %d is %s, expected %s"):format(i, LootCheck.Audit.RANGES[i].text, text))
end

-- Opening the menu builds one clickable item per range
page.range:OpenMenu()
assert(page.range._menu:IsShown(), "the menu opens")
local shown = 0
for _, item in ipairs(page.range._menuItems) do
    if item:IsShown() then shown = shown + 1 end
end
assert(shown == #wanted, "one item per range, got " .. shown)

-- Picking one applies it
local weekItem
for _, item in ipairs(page.range._menuItems) do
    if item.value == "week" then weekItem = item end
end
assert(weekItem, "the past week item exists")
click(weekItem)
assert(not page.range._menu:IsShown(), "picking closes the menu")
assert(LootCheck.db.settings.auditRange == "week", "the choice is stored")
assert(page.range:GetText() == "Past week", "and shown on the button")

local weekCount = #LootCheck.Audit._entries
assert(weekCount <= allCount, "a week cannot hold more than everything")
assert(page.count:GetText():find("past week", 1, true), page.count:GetText())

section("each range is a real window, and they nest")
local now = GetServerTime()
local from = LootCheck.Audit:RangeBounds("week")
assert(math.abs((now - from) - 7 * 86400) < 5, "past week is seven days back")
from = LootCheck.Audit:RangeBounds("month")
assert(math.abs((now - from) - 30 * 86400) < 5, "past month is thirty days back")
assert(LootCheck.Audit:RangeBounds("all") == nil, "all has no lower bound")

-- This phase follows the phase dates, so it starts when the current phase did
local current = LootCheck.Phases:Current()
assert(current, "there is a current phase")
local phaseFrom, phaseTo = LootCheck.Audit:RangeBounds("phase")
assert(phaseFrom == current.epoch, "this phase starts at the phase date")
assert(phaseTo == nil, "and has no end while it is the newest")

-- Last phase ends where this one begins
local lastFrom, lastTo = LootCheck.Audit:RangeBounds("lastphase")
assert(lastTo == current.epoch, "last phase ends where this one starts")
assert(lastFrom and lastFrom < lastTo, "and starts before that")

-- Entry counts respect the windows
local function countFor(value)
    LootCheck.db.settings.auditRange = value
    LootCheck.Audit:Refresh()
    return #LootCheck.Audit._entries
end
local monthCount = countFor("month")
assert(countFor("week") <= monthCount, "a week fits inside a month")
assert(monthCount <= allCount, "a month fits inside everything")

local phaseCount = countFor("phase")
local lastPhaseCount = countFor("lastphase")
assert(phaseCount + lastPhaseCount <= allCount, "two phases cannot exceed everything")
for _, e in ipairs(LootCheck.Audit._entries) do
    assert(e.t >= lastFrom and e.t < lastTo, "every last-phase entry is inside that window")
end

section("an empty range says which range is empty")
LootCheck.db.settings.auditRange = "lastphase"
LootCheckDB.phaseDates = { P1 = "2099-01-01" } -- push every phase into the future
LootCheck.Audit:Refresh()
if #LootCheck.Audit._entries == 0 then
    assert(page.empty:IsShown() and page.empty:GetText():find("last phase", 1, true), page.empty:GetText())
end
LootCheckDB.phaseDates = {}

LootCheck.db.settings.auditRange = "all"
LootCheck.Audit:Refresh()
assert(#LootCheck.Audit._entries == allCount, "back to everything")
LootCheck.Window:Hide()

print("\nAUDIT TESTS PASSED")
