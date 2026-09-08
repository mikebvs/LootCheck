-- Sharing manual edits with the ticked players: outgoing, incoming, and the limits.
local function section(t) print("\n=== " .. t .. " ===") end
local function click(button) button._scripts.OnClick(button) end
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
local function csv(rows)
    local lines = { "type,raid_group_name,character_name,character_class,sort_order,item_name,item_id,is_offspec" }
    for _, r in ipairs(rows) do tinsert(lines, "wishlist,PUG," .. r) end
    return table.concat(lines, "\n")
end
local function lastEdit()
    return FakeComm:Last("E|")
end

section("setup: a council of two, sharing on")
SetTestGroup({ "Casstronaut", "Pary-Nightslayer" })
SetTestClasses({ Casstronaut = "SHAMAN", ["Pary-Nightslayer"] = "WARLOCK" })
LootCheck.Comm:Init()
for _, imp in ipairs(LootCheck.Imports:List()) do LootCheck.Imports:Delete(imp.id) end
LootCheck.Imports:Add("Council", csv({
    "Casstronaut,Shaman,1,Tsunami Talisman,30627,0",
    "Pary,Warlock,1,Leggings of the Vanquished Hero,30247,0",
}))
local raid = LootCheck.Imports:Active()
assert(raid.shareId and raid.shareId ~= "", "an import carries a share id")
LootCheck.Comm:ShareList()["casstronaut"] = true
LootCheck.db.settings.shareEdits = true
local out = capture(function() LootCheck.Comm:AnnounceSharing() end)
assert(out:find("shared with Casstronaut", 1, true), out)

section("my edits go out to the ticked players only")
FakeComm:Reset()
SlashCmdList.LOOTCHECK("giveitem Casstronaut 30627")
local edit = lastEdit()
assert(edit, "an edit message was sent")
assert(edit.distribution == "WHISPER" and edit.target == "Casstronaut", "whispered to the ticked player only")
assert(edit.text:find("^E|1|mark|"), "mark message: " .. edit.text)
assert(#FakeComm.sent == 1, "not sent to the unticked player")
local markMessage = edit.text

FakeComm:Reset()
SlashCmdList.LOOTCHECK("addwlitem Newname 30247 #4")
edit = lastEdit()
assert(edit and edit.text:find("^E|1|wladd|"), "wladd message: " .. tostring(edit and edit.text))
assert(edit.text:find(raid.shareId, 1, true), "wishlist edits carry the dataset's share id")
local wladdMessage = edit.text

FakeComm:Reset()
SlashCmdList.LOOTCHECK("removewlitem Newname 30247")
local wlremoveMessage = lastEdit().text
FakeComm:Reset()
SlashCmdList.LOOTCHECK("removeitem Casstronaut 30627")
local unreceiveMessage = lastEdit().text
assert(unreceiveMessage:find("^E|1|unreceive|"), unreceiveMessage)

section("nothing goes out while sharing is off")
LootCheck.db.settings.shareEdits = false
FakeComm:Reset()
SlashCmdList.LOOTCHECK("giveitem Casstronaut 30627")
assert(not lastEdit(), "no edit message while sharing is off")
SlashCmdList.LOOTCHECK("removeitem Casstronaut 30627")

section("an incoming edit is refused while sharing is off, with one hint")
out = capture(function() FakeComm:Deliver("LootCheck", markMessage, "WHISPER", "Casstronaut") end)
assert(out:find("To accept them", 1, true), out)
assert(not LootCheck.Awards:AlreadyReceived("casstronaut", 30627, false), "nothing was applied")

section("with sharing on, an edit from a ticked player is applied")
LootCheck.db.settings.shareEdits = true
LootCheckDB.auditLog = {} -- so the entry checked below is unambiguously the shared one
out = capture(function() FakeComm:Deliver("LootCheck", markMessage, "WHISPER", "Casstronaut") end)
assert(out:find("Casstronaut marked Tsunami Talisman as received by Casstronaut", 1, true), out)
local mark = LootCheck.Awards:AlreadyReceived("casstronaut", 30627, false)
assert(mark and mark.manual, "the mark exists locally")

-- and it is attributed in the audit log (the mark and its log line share a timestamp,
-- so find the command entry rather than assuming it sorts first)
local logged
for _, e in ipairs(LootCheck.Audit:Entries({})) do
    if e.kind == "command" and e.cmd == "giveitem" then logged = e break end
end
assert(logged and logged.from == "Casstronaut", "audit records who shared it")

LootCheck.Audit:Open()
local shownFrom
for _, row in ipairs(LootCheck.Audit._rows) do
    if row:IsShown() and (row.text:GetText() or ""):find("(from Casstronaut)", 1, true) then shownFrom = true end
end
assert(shownFrom, "the audit page shows the sharer")
LootCheck.Window:Hide()

section("applying an incoming edit does not relay it again")
FakeComm:Reset()
FakeComm:Deliver("LootCheck", unreceiveMessage, "WHISPER", "Casstronaut")
assert(not LootCheck.Awards:AlreadyReceived("casstronaut", 30627, false), "the mark was removed")
assert(not lastEdit(), "a received edit is never passed on")

section("edits from players you have not ticked, or outside the group, are ignored")
FakeComm:Deliver("LootCheck", markMessage, "WHISPER", "Pary-Nightslayer")
assert(not LootCheck.Awards:AlreadyReceived("casstronaut", 30627, false), "unticked player ignored")
FakeComm:Deliver("LootCheck", markMessage, "WHISPER", "Randomstranger")
assert(not LootCheck.Awards:AlreadyReceived("casstronaut", 30627, false), "stranger ignored")
LootCheck.Comm:ShareList()["pary"] = true
FakeComm:Deliver("LootCheck", markMessage, "WHISPER", "Pary-Nightslayer")
assert(LootCheck.Awards:AlreadyReceived("casstronaut", 30627, false), "ticking them lets their edits through")
FakeComm:Deliver("LootCheck", unreceiveMessage, "WHISPER", "Pary-Nightslayer")
LootCheck.Comm:ShareList()["pary"] = nil

section("wishlist edits only apply to the same dataset")
local index = LootCheck.Data:WishlistIndex()
assert(not (index[30247] and index[30247]["newname"]), "not on the list to start with")
FakeComm:Deliver("LootCheck", wladdMessage, "WHISPER", "Casstronaut")
index = LootCheck.Data:WishlistIndex()
assert(index[30247] and index[30247]["newname"], "applied to the matching dataset")
FakeComm:Deliver("LootCheck", wlremoveMessage, "WHISPER", "Casstronaut")
index = LootCheck.Data:WishlistIndex()
assert(not (index[30247] and index[30247]["newname"]), "removal applied too")

-- switch to a different raid: the same edit must not land
LootCheck.Imports:Add("Another raid", csv({ "Casstronaut,Shaman,1,Tsunami Talisman,30627,0" }))
LootCheck.Comm.warnedAboutDataset = nil
out = capture(function() FakeComm:Deliver("LootCheck", wladdMessage, "WHISPER", "Casstronaut") end)
assert(out:find("wishlist you are not on right now", 1, true), out)
index = LootCheck.Data:WishlistIndex()
assert(not (index[30247] and index[30247]["newname"]), "nothing applied to the wrong dataset")
LootCheck.Imports:SetActive(raid.id, true)

section("a dataset sent on carries its share id, so edits follow it")
FakeComm:Reset()
LootCheck.Comm:SendDataset({ "Casstronaut" })
local payload = FakeComm:Last("D|")
local text = LootCheck.Comm:Decode(payload.text:sub(5))
assert(text:find("share=" .. raid.shareId, 1, true), "the export header carries the share id")
local _, _, _, meta = LootCheck.Imports:ParseCSV(text)
assert(meta.share == raid.shareId, "and it parses back out")

section("the send panel remembers the ticked players and the sharing switch")
LootCheck.Imports:Open()
LootCheck.Imports:ShowSend()
local page = LootCheckImportsFrame
assert(page.shareEdits:IsShown() and page.shareEdits:GetChecked(), "the switch shows its state")
assert(page.sendStatus:GetText():find("sharing edits", 1, true), page.sendStatus:GetText())
local shown = {}
for _, row in ipairs(page.sendRows) do if row:IsShown() then tinsert(shown, row) end end
assert(shown[1]:GetChecked(), "Casstronaut is still ticked from before")
out = capture(function()
    page.shareEdits:SetChecked(false)
    click(page.shareEdits)
end)
assert(out:find("no longer shared", 1, true), out)
assert(LootCheck.db.settings.shareEdits == false, "the switch writes the setting")
page.shareEdits:SetChecked(true)
click(page.shareEdits)
LootCheck.Imports:ShowSend()
assert(shown[1]:GetChecked(), "the tick survives reopening the panel")
LootCheck.Window:Hide()

section("cleanup")
for _, imp in ipairs(LootCheck.Imports:List()) do LootCheck.Imports:Delete(imp.id) end
LootCheck.db.shareWith = {}
LootCheck.db.settings.shareEdits = false
LootCheckDB.auditLog = {}
SetTestGroup({})
SetTestClasses({})

print("\nSHARE TESTS PASSED")
