-- Named CSV imports ("raids"): parsing, switching, per-raid manual edits, fallback, UI wiring.
-- Runs last: Gargul stub + real saved variables are in place; no LootCheck imports exist yet.
local function section(t) print("\n=== " .. t .. " ===") end
local function link(itemID, name)
    return ("|cffa335ee|Hitem:%d::::::::70::::::::::|h[%s]|h|r"):format(itemID, name or ("item" .. itemID))
end
local function tooltipNames(itemID)
    SimulateTooltip(GameTooltip, "x", link(itemID), {})
    local names = {}
    for i = 2, GameTooltip:NumLines() do
        local plain = LootCheck:StripColorCodes(_G["GameTooltipTextLeft" .. i]:GetText() or "")
        local n = plain:match("^%s+([^%s%[%(]+)") -- name up to the [prio] / (OS) marker
        if n then names[n:lower()] = true end
    end
    return names
end
local function total()
    local t = 0
    for _, r in ipairs(LootCheck.Data:WishlistAwardCounts({})) do t = t + r.count end
    return t
end
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

-- A CSV built from the real TMBExport rows, plus rows that must be skipped and a tier piece to remap
local function csvField(v)
    v = tostring(v == nil and "" or v)
    if v:find('[,"\n]') then return '"' .. v:gsub('"', '""') .. '"' end
    return v
end
local headers = { "type", "raid_group_name", "member_name", "character_name", "character_class", "sort_order",
                  "item_name", "item_id", "is_offspec", "instance_name", "source_name", "received_at", "note", "item_prio_note" }
local lines = { table.concat(headers, ",") }
for _, e in ipairs(TMBExportDB.wishlists) do
    local row = {}
    for i, h in ipairs(headers) do
        local v = e[h]
        if h == "type" then v = "wishlist" elseif h == "is_offspec" then v = e.is_offspec and "1" or "0" end
        row[i] = csvField(v)
    end
    tinsert(lines, table.concat(row, ","))
end
local imported = #TMBExportDB.wishlists
tinsert(lines, 'received,Raid,someone,Someone,Warrior,1,"Band of Devastation, Extra",30347,0,Black Temple,Illidan,2026-08-01 20:00:00,,')
tinsert(lines, "received,Raid,someone,Someone,Warrior,2,Another Thing,12345,0,,,2026-08-02 20:00:00,,")
tinsert(lines, "prio,Raid,someone,Someone,Warrior,1,Some Prio Item,23456,0,,,,,")
tinsert(lines, "wishlist,Raid,newguy2,Newguy2,Warrior,1,Warbringer Greathelm,29011,0,,,,,") -- tier piece -> token 29761
local csv = table.concat(lines, "\r\n")

section("baseline (TMBExport fallback)")
assert(LootCheck:WishlistData().id == "tmbexport", "should be on the TMBExport fallback before any import")
local baseTotal = total()
print("baseline current total:", baseTotal)

section("parse + add 'Raid A' from a real-shaped CSV")
local out = capture(function() LootCheck.Imports:Add("Raid A", csv) end)
assert(out:find("imported 'Raid A'", 1, true), out)
local raidA = LootCheck.Imports:Active()
assert(raidA and raidA.name == "Raid A", "Raid A should be active")
assert(LootCheck:WishlistData().source == "Raid A", "wishlist source should be Raid A")
assert(raidA.stats.entries == imported + 1, ("entries: %d vs %d"):format(raidA.stats.entries, imported + 1))
assert(raidA.stats.received == 2, "2 received rows should be counted as skipped")
local remapped
for _, e in ipairs(raidA.entries) do if e.character_name == "Newguy2" then remapped = e end end
assert(remapped and remapped.item_id == 29761 and remapped.item_name == "Helm of the Fallen Defender",
    "tier piece should be remapped to its token: " .. tostring(remapped and remapped.item_name))
assert(raidA.remapped >= 1, "remapped counter")
assert(total() == baseTotal, "same rows -> same current total")
local entries = LootCheck.Imports:ParseCSV('type,character_name,item_name,item_id\nwishlist,Bob,"Ring, of ""Commas""",111\n')
assert(#entries == 1 and entries[1].item_name == 'Ring, of "Commas"' and entries[1].item_id == 111, "quoted field: " .. tostring(entries[1] and entries[1].item_name))

section("bad input is rejected and not stored")
out = capture(function() LootCheck.Imports:Add("Junk", "hello world\nthis is not csv") end)
assert(out:find("doesn't look like", 1, true), out)
out = capture(function() LootCheck.Imports:Add("Empty", "type,character_name,item_id\nreceived,Bob,1\n") end)
assert(out:find("no wishlist rows", 1, true), out)
assert(#LootCheck.Imports:List() == 1, "bad imports must not be stored")

section("second import 'PUG night' -> active switches; tooltip + graph follow the active raid")
local pugCsv = "type,raid_group_name,character_name,character_class,sort_order,item_name,item_id,is_offspec\n"
    .. "wishlist,PUG,Newguy,Rogue,1,Tsunami Talisman,30627,0\n"
    .. "wishlist,PUG,Newguy,Rogue,2,Band of Devastation,30347,0\n"
LootCheck.Imports:Add("PUG night", pugCsv)
assert(LootCheck.Imports:Active().name == "PUG night", "PUG night should be active")
assert(tooltipNames(30627)["newguy"], "Newguy should be on the tooltip under PUG night")
local rows = LootCheck.Data:WishlistAwardCounts({})
assert(#rows == 1 and rows[1].normName == "newguy", "graph shows only the PUG roster")
out = capture(function() SlashCmdList.LOOTCHECK("use raid a") end)
assert(out:find("active raid is now 'Raid A'", 1, true), out)
assert(not tooltipNames(30627)["newguy"], "Newguy is not on Raid A")
assert(total() == baseTotal, "Raid A totals back")
out = capture(function() SlashCmdList.LOOTCHECK("use nope") end)
assert(out:find("no raid import", 1, true), out)
out = capture(function() SlashCmdList.LOOTCHECK("use") end)
assert(out:find("Usage", 1, true), out)

section("manual edits are per raid")
SlashCmdList.LOOTCHECK("addwlitem Newguy3 Tsunami Talisman")
assert(LootCheck.Data:Roster()["newguy3"], "added under Raid A")
LootCheck.Imports:SetActiveByName("PUG night")
assert(not LootCheck.Data:Roster()["newguy3"], "not under PUG night")
LootCheck.Imports:SetActiveByName("Raid A")
assert(LootCheck.Data:Roster()["newguy3"], "back under Raid A")
assert(LootCheckDB.overrides[raidA.id] and #LootCheckDB.overrides[raidA.id].added == 1, "stored under the raid's id")
out = capture(function() SlashCmdList.LOOTCHECK("overrides") end)
assert(out:find("for Raid A", 1, true), out)
SlashCmdList.LOOTCHECK("clearoverrides confirm")
assert(not LootCheck.Data:Roster()["newguy3"], "cleared")

section("delete: PUG night via the confirm popup, then Raid A -> fallback to TMBExport")
local pugId = LootCheck.Imports:FindByName("PUG night").id
LootCheck.Imports:Open()
assert(LootCheck.Imports:ConfirmDelete(pugId), "confirmation shown")
assert(LootCheckImportsFrameConfirm:IsShown(), "confirm frame shown")
LootCheckImportsFrameConfirm.no._scripts.OnClick(LootCheckImportsFrameConfirm.no)
assert(not LootCheckImportsFrameConfirm:IsShown() and LootCheck.Imports:Get(pugId), "Cancel keeps the import")
LootCheck.Imports:ConfirmDelete(pugId)
LootCheckImportsFrameConfirm.yes._scripts.OnClick(LootCheckImportsFrameConfirm.yes)
assert(not LootCheckImportsFrameConfirm:IsShown(), "confirm frame hidden")
assert(not LootCheck.Imports:Get(pugId), "PUG deleted")
LootCheck.Window:Hide() -- the confirmation opened the page; later sections expect a closed window
assert(LootCheck.Imports:Active().name == "Raid A", "Raid A still active")
out = capture(function() LootCheck.Imports:Delete(raidA.id) end)
assert(out:find("falling back to TMBExport", 1, true), out)
assert(#LootCheck.Imports:List() == 0, "no imports left")
assert(LootCheck:WishlistData().id == "tmbexport", "fallback to TMBExport")
assert(total() == baseTotal, "fallback totals")

section("copy from TMBExport")
local copied = LootCheck.Imports:CopyFromTMBExport()
assert(copied and copied.stats.entries == imported and LootCheck:WishlistData().id == copied.id, "copied import active")
assert(total() == baseTotal, "copied totals")

section("UI: window, dropdown entries, new-import panel flow, duplicate names")
SlashCmdList.LOOTCHECK("imports")
assert(LootCheckImportsFrame and LootCheckImportsFrame:IsShown(), "window shown")
assert(LootCheckImportsFrameDropdown:GetText() == copied.name, "picker shows the active raid: " .. tostring(LootCheckImportsFrameDropdown:GetText()))
local function menuEntries()
    local shown = {}
    for _, item in ipairs(LootCheck.Imports._menuItems) do
        if item:IsShown() then tinsert(shown, item) end
    end
    return shown
end
LootCheck.Imports:ToggleMenu()
assert(LootCheckImportsFrameMenu:IsShown(), "menu opens")
assert(#menuEntries() == 1, "one import listed")
LootCheck.Imports:ToggleMenu()
assert(not LootCheckImportsFrameMenu:IsShown(), "menu closes again")
LootCheck.Imports:ShowNewPanel(true)
LootCheckImportsFrameNameBox:SetText("Raid B")
LootCheckImportsFramePasteBox:SetText(pugCsv)
LootCheck.Imports:ImportFromUI()
assert(LootCheck.Imports:Active().name == "Raid B", "imported from the UI and made active")
assert(LootCheckImportsFramePasteBox:GetText() == "", "paste box cleared")
LootCheck.Imports:OpenMenu()
local entries = menuEntries()
assert(#entries == 2, "two imports listed")
local firstID = entries[1].importID
entries[1]._scripts.OnClick(entries[1]) -- pick the first entry through the menu
assert(LootCheck.Imports:Active().id == firstID, "menu click switches the active raid")
assert(not LootCheckImportsFrameMenu:IsShown(), "menu closes after choosing")
LootCheck.Imports:ShowNewPanel(true)
LootCheckImportsFramePasteBox:SetText("")
out = capture(function() LootCheck.Imports:ImportFromUI() end)
assert(out:find("paste the CSV", 1, true), out)
LootCheck.Imports:Add("Raid B", pugCsv)
assert(LootCheck.Imports:FindByName("Raid B (2)"), "duplicate name gets a suffix")
SlashCmdList.LOOTCHECK("imports")
assert(not LootCheckImportsFrame:IsShown() and not LootCheckWindow:IsShown(), "toggled off")

section("export / import round trip (sync with another user)")
LootCheck.Imports:Add("Sync A", pugCsv) -- Newguy: 30627 prio 1, 30347 prio 2
SlashCmdList.LOOTCHECK("addwlitem Newguy4 Tsunami Talisman #7")
SlashCmdList.LOOTCHECK("removewlitem Newguy " .. link(30347, "Band of Devastation"))
local text = LootCheck.Imports:ExportText()
assert(text and text:find("^# LootCheck wishlist export"), "export header")
assert(text:find("name=Sync A", 1, true), "name in the metadata line")
assert(text:find("Newguy4", 1, true), "manual add included")
assert(not text:find("Band of Devastation", 1, true), "removed entry excluded")
print(text:sub(1, 400))
out = capture(function() LootCheck.Imports:Add("", text) end) -- blank name: taken from the export
assert(out:find("imported 'Sync A (2)'", 1, true), out)
local copy = LootCheck.Imports:Active()
assert(copy.stats.entries == 2, "effective dataset: 2 entries, got " .. copy.stats.entries)
local manualRow
for _, e in ipairs(copy.entries) do if e.character_name == "Newguy4" then manualRow = e end end
assert(manualRow and manualRow.manual == true and manualRow.sort_order == 7, "manual row kept its tag and prio")
assert(LootCheck.Data:WishlistIndex()[30627]["newguy4"].entries[1].manual, "manual flag flows into the index")
LootCheck.Imports:Open()
LootCheck.Imports:ShowExport()
assert(LootCheckImportsFramePasteBox:GetText() == LootCheck.Imports:ExportText(), "export of the active raid shown in the box")
assert(LootCheckImportsFramePasteBox:GetText():find("name=Sync A (2)", 1, true), "the active raid is the copy now")
LootCheck.Imports:ImportFromUI() -- must be a no-op in export mode
assert(LootCheck.Imports:Active().id == copy.id, "no import happened from export mode")
LootCheck.Window:Hide()

section("legacy flat overrides migrate to the tmbexport bucket")
for _, imp in ipairs(LootCheck.Imports:List()) do LootCheck.Imports:Delete(imp.id) end
assert(LootCheck:WishlistData().id == "tmbexport", "back on the fallback")
LootCheckDB.overrides = {
    added = { { character = "Old", norm = "old", itemID = 30627, itemName = "Tsunami Talisman", prio = 1, os = false } },
    removed = {},
}
local added = LootCheck.Wishlist:Counts()
assert(added == 1, "legacy add visible after migration")
assert(LootCheckDB.overrides.added == nil and LootCheckDB.overrides.tmbexport and #LootCheckDB.overrides.tmbexport.added == 1, "migrated")
SlashCmdList.LOOTCHECK("clearoverrides confirm")

section("status mentions the source")
out = capture(function() SlashCmdList.LOOTCHECK("status") end)
assert(out:find("Wishlist source: |cffffffffTMBExport|r", 1, true), out)

print("\nIMPORTS TESTS PASSED")
