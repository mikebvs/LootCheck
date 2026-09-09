-- The Character Sheet page: a raider's wishlist laid out by equipment slot.
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

section("the page renders, with the rank and the received state")
LootCheck.db.settings.sheetCharacter = subject
Sheet:Open()
local page = LootCheckSheetFrame
assert(page:IsShown(), "the sheet page is up")
assert(page.head.slot:GetText() == "Slot" and page.head.prio:GetText() == "Rank", "columns are labelled")
assert(page.summary:GetText():find("wishlist entries", 1, true), page.summary:GetText())

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

section("the picker lists every raider and switches between them")
assert(page.picker, "there is a character picker")
page.picker:OpenMenu()
local offered = 0
for _, item in ipairs(page.picker._menuItems) do
    if item:IsShown() then offered = offered + 1 end
end
assert(offered == #characters, ("one entry per raider: %d of %d"):format(offered, #characters))

local other
for _, item in ipairs(page.picker._menuItems) do
    if item:IsShown() and item.value ~= subject then other = item break end
end
if other then
    local target = other.value
    click(other)
    assert(LootCheck.db.settings.sheetCharacter == target, "picking switches character")
    assert(Sheet:Selected() == target, "and the page follows")
end
page.picker:CloseMenu()

section("clicking a raider on the graph opens their sheet")
LootCheck.Window:Hide()
LootCheck.Graph:Open()
local bar
for _, row in ipairs(LootCheck.Graph._rows) do
    if row:IsShown() and row.data then bar = row break end
end
assert(bar, "the graph has a bar to click")
local who = bar.data.normName
bar._scripts.OnMouseUp(bar)
assert(LootCheck.Window:Current() == "sheet", "the sheet opened")
assert(Sheet:Selected() == who, "on the raider whose bar was clicked")

section("the command opens it, with or without a name")
LootCheck.Window:Hide()
SlashCmdList.LOOTCHECK("sheet " .. subject)
assert(LootCheck.Window:Current() == "sheet" and Sheet:Selected() == subject, "/lchelp sheet <name>")
LootCheck.Window:Hide()
SlashCmdList.LOOTCHECKSHEET("")
assert(LootCheck.Window:Current() == "sheet", "/lchs opens it")
LootCheck.Window:Hide()

section("cleanup")
LootCheck.db.settings.sheetCharacter = nil

print("\nSHEET TESTS PASSED")
