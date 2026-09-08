-- End-to-end scenario against the real TMBExport / Gargul saved variables.
local GREY = "|cff7f7f7f"
local function isGrey(fs) return (fs:GetText() or ""):find(GREY, 1, true) ~= nil end
local function isGreyText(s) return (s or ""):find(GREY, 1, true) ~= nil end
local function section(title) print("\n=== " .. title .. " ===") end
local function norm(name)
    name = tostring(name or ""):lower():gsub("%s+", ""):gsub("%(os%)", "")
    return name:match("^([^%-]+)") or name
end
local function link(itemID, name)
    return ("|cffa335ee|Hitem:%d::::::::70::::::::::|h[%s]|h|r"):format(itemID, name or ("item" .. itemID))
end

section("startup")
FireEvent("ADDON_LOADED", "LootCheck")
assert(LootCheck.db and LootCheck.db.settings, "saved variables not initialised")

-- Fake the parts of _G.Gargul the addon touches, backed by the real GargulDB
Gargul_L = setmetatable({}, { __index = function(_, key) return tostring(key) end })
registered = {} -- global: later test files fire Gargul events through it
local gargulSettings = {
    ["TMB.OSHasLowerPriority"] = true,
    ["TMB.maximumNumberOfTooltipEntries"] = 35,
    ["TMB.showRaidGroup"] = false,
    ["TMB.showWishListInfoOnTooltips"] = true,
    ["TMB.hideInfoOfPeopleNotInGroup"] = true,
    ["TMB.showEntriesWhenSolo"] = false,
    ["TMB.hideWishListInfoIfPriorityIsPresent"] = false,
}
local GargulOrig = {}     -- itemID -> lines Gargul's own tooltipLines would produce (stale data)
local raidersOnly = false
local importedFromDFT = false
local function origTooltipLines(_, itemLink)
    local id = tonumber(itemLink:match("item:(%d+)"))
    local out = {}
    for _, line in ipairs(GargulOrig[id] or {}) do tinsert(out, line) end
    return out
end
Gargul = {
    version = "7.8.2-test",
    DB = { AwardHistory = GargulDB.AwardHistory },
    Events = { register = function(_, id, event, cb) registered[event] = cb; return true end },
    getLinkedItemsForID = function(_, id) return { tonumber(id) } end,
    Settings = { get = function(_, key) return gargulSettings[key] end },
    User = { isInGroup = true },
    TMB = {
        tooltipLines = origTooltipLines,
        shouldOnlyIncludeRaiders = function() return raidersOnly end,
        wasImportedFromDFT = function() return importedFromDFT end,
        wasImportedFromCPR = function() return false end,
        wasImportedFromRRobin = function() return false end,
        source = function() return "TMB" end,
    },
}
-- Gargul's own tooltip hook, registered BEFORE PLAYER_LOGIN (real load order)
local function gargulHook(tt)
    local _, itemLink = tt:GetItem()
    for _, line in pairs(Gargul.TMB:tooltipLines(itemLink) or {}) do tt:AddLine(line) end
end
GameTooltip:HookScript("OnTooltipSetItem", gargulHook)
ItemRefTooltip:HookScript("OnTooltipSetItem", gargulHook)

TMBExportDB.settings.showTooltip = true -- fixture: pretend TMBExport's own tooltip is still on
FireEvent("PLAYER_LOGIN")
assert(registered["GL.ITEM_AWARDED"], "GL.ITEM_AWARDED listener not registered")
assert(#GameTooltip._hooks.OnTooltipSetItem == 2, "GameTooltip should have Gargul's + LootCheck's hook")
assert(#ItemRefTooltip._hooks.OnTooltipSetItem == 2, "ItemRefTooltip not hooked")
assert(LootCheck.Tooltip.integrated == true, "integration should be active")
assert(Gargul.TMB.tooltipLines ~= origTooltipLines, "GL.TMB:tooltipLines should be overridden")
assert(TMBExportDB.settings.showTooltip == false, "TMBExport's duplicate tooltip should be switched off at login")
assert(LootCheck.db.tmbTooltipHandled == true, "tmbTooltipHandled flag should be set")

section("/lchelp status")
SlashCmdList.LOOTCHECK("status")

section("/lchelp check 30247")
SlashCmdList.LOOTCHECK("check " .. link(30247, "Leggings of the Vanquished Hero"))

-- Find an item with several non-OS wishlisters where some got it and some didn't
local wishByItem = {}
for _, e in ipairs(TMBExportDB.wishlists) do
    local id = tonumber(e.item_id)
    wishByItem[id] = wishByItem[id] or {}
    local who = norm(e.character_name)
    wishByItem[id][who] = wishByItem[id][who] or { name = e.character_name, os = e.is_offspec, prio = e.sort_order, class = e.character_class }
end
local awardsByItem = {}
for _, loot in pairs(GargulDB.AwardHistory) do
    local id = tonumber(loot.itemID)
    awardsByItem[id] = awardsByItem[id] or {}
    awardsByItem[id][norm(loot.awardedTo)] = true
end
local testItem, received, notReceived
for id, players in pairs(wishByItem) do
    local got, notGot, n = {}, {}, 0
    for who in pairs(players) do
        n = n + 1
        if awardsByItem[id] and awardsByItem[id][who] then tinsert(got, who) else tinsert(notGot, who) end
    end
    if n >= 3 and #got >= 1 and #notGot >= 1 then
        testItem, received, notReceived = id, got, notGot
        break
    end
end
assert(testItem, "no suitable mixed item in the data")
local wl = wishByItem[testItem]
local wlCount = 0
for _ in pairs(wl) do wlCount = wlCount + 1 end
print(("test item %d: %d wishlisters, received=%d, not received=%d"):format(testItem, wlCount, #received, #notReceived))

section("integrated tooltip: Gargul's stale section replaced by TMBExport data")
GargulOrig[testItem] = {
    "\n|c00967FD2TMB|r",
    "|c00FFFFFF    Tier: |c00FF8000S|r",
    "\n|c00FFFFFFTMB Wish List|r",
    "|c005F5F5F    Stalename[1]|r",
    "|c005F5F5F    Anotherstale[2]|r",
}
SimulateTooltip(GameTooltip, "x", link(testItem), {})
DumpTooltip(GameTooltip)
local lines = {}
for i = 1, GameTooltip:NumLines() do lines[i] = _G["GameTooltipTextLeft" .. i]:GetText() end
assert(lines[2] == "\n|c00967FD2TMB|r", "Gargul's lines above the wishlist must be kept")
assert(lines[3] == "|c00FFFFFF    Tier: |c00FF8000S|r", "tier line must be kept")
assert(lines[4] == "\n|c00FFFFFFTMB Wish List|r", "wishlist header must follow")
local joined = table.concat(lines, "\n")
assert(not joined:find("Stalename", 1, true) and not joined:find("Anotherstale", 1, true), "Gargul's stale entries must be gone")
local function lineFor(displayName)
    local needle = displayName:lower()
    for i = 5, #lines do
        local plain = LootCheck:StripColorCodes(lines[i]):lower()
        local s, e = plain:find(needle, 1, true)
        if s and plain:sub(1, s - 1):match("^%s*$") then
            local after = plain:sub(e + 1, e + 1)
            if after == "[" or after == " " then return lines[i] end
        end
    end
end
for who, p in pairs(wl) do
    local l = lineFor(p.name)
    assert(l, "missing wishlist line for " .. p.name)
    local shouldGrey = (awardsByItem[testItem] and awardsByItem[testItem][who]) and true or false
    assert(isGreyText(l) == shouldGrey, ("%s grey=%s expected=%s: %s"):format(p.name, tostring(isGreyText(l)), tostring(shouldGrey), l))
    if not shouldGrey then
        assert(l:find("^|c00" .. LootCheck:ClassHex(p.class)), "class colour expected for " .. p.name .. ": " .. l)
    end
    assert(l:find("%[" .. tostring(p.prio) .. "%]"), "prio missing for " .. p.name .. ": " .. l)
    if p.os then assert(l:find(" (OS)[", 1, true), "OS marker missing for " .. p.name) end
end
-- ordering: prio (+100 for OS) must be non-decreasing
local last = -1
for i = 5, #lines do
    local plain = LootCheck:StripColorCodes(lines[i])
    local prio = tonumber(plain:match("%[(%d+)%]"))
    local key = prio + (plain:find("(OS)", 1, true) and 100 or 0)
    assert(key >= last, "entries out of order at line " .. i)
    last = key
end
print("integrated section OK: " .. (#lines - 4) .. " entries, correct colours/greys/order")

section("the version comes from the .toc, not a second copy in the source")
do
    local fromToc = GetAddOnMetadata("LootCheck", "Version")
    assert(fromToc and fromToc ~= "", "the stub can read the toc")
    assert(LootCheck.version == fromToc,
        ("addon reports %s but the toc says %s"):format(tostring(LootCheck.version), tostring(fromToc)))
    assert(LootCheck.version:match("^%d+%.%d+%.%d+$"), "version is x.y.z: " .. LootCheck.version)
end

section("integrated tooltip: raiders-only filter + max entries + suffix")
raidersOnly = true
SetTestGroup({ wl[received[1]].name })
SimulateTooltip(GameTooltip, "x", link(testItem), {})
DumpTooltip(GameTooltip)
local playerWished = wl[LootCheck:NormalizeName(UnitName("player"))] ~= nil
assert(GameTooltip:NumLines() == (playerWished and 6 or 5), "only group members expected, got " .. GameTooltip:NumLines())
local greyFound = false
for i = 5, GameTooltip:NumLines() do
    local t = _G["GameTooltipTextLeft" .. i]:GetText()
    if LootCheck:StripColorCodes(t):lower():find(wl[received[1]].name:lower(), 1, true) then greyFound = isGreyText(t) end
end
assert(greyFound, "group member who received it must be grey")
raidersOnly = false
gargulSettings["TMB.maximumNumberOfTooltipEntries"] = 2
LootCheck.db.settings.receivedSuffix = " (received)"
SimulateTooltip(GameTooltip, "x", link(testItem), {})
DumpTooltip(GameTooltip)
assert(GameTooltip:NumLines() == 6, "max entries 2 -> header + 2 lines")
for i = 5, 6 do
    local t = _G["GameTooltipTextLeft" .. i]:GetText()
    if isGreyText(t) then assert(t:find(" (received)|r", 1, true), "suffix missing on greyed line") end
end
gargulSettings["TMB.maximumNumberOfTooltipEntries"] = 35
LootCheck.db.settings.receivedSuffix = ""

section("integrated tooltip: hideWishListInfoIfPriorityIsPresent keeps prio list, greys it, adds no wishlist")
gargulSettings["TMB.hideWishListInfoIfPriorityIsPresent"] = true
local recName = wl[received[1]].name
GargulOrig[testItem] = {
    "\n|c00FF7A0ATMB Prio List|r",
    "|c00C79C6E    " .. recName .. "[1]|r",
    "|c00C79C6E    Someoneelse[2]|r",
    "\n|c00FFFFFFTMB Wish List|r",
    "|c005F5F5F    Stalename[1]|r",
}
SimulateTooltip(GameTooltip, "x", link(testItem), {})
DumpTooltip(GameTooltip)
assert(GameTooltip:NumLines() == 4, "prio list only (3 lines + item name)")
assert(isGrey(GameTooltipTextLeft3), "received player in prio list must be greyed")
assert(not isGrey(GameTooltipTextLeft4), "other prio-list player untouched")
gargulSettings["TMB.hideWishListInfoIfPriorityIsPresent"] = false

section("integrated tooltip: Gargul has NO data for the item -> TMBExport section still shown")
GargulOrig[testItem] = nil
SimulateTooltip(GameTooltip, "x", link(testItem), {})
assert(GameTooltip:NumLines() > 2 and GameTooltipTextLeft2:GetText() == "\n|c00FFFFFFTMB Wish List|r", "wishlist should appear even without Gargul data")

section("integrated tooltip: solo + hideInfoOfPeopleNotInGroup -> nothing (mirrors Gargul)")
Gargul.User.isInGroup = false
SimulateTooltip(GameTooltip, "x", link(testItem), {})
assert(GameTooltip:NumLines() == 1, "solo should show nothing")
Gargul.User.isInGroup = true

section("integrated tooltip: DFT import -> Gargul's lines untouched")
importedFromDFT = true
GargulOrig[testItem] = { "\n|c00FF7A0ADFT Prio List|r", "|c00C79C6E" .. recName .. "[5]|r" }
SimulateTooltip(GameTooltip, "x", link(testItem), {})
assert(GameTooltipTextLeft3:GetText() == "|c00C79C6E" .. recName .. "[5]|r", "DFT lines must pass through unchanged")
importedFromDFT = false
GargulOrig[testItem] = nil

section("integration error -> falls back to Gargul's own lines")
GargulOrig[testItem] = { "\n|c00FFFFFFTMB Wish List|r", "|c005F5F5F    Stalename[1]|r" }
local savedFn = LootCheck.Data.WishlistIndex
LootCheck.Data.WishlistIndex = function() error("boom") end
SimulateTooltip(GameTooltip, "x", link(testItem), {})
assert(GameTooltipTextLeft3:GetText() == "|c005F5F5F    Stalename[1]|r", "fallback should show Gargul's lines")
assert(LootCheck.Tooltip.reportedError, "error should be reported once")
LootCheck.Data.WishlistIndex = savedFn
GargulOrig[testItem] = nil

section("fallback greying when TMBExport is absent (award discovered from real data)")
local savedTMB = TMBExportDB
TMBExportDB = nil
-- With no wishlist data the tooltip is greyed by scanning Gargul's own lines
-- against its award history, so this needs a real award to work from
local fbItem, fbName
for _, loot in pairs(GargulDB.AwardHistory) do
    local id = tonumber(loot.itemID) or tonumber((loot.itemLink or ""):match("item:(%d+)") or "")
    local who = (loot.awardedTo or ""):match("^([^%-]+)")
    if id and who and who ~= "" and not loot.OS then
        fbItem, fbName = id, who
        break
    end
end
assert(fbItem, "the award history has a non-OS award to grey")

GargulOrig[fbItem] = {
    "\n|c00FFFFFFTMB Wish List|r",
    "|c00C79C6E    " .. fbName .. "[1]|r",
    "|c00F58CBA    Nobodyhere[2]|r",
    "|c00FFFFFF    " .. fbName .. "x[3]|r",
    "\n|c00efb8cdAwarded To|r",
    "    " .. fbName .. " | Given: yes",
}
SimulateTooltip(GameTooltip, "Item", link(fbItem, "Awarded Item"), {})
DumpTooltip(GameTooltip)
assert(isGrey(GameTooltipTextLeft3), fbName .. " should be greyed by the fallback scanner")
assert(not isGrey(GameTooltipTextLeft4), "Nobodyhere untouched")
assert(not isGrey(GameTooltipTextLeft5), "a longer name starting the same way is untouched")
assert(not isGrey(GameTooltipTextLeft7), "'Awarded To' line untouched")
TMBExportDB = savedTMB
GargulOrig[fbItem] = nil

section("greyOSAwards toggle on an OS-only award (pair discovered from real data)")
local flags = {}
for _, loot in pairs(GargulDB.AwardHistory) do
    local who = norm(loot.awardedTo)
    local key = who .. "|" .. tostring(loot.itemID)
    flags[key] = flags[key] or { who = who, itemID = tonumber(loot.itemID), os = 0, ms = 0 }
    if loot.OS then flags[key].os = flags[key].os + 1 else flags[key].ms = flags[key].ms + 1 end
end
local osOnly
for _, f in pairs(flags) do
    if f.os > 0 and f.ms == 0 and f.who ~= "" and wishByItem[f.itemID] and wishByItem[f.itemID][f.who] then
        osOnly = f
        break
    end
end
if osOnly then
    print(("using %s / item %d (OS-only award, on wishlist)"):format(osOnly.who, osOnly.itemID))
    local function findLine(name)
        for i = 1, GameTooltip:NumLines() do
            local t = _G["GameTooltipTextLeft" .. i]:GetText()
            if LootCheck:StripColorCodes(t):lower():find(name, 1, true) then return t end
        end
    end
    LootCheck.db.settings.greyOSAwards = false
    SimulateTooltip(GameTooltip, "x", link(osOnly.itemID), {})
    assert(not isGreyText(findLine(osOnly.who)), "OS-only award must NOT grey when greyOSAwards=false")
    LootCheck.db.settings.greyOSAwards = true
    SimulateTooltip(GameTooltip, "x", link(osOnly.itemID), {})
    assert(isGreyText(findLine(osOnly.who)), "OS award must grey when greyOSAwards=true")
else
    print("(no OS-only wishlisted award in the data; skipped)")
end

section("/lchelp tmbtooltip toggles TMBExport's own list")
SlashCmdList.LOOTCHECK("tmbtooltip")
assert(TMBExportDB.settings.showTooltip == true, "toggle on")
SlashCmdList.LOOTCHECK("tmbtooltip")
assert(TMBExportDB.settings.showTooltip == false, "toggle off")

section("graph counts (all time)")
local rows = LootCheck.Data:WishlistAwardCounts({})
print("roster rows:", #rows)
local addonTotal = 0
for i, r in ipairs(rows) do
    addonTotal = addonTotal + r.count
    if i <= 5 then print(("%-14s %-8s %d"):format(r.displayName, tostring(r.class), r.count)) end
end
print("addon total:", addonTotal)
local wishes, seen = {}, {}
for _, e in ipairs(TMBExportDB.wishlists) do
    local key = norm(e.character_name) .. "|" .. tostring(e.item_id) .. "|" .. tostring(e.sort_order) .. "|" .. tostring(e.is_offspec)
    if not e.is_offspec and not seen[key] then
        seen[key] = true
        local k = norm(e.character_name) .. "|" .. tostring(tonumber(e.item_id))
        wishes[k] = (wishes[k] or 0) + 1
    end
end
local awards = {}
for _, loot in pairs(GargulDB.AwardHistory) do
    if not loot.OS then
        local k = norm(loot.awardedTo) .. "|" .. tostring(tonumber(loot.itemID))
        awards[k] = (awards[k] or 0) + 1
    end
end
local naiveTotal, perPlayer = 0, {}
for k, wcount in pairs(wishes) do
    local a = awards[k]
    if a then
        local n = math.min(a, wcount)
        naiveTotal = naiveTotal + n
        local who = k:match("^([^|]+)")
        perPlayer[who] = (perPlayer[who] or 0) + n
    end
end
print("naive total:", naiveTotal)
assert(naiveTotal == addonTotal, ("count mismatch: addon=%d naive=%d"):format(addonTotal, naiveTotal))
for _, r in ipairs(rows) do
    assert((perPlayer[r.normName] or 0) == r.count, ("per-player mismatch for %s"):format(r.displayName))
end
-- A player with one MS and at least one OS award for an item on their current wishlist must count it exactly once
local mixed
for k, wcount in pairs(wishes) do
    local who, id = k:match("^([^|]+)|(%d+)$")
    local ms, os = 0, 0
    for _, loot in pairs(GargulDB.AwardHistory) do
        if norm(loot.awardedTo) == who and tonumber(loot.itemID) == tonumber(id) then
            if loot.OS then os = os + 1 else ms = ms + 1 end
        end
    end
    if ms == 1 and os >= 1 and wcount == 1 then
        mixed = { who = who, id = tonumber(id) }
        break
    end
end
if mixed then
    for _, r in ipairs(rows) do
        if r.normName == mixed.who then
            local hits = 0
            for _, it in ipairs(r.items) do
                if tostring(it.itemLink):find("item:" .. mixed.id .. ":", 1, true) then hits = hits + 1 end
            end
            assert(hits == 1, ("%s/%d should count exactly once (MS award only), got %d"):format(mixed.who, mixed.id, hits))
            print(("%s/%d counted once (MS award only) - OK"):format(mixed.who, mixed.id))
        end
    end
else
    print("(no MS+OS mixed pair on a current wishlist; skipped)")
end
print("cross-check OK: totals and per-player counts agree")

section("graph counts (last 30 days / group only)")
local recent = LootCheck.Data:WishlistAwardCounts({ days = 30 })
local recentTotal = 0
for _, r in ipairs(recent) do recentTotal = recentTotal + r.count end
print("last-30-day total:", recentTotal)
assert(recentTotal <= addonTotal, "30-day total cannot exceed all-time")
-- Build the group from raiders who really are in the wishlist data, so the
-- filter has something to keep and the assertion is not vacuous
local roster = LootCheck.Data:Roster()
local groupNames, expected = {}, {}
for norm, entry in pairs(roster) do
    if #groupNames >= 3 then break end
    tinsert(groupNames, entry.displayName)
    expected[norm] = true
end
expected[LootCheck:NormalizeName(UnitName("player"))] = true -- you are in your own group
assert(#groupNames == 3, "the wishlist data has at least three raiders")

SetTestGroup(groupNames)
local grp = LootCheck.Data:WishlistAwardCounts({ groupOnly = true })
assert(#grp > 0, "the group-only filter kept the raiders who are in the group")
for _, r in ipairs(grp) do
    assert(expected[r.normName], "unexpected row " .. r.normName)
end

section("slash commands / graph window")
SlashCmdList.LOOTCHECK("graph")
assert(LootCheckGraphFrame and LootCheckGraphFrame:IsShown(), "graph frame should be shown")
print("subtitle:", LootCheckGraphFrame.subtitle:GetText())
SlashCmdList.LOOTCHECK("graph")
assert(not LootCheckGraphFrame:IsShown(), "graph should toggle off")
SlashCmdList.LOOTCHECK("graph 30")
assert(LootCheckGraphFrame:IsShown() and LootCheck.db.settings.graphDays == 30, "graph 30")
SlashCmdList.LOOTCHECK("graph 0")
SlashCmdList.LOOTCHECK("grouponly")
SlashCmdList.LOOTCHECK("grouponly")
SlashCmdList.LOOTCHECK("greyos")
SlashCmdList.LOOTCHECK("greyos")
SlashCmdList.LOOTCHECK("check")
SlashCmdList.LOOTCHECK("bogus")
SlashCmdList.LOOTCHECK("") -- opens the window on the home page
assert(LootCheckConfigFrame and LootCheckConfigFrame:IsShown(), "bare /lchelp should open the window")
LootCheck.Window:Hide()

section("Gargul event invalidates cache + refreshes open graph")
LootCheck.Graph:Open()
registered["GL.ITEM_AWARDED"]("GL.ITEM_AWARDED", {})
assert(LootCheckGraphFrame:IsShown(), "graph page still shown after an award event")
LootCheck.Window:Hide()

print("\nALL TESTS PASSED")
