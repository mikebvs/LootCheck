-- All-time history: "4 (22)" - current-wishlist matches vs everything ever wishlisted-and-received.
-- Runs after test.lua (Gargul stub, real data, `registered` event callbacks) and before test_wishlist.lua.
local function section(t) print("\n=== " .. t .. " ===") end
local function norm(name)
    name = tostring(name or ""):lower():gsub("%s+", ""):gsub("%(os%)", "")
    return name:match("^([^%-]+)") or name
end
local function rowFor(n)
    for _, r in ipairs(LootCheck.Data:WishlistAwardCounts({})) do
        if r.normName == n then return r end
    end
end

section("history: log fills from current matches; Gargul WL stamps add earlier phases")
LootCheckDB.history = {} -- first run
local rows = LootCheck.Data:WishlistAwardCounts({})
local current, allTime = 0, 0
for _, r in ipairs(rows) do
    current = current + r.count
    allTime = allTime + r.history
    assert(r.history >= r.count, r.displayName .. ": history below current count")
end
local logged = 0
for _ in pairs(LootCheckDB.history) do logged = logged + 1 end
assert(logged == current, ("log should hold one entry per current match: %d vs %d"):format(logged, current))

-- Independent: union of (logged current matches) and (WL-stamped, non-OS awards) for roster players
local roster = LootCheck.Data:Roster()
local naive = {}
for cs, loot in pairs(GargulDB.AwardHistory) do
    if loot.WL and not loot.OS and roster[norm(loot.awardedTo)] then naive[cs] = true end
end
for cs in pairs(LootCheckDB.history) do naive[cs] = true end
local naiveCount = 0
for _ in pairs(naive) do naiveCount = naiveCount + 1 end
print(("current=%d  all-time=%d  (independent: %d)"):format(current, allTime, naiveCount))
assert(allTime == naiveCount, "all-time total mismatch")
assert(allTime > current, "expected Gargul WL stamps to add earlier-phase receipts")
for i = 1, math.min(6, #rows) do
    print(("  %-14s %d (%d)"):format(rows[i].displayName, rows[i].count, rows[i].history))
end

section("history survives the wish being removed (override); current count drops")
-- pick a logged match whose player has exactly one wishlist entry and one match for that item
local pick
for _, e in pairs(LootCheckDB.history) do
    local p = LootCheck.Data:WishlistIndex()[e.itemID]
    p = p and p[e.norm]
    local n = 0
    for _, o in pairs(LootCheckDB.history) do
        if o.norm == e.norm and o.itemID == e.itemID then n = n + 1 end
    end
    if p and p.mainSpec == 1 and #p.entries == 1 and n == 1 then
        pick = e
        break
    end
end
assert(pick, "no single-entry logged match to test with")
print(("using %s / %s"):format(pick.norm, tostring(pick.itemName)))
local before = rowFor(pick.norm)
SlashCmdList.LOOTCHECK(("removewlitem %s %d"):format(pick.norm, pick.itemID))
local after = rowFor(pick.norm)
assert(after.count == before.count - 1, "current count should drop by one")
assert(after.history == before.history, "all-time count must not drop")
SlashCmdList.LOOTCHECK(("addwlitem %s %d"):format(pick.norm, pick.itemID))
assert(rowFor(pick.norm).count == before.count, "restored")

section("history: stale entry (award edited to another winner) pruned then re-logged; unknown checksum kept; unaward forgets")
local cs = next(LootCheckDB.history)
local realNorm = LootCheckDB.history[cs].norm
LootCheckDB.history[cs].norm = "someoneelse"
LootCheck.Data:History()
assert(not LootCheckDB.history[cs], "stale entry should be pruned")
LootCheck.Data:WishlistAwardCounts({})
assert(LootCheckDB.history[cs] and LootCheckDB.history[cs].norm == realNorm, "still a current match: re-logged")

local hBefore = LootCheck.Data:History()[realNorm].count
LootCheckDB.history["ghost00000000000001"] = { norm = realNorm, itemID = 1, itemName = "Ghost Item", timestamp = 1 }
assert(LootCheck.Data:History()[realNorm].count == hBefore + 1, "entry for an award Gargul no longer has must be kept")
registered["GL.ITEM_UNAWARDED"]("GL.ITEM_UNAWARDED", { checksum = "ghost00000000000001" })
assert(not LootCheckDB.history["ghost00000000000001"], "unaward should forget the entry")
assert(LootCheck.Data:History()[realNorm].count == hBefore, "back to before")

section("GL.ITEM_AWARDED logs immediately")
LootCheckDB.history = {}
registered["GL.ITEM_AWARDED"]("GL.ITEM_AWARDED", {})
local n = 0
for _ in pairs(LootCheckDB.history) do n = n + 1 end
assert(n == current, "award event should re-log current matches")

section("graph shows 'N / T (M)', subtitle mentions all time, row tooltip lists the rest")
LootCheck.Graph:Open()
local first = LootCheck.Graph._rows[1]
-- items / tier tokens (all-time items)
local countText = first and first.count:GetText()
assert(countText and countText:match("^%d+ |cff7f7f7f/|r |cffffd100%d+|r |cffaaaaaa%(%d+%)|r$"),
    "count text: " .. tostring(countText))
local shownCount, shownTokens, shownHistory = countText:match("^(%d+) |cff7f7f7f/|r |cffffd100(%d+)|r |cffaaaaaa%((%d+)%)|r$")
assert(tonumber(shownCount) == first.data.count, "the first number is the wishlist count")
assert(tonumber(shownTokens) == first.data.tokens, "the second is the tier token count")
assert(tonumber(shownHistory) == first.data.history, "the third is the all-time count")
print("first row:", first.name:GetText(), first.count:GetText())
print("subtitle:", LootCheckGraphFrame.subtitle:GetText())
assert(LootCheckGraphFrame.subtitle:GetText():find("all time", 1, true), "subtitle")
LootCheck.Graph:ShowRowTooltip(first)
local tip = {}
for i = 1, GameTooltip:NumLines() do tip[i] = _G["GameTooltipTextLeft" .. i]:GetText() end
print("row tooltip:\n   " .. table.concat(tip, "\n   "))
if first.data.history > first.data.count then
    assert(table.concat(tip, "\n"):find("outside this window", 1, true), "the out-of-window section is expected")
end
LootCheck.Window:Hide()

section("/lchelp wishlist and /lchelp status show both numbers")
local realPrint = print
local captured = {}
print = function(...)
    local t = {}
    for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
    tinsert(captured, table.concat(t, " "))
    realPrint(...)
end
SlashCmdList.LOOTCHECK("wishlist " .. rows[1].displayName)
SlashCmdList.LOOTCHECK("status")
print = realPrint
local text = table.concat(captured, "\n")
assert(text:find("wishlist items received: %d+ against the current wishlist, %d+ all time"), text)
assert(text:find("Non%-OS wishlist items awarded: %d+ against the current wishlist, %d+ all time"), text)

section("tier tokens are counted from the award history, not the wishlist")
local tokenIDs = LootCheck:TokenIDs()
local tokenCount = 0
for _ in pairs(tokenIDs) do tokenCount = tokenCount + 1 end
assert(tokenCount > 0, "the piece map yields token ids")
assert(LootCheck:TokenName(29764) == "Pauldrons of the Fallen Defender",
    "a known token resolves: " .. tostring(LootCheck:TokenName(29764)))
assert(LootCheck:TokenName(30627) == nil, "an ordinary item is not a token")

-- Every counted token must really be a token award to that player
local counts = LootCheck.Data:WishlistAwardCounts({})
local anyTokens = 0
for _, r in ipairs(counts) do
    anyTokens = anyTokens + (r.tokens or 0)
    assert(r.tokens == #r.tokenItems, r.displayName .. ": count and item list disagree")
    for _, item in ipairs(r.tokenItems) do
        assert(tokenIDs[item.itemID], ("%s was counted a token but is not one"):format(tostring(item.itemID)))
    end
end
print(("tier tokens counted across the roster: %d"):format(anyTokens))

-- A token awarded to someone who never wishlisted it still counts: the
-- question is how much tier they have had, not whether they asked for it
local victim = counts[1] and counts[1].normName
if victim then
    local before = 0
    for _, r in ipairs(LootCheck.Data:WishlistAwardCounts({})) do
        if r.normName == victim then before = r.tokens or 0 end
    end

    LootCheck.Awards:ApplyMark(victim, 29764, "Pauldrons of the Fallen Defender", nil, false, GetServerTime())
    LootCheck.Data:Invalidate()

    local after = 0
    for _, r in ipairs(LootCheck.Data:WishlistAwardCounts({})) do
        if r.normName == victim then after = r.tokens or 0 end
    end
    assert(after == before + 1, ("a new token award counts: %d became %d"):format(before, after))

    LootCheckDB.manualAwards = {}
    LootCheck.Data:Invalidate()
end

section("tokens are classified by tier, and a phase counts only its own")
-- T5 is "Vanquished", T6 is "Forgotten Vanquisher": a substring search would
-- put half of T6 into T5, so the classification reads the word after "of the"
local tiers = {}
for id, name in pairs(LootCheck:TokenIDs()) do
    local tier = LootCheck:TokenTier(id)
    assert(tier, ("no tier for %s (%s)"):format(name, tostring(id)))
    tiers[tier] = (tiers[tier] or 0) + 1

    local qualifier = name:match("of the (%a+)")
    if qualifier == "Fallen" then
        assert(tier == "T4", name .. " should be T4")
    elseif qualifier == "Vanquished" then
        assert(tier == "T5", name .. " should be T5")
    elseif qualifier == "Forgotten" then
        assert(tier == "T6", name .. " should be T6, got " .. tier)
    else
        error("unexpected token name: " .. name)
    end
end
assert(tiers.T4 and tiers.T5 and tiers.T6, "all three tiers are represented")
print(("tokens by tier: T4 %d, T5 %d, T6 %d"):format(tiers.T4, tiers.T5, tiers.T6))

-- The names that trip a naive match
assert(LootCheck:TokenTier(29764) == "T4", "Pauldrons of the Fallen Defender is T4")
for id, name in pairs(LootCheck:TokenIDs()) do
    if name:find("Vanquished", 1, true) then
        assert(LootCheck:TokenTier(id) == "T5", name .. " is T5, not T6")
    end
    if name:find("Vanquisher", 1, true) then
        assert(LootCheck:TokenTier(id) == "T6", name .. " is T6, not T5")
    end
end

assert(LootCheck:TierForPhase("P1") == "T4", "P1 drops T4")
assert(LootCheck:TierForPhase("P2") == "T5", "P2 drops T5")
assert(LootCheck:TierForPhase("P3") == "T6", "P3 drops T6")
assert(LootCheck:TierForPhase("P4") == "T6", "Zul'Aman keeps T6")
assert(LootCheck:TierForPhase("P5") == "T6", "Sunwell upgrades T6 rather than adding tokens")
assert(LootCheck:TierForPhase("") == nil and LootCheck:TierForPhase(nil) == nil,
    "no phase means every tier counts")

-- Asking for one tier must return only that tier's tokens
for _, tier in ipairs({ "T4", "T5", "T6" }) do
    local rows = LootCheck.Data:WishlistAwardCounts({ tokenTier = tier })
    local seen = 0
    for _, r in ipairs(rows) do
        for _, item in ipairs(r.tokenItems or {}) do
            assert(LootCheck:TokenTier(item.itemID) == tier,
                ("%s counted towards %s"):format(tostring(item.itemName), tier))
            seen = seen + 1
        end
    end
    print(("  %s tokens awarded: %d"):format(tier, seen))
end

-- The tiers partition the unfiltered total: nothing counted twice or lost
local total = 0
for _, r in ipairs(LootCheck.Data:WishlistAwardCounts({})) do total = total + (r.tokens or 0) end
local summed = 0
for _, tier in ipairs({ "T4", "T5", "T6" }) do
    for _, r in ipairs(LootCheck.Data:WishlistAwardCounts({ tokenTier = tier })) do
        summed = summed + (r.tokens or 0)
    end
end
assert(summed == total, ("the tiers should add up to the whole: %d vs %d"):format(summed, total))

print("\nHISTORY TESTS PASSED")
