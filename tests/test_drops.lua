-- Raid drops: recording from the loot window, raid weeks, and the panel on
-- the Wishlist Awards page.
local function section(t) print("\n=== " .. t .. " ===") end
local function click(button) button._scripts.OnClick(button) end
local DAY, WEEK = 86400, 604800
local Drops = LootCheck.Drops

local function reset()
    LootCheckDB.drops = {}
    Drops:Invalidate()
    Drops.weekOffset = 0
    LootCheck.db.settings.dropsIncludeRare = false
    LootCheck.db.settings.dropsGearOnly = false
end

local function rowTexts()
    local out = {}
    for _, row in ipairs(Drops._rows) do
        if row:IsShown() then tinsert(out, row.text:GetText() or "") end
    end
    return out
end

section("a raid week starts at the Tuesday reset and covers seven days")
local now = GetServerTime()
local start = Drops:WeekStart(now)
local t = date("*t", start)
assert(t.wday == Drops.RESET_WDAY, "the week starts on a Tuesday, got wday " .. t.wday)
assert(t.hour == Drops.RESET_HOUR and t.min == 0 and t.sec == 0, "at the reset hour, got " .. t.hour)
assert(start <= now and now < start + WEEK, "and it contains right now")

-- an hour before its own reset still belongs to the week before
assert(Drops:WeekStart(start - 3600) == start - WEEK, "just before the reset is still last week")
assert(Drops:WeekStart(start + 3600) == start, "just after it is this week")

local from, to = Drops:WeekBounds(0)
assert(from == start and to == start + WEEK, "this week's bounds")
assert(Drops:WeekBounds(2) == start - 2 * WEEK, "two weeks back")
assert(Drops:WeekLabel(0):find("This week", 1, true), Drops:WeekLabel(0))
assert(Drops:WeekLabel(1):find("Last week", 1, true), Drops:WeekLabel(1))
assert(Drops:WeekLabel(3):find("3 weeks ago", 1, true), Drops:WeekLabel(3))

section("drops are only recorded in a raid")
reset()
SetTestGroup({})
SetTestInstance(nil)
SetTestLoot({
    guid = "Creature-0-1-532-1-15690-000000",
    source = "Prince Malchezaar",
    zone = "Karazhan",
    items = { { id = 30627, name = "Tsunami Talisman", quality = 4 } },
})
assert(not Drops:ShouldTrack(), "solo, not in an instance")
assert(Drops:ScanLootWindow() == 0, "nothing recorded outside a raid")
assert(#LootCheckDB.drops == 0, "log still empty")

SetTestInstance("party")
assert(not Drops:ShouldTrack(), "a 5-man is not a raid")

section("inside a raid the loot window is read, and only once per corpse")
SetTestInstance("raid")
assert(Drops:ShouldTrack(), "raid instance tracks")
assert(Drops:ScanLootWindow() == 1, "one item recorded")
local drop = LootCheckDB.drops[1]
assert(drop.itemID == 30627 and drop.itemName == "Tsunami Talisman", "item stored: " .. tostring(drop.itemName))
assert(drop.source == "Prince Malchezaar" and drop.zone == "Karazhan", "corpse and zone stored")
assert(drop.quality == 4 and drop.itemLink:find("Tsunami Talisman", 1, true), "quality and link stored")

-- LOOT_READY and LOOT_OPENED both fire for the same corpse
FireEvent("LOOT_OPENED")
FireEvent("LOOT_READY")
assert(#LootCheckDB.drops == 1, "reopening the same corpse records nothing new")

-- a different corpse dropping the same item is a separate drop
SetTestLoot({
    guid = "Creature-0-1-532-1-15690-111111",
    source = "Netherspite",
    zone = "Karazhan",
    items = { { id = 30627, name = "Tsunami Talisman", quality = 4 } },
})
FireEvent("LOOT_OPENED")
assert(#LootCheckDB.drops == 2, "a second corpse is recorded")

section("greens are ignored, blues are stored but hidden until asked for")
reset()
SetTestLoot({
    guid = "Creature-0-1-532-1-15690-222222",
    source = "Attumen the Huntsman",
    zone = "Karazhan",
    items = {
        { id = 30627, name = "Tsunami Talisman", quality = 4 },
        { id = 28040, name = "Some Blue Thing", quality = 3 },
        { id = 22463, name = "A Green Thing", quality = 2 },
        { id = 29434, name = "Badge of Justice", quality = 4, slotType = 2 }, -- currency slot: skipped
    },
})
assert(Drops:ScanLootWindow() == 2, "epic and rare stored, green and currency skipped")

local list = Drops:List()
assert(#list == 1 and list[1].itemID == 30627, "only the epic is listed by default")
LootCheck.db.settings.dropsIncludeRare = true
list = Drops:List()
assert(#list == 2, "the blue appears once asked for, without having been re-looted")
LootCheck.db.settings.dropsIncludeRare = false

section("the list is per raid week, newest first")
reset()
local weekStart = Drops:WeekStart()
Drops:Record({ key = "a", t = weekStart + 3600, itemID = 30627, itemName = "Early", quality = 4 })
Drops:Record({ key = "b", t = weekStart + 7200, itemID = 30247, itemName = "Later", quality = 4 })
Drops:Record({ key = "c", t = weekStart - DAY, itemID = 30246, itemName = "Last week", quality = 4 })
list = Drops:List()
assert(#list == 2, "this week has two, got " .. #list)
assert(list[1].itemName == "Later" and list[2].itemName == "Early", "newest first")
list = Drops:List({ weekOffset = 1 })
assert(#list == 1 and list[1].itemName == "Last week", "last week has the older one")

section("each drop is paired with the award that followed it")
reset()
-- Pick a real player/item pair out of the active wishlist data, choosing an
-- item Gargul has never awarded so real award history cannot pair with it.
local wish = LootCheck.Data:WishlistIndex()
local awardIndex = LootCheck.Data:AwardIndex()
local itemID, norm
for id, players in pairs(wish) do
    if not awardIndex[id] then
        for who in pairs(players) do
            itemID, norm = id, who
            break
        end
    end
    if itemID then break end
end
assert(itemID, "the wishlist data has an item with no awards against it")

local dropTime = Drops:WeekStart() + 3600
Drops:Record({ key = "pair1", t = dropTime, itemID = itemID, itemName = "Wanted", quality = 4 })
Drops:Record({ key = "pair2", t = dropTime + 60, itemID = itemID, itemName = "Wanted", quality = 4 })

list = Drops:List()
assert(#list == 2, "both drops listed")
assert(not list[1].award and not list[2].award, "neither is awarded yet")
assert(#list[1].wanters > 0, "the raiders who want it are attached")

LootCheck.Data:Invalidate()
LootCheck.Awards:ApplyMark(norm, itemID, "Wanted", nil, false, dropTime + 120)
LootCheck.Data:Invalidate()
list = Drops:List()
-- newest first, so the older drop is list[2]; one award, so exactly one pairs up
local awarded = 0
for _, r in ipairs(list) do
    if r.award then awarded = awarded + 1 end
end
assert(awarded == 1, "one award pairs with one drop, got " .. awarded)

LootCheck.Awards:ApplyMark(norm, itemID, "Wanted", nil, false, dropTime + 180, nil)
LootCheck.Data:Invalidate()
awarded = 0
for _, r in ipairs(Drops:List()) do
    if r.award then awarded = awarded + 1 end
end
assert(awarded == 2, "a second award pairs with the second drop, got " .. awarded)

-- an award from before the drop is not claimed by it
reset()
LootCheck.Data:Invalidate()
Drops:Record({ key = "late", t = dropTime + 4 * 3600, itemID = itemID, itemName = "Wanted", quality = 4 })
assert(not Drops:List()[1].award, "an earlier award does not attach to a later drop")

section("old weeks are pruned")
reset()
Drops:Record({ key = "ancient", t = Drops:WeekStart() - (Drops.KEEP_WEEKS + 1) * WEEK, itemID = 30627, quality = 4 })
assert(#LootCheckDB.drops == 0, "an entry older than the kept window is dropped on write")
Drops:Record({ key = "recent", t = Drops:WeekStart() + 60, itemID = 30627, quality = 4 })
assert(#LootCheckDB.drops == 1, "a recent one is kept")

section("the panel lists the week and steps back through earlier ones")
reset()
Drops:Record({ key = "now1", t = Drops:WeekStart() + 3600, itemID = 30627, itemName = "This week epic", quality = 4 })
Drops:Record({ key = "old1", t = Drops:WeekStart() - 2 * DAY, itemID = 30247, itemName = "Older epic", quality = 4 })

LootCheck.Graph:Open()
assert(LootCheckGraphFrame:IsShown(), "the graph page is up")
local panel = LootCheckGraphFrameDrops
assert(panel and panel.week:GetText():find("This week", 1, true), "the panel names the week")
assert(panel.count:GetText() == "1 dropped, 0 awarded", panel.count:GetText())
assert(#rowTexts() == 1 and rowTexts()[1]:find("This week epic", 1, true), "this week's drop is on screen")

click(panel.prevWeek)
assert(Drops.weekOffset == 1 and panel.week:GetText():find("Last week", 1, true), "stepped back a week")
assert(#rowTexts() == 1 and rowTexts()[1]:find("Older epic", 1, true), "last week's drop is on screen")

click(panel.nextWeek)
assert(Drops.weekOffset == 0, "and forward again")
assert(rowTexts()[1]:find("This week epic", 1, true), "back to this week")

-- the forward button stops at this week, the back button at the kept window
click(panel.nextWeek)
assert(Drops.weekOffset == 0, "cannot step into the future")
for _ = 1, Drops.KEEP_WEEKS + 3 do click(panel.prevWeek) end
assert(Drops.weekOffset == Drops.KEEP_WEEKS - 1, "cannot step past what is kept")
Drops.weekOffset = 0
Drops:RefreshPanel()

section("the blue check box is wired to the list")
Drops:Record({ key = "blue1", t = Drops:WeekStart() + 3600, itemID = 28040, itemName = "A blue", quality = 3 })
Drops:RefreshPanel()
assert(#rowTexts() == 1, "blues are hidden by default")
panel.includeRare:SetChecked(true)
click(panel.includeRare)
assert(LootCheck.db.settings.dropsIncludeRare == true, "the box writes the setting")
assert(#rowTexts() == 2, "and the blue shows up")
panel.includeRare:SetChecked(false)
click(panel.includeRare)

section("gear is told from gems and reagents by where the client says it goes")
reset()
local gearWeek = Drops:WeekStart() + 3600
SetTestItems({
    [32837] = { name = "Warglaive of Azzinoth", equipLoc = "INVTYPE_WEAPONMAINHAND" },
    [32409] = { name = "Relentless Earthstorm Diamond", equipLoc = "" }, -- a gem
    [23572] = { name = "Primal Nether", equipLoc = "" },                 -- a reagent
    [21841] = { name = "Netherweave Bag", equipLoc = "INVTYPE_BAG" },
})

assert(Drops:IsGear(32837) == true, "a weapon is gear")
assert(Drops:IsGear(32409) == false, "a gem is not")
assert(Drops:IsGear(23572) == false, "nor is a crafting reagent")
assert(Drops:IsGear(21841) == false, "nor is a bag")

-- Tier tokens cannot be equipped, so the client has no slot for them; they are
-- the most contested gear in the raid all the same
assert(Drops:IsGear(29764) == true, "a tier token is gear even with nothing cached")

-- An item the client has not loaded cannot be judged either way, and saying so
-- is what keeps it on the list instead of it vanishing
assert(Drops:IsGear(999999) == nil, "an uncached item is not yet known either way")

Drops:Record({ key = "g1", t = gearWeek, itemID = 32837, itemName = "Warglaive of Azzinoth", quality = 4 })
Drops:Record({ key = "g2", t = gearWeek + 60, itemID = 32409, itemName = "Relentless Earthstorm Diamond", quality = 4 })
Drops:Record({ key = "g3", t = gearWeek + 120, itemID = 23572, itemName = "Primal Nether", quality = 4 })
Drops:Record({ key = "g4", t = gearWeek + 180, itemID = 29764, itemName = "Pauldrons of the Fallen Defender", quality = 4 })
Drops:Record({ key = "g5", t = gearWeek + 240, itemID = 999999, itemName = "Something Uncached", quality = 4 })

assert(#Drops:List({ gearOnly = false }) == 5, "everything is recorded whatever the filter shows")

local gearList = Drops:List({ gearOnly = true })
local gearNames = {}
for _, r in ipairs(gearList) do gearNames[r.itemName] = true end
assert(#gearList == 3, "the gem and the reagent are gone, got " .. #gearList)
assert(gearNames["Warglaive of Azzinoth"], "worn and wielded items stay")
assert(gearNames["Pauldrons of the Fallen Defender"], "and so do tier tokens")
assert(gearNames["Something Uncached"], "and so does one the client cannot judge yet")
assert(not gearNames["Relentless Earthstorm Diamond"] and not gearNames["Primal Nether"],
    "the rest are hidden")

section("the gear check box is wired to the list")
Drops:RefreshPanel()
assert(#rowTexts() == 5, "everything shows with the box unticked, got " .. #rowTexts())
panel.gearOnly:SetChecked(true)
click(panel.gearOnly)
assert(LootCheck.db.settings.dropsGearOnly == true, "the box writes the setting")
assert(#rowTexts() == 3, "and the list drops what is not gear, got " .. #rowTexts())

-- A week whose every drop is filtered out has to say so, or it reads as a week
-- where nothing dropped at all
LootCheckDB.drops = {}
Drops:Invalidate()
Drops:Record({ key = "g6", t = gearWeek, itemID = 32409, itemName = "Relentless Earthstorm Diamond", quality = 4 })
Drops:RefreshPanel()
assert(#rowTexts() == 0 and panel.empty:IsShown(), "nothing left to show")
assert(panel.empty:GetText():find("Gear only", 1, true), panel.empty:GetText())

panel.gearOnly:SetChecked(false)
click(panel.gearOnly)
assert(#rowTexts() == 1, "unticking brings it back, without it having been re-looted")
SetTestItems({})

section("an empty week says so")
Drops:Clear()
Drops:RefreshPanel()
assert(#rowTexts() == 0 and panel.empty:IsShown(), "no rows, empty message shown")
assert(panel.empty:GetText():find("Nothing recorded yet this week", 1, true), panel.empty:GetText())
LootCheck.Window:Hide()

section("/lchelp drops opens the page, /lchelp drops clear empties the log")
Drops:Record({ key = "z", t = Drops:WeekStart() + 60, itemID = 30627, quality = 4 })
SlashCmdList.LOOTCHECK("drops")
assert(LootCheckGraphFrame:IsShown() and Drops.weekOffset == 0, "the command opens the graph on this week")
SlashCmdList.LOOTCHECK("drops clear")
assert(#LootCheckDB.drops == 0, "the log was cleared")
LootCheck.Window:Hide()

section("loot messages in chat are parsed in all four shapes")
local EPIC = "|cffa335ee|Hitem:30627::::::::70:::::|h[Tsunami Talisman]|h|r"
local BLUE = "|cff0070dd|Hitem:28040::::::::70:::::|h[Blue Thing]|h|r"
local GREEN = "|cff1eff00|Hitem:22463::::::::70:::::|h[Green Thing]|h|r"

local link, who, count = Drops:ParseLootMessage("John receives loot: " .. EPIC .. ".")
assert(link == EPIC and who == "John" and count == 1, "someone else, single")
link, who, count = Drops:ParseLootMessage("John receives loot: " .. EPIC .. "x3.")
assert(link == EPIC and who == "John" and count == 3, "someone else, stack of " .. tostring(count))
link, who, count = Drops:ParseLootMessage("You receive loot: " .. EPIC .. ".")
assert(link == EPIC and who == "Steven" and count == 1, "yourself, single: " .. tostring(who))
link, who, count = Drops:ParseLootMessage("You receive loot: " .. EPIC .. "x2.")
assert(link == EPIC and who == "Steven" and count == 2, "yourself, stack")
assert(not Drops:ParseLootMessage("John says hello"), "unrelated chat is not loot")
assert(Drops:QualityFromLink(EPIC) == 4 and Drops:QualityFromLink(BLUE) == 3, "quality comes off the link colour")

section("chat receipts are only recorded in a raid, and only rare and up")
reset()
SetTestGroup({})
SetTestInstance(nil)
FireEvent("CHAT_MSG_LOOT", "John receives loot: " .. EPIC .. ".")
assert(#LootCheckDB.drops == 0, "nothing recorded outside a raid")

SetTestInstance("raid")
FireEvent("CHAT_MSG_LOOT", "John receives loot: " .. GREEN .. ".")
assert(#LootCheckDB.drops == 0, "greens are ignored")

FireEvent("CHAT_MSG_LOOT", "John receives loot: " .. EPIC .. ".")
assert(#LootCheckDB.drops == 1, "the epic was recorded")
local chatDrop = LootCheckDB.drops[1]
assert(chatDrop.via == "chat" and chatDrop.lootedBy == "John", "recorded as a chat receipt")
assert(chatDrop.itemID == 30627 and chatDrop.quality == 4, "item and quality read off the link")

section("a receipt for an item already seen on the corpse fills the looter in")
reset()
SetTestLoot({
    guid = "Creature-0-1-532-1-15690-333333",
    source = "Prince Malchezaar",
    zone = "Karazhan",
    items = { { id = 30627, name = "Tsunami Talisman", quality = 4 } },
})
FireEvent("LOOT_OPENED")
assert(#LootCheckDB.drops == 1 and LootCheckDB.drops[1].via == "loot", "seen on the corpse first")
assert(not LootCheckDB.drops[1].lootedBy, "nobody has picked it up yet")

FireEvent("CHAT_MSG_LOOT", "John receives loot: " .. EPIC .. ".")
assert(#LootCheckDB.drops == 1, "the receipt did not add a second row, got " .. #LootCheckDB.drops)
assert(LootCheckDB.drops[1].lootedBy == "John", "the looter was filled in")
assert(LootCheckDB.drops[1].source == "Prince Malchezaar", "the corpse it came from is kept")

-- a second receipt for the same item has nothing left to attach to, so it stands alone
FireEvent("CHAT_MSG_LOOT", "Mary receives loot: " .. EPIC .. ".")
assert(#LootCheckDB.drops == 2, "a second receipt is its own row")
assert(LootCheckDB.drops[2].lootedBy == "Mary" and LootCheckDB.drops[2].via == "chat", "recorded from chat")

section("who looted it is not who it was assigned to")
reset()
LootCheck.Data:Invalidate()
local wish2 = LootCheck.Data:WishlistIndex()
local awards2 = LootCheck.Data:AwardIndex()
local wantedID, winner
for id, players in pairs(wish2) do
    if not awards2[id] then -- nothing in the real history can pair with it
        for w in pairs(players) do
            wantedID, winner = id, w
            break
        end
    end
    if wantedID then break end
end
assert(wantedID, "the wishlist data has an item with no awards against it")

local dropAt = Drops:WeekStart() + 3600
-- the master looter's bags were full, so a council member holds it
Drops:Record({
    key = "held", t = dropAt, itemID = wantedID, itemName = "Held item", quality = 4,
    lootedBy = "John", lootedNorm = "john", lootedAt = dropAt,
})
local held = Drops:List()[1]
assert(held.lootedBy == "John", "the holder is listed")
assert(not held.award, "and it is not assigned to anyone yet")

-- later that night it is assigned to someone else entirely in Gargul
LootCheck.Awards:ApplyMark(winner, wantedID, "Held item", nil, false, dropAt + 7200)
LootCheck.Data:Invalidate()
held = Drops:List()[1]
assert(held.lootedBy == "John", "the holder is unchanged")
assert(held.award and LootCheck:NormalizeName(held.award.awardedTo) == winner,
    "the assignment is picked up separately from who looted it")
LootCheckDB.manualAwards = {}
LootCheck.Data:Invalidate()

section("the panel shows both names in their own columns")
reset()
Drops:Record({
    key = "cols", t = Drops:WeekStart() + 600, itemID = 30627, itemName = "Two column item", quality = 4,
    lootedBy = "John", lootedNorm = "john", lootedAt = Drops:WeekStart() + 600,
})
LootCheck.Graph:Open()
local shownRow
for _, row in ipairs(Drops._rows) do
    if row:IsShown() then shownRow = row break end
end
assert(shownRow, "a row is on screen")
assert((shownRow.looted:GetText() or ""):find("John", 1, true), "the looter column: " .. tostring(shownRow.looted:GetText()))
assert((shownRow.status:GetText() or ""):find("want", 1, true) or (shownRow.status:GetText() or ""):find("-", 1, true),
    "the assigned column is separate: " .. tostring(shownRow.status:GetText()))
assert(LootCheckGraphFrameDrops.head.looted:GetText() == "Looted by", "the column is labelled")
assert(LootCheckGraphFrameDrops.head.status:GetText() == "Assigned", "and so is the other one")
LootCheck.Window:Hide()

section("/lchelp testdrops fills the list without touching real drops")
reset()
LootCheck.Data:Invalidate()
Drops:Record({ key = "real-one", t = Drops:WeekStart() + 120, itemID = 30627, itemName = "A real drop", quality = 4 })

SlashCmdList.LOOTCHECK("testdrops true")
local total = #LootCheckDB.drops
assert(total > 1, "test drops were added, got " .. total)
assert(Drops:TestDataCount() == total - 1, "every added entry is flagged as test data")

-- the real one is still there and is not flagged
local real
for _, d in ipairs(LootCheckDB.drops) do
    if d.key == "real-one" then real = d end
end
assert(real and not Drops:IsTest(real), "the real drop survived and stayed real")

-- both weeks got something, so the < stepper has something to show
assert(#Drops:List({ weekOffset = 0 }) > 0, "this week has test drops")
assert(#Drops:List({ weekOffset = 1 }) > 0, "last week has test drops")

-- drops built from real awards pair up on their own
local pairedAward = false
for week = 0, Drops.KEEP_WEEKS - 1 do
    for _, r in ipairs(Drops:List({ weekOffset = week })) do
        if r.test and r.award then pairedAward = true end
    end
end
assert(pairedAward, "at least one test drop pairs with the award it was built from")

-- running it again replaces rather than duplicates
local again = #LootCheckDB.drops
SlashCmdList.LOOTCHECK("testdrops true")
assert(#LootCheckDB.drops == again, "re-running replaces the test data instead of doubling it")

section("the panel calls test data out")
LootCheck.Graph:Open()
assert(LootCheckGraphFrameDrops.count:GetText():find("test", 1, true), LootCheckGraphFrameDrops.count:GetText())
LootCheck.Window:Hide()

section("/lchelp testdrops false removes only the test data")
local removed = Drops:TestDataCount()
SlashCmdList.LOOTCHECK("testdrops false")
assert(Drops:TestDataCount() == 0, "no test data left")
assert(#LootCheckDB.drops == 1 and LootCheckDB.drops[1].key == "real-one", "the real drop is untouched")
assert(removed > 0, "something was actually removed")

section("cleanup")
reset()
LootCheckDB.manualAwards = {}
LootCheck.Data:Invalidate()
SetTestLoot(nil)
SetTestInstance(nil)
SetTestGroup({})

print("\nDROPS TESTS PASSED")
