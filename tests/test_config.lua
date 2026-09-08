-- /lchelp home page: status, settings, page buttons, one shared window.
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
local function click(button) button._scripts.OnClick(button) end

section("/lchelp opens the window on the home page; /lchelp help switches pages in the same window")
LootCheck.Window:Hide()
local out = capture(function() SlashCmdList.LOOTCHECK("") end)
assert(LootCheckWindow and LootCheckWindow:IsShown(), "window shown")
assert(LootCheckConfigFrame and LootCheckConfigFrame:IsShown(), "home page shown")
assert(LootCheck.Window:Current() == "home", "current page is home")
assert(not LootCheckWindow.back:IsShown(), "no Back button on the home page")
assert(not out:find("/lchelp graph", 1, true), "bare /lchelp should not print the command list")
SlashCmdList.LOOTCHECK("help")
assert(LootCheckHelpFrame and LootCheckHelpFrame:IsShown() and not LootCheckConfigFrame:IsShown(), "switched to the help page")
assert(LootCheckWindow.back:IsShown(), "Back button visible on a sub page")
assert(LootCheckWindow.title:GetText() == "LootCheck - Slash Commands", "title follows the page")
LootCheckWindow.back._scripts.OnClick(LootCheckWindow.back)
assert(LootCheckConfigFrame:IsShown() and not LootCheckHelpFrame:IsShown(), "Back returns home")
assert(LootCheckWindow.title:GetText() == "LootCheck", "home title")

local f = LootCheckConfigFrame
print("status 1:", f.status[1]:GetText())
print("status 2:", f.status[2]:GetText())
print("status 3:", f.status[3]:GetText())
assert(f.status[1]:GetText():find("Gargul: |cff00ff00found", 1, true), "Gargul status")
assert(f.status[2]:GetText():find("Active raid: |cffffffffTMBExport", 1, true), "source status")
assert(f.status[3]:GetText():match("Wishlist items awarded: %d+ against the current wishlist, %d+ all time"), "totals status")

section("check boxes reflect and change settings")
assert(f.greyOS:GetChecked() == true, "greyOS starts on")
f.greyOS:SetChecked(false); click(f.greyOS)
assert(LootCheck.db.settings.greyOSAwards == false, "greyOS off")
f.greyOS:SetChecked(true); click(f.greyOS)
assert(LootCheck.db.settings.greyOSAwards == true, "greyOS on")

assert(f.groupOnly:GetChecked() == false, "groupOnly starts off")
f.groupOnly:SetChecked(true); click(f.groupOnly)
assert(LootCheck.db.settings.graphGroupOnly == true, "groupOnly on")
f.groupOnly:SetChecked(false); click(f.groupOnly)
assert(LootCheck.db.settings.graphGroupOnly == false, "groupOnly off")

assert(f.tmbTooltip:IsShown(), "TMBExport box shown while TMBExport is present")
assert(f.tmbTooltip:GetChecked() == false, "TMBExport tooltip is off")
f.tmbTooltip:SetChecked(true); click(f.tmbTooltip)
assert(TMBExportDB.settings.showTooltip == true, "TMBExport tooltip switched on")
f.tmbTooltip:SetChecked(false); click(f.tmbTooltip)
assert(TMBExportDB.settings.showTooltip == false, "and off again")

section("edit boxes: graph days + suffix")
f.days:SetText("30"); f.days._scripts.OnEnterPressed(f.days)
assert(LootCheck.db.settings.graphDays == 30, "days applied on Enter")
assert(f.days:GetText() == "30", "days box refreshed")
f.days:SetText("abc"); f.days._scripts.OnEditFocusLost(f.days)
assert(LootCheck.db.settings.graphDays == 0 and f.days:GetText() == "0", "garbage -> 0")
f.suffix:SetText(" (received)"); f.suffix._scripts.OnEnterPressed(f.suffix)
assert(LootCheck.db.settings.receivedSuffix == " (received)", "suffix applied")
f.suffix:SetText(""); f.suffix._scripts.OnEnterPressed(f.suffix)
assert(LootCheck.db.settings.receivedSuffix == "", "suffix cleared")

section("buttons switch pages inside the same window; Back returns home")
click(f.graphButton)
assert(LootCheckGraphFrame and LootCheckGraphFrame:IsShown() and not f:IsShown(), "graph page")
assert(LootCheck.Window:Current() == "graph" and LootCheckWindow:IsShown(), "same window, graph page")
LootCheck.Window:Back()
click(f.importsButton)
assert(LootCheckImportsFrame and LootCheckImportsFrame:IsShown() and LootCheck.Window:Current() == "imports", "wishlist data page")
assert(LootCheckWindow.title:GetText() == "LootCheck - Wishlist Data", "wishlist data title")
LootCheck.Window:Back()
click(f.auditButton)
assert(LootCheckAuditFrame and LootCheckAuditFrame:IsShown() and LootCheck.Window:Current() == "audit", "audit page")
LootCheck.Window:Back()
click(f.helpButton)
assert(LootCheckHelpFrame:IsShown() and LootCheck.Window:Current() == "help", "commands page")
LootCheck.Window:Back()
assert(f:IsShown() and LootCheck.Window:Current() == "home", "home again")

section("toggle + aliases")
SlashCmdList.LOOTCHECK("")
assert(not f:IsShown() and not LootCheckWindow:IsShown(), "toggled off")
SlashCmdList.LOOTCHECK("config")
assert(f:IsShown(), "config alias opens")
SlashCmdList.LOOTCHECK("options")
assert(not f:IsShown(), "options alias toggles")
SlashCmdList.LOOTCHECK("graph")
assert(LootCheckGraphFrame:IsShown(), "graph page from chat")
SlashCmdList.LOOTCHECK("")
assert(f:IsShown() and not LootCheckGraphFrame:IsShown(), "/lchelp from another page goes home")

section("no TMBExport -> its check box is hidden")
local saved = TMBExportDB
TMBExportDB = nil
LootCheck.Config:Open()
assert(not f.tmbTooltip:IsShown(), "hidden without TMBExport")
assert(f.status[2]:GetText():find("none", 1, true), "no source status: " .. f.status[2]:GetText())
TMBExportDB = saved
LootCheck.Config:Refresh()
assert(f.tmbTooltip:IsShown(), "back")
LootCheck.Window:Hide()

print("\nCONFIG TESTS PASSED")
