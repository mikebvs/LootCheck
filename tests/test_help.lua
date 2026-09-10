-- Slash Commands page (/lchelp help) and the command table behind it.
local function section(t) print("\n=== " .. t .. " ===") end
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

section("/lchelp help shows the page with one row per command")
LootCheck.Window:Hide()
SlashCmdList.LOOTCHECK("help")
assert(LootCheckHelpFrame and LootCheckHelpFrame:IsShown(), "help page shown")
assert(LootCheck.Window:Current() == "help", "window on the help page")
assert(#LootCheck.Help._rows == #LootCheck.Help.COMMANDS, "one row per command")
for _, row in ipairs(LootCheck.Help._rows) do
    assert(row.cmd:GetText():find(row.data.cmd, 1, true), "command text")
    assert(row.desc:GetText() == row.data.desc, "description text")
    if row.data.aliases then
        assert(row.shorthand and row.shorthand:GetText():find("Shorthands: " .. row.data.aliases[1], 1, true), "shorthands text")
    end
end
SlashCmdList.LOOTCHECK("help")
assert(not LootCheckHelpFrame:IsShown() and not LootCheckWindow:IsShown(), "toggled off")
SlashCmdList.LOOTCHECK("commands")
assert(LootCheckHelpFrame:IsShown(), "commands alias")
LootCheck.Window:Hide()

section("/lchelp help chat prints the same list")
local out = capture(function() SlashCmdList.LOOTCHECK("help chat") end)
for _, c in ipairs(LootCheck.Help.COMMANDS) do
    assert(out:find(c.cmd .. "|r", 1, true), "chat list missing " .. c.cmd)
end
assert(not LootCheckWindow:IsShown(), "chat variant does not open the window")

section("every documented command is handled (no 'unknown command'), and vice versa")
local documented = {}
for _, c in ipairs(LootCheck.Help.COMMANDS) do
    local keyword = c.cmd:match("^/lchelp%s*(%S*)$")
    assert(keyword, "bad cmd string " .. c.cmd)
    documented[keyword] = true
    for _, alias in ipairs(c.aliases or {}) do
        -- Some aliases are slash commands of their own ("/lch", "/lchg"), not
        -- "/lchelp x" keywords; those are covered by test_council.lua
        local aliasKeyword = alias:match("^/lchelp%s*(%S*)$")
        if aliasKeyword then documented[aliasKeyword] = true end
    end
end
for keyword in pairs(documented) do
    out = capture(function() SlashCmdList.LOOTCHECK(keyword) end)
    assert(not out:find("unknown command", 1, true), "documented but unhandled: " .. keyword)
    LootCheck.Window:Hide()
end
-- toggles were flipped once above; flip them back
for _, keyword in ipairs({ "greyos", "grouponly", "tmbtooltip", "shareedits" }) do
    SlashCmdList.LOOTCHECK(keyword)
end
-- "sheet" opened the graph's character popout, which is remembered and widens
-- the window's floor while it is out; leaving it on would follow this suite
LootCheck.Graph:SetSheetOpen(false)
assert(LootCheck.db.settings.greyOSAwards == true and LootCheck.db.settings.graphGroupOnly == false, "toggles restored")
assert(LootCheck.db.settings.shareEdits == false, "edit sharing left off")
assert(TMBExportDB.settings.showTooltip == false, "TMBExport tooltip restored")
for _, keyword in ipairs({ "graph", "drops", "council", "members", "sheet", "character", "char", "contested", "competition", "phase", "phases", "resetsize", "grouponly", "audit", "imports", "data", "use", "giveitem", "removeitem", "addwlitem",
                           "removewlitem", "wishlist", "check", "overrides", "status", "greyos", "tmbtooltip", "help", "config" }) do
    assert(documented[keyword], "handled but undocumented: " .. keyword)
end
-- testdrops is a testing aid: handled, but deliberately kept off the page
assert(not documented["testdrops"], "testdrops must stay out of Help.COMMANDS")
out = capture(function() SlashCmdList.LOOTCHECK("testdrops") end)
assert(not out:find("unknown command", 1, true), "testdrops is still handled")
assert(out:find("usage", 1, true), out)

out = capture(function() SlashCmdList.LOOTCHECK("definitelynotacommand") end)
assert(out:find("unknown command", 1, true), out)

section("Commands button on the home page switches to it; Back returns")
SlashCmdList.LOOTCHECK("")
LootCheckConfigFrame.helpButton._scripts.OnClick(LootCheckConfigFrame.helpButton)
assert(LootCheckHelpFrame:IsShown() and not LootCheckConfigFrame:IsShown(), "switched to the commands page")
LootCheck.Window:Back()
assert(LootCheckConfigFrame:IsShown(), "back home")
LootCheck.Window:Hide()

print("\nHELP TESTS PASSED")
