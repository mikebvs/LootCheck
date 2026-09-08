--[[
    LootCheck - Config.lua

    The home page of the LootCheck window (/lchelp with no arguments): a
    status block, the basic settings, and buttons to the other pages
    (wishlist graph, wishlist data, audit, slash commands).

    Everything is anchored to the element above it, so a status line that
    wraps pushes the rest of the page down instead of overlapping it.
]]

local LC = LootCheck
local Config = {}
LC.Config = Config

local PAGE = "home"
local WIDTH, HEIGHT = 600, 372
local MARGIN = 22

local frame -- the page

local function Settings()
    LC.db = LC.db or LootCheckDB or {}
    LC.db.settings = LC.db.settings or {}
    return LC.db.settings
end

local function Changed()
    LC.Data:Invalidate()
    if LC.Graph then LC.Graph:RefreshIfShown() end
end

--- A check box with a single-line label to its right. The label is bounded
--- on the right by the page margin, so a long one truncates inside the window
--- instead of running off the edge.
local function CheckBox(parent, name, label, onClick)
    local box = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    box:SetSize(24, 24)
    box:SetScript("OnClick", function(self)
        onClick(self:GetChecked() and true or false)
    end)

    local text = LC.Window:Text(parent, "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 4, 0)
    text:SetPoint("RIGHT", parent, "RIGHT", -MARGIN, 0)
    text:SetText(label)
    box.label = text
    return box
end

--- A single-line edit box that applies its value on Enter or when it loses focus
local function EditBox(parent, name, width, numeric, onApply)
    local box = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    if numeric then box:SetNumeric(true) end
    box:SetMaxLetters(numeric and 4 or 40)
    box:SetScript("OnEnterPressed", function(self)
        onApply(self:GetText())
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        onApply(self:GetText())
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        Config:Refresh()
    end)
    return box
end

local function BuildPage(page)
    frame = page

    local version = LC.Window:Text(page, "GameFontDisableSmall")
    version:SetPoint("TOP", 0, -4)
    version:SetJustifyH("CENTER")
    version:SetText("v" .. tostring(LC.version) .. " - Gargul + That's My BIS companion")

    -- Status block: each line wraps inside the page and pushes the next one down
    page.status = {}
    for i = 1, 3 do
        local line = LC.Window:Text(page, "GameFontHighlightSmall", WIDTH - MARGIN * 2)
        if i == 1 then
            line:SetPoint("TOPLEFT", MARGIN, -24)
        else
            line:SetPoint("TOPLEFT", page.status[i - 1], "BOTTOMLEFT", 0, -3)
        end
        page.status[i] = line
    end

    -- Settings
    page.settingsHeader = LC.Window:Text(page, "GameFontNormal")
    page.settingsHeader:SetPoint("TOPLEFT", page.status[3], "BOTTOMLEFT", 0, -14)
    page.settingsHeader:SetText("Settings")

    page.greyOS = CheckBox(page, "LootCheckConfigFrameGreyOS",
        "Grey out names that received the item via an OS roll", function(checked)
            Settings().greyOSAwards = checked
        end)
    page.greyOS:SetPoint("TOPLEFT", page.settingsHeader, "BOTTOMLEFT", -2, -6)

    page.groupOnly = CheckBox(page, "LootCheckConfigFrameGroupOnly",
        "Graph: only raiders in my current group", function(checked)
            Settings().graphGroupOnly = checked
            Changed()
        end)
    page.groupOnly:SetPoint("TOPLEFT", page.greyOS, "BOTTOMLEFT", 0, -2)

    page.tmbTooltip = CheckBox(page, "LootCheckConfigFrameTMBTooltip",
        "Also show TMBExport's own (separate) tooltip list", function(checked)
            if LC.Tooltip and LC.Tooltip.SetTMBExportTooltip then
                LC.Tooltip:SetTMBExportTooltip(checked)
                LC.db.tmbTooltipHandled = true
            end
        end)
    page.tmbTooltip:SetPoint("TOPLEFT", page.groupOnly, "BOTTOMLEFT", 0, -2)

    page.daysLabel = LC.Window:Text(page, "GameFontHighlight")
    page.daysLabel:SetText("Graph counts awards from the last")
    page.days = EditBox(page, "LootCheckConfigFrameDays", 44, true, function(text)
        local days = tonumber(text) or 0
        days = math.max(0, math.floor(days))
        if Settings().graphDays ~= days then
            Settings().graphDays = days
            Changed()
        end
        Config:Refresh()
    end)
    page.days:SetPoint("LEFT", page.daysLabel, "RIGHT", 12, 0)
    -- Trailing text is bounded by the page margin so it cannot clip out of
    -- the window when a font or locale makes the row wider than expected
    local daysTail = LC.Window:Text(page, "GameFontHighlight")
    daysTail:SetPoint("LEFT", page.days, "RIGHT", 8, 0)
    daysTail:SetPoint("RIGHT", page, "RIGHT", -MARGIN, 0)
    daysTail:SetText("days (0 = whole phase)")
    page.daysTail = daysTail

    local suffixLabel = LC.Window:Text(page, "GameFontHighlight")
    suffixLabel:SetPoint("TOPLEFT", page.daysLabel, "BOTTOMLEFT", 0, -14)
    suffixLabel:SetText("Text after greyed-out names:")
    page.suffix = EditBox(page, "LootCheckConfigFrameSuffix", 150, false, function(text)
        Settings().receivedSuffix = text or ""
    end)
    page.suffix:SetPoint("LEFT", suffixLabel, "RIGHT", 12, 0)
    local suffixTail = LC.Window:Text(page, "GameFontDisableSmall")
    suffixTail:SetPoint("LEFT", page.suffix, "RIGHT", 8, 0)
    suffixTail:SetPoint("RIGHT", page, "RIGHT", -MARGIN, 0)
    suffixTail:SetText("e.g. \" (received)\"")
    page.suffixTail = suffixTail
    page.suffixLabel = suffixLabel

    -- Buttons to the other pages, evenly spaced along the bottom
    local buttons = {
        { key = "graphButton", text = "Wishlist graph", width = 116, open = function() return LC.Graph end },
        { key = "importsButton", text = "Wishlist Data", width = 116, open = function() return LC.Imports end },
        { key = "auditButton", text = "Audit", width = 76, open = function() return LC.Audit end },
        { key = "helpButton", text = "Commands", width = 100, open = function() return LC.Help end },
    }

    local previous
    for _, spec in ipairs(buttons) do
        local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        button:SetSize(spec.width, 24)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 8, 0)
        else
            button:SetPoint("BOTTOMLEFT", MARGIN, 20)
        end
        button:SetText(spec.text)
        button:SetScript("OnClick", function()
            local module = spec.open()
            if module then module:Open() end
        end)
        page[spec.key] = button
        previous = button
    end
end

function Config:Refresh()
    if not frame or not LC.Window:IsShowing(PAGE) then return end

    local s = Settings()
    local GL = LC:Gargul()
    local data = LC:WishlistData()

    frame.status[1]:SetText(GL
        and ("Gargul: |cff00ff00found|r (v" .. tostring(GL.version) .. ")" .. (LC.Tooltip and LC.Tooltip.integrated and " - tooltip integration active" or ""))
        or "Gargul: |cffff0000not found|r - tooltip integration and award history are off")

    if data then
        local stored = LC.Imports and #LC.Imports:List() or 0
        frame.status[2]:SetText(("Active raid: |cffffffff%s|r - %d wishlist entries (%d import%s stored)"):format(
            data.source, #data.wishlists, stored, stored == 1 and "" or "s"))
    else
        frame.status[2]:SetText("Active raid: |cffff0000none|r - open Wishlist Data and paste a That's My BIS CSV export")
    end

    if GL and data then
        local current, allTime = 0, 0
        for _, row in ipairs(LC.Data:WishlistAwardCounts({ days = s.graphDays })) do
            current = current + row.count
            allTime = allTime + row.history
        end
        frame.status[3]:SetText(("Wishlist items awarded: %d this phase, %d all time"):format(current, allTime))
    else
        frame.status[3]:SetText("")
    end

    frame.greyOS:SetChecked(s.greyOSAwards ~= false)
    frame.groupOnly:SetChecked(s.graphGroupOnly and true or false)

    -- The TMBExport row only exists while that addon does; the rows below it
    -- re-anchor so no gap is left behind.
    local tmbTip = LC.Tooltip and LC.Tooltip:TMBExportTooltipEnabled()
    frame.daysLabel:ClearAllPoints()
    if tmbTip == nil then
        frame.tmbTooltip:Hide()
        frame.tmbTooltip.label:Hide()
        frame.daysLabel:SetPoint("TOPLEFT", frame.groupOnly, "BOTTOMLEFT", 4, -14)
    else
        frame.tmbTooltip:Show()
        frame.tmbTooltip.label:Show()
        frame.tmbTooltip:SetChecked(tmbTip)
        frame.daysLabel:SetPoint("TOPLEFT", frame.tmbTooltip, "BOTTOMLEFT", 4, -14)
    end

    frame.days:SetText(tostring(s.graphDays or 0))
    frame.suffix:SetText(s.receivedSuffix or "")
end

function Config:Open()
    LC.Window:Show(PAGE)
end

function Config:Toggle()
    LC.Window:Toggle(PAGE)
end

LC.Window:RegisterPage(PAGE, {
    title = "LootCheck",
    frameName = "LootCheckConfigFrame",
    width = WIDTH,
    height = HEIGHT,
    build = BuildPage,
    onShow = function() Config:Refresh() end,
})
