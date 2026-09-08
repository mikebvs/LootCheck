-- Manual wishlist edits (/lchelp giveitem, removeitem, wishlist, overrides, clearoverrides).
-- Runs after test.lua in the same VM: Gargul stub + real saved variables are already in place.
local function section(t) print("\n=== " .. t .. " ===") end
local function link(itemID, name)
    return ("|cffa335ee|Hitem:%d::::::::70::::::::::|h[%s]|h|r"):format(itemID, name or ("item" .. itemID))
end
local function tooltipLines(itemID)
    SimulateTooltip(GameTooltip, "x", link(itemID), {})
    local t = {}
    for i = 1, GameTooltip:NumLines() do t[i] = _G["GameTooltipTextLeft" .. i]:GetText() end
    return t
end
local function findLine(lines, name)
    for _, l in ipairs(lines) do
        local plain = LootCheck:StripColorCodes(l):lower()
        local s, e = plain:find(name:lower(), 1, true)
        if s and plain:sub(1, s - 1):match("^%s*$") then
            local after = plain:sub(e + 1, e + 1)
            if after == "[" or after == " " then return l end
        end
    end
end
local function countFor(norm)
    for _, r in ipairs(LootCheck.Data:WishlistAwardCounts({})) do
        if r.normName == norm then return r.count end
    end
    return 0
end
local function norm(name)
    name = tostring(name or ""):lower():gsub("%s+", ""):gsub("%(os%)", "")
    return name:match("^([^%-]+)") or name
end

-- Discover imported (player, item) pairs from the current data:
--   notReceived: single non-OS wishlist entry, player never awarded the item
--   received:    single non-OS wishlist entry, player got it via an MS award
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
        local pair = {
            who = who, name = e.character_name, id = id, item = e.item_name, prio = e.sort_order,
            display = LootCheck.Data:Roster()[who].displayName,
        }
        if not a and not notReceivedPair then notReceivedPair = pair end
        if a and a.ms > 0 and not receivedPair then receivedPair = pair end
    end
end
assert(notReceivedPair, "no imported, not-yet-received wishlist entry in the data")
assert(receivedPair, "no imported, received wishlist entry in the data")
print(("not-received pair: %s / %s (prio %s)"):format(notReceivedPair.display, notReceivedPair.item, tostring(notReceivedPair.prio)))
print(("received pair:     %s / %s"):format(receivedPair.display, receivedPair.item))

-- Baseline graph total before any manual edits; must be unchanged once they are cleared again
local baselineTotal = 0
for _, r in ipairs(LootCheck.Data:WishlistAwardCounts({})) do baselineTotal = baselineTotal + r.count end

-- Capture everything printed during fn (still echoed to stdout)
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

section("addwlitem: PUG not in TMBExport, plain item name (unique match)")
local out = capture(function() SlashCmdList.LOOTCHECK("addwlitem Newguy Tsunami Talisman") end)
assert(out:find("added Tsunami Talisman to Newguy's wishlist as prio 1", 1, true), out)
assert(LootCheck.Data:Roster()["newguy"], "Newguy should now be in the roster")
local p = LootCheck.Data:WishlistIndex()[30627]["newguy"]
assert(p and #p.entries == 1 and p.entries[1].prio == 1 and p.entries[1].manual, "manual entry expected")
local lines = tooltipLines(30627)
local l = findLine(lines, "Newguy")
assert(l and l:find("^|c00FFFFFF    Newguy%[1%]"), "Newguy should be white (class unknown) on the tooltip: " .. tostring(l))

section("addwlitem: duplicate is refused")
out = capture(function() SlashCmdList.LOOTCHECK("addwlitem Newguy Tsunami Talisman") end)
assert(out:find("already on Newguy's wishlist", 1, true), out)
assert(#LootCheck.Data:WishlistIndex()[30627]["newguy"].entries == 1, "no duplicate")

section("addwlitem: #prio + os flags, realm suffix, class picked up from the group")
SetTestGroup({ "Newguy" })
SetTestClasses({ Newguy = "ROGUE" })
out = capture(function() SlashCmdList.LOOTCHECK("addwlitem Newguy-Testrealm Tsunami Talisman #3 os") end)
assert(out:find("as prio 3 (OS)", 1, true), out)
p = LootCheck.Data:WishlistIndex()[30627]["newguy"]
assert(#p.entries == 2, "MS + OS entries expected")
lines = tooltipLines(30627)
for _, x in ipairs(lines) do print("   " .. x) end
local rogue = LootCheck:ClassHex("ROGUE")
local osLine, msLine
for _, x in ipairs(lines) do
    if x:find("Newguy (OS)[3]", 1, true) then osLine = x end
    if x:find("Newguy[1]", 1, true) then msLine = x end
end
assert(osLine and osLine:find("^|c00" .. rogue), "OS entry should be rogue-coloured: " .. tostring(osLine))
assert(msLine and msLine:find("^|c00" .. rogue), "MS entry should now be rogue-coloured too: " .. tostring(msLine))
SetTestGroup({})
SetTestClasses({})

section("addwlitem: item known only from Gargul's award history (nobody wishlisted 29764)")
out = capture(function() SlashCmdList.LOOTCHECK("addwlitem Newguy Pauldrons of the Fallen Defender") end)
assert(out:find("added Pauldrons of the Fallen Defender to Newguy's wishlist as prio 4", 1, true), out)

section("addwlitem: item link")
out = capture(function() SlashCmdList.LOOTCHECK("addwlitem Newguy " .. link(30247, "Leggings of the Vanquished Hero")) end)
assert(out:find("added Leggings of the Vanquished Hero to Newguy's wishlist as prio 5", 1, true), out)

section("addwlitem: ambiguous / unknown / missing arguments add nothing")
local addedBefore = LootCheck.Wishlist:Counts()
out = capture(function() SlashCmdList.LOOTCHECK("addwlitem Newguy of the") end)
assert(out:find("matches %d+ items"), out)
out = capture(function() SlashCmdList.LOOTCHECK("addwlitem Newguy Totally Made Up Item") end)
assert(out:find("unknown item", 1, true), out)
out = capture(function() SlashCmdList.LOOTCHECK("addwlitem Newguy") end)
assert(out:find("Usage", 1, true), out)
out = capture(function() SlashCmdList.LOOTCHECK("addwlitem") end)
assert(out:find("Usage", 1, true), out)
assert(LootCheck.Wishlist:Counts() == addedBefore, "nothing should have been added")

section("graph: manual wishlister shows up (Newguy has no awards -> 0)")
local rows = LootCheck.Data:WishlistAwardCounts({})
local newguyRow
for _, r in ipairs(rows) do if r.normName == "newguy" then newguyRow = r end end
assert(newguyRow and newguyRow.count == 0, "Newguy row expected with count 0")

section("removewlitem: manual entries (both MS and OS go)")
out = capture(function() SlashCmdList.LOOTCHECK("removewlitem Newguy Tsunami Talisman") end)
assert(out:find("removed Tsunami Talisman from Newguy's wishlist", 1, true), out)
assert(not (LootCheck.Data:WishlistIndex()[30627] or {})["newguy"], "both Newguy entries for 30627 should be gone")
out = capture(function() SlashCmdList.LOOTCHECK("removewlitem Newguy Tsunami Talisman") end)
assert(out:find("not on Newguy's wishlist", 1, true), out)

section("removewlitem: imported entry leaves the tooltip; giveitem restores the original")
local P = notReceivedPair
lines = tooltipLines(P.id)
assert(findLine(lines, P.display), P.display .. " should be on the tooltip before removal")
out = capture(function() SlashCmdList.LOOTCHECK("removewlitem " .. P.name .. " " .. link(P.id, P.item)) end)
assert(out:find("removed " .. P.item .. " from " .. P.display .. "'s wishlist", 1, true), out)
lines = tooltipLines(P.id)
assert(not findLine(lines, P.display), P.display .. " should be hidden after removal")
local _, removedCount = LootCheck.Wishlist:Counts()
assert(removedCount == 1, "one removed override expected")
out = capture(function() SlashCmdList.LOOTCHECK("addwlitem " .. P.name .. " " .. link(P.id, P.item)) end)
assert(out:find(("restored %s on %s's wishlist (prio %s)"):format(P.item, P.display, tostring(P.prio)), 1, true), out)
lines = tooltipLines(P.id)
l = findLine(lines, P.display)
assert(l and l:find("[" .. tostring(P.prio) .. "]", 1, true), "original imported entry should be back: " .. tostring(l))
_, removedCount = LootCheck.Wishlist:Counts()
assert(removedCount == 0, "removed override should be cleared")

section("removewlitem: a received imported entry drops the graph count")
local R = receivedPair
local before = countFor(R.who)
assert(before > 0, "received pair should have a count")
SlashCmdList.LOOTCHECK("removewlitem " .. R.name .. " " .. link(R.id, R.item))
assert(countFor(R.who) == before - 1, "count should drop by one")
SlashCmdList.LOOTCHECK("addwlitem " .. R.name .. " " .. link(R.id, R.item))
assert(countFor(R.who) == before, "count should be restored")

section("wishlist view / overrides listing")
out = capture(function() SlashCmdList.LOOTCHECK("wishlist Newguy") end)
assert(out:find("Newguy's wishlist (2 entries)", 1, true) and out:find("manual", 1, true), out)
out = capture(function() SlashCmdList.LOOTCHECK("wishlist " .. receivedPair.name) end)
assert(out:find(receivedPair.display .. "'s wishlist", 1, true) and out:find("(received)", 1, true), out)
out = capture(function() SlashCmdList.LOOTCHECK("wishlist Nobodyatall") end)
assert(out:find("no wishlist entries", 1, true), out)
out = capture(function() SlashCmdList.LOOTCHECK("wishlist") end)
assert(out:find("Usage", 1, true), out)
out = capture(function() SlashCmdList.LOOTCHECK("overrides") end)
assert(out:find("2 added, 0 removed", 1, true), out)
out = capture(function() SlashCmdList.LOOTCHECK("status") end)
assert(out:find("Manual wishlist edits: 2 added, 0 removed", 1, true), out)

section("overrides live in LootCheckDB and survive a fresh index build")
assert(#LootCheckDB.overrides.tmbexport.added == 2, "2 manual adds expected in saved variables")
LootCheck.Data:Invalidate()
assert(LootCheck.Data:Roster()["newguy"], "Newguy still present after rebuild")

section("clearoverrides needs confirm")
out = capture(function() SlashCmdList.LOOTCHECK("clearoverrides") end)
assert(out:find("confirm", 1, true), out)
assert(#LootCheckDB.overrides.tmbexport.added == 2, "not cleared without confirm")
out = capture(function() SlashCmdList.LOOTCHECK("clearoverrides confirm") end)
assert(out:find("cleared 2 added and 0 removed", 1, true), out)
assert(#LootCheckDB.overrides.tmbexport.added == 0, "cleared")
assert(not LootCheck.Data:Roster()["newguy"], "Newguy gone after clearing")
out = capture(function() SlashCmdList.LOOTCHECK("overrides") end)
assert(out:find("no manual wishlist edits", 1, true), out)

section("graph baseline unchanged after clearing")
local total = 0
for _, r in ipairs(LootCheck.Data:WishlistAwardCounts({})) do total = total + r.count end
assert(total == baselineTotal, ("expected baseline %d, got %d"):format(baselineTotal, total))

print("\nWISHLIST TESTS PASSED")
