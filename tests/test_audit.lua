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
assert(LootCheckAuditFrame.count:GetText() == (#entries .. " entries"), LootCheckAuditFrame.count:GetText())
LootCheckAuditFrame.wishlistOnly:SetChecked(true); click(LootCheckAuditFrame.wishlistOnly)
assert(LootCheck.db.settings.auditWishlistOnly == true, "setting stored")
assert(LootCheckAuditFrame.count:GetText() == ((#only + 4) .. " entries"), "filtered count: " .. LootCheckAuditFrame.count:GetText())
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

print("\nAUDIT TESTS PASSED")
