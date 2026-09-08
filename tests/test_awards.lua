-- Manual "received" marks: /lchelp giveitem + removeitem, hiding / restoring Gargul awards.
-- Runs last: TMBExport fallback active, wishlist overrides cleared, history log populated.
local function section(t) print("\n=== " .. t .. " ===") end
local function link(itemID, name)
    return ("|cffa335ee|Hitem:%d::::::::70::::::::::|h[%s]|h|r"):format(itemID, name or ("item" .. itemID))
end
local function norm(name)
    name = tostring(name or ""):lower():gsub("%s+", ""):gsub("%(os%)", "")
    return name:match("^([^%-]+)") or name
end
local function rowFor(n)
    for _, r in ipairs(LootCheck.Data:WishlistAwardCounts({})) do
        if r.normName == n then return r end
    end
end
local function lineFor(itemID, display)
    SimulateTooltip(GameTooltip, "x", link(itemID), {})
    for i = 2, GameTooltip:NumLines() do
        local t = _G["GameTooltipTextLeft" .. i]:GetText() or ""
        local plain = LootCheck:StripColorCodes(t):lower()
        local s, e = plain:find(display:lower(), 1, true)
        if s and plain:sub(1, s - 1):match("^%s*$") then
            local after = plain:sub(e + 1, e + 1)
            if after == "[" or after == " " then return t end
        end
    end
end
local GREY = "|cff7f7f7f"
local function isGrey(t) return (t or ""):find(GREY, 1, true) ~= nil end
local function count(tbl) local n = 0 for _ in pairs(tbl or {}) do n = n + 1 end return n end
local realPrint = print
local function capture(fn)
    local captured = {}
    print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
        local s = table.concat(parts, " ")
        tinsert(captured, s)
        realPrint(s)
    end
    local ok, err = pcall(fn)
    print = realPrint
    assert(ok, err)
    return table.concat(captured, "\n")
end

-- Discover pairs from the current data (single non-OS wishlist entry each):
--   notReceived: no award at all;  received: exactly one MS Gargul award, no OS award
local awardFlags = {}
for _, loot in pairs(GargulDB.AwardHistory) do
    local k = norm(loot.awardedTo) .. "|" .. tostring(tonumber(loot.itemID))
    awardFlags[k] = awardFlags[k] or { ms = 0, os = 0 }
    if loot.OS then awardFlags[k].os = awardFlags[k].os + 1 else awardFlags[k].ms = awardFlags[k].ms + 1 end
end
local entryCounts = {}
for _, e in ipairs(TMBExportDB.wishlists) do
    if not e.is_offspec then
        local k = norm(e.character_name) .. "|" .. tostring(tonumber(e.item_id))
        entryCounts[k] = (entryCounts[k] or 0) + 1
    end
end
local notReceivedPair, receivedPair
for _, e in ipairs(TMBExportDB.wishlists) do
    local who, id = norm(e.character_name), tonumber(e.item_id)
    local k = who .. "|" .. tostring(id)
    if not e.is_offspec and entryCounts[k] == 1 and e.item_name and e.item_name ~= "" then
        local a = awardFlags[k]
        local pair = { who = who, name = e.character_name, id = id, item = e.item_name,
                       display = LootCheck.Data:Roster()[who].displayName }
        if not a and not notReceivedPair then notReceivedPair = pair end
        if a and a.ms == 1 and a.os == 0 and not receivedPair then receivedPair = pair end
    end
end
assert(notReceivedPair and receivedPair, "no suitable pairs in the data")
print(("not-received pair: %s / %s"):format(notReceivedPair.display, notReceivedPair.item))
print(("received pair:     %s / %s"):format(receivedPair.display, receivedPair.item))

section("giveitem: manual received mark greys the tooltip and counts (current wishlist + all time)")
local P = notReceivedPair
assert(not isGrey(lineFor(P.id, P.display)), "should not be grey before")
local before = rowFor(P.who)
local out = capture(function() SlashCmdList.LOOTCHECK(("giveitem %s %s"):format(P.name, link(P.id, P.item))) end)
assert(out:find("marked " .. P.item .. " as received by " .. P.display, 1, true), out)
assert(isGrey(lineFor(P.id, P.display)), "should be grey after")
local after = rowFor(P.who)
assert(after.count == before.count + 1, "current count +1")
assert(after.history == before.history + 1, "all-time +1")
assert(count(LootCheckDB.manualAwards) == 1, "one manual mark stored")
out = capture(function() SlashCmdList.LOOTCHECK("check " .. link(P.id, P.item)) end)
assert(out:find("manual mark", 1, true), out)

section("giveitem: duplicate refused unless force; count stays capped by the single wishlist entry")
out = capture(function() SlashCmdList.LOOTCHECK(("giveitem %s %s"):format(P.name, link(P.id, P.item))) end)
assert(out:find("already marked as received", 1, true), out)
assert(count(LootCheckDB.manualAwards) == 1, "still one mark")
out = capture(function() SlashCmdList.LOOTCHECK(("giveitem %s %s force"):format(P.name, link(P.id, P.item))) end)
assert(out:find("marked " .. P.item, 1, true), out)
assert(count(LootCheckDB.manualAwards) == 2, "two marks")
assert(rowFor(P.who).count == before.count + 1, "still +1")

section("removeitem: removes all manual marks; count and all-time go back")
out = capture(function() SlashCmdList.LOOTCHECK(("removeitem %s %s"):format(P.name, link(P.id, P.item))) end)
assert(out:find("removed 2 manual received mark", 1, true), out)
assert(count(LootCheckDB.manualAwards) == 0, "marks gone")
assert(not isGrey(lineFor(P.id, P.display)), "not grey any more")
after = rowFor(P.who)
assert(after.count == before.count and after.history == before.history, "back to baseline")
out = capture(function() SlashCmdList.LOOTCHECK(("removeitem %s %s"):format(P.name, link(P.id, P.item))) end)
assert(out:find("is not marked as received", 1, true), out)

section("giveitem ... os: greys while greyOSAwards is on, never counts")
SlashCmdList.LOOTCHECK(("giveitem %s %s os"):format(P.name, link(P.id, P.item)))
assert(isGrey(lineFor(P.id, P.display)), "OS mark greys")
assert(rowFor(P.who).count == before.count, "OS mark does not count")
LootCheck.db.settings.greyOSAwards = false
assert(not isGrey(lineFor(P.id, P.display)), "not grey with greyOSAwards off")
LootCheck.db.settings.greyOSAwards = true
SlashCmdList.LOOTCHECK(("removeitem %s %s"):format(P.name, link(P.id, P.item)))
assert(count(LootCheckDB.manualAwards) == 0)

section("removeitem hides a Gargul award (counts drop); giveitem restores it")
local R = receivedPair
assert(isGrey(lineFor(R.id, R.display)), "received pair grey before")
local rBefore = rowFor(R.who)
out = capture(function() SlashCmdList.LOOTCHECK(("removeitem %s %s"):format(R.name, link(R.id, R.item))) end)
assert(out:find("hidden Gargul's award", 1, true), out)
assert(not isGrey(lineFor(R.id, R.display)), "not grey after hiding")
local rAfter = rowFor(R.who)
assert(rAfter.count == rBefore.count - 1, "current -1")
assert(rAfter.history == rBefore.history - 1, ("all-time -1: %d -> %d"):format(rBefore.history, rAfter.history))
assert(count(LootCheckDB.ignoredAwards) == 1, "one hidden award")
out = capture(function() SlashCmdList.LOOTCHECK("check " .. link(R.id, R.item)) end)
local awardsSection = out:match("Gargul awards(.*)$") or ""
assert(not awardsSection:find(R.display .. " - ", 1, true), "hidden award must not show under Gargul awards: " .. out)
out = capture(function() SlashCmdList.LOOTCHECK(("giveitem %s %s"):format(R.name, link(R.id, R.item))) end)
assert(out:find("restored Gargul's award", 1, true), out)
assert(count(LootCheckDB.ignoredAwards) == 0 and count(LootCheckDB.manualAwards) == 0, "restored, no manual mark added")
assert(isGrey(lineFor(R.id, R.display)), "grey again")
rAfter = rowFor(R.who)
assert(rAfter.count == rBefore.count and rAfter.history == rBefore.history, "counts restored")

section("giveitem for someone with no wishlist entry for the item")
out = capture(function() SlashCmdList.LOOTCHECK("giveitem Randomguy " .. link(P.id, P.item)) end)
assert(out:find("not on their wishlist", 1, true), out)
assert(count(LootCheckDB.manualAwards) == 1)
SlashCmdList.LOOTCHECK("removeitem Randomguy " .. link(P.id, P.item))
assert(count(LootCheckDB.manualAwards) == 0)

section("usage / unknown item")
out = capture(function() SlashCmdList.LOOTCHECK("giveitem") end)
assert(out:find("Usage", 1, true), out)
out = capture(function() SlashCmdList.LOOTCHECK("removeitem Bob") end)
assert(out:find("Usage", 1, true), out)
out = capture(function() SlashCmdList.LOOTCHECK("giveitem Bob Totally Made Up Item") end)
assert(out:find("unknown item", 1, true), out)

section("wishlist commands still work under their new names")
out = capture(function() SlashCmdList.LOOTCHECK("addwlitem Newguy9 Tsunami Talisman") end)
assert(out:find("added Tsunami Talisman to Newguy9's wishlist", 1, true), out)
out = capture(function() SlashCmdList.LOOTCHECK("removewlitem Newguy9 Tsunami Talisman") end)
assert(out:find("removed Tsunami Talisman from Newguy9's wishlist", 1, true), out)
out = capture(function() SlashCmdList.LOOTCHECK("additem Newguy9 Tsunami Talisman") end)
assert(out:find("added Tsunami Talisman", 1, true), out)
SlashCmdList.LOOTCHECK("removewish Newguy9 Tsunami Talisman")
assert(not LootCheck.Data:Roster()["newguy9"], "alias removed it")

section("overrides + status list the marks")
SlashCmdList.LOOTCHECK(("giveitem %s %s"):format(P.name, link(P.id, P.item)))
out = capture(function() SlashCmdList.LOOTCHECK("overrides") end)
assert(out:find("manual received marks: 1", 1, true), out)
out = capture(function() SlashCmdList.LOOTCHECK("status") end)
assert(out:find("Manual received marks: 1, hidden Gargul awards: 0", 1, true), out)
SlashCmdList.LOOTCHECK(("removeitem %s %s"):format(P.name, link(P.id, P.item)))

print("\nAWARDS TESTS PASSED")
