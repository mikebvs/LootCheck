-- Sending the dataset to chosen players, and the receiver's save / merge / discard choice.
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

section("setup: a group, an active raid, sync initialised")
SetTestGroup({ "Casstronaut", "Pary-Nightslayer", "Jintoe" })
SetTestClasses({ Casstronaut = "SHAMAN", ["Pary-Nightslayer"] = "WARLOCK", Jintoe = "SHAMAN" })
LootCheck.Comm:Init()
assert(LootCheck.Comm:Available(), "sync should be available with the libraries loaded")
for _, imp in ipairs(LootCheck.Imports:List()) do LootCheck.Imports:Delete(imp.id) end
LootCheck.Imports:Add("Send Test", csv({
    "Casstronaut,Shaman,1,Tsunami Talisman,30627,0",
    "Casstronaut,Shaman,2,Band of Devastation,30347,0",
    "Jintoe,Shaman,1,Tsunami Talisman,30627,0",
}))
local mine = LootCheck.Imports:Active()
assert(mine.stats.entries == 3, "3 entries to send")

local roster = LootCheck.Comm:GroupRoster()
print(("roster: %d players"):format(#roster))
for _, m in ipairs(roster) do print("   " .. m.name .. " (" .. tostring(m.class) .. ")") end
assert(#roster == 3, "three group members, excluding me")

section("ping and reply")
FakeComm:Reset()
assert(LootCheck.Comm:Ping(), "ping sent")
local ping = FakeComm:Last("P|")
assert(ping and (ping.distribution == "RAID" or ping.distribution == "PARTY"), "ping goes to the whole group, not one player: " .. tostring(ping and ping.distribution))
assert(ping.target == nil, "a ping has no single target")
-- Somebody else's ping gets a whispered reply
FakeComm:Reset()
FakeComm:Deliver("LootCheck", "P|1", "RAID", "Casstronaut")
local reply = FakeComm:Last("R|")
assert(reply and reply.distribution == "WHISPER" and reply.target == "Casstronaut", "reply whispered back")
assert(reply.text:find(LootCheck.version, 1, true), "reply carries our version")
-- Their reply marks them as having the addon
assert(not LootCheck.Comm:HasAddon("casstronaut"), "not known yet")
FakeComm:Deliver("LootCheck", "R|1|1.0.0", "WHISPER", "Casstronaut")
assert(LootCheck.Comm:HasAddon("casstronaut"), "peer recorded")

section("send: only to the players who were ticked")
FakeComm:Reset()
local out = capture(function()
    LootCheck.Comm:SendDataset({ "Casstronaut", "Jintoe" })
end)
assert(out:find("sending", 1, true), out)
assert(#FakeComm.sent == 2, "one message stream per target, got " .. #FakeComm.sent)
local seen = {}
for _, m in ipairs(FakeComm.sent) do
    assert(m.distribution == "WHISPER", "datasets are whispered, not broadcast")
    assert(m.prio == "BULK", "datasets go at BULK priority")
    assert(m.text:sub(1, 4) == "D|1|", "dataset framing")
    seen[m.target] = true
end
assert(seen.Casstronaut and seen.Jintoe and not seen["Pary-Nightslayer"], "only the chosen players")
local payload = FakeComm.sent[1].text
print(("payload: %d bytes on the wire for %d entries"):format(#payload, mine.stats.entries))
out = capture(function() LootCheck.Comm:SendDataset({}) end)
assert(out:find("pick at least one player", 1, true), out)

section("the payload really round-trips through compression")
local decoded = LootCheck.Comm:Decode(payload:sub(5))
assert(decoded == LootCheck.Imports:ExportText(), "decode(encode(export)) must return the export text")

section("receiving: a prompt, then Save as new")
local before = #LootCheck.Imports:List()
FakeComm:Deliver("LootCheck", payload, "WHISPER", "Casstronaut")
assert(#LootCheck.Comm.queue == 1, "queued for a decision")
assert(LootCheckCommPrompt and LootCheckCommPrompt:IsShown(), "prompt shown")
assert(LootCheckCommPrompt.text:GetText():find("Casstronaut", 1, true), "prompt names the sender")
assert(LootCheckCommPrompt.mergeButton:IsShown(), "merge offered while a raid is active")
out = capture(function() click(LootCheckCommPrompt.saveButton) end)
assert(out:find("imported 'Send Test (from Casstronaut)'", 1, true), out)
assert(#LootCheck.Imports:List() == before + 1, "saved as a new raid")
assert(not LootCheckCommPrompt:IsShown(), "prompt closed")
assert(LootCheck.Imports:Active().name == "Send Test (from Casstronaut)", "the new raid became active")
LootCheck.Imports:SetActive(mine.id, true)

section("receiving: Merge keeps local rows and adds only what is new")
local incoming = csv({
    "Casstronaut,Shaman,7,Tsunami Talisman,30627,0", -- duplicate, different prio
    "Casstronaut,Shaman,1,Tsunami Talisman,30627,1", -- same item, off-spec: not a duplicate
    "Pary,Warlock,1,Leggings of the Vanquished Hero,30247,0", -- new
})
local encoded = "D|1|" .. LootCheck.Comm:Encode(incoming)
FakeComm:Deliver("LootCheck", encoded, "WHISPER", "Pary-Nightslayer")
assert(#LootCheck.Comm.queue == 1, "queued")
out = capture(function() click(LootCheckCommPrompt.mergeButton) end)
assert(out:find("2 new entries, 1 duplicates skipped", 1, true), out)
assert(LootCheck.Imports:Active().id == mine.id, "merged into my raid, no new raid")
assert(mine.stats.entries == 5, "3 + 2 new = 5, got " .. mine.stats.entries)
assert(mine.mergedFrom == "Pary", "merge is recorded on the import")
local index = LootCheck.Data:WishlistIndex()
assert(index[30627]["casstronaut"] and #index[30627]["casstronaut"].entries == 2, "MS kept plus the new OS entry")
assert(index[30627]["casstronaut"].bestPrio == 1, "the local priority survived the merge")
assert(index[30247]["pary"], "the new character came through")

section("receiving: Discard")
FakeComm:Deliver("LootCheck", encoded, "WHISPER", "Pary-Nightslayer")
local entriesBefore = mine.stats.entries
out = capture(function() click(LootCheckCommPrompt.discardButton) end)
assert(out:find("discarded", 1, true), out)
assert(mine.stats.entries == entriesBefore, "nothing changed")
assert(#LootCheck.Comm.queue == 0, "queue empty")

section("a second dataset queues behind the first")
FakeComm:Deliver("LootCheck", encoded, "WHISPER", "Casstronaut")
FakeComm:Deliver("LootCheck", encoded, "WHISPER", "Jintoe")
assert(#LootCheck.Comm.queue == 2, "two queued")
assert(LootCheckCommPrompt.text:GetText():find("1 more waiting", 1, true), "the prompt says one more is waiting")
LootCheck.Comm:Resolve("discard")
assert(#LootCheck.Comm.queue == 1 and LootCheckCommPrompt:IsShown(), "second prompt follows")
LootCheck.Comm:Resolve("discard")
assert(not LootCheckCommPrompt:IsShown(), "prompt closes when the queue empties")

section("data from outside the group, bad protocol and junk are ignored")
FakeComm:Deliver("LootCheck", encoded, "WHISPER", "Randomstranger")
assert(#LootCheck.Comm.queue == 0, "a stranger's dataset is ignored")
FakeComm:Deliver("LootCheck", "D|9|" .. LootCheck.Comm:Encode(incoming), "WHISPER", "Casstronaut")
assert(#LootCheck.Comm.queue == 0, "another protocol version is ignored")
out = capture(function() FakeComm:Deliver("LootCheck", "D|1|not-actually-compressed", "WHISPER", "Casstronaut") end)
assert(#LootCheck.Comm.queue == 0, "junk is ignored")
FakeComm:Deliver("LootCheck", payload, "WHISPER", UnitName("player"))
assert(#LootCheck.Comm.queue == 0, "our own message is ignored")

section("the send panel lists the group and only sends to ticked players")
LootCheck.Imports:Open()
LootCheck.Imports:ShowSend()
local page = LootCheckImportsFrame
assert(page.mode == "send" and page.sendList:IsShown(), "send mode")
assert(not page.scroll:IsShown() and not page.hint:IsShown(), "text area and hint hidden")
assert(page.sendNowButton:IsShown() and not page.importButton:IsShown(), "Send button, no Import button")
local shown = {}
for _, row in ipairs(page.sendRows) do if row:IsShown() then tinsert(shown, row) end end
assert(#shown == 3, "three players listed, got " .. #shown)
assert(shown[1].label:GetText():find("LootCheck", 1, true), "Casstronaut is marked as having the addon")
assert(page.sendStatus:GetText() == "0 of 3 selected", page.sendStatus:GetText())

shown[2]:SetChecked(true); click(shown[2])
assert(page.sendStatus:GetText() == "1 of 3 selected", page.sendStatus:GetText())
local targets = LootCheck.Imports:SelectedTargets()
assert(#targets == 1 and targets[1] == shown[2].playerName, "only the ticked player is a target")

page.selectAll:SetChecked(true); click(page.selectAll)
assert(#LootCheck.Imports:SelectedTargets() == 3, "select all ticks everyone")
FakeComm:Reset()
click(page.sendNowButton)
assert(#FakeComm.sent == 3, "sent to all three")
assert(page.mode == nil, "the panel closes after sending")

page.selectAll:SetChecked(false); click(page.selectAll)
LootCheck.Imports:ShowSend()
assert(#LootCheck.Imports:SelectedTargets() == 0, "selection resets each time the panel opens")
LootCheck.Window:Hide()

section("cleanup")
for _, imp in ipairs(LootCheck.Imports:List()) do LootCheck.Imports:Delete(imp.id) end
SetTestGroup({})
SetTestClasses({})

print("\nCOMM TESTS PASSED")
