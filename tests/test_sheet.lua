-- The character sheet: a raider's wishlist laid out by equipment slot, in
-- the popout column on the right of the wishlist graph.
local function section(t) print("\n=== " .. t .. " ===") end
local function click(button) button._scripts.OnClick(button) end
local Sheet = LootCheck.Sheet

local function shownRows()
    local out = {}
    for _, row in ipairs(Sheet._rows) do
        if row:IsShown() then tinsert(out, row) end
    end
    return out
end

section("tier tokens are placed by name, since the client has no slot for them")
-- These are not equippable, so GetItemInfo can never answer for them; the
-- name is the only thing that says where the redeemed piece goes
assert(Sheet:SlotFor(29764) == "shoulder", "Pauldrons of the Fallen Defender is a shoulder")
assert(Sheet:SlotFor(29761) == "head", "Helm of the Fallen Defender is a head")
assert(Sheet:SlotFor(29753) == "chest", "Chestguard of the Fallen Defender is a chest")
assert(Sheet:SlotFor(29758) == "hands", "Gloves of the Fallen Defender is hands")
assert(Sheet:SlotFor(29767) == "legs", "Leggings of the Fallen Defender is legs")

-- Every token in the map must land in a real slot, not the unknown bucket
local unplaced = {}
for id, name in pairs(LootCheck:TokenIDs()) do
    if Sheet:SlotFor(id) == "unknown" then tinsert(unplaced, name) end
end
assert(#unplaced == 0, "tokens with no slot: " .. table.concat(unplaced, ", "))

-- An item the client knows nothing about waits rather than being dropped
assert(Sheet:SlotFor(999999, "Something Unheard Of") == "unknown", "an unknown item has no slot yet")

section("the client's equip location is read from the right return value")
-- itemEquipLoc is GetItemInfo's 9th return. Reading the 8th gives
-- itemStackCount, a number, which quietly sent every non-token item to the
-- unknown bucket. The stub returns the client's real tuple so miscounting it
-- fails here rather than in game.
SetTestItems({
    [32837] = { name = "Warglaive of Azzinoth", equipLoc = "INVTYPE_WEAPONMAINHAND",
                itemType = "Weapon", subType = "One-Handed Swords", stackCount = 1 },
    [32838] = { name = "Warglaive of Azzinoth", equipLoc = "INVTYPE_WEAPONOFFHAND",
                itemType = "Weapon", subType = "One-Handed Swords" },
    [30627] = { name = "Tsunami Talisman", equipLoc = "INVTYPE_TRINKET" },
    [28830] = { name = "Dragonspine Trophy", equipLoc = "INVTYPE_TRINKET" },
    [29381] = { name = "Ring of a Thousand Marks", equipLoc = "INVTYPE_FINGER" },
    [28802] = { name = "Cowl of the Grand Engineer", equipLoc = "INVTYPE_HEAD" },
    [30871] = { name = "Cloak of Darkness", equipLoc = "INVTYPE_CLOAK" },
    [28963] = { name = "Robe of the Elder Scribes", equipLoc = "INVTYPE_ROBE" },
    [32235] = { name = "Cursed Vision of Sargeras", equipLoc = "INVTYPE_HEAD" },
    [28587] = { name = "Girdle of Zaetar", equipLoc = "INVTYPE_WAIST" },
    [30105] = { name = "Fang of the Leviathan", equipLoc = "INVTYPE_WEAPON" },
    [28773] = { name = "Bulwark of Azzinoth", equipLoc = "INVTYPE_SHIELD" },
    [28572] = { name = "Wand of the Forgotten Star", equipLoc = "INVTYPE_RANGEDRIGHT" },
    [27886] = { name = "Idol of the Emerald Queen", equipLoc = "INVTYPE_RELIC" },
    [28189] = { name = "Belt of Blasting", equipLoc = "INVTYPE_WAIST", stackCount = 1 },
})

-- The name says "main hand" and so does the client; both Warglaives are swords
assert(Sheet:SlotFor(32837, "Warglaive of Azzinoth") == "mainhand", "the main-hand Warglaive")
assert(Sheet:SlotFor(32838, "Warglaive of Azzinoth") == "offhand", "the off-hand one")

local expected = {
    [30627] = "trinket", [28830] = "trinket", [29381] = "finger",
    [28802] = "head", [30871] = "back", [28963] = "chest",
    [32235] = "head", [28587] = "waist", [30105] = "mainhand",
    [28773] = "offhand", [28572] = "ranged", [27886] = "ranged",
    [28189] = "waist",
}
for itemID, slot in pairs(expected) do
    local got = Sheet:SlotFor(itemID)
    assert(got == slot, ("%s: expected %s, got %s"):format(tostring(itemID), slot, tostring(got)))
end

-- Nothing cached must still be honest about it rather than guessing
assert(Sheet:SlotFor(999999, "Utterly Unknown Thing") == "unknown", "an uncached item is unknown")

-- Every equip location the client can report is either mapped or deliberately
-- left out; none may resolve to a slot that is not in the paper doll
local slotKeys = {}
for _, slot in ipairs(Sheet.SLOTS) do slotKeys[slot.key] = true end
for _, loc in ipairs({ "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK",
                       "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_WRIST", "INVTYPE_HAND",
                       "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_FINGER",
                       "INVTYPE_TRINKET", "INVTYPE_WEAPON", "INVTYPE_2HWEAPON",
                       "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD",
                       "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT",
                       "INVTYPE_THROWN", "INVTYPE_RELIC" }) do
    SetTestItems({ [1] = { name = "probe", equipLoc = loc } })
    local slot = Sheet:SlotFor(1)
    assert(slot ~= "unknown", loc .. " has no slot")
    assert(slotKeys[slot], ("%s maps to %s, which is not a slot on the sheet"):format(loc, slot))
end
SetTestItems({})

section("the slots read like a paper doll, and every one is accounted for")
local seen = {}
for _, slot in ipairs(Sheet.SLOTS) do
    assert(not seen[slot.key], "duplicate slot " .. slot.key)
    seen[slot.key] = true
end
assert(Sheet.SLOTS[1].key == "head", "head comes first")
assert(Sheet.SLOTS[#Sheet.SLOTS].key == "unknown", "the unknown bucket comes last")
for _, key in ipairs({ "head", "neck", "shoulder", "back", "chest", "wrist", "hands",
                       "waist", "legs", "feet", "finger", "trinket", "mainhand", "offhand", "ranged" }) do
    assert(seen[key], "missing slot " .. key)
end

section("a raider's wishlist is laid out by slot, empty slots included")
local characters = Sheet:Characters()
assert(#characters > 0, "the wishlist data has raiders to pick from")

-- Pick one who actually wants something, so the assertions have teeth
local subject, wishCount
for _, entry in ipairs(characters) do
    local wanted = Sheet:Summary(entry.value)
    if wanted > 0 then subject, wishCount = entry.value, wanted break end
end
assert(subject, "somebody in the data has wishlist entries")
print(("subject: %s with %d wishlist entries"):format(subject, wishCount))

local layout = Sheet:Rows(subject)
assert(#layout > 0, "the sheet has rows")

-- Every wishlist entry appears exactly once, and nothing is invented
local placed = 0
for _, row in ipairs(layout) do
    if not row.empty then
        placed = placed + 1
        assert(row.entry and row.entry.itemID, "a filled row carries its entry")
        assert(Sheet:SlotFor(row.entry.itemID, row.entry.name) == row.slot,
            ("%s filed under %s"):format(tostring(row.entry.name), row.slot))
    end
end
assert(placed == wishCount, ("every entry is placed once: %d of %d"):format(placed, wishCount))

-- Slots they want nothing in are still shown, because a gap is information
local emptyRows = 0
for _, row in ipairs(layout) do
    if row.empty then
        emptyRows = emptyRows + 1
        assert(row.slotLabel ~= "", "an empty slot is still named")
    end
end
print(("empty slots shown: %d"):format(emptyRows))

-- The unknown bucket never appears as an empty row: it is not a real slot
for _, row in ipairs(layout) do
    if row.slot == "unknown" then assert(not row.empty, "the unknown bucket is only shown when used") end
end

section("a slot wanted several times is named once and ordered by rank")
local multi
for _, slotKey in ipairs({ "finger", "trinket" }) do
    local inSlot = {}
    for _, row in ipairs(layout) do
        if row.slot == slotKey and not row.empty then tinsert(inSlot, row) end
    end
    if #inSlot > 1 then multi = inSlot break end
end

if multi then
    assert(multi[1].slotLabel ~= "", "the first row names the slot")
    for i = 2, #multi do
        assert(multi[i].slotLabel == "", "the rest leave it blank so it reads as one slot")
        assert(multi[i].entry.prio >= multi[i - 1].entry.prio, "ordered by rank within the slot")
    end
    print(("a slot with %d wants reads as one slot"):format(#multi))
else
    print("no slot wanted more than once in this data")
end

section("the sheet is a popout on the wishlist graph, not a page of its own")
LootCheck.Window:Hide()
assert(LootCheck.Window:Show("sheet") == false, "there is no sheet page left to show")

LootCheck.db.settings.sheetCharacter = subject
LootCheck.Graph:SetSheetOpen(false)
LootCheck.Graph:Open()
local graph = LootCheckGraphFrame
local popout = LootCheckGraphFrameSheet
assert(popout, "the graph page has a popout column")
assert(not popout:IsShown(), "which starts closed")
assert((graph.sheetToggle:GetText() or ""):find("Character", 1, true),
    "the button says what it opens: " .. tostring(graph.sheetToggle:GetText()))

section("opening it widens the window instead of squeezing the other columns")
local closedW = select(1, LootCheck.Window:ContentSize())
local closedDrops = LootCheck.Drops.rowCount

click(graph.sheetToggle)
assert(LootCheck.Graph:SheetOpen(), "the button opened it")
assert(popout:IsShown(), "and the column is on screen")

local openW = select(1, LootCheck.Window:ContentSize())
assert(openW > closedW, ("the window widened: %d then %d"):format(closedW, openW))
assert(openW - closedW >= 300, ("by the width of the column, got %d"):format(openW - closedW))
assert(LootCheck.Drops.rowCount == closedDrops, "the drops list was not shortened to make room")

-- Closing gives the width back rather than leaving a gap where it was
click(graph.sheetToggle)
assert(not LootCheck.Graph:SheetOpen() and not popout:IsShown(), "the button closed it again")
assert(select(1, LootCheck.Window:ContentSize()) == closedW,
    "and the window went back to the width it had, got " .. select(1, LootCheck.Window:ContentSize()))

section("the floor makes room for the popout, but only on this page")
local closedMin = LootCheck.Window:MinimumSize()
LootCheck.Graph:SetSheetOpen(true)
local openMin = LootCheck.Window:MinimumSize()
assert(openMin - closedMin >= 300,
    ("the floor grows with the popout: %d then %d"):format(closedMin, openMin))

-- Squeezed to nothing, the page still keeps room for all three columns
LootCheck.Window:Resize(100, 100)
assert(select(1, LootCheck.Window:ContentSize()) >= openMin,
    "the graph enforces room for all three columns, got " .. select(1, LootCheck.Window:ContentSize()))

LootCheck.Window:Show("audit")
assert(LootCheck.Window:MinimumSize() == closedMin,
    "another page does not inherit a floor for a column it has not got, got "
    .. LootCheck.Window:MinimumSize())
LootCheck.Graph:Open()

section("the popout renders, with the rank and the received state")
LootCheck.Window:Resize(1500, 800)
assert(popout.head.slot:GetText() == "Slot" and popout.head.prio:GetText() == "Rank", "columns are labelled")
local sumWanted, sumReceived = Sheet:Summary(Sheet:Selected())
assert(popout.summary:GetText() == ("%d of %d received"):format(sumReceived, sumWanted),
    "the summary counts what is left: " .. tostring(popout.summary:GetText()))

local rendered = shownRows()
assert(#rendered > 0, "rows on screen")

local sawRank, sawEmpty = false, false
for _, row in ipairs(rendered) do
    if row.data and row.data.empty then
        sawEmpty = true
        assert((row.item:GetText() or ""):find("-", 1, true), "an empty slot shows a dash")
        assert(row.prio:GetText() == "", "and no rank")
    elseif row.data then
        local prio = row.data.entry.prio
        if prio and prio < 1000 then
            assert((row.prio:GetText() or ""):find("#" .. prio, 1, true),
                "the rank they set: " .. tostring(row.prio:GetText()))
            sawRank = true
        end
    end
end
assert(sawRank or wishCount == 0, "at least one rank was rendered")
assert(sawEmpty, "at least one empty slot was rendered")

-- Received items are greyed, the same as on the tooltip
for _, row in ipairs(rendered) do
    if row.data and row.data.entry and row.data.entry.received then
        assert((row.item:GetText() or ""):find(LootCheck.GREY, 1, true),
            "a received item is greyed: " .. tostring(row.item:GetText()))
    end
end

section("hovering a row draws a guide line above and below it")
-- Rows are wide and the numbers that matter are at the far right, so the eye
-- needs a line to follow across from the item name
local guided = shownRows()[1]
assert(guided, "there is a row to hover")
assert(guided.guideTop and guided.guideBottom, "the row has both guides")
assert(not guided.guideTop:IsShown() and not guided.guideBottom:IsShown(),
    "they are off until the cursor arrives")

guided._scripts.OnEnter(guided)
assert(guided.guideTop:IsShown() and guided.guideBottom:IsShown(),
    "both appear on hover")

guided._scripts.OnLeave(guided)
assert(not guided.guideTop:IsShown() and not guided.guideBottom:IsShown(),
    "and go again when the cursor leaves")

-- A row hidden while the cursor is on it never receives OnLeave, so a refresh
-- has to clear the guides itself or one is left glowing on an empty row.
-- The row hovered here has to be one the shrink actually hides, or the test
-- passes whether or not the clearing happens.
local doomed = shownRows()[#shownRows()]
assert(doomed and doomed ~= shownRows()[1], "there is a row below the first to hover")
doomed._scripts.OnEnter(doomed)
assert(doomed.guideTop:IsShown(), "it is guided before the refresh")
LootCheck.Sheet.rowCount = 1
LootCheck.Sheet:RefreshPanel()
for _, row in ipairs(LootCheck.Sheet._rows) do
    if not row:IsShown() then
        assert(not row.guideTop:IsShown(), "a hidden row must not keep its guide")
    end
end

LootCheck.Sheet.rowCount = 22
LootCheck.Sheet:RefreshPanel()

-- The other way a row goes away: it stays inside the row count, but the list
-- got shorter. That is a different loop in the refresh and it needs the same
-- clearing, or switching to a raider who wants less leaves a line floating
-- over an empty row.
local longest, shortest
for _, entry in ipairs(Sheet:Characters()) do
    local n = #Sheet:Rows(entry.value)
    if not longest or n > longest.n then longest = { value = entry.value, n = n } end
    if not shortest or n < shortest.n then shortest = { value = entry.value, n = n } end
end

Sheet:Select(longest.value)
local tallest = shownRows()[#shownRows()]
if tallest and #shownRows() > shortest.n then
    tallest._scripts.OnEnter(tallest)
    assert(tallest.guideTop:IsShown(), "guided before the list shrinks under it")

    Sheet:Select(shortest.value)
    for _, row in ipairs(LootCheck.Sheet._rows) do
        if not row:IsShown() then
            assert(not row.guideTop:IsShown(), "a row hidden by a shorter list must not keep its guide")
        end
    end
    print(("a %d row sheet shrank to %d"):format(longest.n, shortest.n))
else
    print("no raider in this data has a short enough sheet to test the shrink")
end
LootCheck.db.settings.sheetCharacter = subject
Sheet:RefreshPanel()

section("the picker lists every raider and switches between them")
assert(popout.picker, "there is a character picker")
popout.picker:OpenMenu()
local offered = 0
for _, item in ipairs(popout.picker._menuItems) do
    if item:IsShown() then offered = offered + 1 end
end
assert(offered == #characters, ("one entry per raider: %d of %d"):format(offered, #characters))

local other
for _, item in ipairs(popout.picker._menuItems) do
    if item:IsShown() and item.value ~= subject then other = item break end
end
if other then
    local target = other.value
    click(other)
    assert(LootCheck.db.settings.sheetCharacter == target, "picking switches character")
    assert(Sheet:Selected() == target, "and the page follows")
end
popout.picker:CloseMenu()

section("clicking a raider on the graph pops their sheet out beside the bars")
LootCheck.Window:Hide()
LootCheck.Graph:SetSheetOpen(false)
LootCheck.Graph:Open()
local bar
for _, row in ipairs(LootCheck.Graph._rows) do
    if row:IsShown() and row.data then bar = row break end
end
assert(bar, "the graph has a bar to click")
local who = bar.data.normName
bar._scripts.OnMouseUp(bar)
assert(LootCheck.Window:Current() == "graph", "the graph is still the page")
assert(LootCheck.Graph:SheetOpen() and popout:IsShown(), "the popout came out")
assert(Sheet:Selected() == who, "on the raider whose bar was clicked")

section("the command opens it, with or without a name")
LootCheck.Window:Hide()
LootCheck.Graph:SetSheetOpen(false)
SlashCmdList.LOOTCHECK("sheet " .. subject)
assert(LootCheck.Window:Current() == "graph" and LootCheck.Graph:SheetOpen(), "/lchelp sheet opens the popout")
assert(Sheet:Selected() == subject, "on the named raider")

SlashCmdList.LOOTCHECKSHEET("")
assert(not LootCheckWindow:IsShown(), "/lchs with the popout already out closes the window")

SlashCmdList.LOOTCHECKSHEET("")
assert(LootCheck.Window:Current() == "graph" and LootCheck.Graph:SheetOpen(), "and opens it again")
LootCheck.Window:Hide()

section("cleanup")
LootCheck.Graph:SetSheetOpen(false)
LootCheck.db.settings.sheetCharacter = nil
LootCheckDB.windowSize = {}

print("\nSHEET TESTS PASSED")
