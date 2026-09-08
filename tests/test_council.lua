-- The Loot Council page: who is running LootCheck, on which version, across
-- both the group and the online half of the guild.
local function section(t) print("\n=== " .. t .. " ===") end
local function click(button) button._scripts.OnClick(button) end
local Council = LootCheck.Council
local Comm = LootCheck.Comm

local BEHIND, AHEAD = "0.0.1", "999.0.0"

local function stateOf(list, norm)
    for _, entry in ipairs(list) do
        if entry.norm == norm then return entry end
    end
end

local function shownRows()
    local out = {}
    for _, row in ipairs(Council._rows) do
        if row:IsShown() then tinsert(out, row) end
    end
    return out
end

section("setup: three in the group, three in the guild, one in both")
SetTestGroup({ "John", "Mary-Testrealm", "Jill" })
SetTestClasses({ John = "SHAMAN", ["Mary-Testrealm"] = "WARLOCK", Jill = "SHAMAN" })
SetTestGuild({
    { name = "Jill", class = "SHAMAN", online = true },      -- also in the group
    { name = "Jane", class = "PRIEST", online = true },
    { name = "Joe", class = "ROGUE", online = true },
    { name = "Offlineguy", class = "MAGE", online = false }, -- cannot answer
})
Comm:Init()
Comm.peers = {}

local roster = Comm:PingableRoster()
assert(#roster == 5, "group (3) + online guild (3) with one overlap = 5, got " .. #roster)

local byNorm = {}
for _, m in ipairs(roster) do byNorm[m.norm] = m end
assert(byNorm.john.where == "group", "John is group only: " .. byNorm.john.where)
assert(byNorm.jane.where == "guild", "Jane is guild only: " .. byNorm.jane.where)
assert(byNorm.jill.where == "group+guild", "Jill is in both: " .. byNorm.jill.where)
assert(not byNorm.offlineguy, "offline guild members cannot answer, so they are not listed")

section("a check asks the group and the guild")
FakeComm:Reset()
local asked = Council:Check()
assert(asked == 2, "asked two channels, got " .. asked)

local channels = {}
for _, sent in ipairs(FakeComm.sent) do
    if sent.text:find("^P|") then channels[sent.distribution] = true end
end
assert(channels.RAID or channels.PARTY, "the group was pinged")
assert(channels.GUILD, "the guild was pinged")

section("replies record the version, and are graded against ours")
FakeComm:Deliver("LootCheck", "R|1|" .. LootCheck.version, "WHISPER", "John")
FakeComm:Deliver("LootCheck", "R|1|" .. BEHIND, "WHISPER", "Jane")
FakeComm:Deliver("LootCheck", "R|1|" .. AHEAD, "WHISPER", "Jill")

local list = Council:List({})
assert(#list == 3, "only the three who answered, got " .. #list)
assert(stateOf(list, "john").state == "current", "same version as ours")
assert(stateOf(list, "jane").state == "behind", "older version")
assert(stateOf(list, "jill").state == "ahead", "newer version")
assert(stateOf(list, "jane").version == BEHIND, "the version string is kept")

local running, behind, silent = Council:Summary()
assert(running == 3 and behind == 1 and silent == 2,
    ("summary: %d running, %d behind, %d silent"):format(running, behind, silent))

section("version comparison is numeric, not alphabetical")
assert(Comm:CompareVersions("1.0.10", "1.0.9") == 1, "1.0.10 is newer than 1.0.9")
assert(Comm:CompareVersions("1.0.9", "1.0.10") == -1, "and the other way round")
assert(Comm:CompareVersions("1.2.0", "1.2") == 0, "a missing part counts as zero")
assert(Comm:CompareVersions("2.0.0", "1.9.9") == 1, "major wins")

section("someone on an incompatible protocol still shows up, flagged")
FakeComm:Deliver("LootCheck", "R|99|2.0.0", "WHISPER", "Joe")
local joe = stateOf(Council:List({}), "joe")
assert(joe, "a peer on another protocol is still listed")
assert(joe.incompatible, "and is flagged as unable to sync")
assert(joe.version == "2.0.0", "their version is still readable")

section("the page lists them, and can also show who stayed silent")
LootCheck.db.settings.councilShowEveryone = false
Council:Open()
assert(LootCheckCouncilFrame:IsShown(), "the council page is up")
assert(#shownRows() == 4, "four answered, got " .. #shownRows())
assert(LootCheckCouncilFrame.subtitle:GetText():find("not up to date", 1, true),
    LootCheckCouncilFrame.subtitle:GetText())
assert(LootCheckCouncilFrame.head.version:GetText() == "Version", "columns are labelled")

local first = shownRows()[1]
assert((first.name:GetText() or ""):find("|cff", 1, true), "names are class coloured")
assert((first.version:GetText() or ""):find("v", 1, true), "the version column is filled")

LootCheckCouncilFrame.everyone:SetChecked(true)
click(LootCheckCouncilFrame.everyone)
assert(LootCheck.db.settings.councilShowEveryone == true, "the box writes the setting")
assert(#shownRows() == 5, "everyone who was asked is listed, got " .. #shownRows())

local silentRow
for _, row in ipairs(shownRows()) do
    if row.data and row.data.state == "silent" then silentRow = row end
end
assert(silentRow, "the player who did not answer is listed")
assert((silentRow.state:GetText() or ""):find("no reply", 1, true),
    "and is shown as no reply, not as missing the addon: " .. tostring(silentRow.state:GetText()))
assert((silentRow.version:GetText() or ""):find("-", 1, true), "with no version")

LootCheck.db.settings.councilShowEveryone = false
LootCheck.Window:Hide()

section("with nobody around, the page says so instead of looking broken")
SetTestGroup({})
SetTestGuild({})
Comm.peers = {}
Council:Open()
assert(#shownRows() == 0 and LootCheckCouncilFrame.empty:IsShown(), "no rows, a message instead")
assert(LootCheckCouncilFrame.empty:GetText():find("not in a group", 1, true),
    LootCheckCouncilFrame.empty:GetText())
LootCheck.Window:Hide()

section("the shorthand slash commands land on the right pages")
assert(SLASH_LOOTCHECKMENU1 == "/lch", "/lch registered")
assert(SLASH_LOOTCHECKGRAPH1 == "/lchg", "/lchg registered")
assert(SLASH_LOOTCHECKAUDIT1 == "/lcha", "/lcha registered")
assert(SLASH_LOOTCHECKCOUNCIL1 == "/lchc", "/lchc registered")

SlashCmdList.LOOTCHECKMENU("")
assert(LootCheck.Window:Current() == "home", "/lch opens the menu")
LootCheck.Window:Hide()

SlashCmdList.LOOTCHECKGRAPH("")
assert(LootCheck.Window:Current() == "graph", "/lchg opens the graph")
LootCheck.Window:Hide()

SlashCmdList.LOOTCHECKAUDIT("")
assert(LootCheck.Window:Current() == "audit", "/lcha opens the audit")
LootCheck.Window:Hide()

SlashCmdList.LOOTCHECKCOUNCIL("")
assert(LootCheck.Window:Current() == "council", "/lchc opens the council page")
LootCheck.Window:Hide()

-- arguments are passed straight through, so "/lchg 30" is "/lchelp graph 30"
SlashCmdList.LOOTCHECKGRAPH("30")
assert(LootCheck.db.settings.graphDays == 30, "/lchg 30 sets the window")
SlashCmdList.LOOTCHECKGRAPH("0")
LootCheck.Window:Hide()

section("cleanup")
Comm.peers = {}
SetTestGroup({})
SetTestGuild({})
SetTestClasses({})
LootCheck.db.settings.councilShowEveryone = false

print("\nCOUNCIL TESTS PASSED")
