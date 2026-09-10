-- The Contested Items page: every wishlisted item and how many want it.
local function section(t) print("\n=== " .. t .. " ===") end
local function click(button) button._scripts.OnClick(button) end
local Contested = LootCheck.Contested

local function shownRows()
    local out = {}
    for _, row in ipairs(Contested._rows) do
        if row:IsShown() then tinsert(out, row) end
    end
    return out
end

section("every wishlisted item appears exactly once, with its wanters counted")
LootCheck.db.settings.contestedGroupOnly = false
SetTestGroup({})
local list = Contested:Rows({})
assert(#list > 0, "the wishlist data yields items")

local wish = LootCheck.Data:WishlistIndex()
local expectedItems = 0
for _ in pairs(wish) do expectedItems = expectedItems + 1 end
assert(#list == expectedItems, ("one row per item: %d rows for %d items"):format(#list, expectedItems))

local seen = {}
for _, r in ipairs(list) do
    assert(not seen[r.itemID], "item listed twice: " .. tostring(r.itemName))
    seen[r.itemID] = true

    -- The count is the number of distinct raiders, not the number of entries:
    -- a raider who wishlisted a ring twice is still one person wanting it
    local people = 0
    for _ in pairs(wish[r.itemID]) do people = people + 1 end
    assert(r.wanted == people, ("%s: counted %d, %d raiders want it"):format(tostring(r.itemName), r.wanted, people))
    assert(r.wanted == #r.wanters, "the count matches the list of wanters")
    assert(r.still <= r.wanted, "no more can still want it than want it")
end

section("the order puts live contention first, not the raw total")
for i = 2, #list do
    local before, after = list[i - 1], list[i]
    if before.still == after.still then
        if before.wanted == after.wanted then
            assert(tostring(before.itemName) <= tostring(after.itemName), "ties break by name")
        else
            assert(before.wanted >= after.wanted, "then by how many wanted it")
        end
    else
        assert(before.still > after.still, "sorted by who is still waiting")
    end
end
print(("most contested: %s, wanted by %d, %d still waiting"):format(
    list[1].itemName, list[1].wanted, list[1].still))

-- An item everyone already holds must not outrank one people are waiting on
local settled, waiting
for _, r in ipairs(list) do
    if not waiting and r.still > 0 then waiting = r end
    if not settled and r.still == 0 and r.wanted > 0 then settled = r end
end
if settled and waiting then
    local settledIndex, waitingIndex
    for i, r in ipairs(list) do
        if r == settled then settledIndex = i end
        if r == waiting then waitingIndex = i end
    end
    assert(waitingIndex < settledIndex,
        "an item people are still waiting on outranks one they all hold")
end

section("received raiders count towards wanted but not towards still waiting")
local subject
for _, r in ipairs(list) do
    if r.wanted > 1 then subject = r break end
end
assert(subject, "some item is wanted by more than one raider")

local received = 0
for _, w in ipairs(subject.wanters) do
    if w.received then received = received + 1 end
end
assert(subject.still == subject.wanted - received,
    ("%d want it, %d received, so %d should still be waiting, got %d"):format(
        subject.wanted, received, subject.wanted - received, subject.still))

-- Marking someone as having received it moves them out of "still waiting"
if subject.still > 0 then
    local target
    for _, w in ipairs(subject.wanters) do
        if not w.received then target = w break end
    end

    LootCheck.Awards:ApplyMark(target.norm, subject.itemID, subject.itemName, nil, false, GetServerTime())
    LootCheck.Data:Invalidate()

    local after
    for _, r in ipairs(Contested:Rows({})) do
        if r.itemID == subject.itemID then after = r break end
    end
    assert(after, "the item is still listed")
    assert(after.wanted == subject.wanted, "they still wanted it")
    assert(after.still == subject.still - 1,
        ("one fewer waiting: %d became %d"):format(subject.still, after.still))

    LootCheckDB.manualAwards = {}
    LootCheck.Data:Invalidate()
end

section("the group filter narrows it to raiders who are here")
local roster = LootCheck.Data:Roster()
local names = {}
for norm, r in pairs(roster) do
    if #names < 2 then tinsert(names, r.displayName or norm) end
end
SetTestGroup(names)

local grouped = Contested:Rows({ groupOnly = true })
local groupMembers = LootCheck.Data:GroupMembers()
for _, r in ipairs(grouped) do
    for _, w in ipairs(r.wanters) do
        assert(groupMembers[w.norm], ("%s is not in the group but was counted"):format(w.displayName))
    end
end
local ungrouped = Contested:Rows({})
assert(#grouped <= #ungrouped, "the filter cannot add items")
print(("items wanted by the group: %d of %d"):format(#grouped, #ungrouped))
SetTestGroup({})

section("the page renders, colours the contention and lists the wanters")
LootCheck.db.settings.contestedGroupOnly = false
Contested:Open()
local page = LootCheckContestedFrame
assert(page:IsShown(), "the page is up")
assert(page.head.wanted:GetText() == "Wanted by" and page.head.still:GetText() == "Still want",
    "columns are labelled")
assert(page.subtitle:GetText():find("wishlisted items", 1, true), page.subtitle:GetText())

local rendered = shownRows()
assert(#rendered > 0, "rows on screen")
for _, row in ipairs(rendered) do
    local r = row.data
    assert((row.wanted:GetText() or ""):find(tostring(r.wanted), 1, true), "the wanted count is shown")
    assert((row.still:GetText() or ""):find(tostring(r.still), 1, true), "and how many still want it")
end

-- Hovering names the raiders, greying the ones who already have it
LootCheck.Contested:ShowRowTooltip(rendered[1])
local tip = {}
for i = 1, GameTooltip:NumLines() do tip[i] = _G["GameTooltipTextLeft" .. i]:GetText() end
local text = table.concat(tip, "\n")
assert(text:find("Wanted by " .. rendered[1].data.wanted, 1, true), "the tooltip counts them: " .. text)
assert(text:find(rendered[1].data.wanters[1].displayName, 1, true), "and names them")

-- The group check box is wired to the setting
page.groupOnly:SetChecked(true)
click(page.groupOnly)
assert(LootCheck.db.settings.contestedGroupOnly == true, "the box writes the setting")
assert(page.subtitle:GetText():find("current group only", 1, true), page.subtitle:GetText())
page.groupOnly:SetChecked(false)
click(page.groupOnly)

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
LootCheck.Contested.rowCount = 1
LootCheck.Contested:Refresh()
for _, row in ipairs(LootCheck.Contested._rows) do
    if not row:IsShown() then
        assert(not row.guideTop:IsShown(), "a hidden row must not keep its guide")
    end
end

LootCheck.Contested.rowCount = 22
LootCheck.Contested:Refresh()

-- The other way a row goes away: it stays inside the row count, but the list
-- got shorter. That is a different loop in the refresh and it needs the same
-- clearing, or narrowing to the group leaves a line floating over an empty row.
SetTestGroup(names) -- a real group, so the narrowing is a real one
LootCheck.Contested.rowCount = 40
LootCheck.Contested:Refresh()
local tallest = shownRows()[#shownRows()]
local narrowed = #Contested:Rows({ groupOnly = true })

if tallest and #shownRows() > narrowed then
    tallest._scripts.OnEnter(tallest)
    assert(tallest.guideTop:IsShown(), "guided before the list shrinks under it")

    page.groupOnly:SetChecked(true)
    click(page.groupOnly)
    for _, row in ipairs(LootCheck.Contested._rows) do
        if not row:IsShown() then
            assert(not row.guideTop:IsShown(), "a row hidden by a shorter list must not keep its guide")
        end
    end
    print(("%d rows narrowed to %d"):format(#LootCheck.Contested._rows, narrowed))
    page.groupOnly:SetChecked(false)
    click(page.groupOnly)
else
    print("the group filter does not shorten this data enough to test the shrink")
end

SetTestGroup({})
LootCheck.Contested.rowCount = 22
LootCheck.Contested:Refresh()

section("the home page buttons wrap instead of running off the window")
LootCheck.Window:Show("home")
local home = LootCheckConfigFrame
assert(#home.buttons > 0, "the home page has buttons to lay out")

-- Whatever the button set is, no row may be wider than the page it sits on.
-- Widths from the narrowest the window goes up to a generous one, so a button
-- added later cannot quietly start overflowing at some size in between.
local floorWidth = LootCheck.Window:MinimumSize()
for width = 300, 2000, 50 do
    LootCheck.Config:LayoutButtons(home, width)
    assert(home.buttonRowWidth <= width - 22 * 2,
        ("buttons overflow at %d: widest row is %d"):format(width, home.buttonRowWidth))
end

LootCheck.Config:LayoutButtons(home, floorWidth)
assert(home.buttonRowWidth <= floorWidth - 22 * 2, "and at the window's own floor")

-- They do wrap when there is genuinely not room, and unwrap when there is
LootCheck.Config:LayoutButtons(home, 300)
assert(home.buttonRows > 1, "too narrow for one row: they wrap")

LootCheck.Config:LayoutButtons(home, 2000)
assert(home.buttonRows == 1, "and fit on one row when there is room")
LootCheck.Window:Hide()

section("the command opens it")
SlashCmdList.LOOTCHECK("contested")
assert(LootCheck.Window:Current() == "contested", "/lchelp contested")
SlashCmdList.LOOTCHECK("contested")
assert(not LootCheckWindow:IsShown(), "and toggles off")

section("cleanup")
LootCheck.Window:Hide()
LootCheck.db.settings.contestedGroupOnly = false
SetTestGroup({})

print("\nCONTESTED TESTS PASSED")
