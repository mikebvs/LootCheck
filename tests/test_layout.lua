-- Layout wiring: wrapping widths, inset panels, and the Wishlist Data panel modes.
-- These are the things that broke visually before (text overlapping, a paste box
-- with no visible boundary), so they get asserted rather than eyeballed.
local function section(t) print("\n=== " .. t .. " ===") end

local function hasInsetBackdrop(f, label)
    assert(f, label .. ": frame missing")
    local bd = f.GetBackdrop and f:GetBackdrop()
    assert(type(bd) == "table" and bd.bgFile and bd.edgeFile, label .. ": no inset backdrop")
    assert(bd.bgFile:find("Tooltip", 1, true), label .. ": unexpected inset texture " .. tostring(bd.bgFile))
    assert(f._backdropColor and f._backdropColor[4] and f._backdropColor[4] > 0, label .. ": inset not tinted")
end

section("wrapping text has a width (so it wraps instead of running off the page)")
LootCheck.Window:Show("home")
local home = LootCheckConfigFrame
for i = 1, 3 do
    assert(home.status[i]._width and home.status[i]._width > 300, "home status line " .. i .. " has no wrap width")
    assert(home.status[i]._wordWrap == true, "home status line " .. i .. " does not wrap")
end
assert(home.greyOS.label._wordWrap == false, "check box labels should stay on one line")

-- Single-line text that sits at the end of a row must be bounded on the right,
-- or it clips out through the window border (it did, on the home page)
local function bounded(f, label)
    assert(f, label .. ": missing")
    assert(f:HasAnchor("LEFT") or f:HasAnchor("TOPLEFT"), label .. ": not anchored on the left")
    assert(f:HasAnchor("RIGHT"), label .. ": no right bound, it can run off the page")
end
bounded(home.greyOS.label, "home: OS check box label")
bounded(home.groupOnly.label, "home: group check box label")
bounded(home.tmbTooltip.label, "home: TMB check box label")
bounded(home.daysTail, "home: \"days (0 = no limit)\"")
bounded(home.suffixTail, "home: greyed-name suffix example")

LootCheck.Imports:Open()
local imports = LootCheckImportsFrame
assert(imports.info._width and imports.info._wordWrap, "imports info line does not wrap")
assert(imports.info2._width and imports.info2._wordWrap, "imports second info line does not wrap")
assert(imports.hint._width and imports.hint._wordWrap, "imports hint does not wrap")
assert(imports.pasteLabel._width and imports.pasteLabel._wordWrap, "paste instructions do not wrap")

LootCheck.Graph:Open()
assert(LootCheckGraphFrame.subtitle._width, "graph subtitle has no wrap width")
assert(LootCheck.Graph._rows[1].name._wordWrap == false, "graph names must not wrap (fixed row height)")

-- The graph page is two columns: anything in the left one that is not bounded
-- on the right runs on into the raid drops list beside it, which it did
bounded(LootCheckGraphFrame.header2, "graph: awarded column heading")
bounded(LootCheckGraphFrame.groupLabel, "graph: group check box label")
bounded(LootCheckGraphFrame.phaseLabel, "graph: phase label")
bounded(LootCheckGraphFrameDrops.rareLabel, "drops: blue items label")

-- The drops column: the date needs room for "Tue 09:41", and the week label
-- must stop before the counts rather than running underneath them
local dropsPanel = LootCheckGraphFrameDrops
bounded(dropsPanel.week, "drops: week label")
assert(LootCheck.Drops._rows[1].time._width >= 70,
    "drops date column is too narrow (" .. tostring(LootCheck.Drops._rows[1].time._width) .. "), dates truncate")
assert(LootCheck.Drops._rows[1].text._wordWrap == false, "drops rows must not wrap (fixed row height)")
assert(LootCheck.Drops._rows[1].looted._width and LootCheck.Drops._rows[1].status._width,
    "drops name columns have no width")
bounded(dropsPanel.gearLabel, "drops: gear only label")

-- The Character button owns the top-right corner of the page, so the subtitle
-- has to stop short of it rather than running underneath
local graphWidth = select(1, LootCheck.Window:ContentSize())
assert(LootCheckGraphFrame.subtitle._width <= graphWidth - 22 * 2 - 116,
    "graph subtitle runs into the Character button, width " .. tostring(LootCheckGraphFrame.subtitle._width))

-- The character popout is a third column on the same page: its text needs
-- bounding too, or it runs out through the right-hand edge of the window
LootCheck.Graph:SetSheetOpen(true)
local sheetPanel = LootCheckGraphFrameSheet
bounded(sheetPanel.summary, "sheet: wishlist entry count")
assert(LootCheck.Sheet._rows[1].item._wordWrap == false, "sheet rows must not wrap (fixed row height)")
assert(LootCheck.Sheet._rows[1].slot._width and LootCheck.Sheet._rows[1].prio._width,
    "sheet slot and rank columns have no width")
LootCheck.Graph:SetSheetOpen(false)

LootCheck.Audit:Open()
assert(LootCheck.Audit._rows[1].text._wordWrap == false, "audit rows must not wrap (fixed row height)")
bounded(LootCheckAuditFrame.wishlistOnlyLabel, "audit: hide-non-wishlist label")
assert(LootCheck.Audit._rows[1].time._width, "audit time column has no width")

section("list and text areas sit on a dark inset")
-- Dropdowns are dark fields, not UIPanelButtonTemplate action buttons: they
-- must not look like "< Back"
hasInsetBackdrop(LootCheckAuditFrameRange, "audit range dropdown")
hasInsetBackdrop(LootCheckImportsFrameDropdown, "wishlist data raid dropdown")
hasInsetBackdrop(LootCheckAuditFrameRangeMenu, "audit range menu")

hasInsetBackdrop(LootCheckImportsFrameInset, "wishlist data paste box")
hasInsetBackdrop(LootCheckGraphFrameInset, "graph list")
hasInsetBackdrop(LootCheckAuditFrameInset, "audit list")
LootCheck.Help:Open()
hasInsetBackdrop(LootCheckHelpFrameInset, "slash commands list")

section("Wishlist Data panel modes: idle hint, import, export")
-- Earlier suites leave no imports behind; give the page one so it opens idle
LootCheck.Imports:Add("Layout Test", table.concat({
    "type,raid_group_name,character_name,character_class,sort_order,item_name,item_id,is_offspec",
    "wishlist,PUG,Layoutguy,Rogue,1,Tsunami Talisman,30627,0",
}, "\n"))
LootCheck.Imports:Open()
assert(imports.mode == nil, "page should open idle when a raid is active")
assert(imports.hint:IsShown(), "idle: hint shown")
assert(not imports.scroll:IsShown() and not imports.nameBox:IsShown(), "idle: text area and name box hidden")
assert(not imports.importButton:IsShown(), "idle: no Import button")

LootCheck.Imports:ShowNewPanel(true)
assert(imports.mode == "import" and imports.nameBox:IsShown() and imports.scroll:IsShown(), "import mode widgets")
assert(not imports.hint:IsShown(), "import: hint hidden")
assert(imports.importButton:IsShown() and imports.cancelButton:IsShown(), "import: both buttons")

LootCheck.Imports:ShowExport()
assert(imports.mode == "export" and imports.scroll:IsShown(), "export mode shows the text area")
assert(not imports.nameBox:IsShown(), "export: no name box")
assert(not imports.importButton:IsShown(), "export: no Import button")
assert(imports.pasteBox:GetText():find("# LootCheck wishlist export", 1, true), "export text in the box")

LootCheck.Imports:ShowNewPanel(false)
assert(imports.mode == nil and imports.hint:IsShown(), "back to idle")

section("with no imports at all the page opens ready to paste")
LootCheck.Imports:Delete(LootCheck.Imports:FindByName("Layout Test").id)
LootCheck.Window:Hide()
LootCheck.Imports:Open()
assert(imports.mode == "import" and imports.nameBox:IsShown(), "no data: opens in import mode")

section("the Copy from TMBExport button only exists while TMBExport does")
assert(imports.copyButton:IsShown(), "shown with TMBExport present")
local saved = TMBExportDB
TMBExportDB = nil
LootCheck.Imports:RefreshUI()
assert(not imports.copyButton:IsShown(), "hidden without TMBExport")
TMBExportDB = saved
LootCheck.Imports:RefreshUI()
assert(imports.copyButton:IsShown(), "shown again")
LootCheck.Window:Hide()

print("\nLAYOUT TESTS PASSED")
