--[[
    LootCheck - Window.lua

    The single LootCheck window. Every screen is a "page" registered here
    (home, graph, imports, audit, help). The window shows one page at a time
    under a shared title bar with a "< Back" button (to the home page) and a
    close button; Escape closes the window. Each page keeps its own size.

    Pages register themselves at load time:
        LC.Window:RegisterPage("graph", {
            title = "...", frameName = "LootCheckGraphFrame", width = 500, height = 540,
            build = function(pageFrame) ... end,   -- called once, lazily
            onShow = function() ... end,           -- called every time the page is shown
        })
]]

local LC = LootCheck
local Window = {}
LC.Window = Window

local FRAME_NAME = "LootCheckWindow"
local HEADER = 44 -- title bar height; page content starts below it

local pages = {}
local frame, current

function Window:RegisterPage(key, def)
    def.key = key
    pages[key] = def
end

local function SavePosition()
    if not frame or not LC.db then return end
    local point, _, relPoint, x, y = frame:GetPoint()
    LC.db.windowPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestorePosition()
    frame:ClearAllPoints()
    local p = LC.db and LC.db.windowPos
    if p and p.point then
        frame:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
    else
        frame:SetPoint("CENTER")
    end
end

local function Build()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", FRAME_NAME, UIParent, template)
    f:SetSize(500, 400)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    f:Hide()

    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -16)
    f.title:SetText("LootCheck")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    f.back = CreateFrame("Button", FRAME_NAME .. "Back", f, "UIPanelButtonTemplate")
    f.back:SetSize(64, 22)
    f.back:SetPoint("TOPLEFT", 14, -13)
    f.back:SetText("< Back")
    f.back:SetScript("OnClick", function() Window:Back() end)
    f.back:Hide()

    -- Escape closes the window
    tinsert(UISpecialFrames, FRAME_NAME)
    return f
end

local function EnsurePage(key)
    local def = pages[key]
    if not def then return nil end

    if not def.frame then
        local page = CreateFrame("Frame", def.frameName, frame)
        page:SetPoint("TOPLEFT", 0, -HEADER)
        page:SetPoint("BOTTOMRIGHT", 0, 0)
        page:Hide()
        def.frame = page
        def.build(page)
    end
    return def
end

--- Show the window on the given page (default: home)
function Window:Show(key)
    key = key or "home"
    if not frame then
        frame = Build()
        RestorePosition()
    end

    local def = EnsurePage(key)
    if not def then return false end

    for k, other in pairs(pages) do
        if k ~= key and other.frame then other.frame:Hide() end
    end
    current = key

    frame:SetSize(def.width or 500, def.height or 400)
    frame.title:SetText(def.title or "LootCheck")
    if key == "home" then frame.back:Hide() else frame.back:Show() end

    frame:Show()
    def.frame:Show()
    if def.onShow then def.onShow() end
    return true
end

function Window:Hide()
    if not frame then return end
    frame:Hide()
    local def = current and pages[current]
    if def and def.frame then def.frame:Hide() end
end

--- Toggle: hides the window when it already shows that page, otherwise shows it
function Window:Toggle(key)
    key = key or "home"
    if self:IsShowing(key) then
        self:Hide()
    else
        self:Show(key)
    end
end

function Window:Back()
    self:Show("home")
end

function Window:IsShowing(key)
    return frame ~= nil and frame:IsShown() and current == key
end

--- The page currently on screen, or nil when the window is hidden
function Window:Current()
    if frame and frame:IsShown() then return current end
    return nil
end

function Window:Frame()
    return frame
end

------------------------------------------------------------------------------
-- Shared building blocks, so every page keeps the same margins and styling
------------------------------------------------------------------------------

Window.MARGIN = 22

--- A dark inset panel: used behind lists and text boxes so they stand out
--- from the window's own background.
function Window:CreateInset(parent, name)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local inset = CreateFrame("Frame", name, parent, template)

    if inset.SetBackdrop then
        inset:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        if inset.SetBackdropColor then inset:SetBackdropColor(0, 0, 0, 0.55) end
        if inset.SetBackdropBorderColor then inset:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9) end
    end

    return inset
end

--- A font string. `width` makes it wrap inside that width (anchor the next
--- element to its BOTTOMLEFT so wrapping pushes content down instead of
--- overlapping it); without a width it stays on one line and truncates.
function Window:Text(parent, style, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", style or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")

    if width then
        fs:SetWidth(width)
        if fs.SetWordWrap then fs:SetWordWrap(true) end
        if fs.SetSpacing then fs:SetSpacing(2) end
    elseif fs.SetWordWrap then
        fs:SetWordWrap(false)
    end

    return fs
end

--- A dropdown built from plain frames.
---
--- Blizzard's UIDropDownMenu keeps global state that the secure UI reads, so
--- driving it from an addon taints the game menu and "Log Out" silently stops
--- working until you reload. Nothing in LootCheck may touch it; the test
--- harness greps the source and fails if it appears.
---
--- opts = {
---   width    = 150,
---   items    = function() return { { value = "week", text = "Past week" }, ... } end,
---   selected = function() return "week" end,          -- which one is ticked
---   onSelect = function(value) ... end,
--- }
--- Returns the button, with :Refresh() to re-read the selection.
function Window:CreateDropdown(parent, name, opts)
    local ITEM_HEIGHT = 18
    local width = opts.width or 150

    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)

    -- Left-align the label and leave room for the arrow
    local fs = button.GetFontString and button:GetFontString()
    if fs then
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", 8, 0)
        fs:SetPoint("RIGHT", -18, 0)
        fs:SetJustifyH("LEFT")
        if fs.SetWordWrap then fs:SetWordWrap(false) end
    end

    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    arrow:SetSize(16, 16)
    arrow:SetPoint("RIGHT", -3, -1)

    -- Clicking anywhere else closes the menu
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", function() button:CloseMenu() end)
    catcher:Hide()

    local menu = self:CreateInset(UIParent, name and (name .. "Menu") or nil)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel((catcher.GetFrameLevel and catcher:GetFrameLevel() or 1) + 10)
    menu:SetSize(width, 40)
    if menu.SetBackdropColor then menu:SetBackdropColor(0.04, 0.04, 0.04, 0.96) end
    menu:Hide()

    local items = {}
    button._menu, button._menuItems = menu, items -- exposed for tests

    local function Item(index)
        if items[index] then return items[index] end

        local item = CreateFrame("Button", nil, menu)
        item:SetHeight(ITEM_HEIGHT)
        item:SetPoint("TOPLEFT", 6, -(6 + (index - 1) * ITEM_HEIGHT))
        item:SetPoint("RIGHT", menu, "RIGHT", -6, 0)

        local highlight = item:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.15)

        item.text = Window:Text(item, "GameFontHighlightSmall")
        item.text:SetPoint("LEFT", 6, 0)
        item.text:SetPoint("RIGHT", -6, 0)

        item:SetScript("OnClick", function(self)
            button:CloseMenu()
            if self.value ~= nil and opts.onSelect then opts.onSelect(self.value) end
        end)

        items[index] = item
        return item
    end

    function button:Refresh()
        local selected = opts.selected and opts.selected() or nil
        for _, entry in ipairs(opts.items() or {}) do
            if entry.value == selected then
                self:SetText(entry.text)
                return
            end
        end
        self:SetText(opts.emptyText or "")
    end

    function button:OpenMenu()
        local list = opts.items() or {}
        local selected = opts.selected and opts.selected() or nil

        for i, entry in ipairs(list) do
            local item = Item(i)
            item.value = entry.value
            item.text:SetText(("%s%s|r"):format(entry.value == selected and "|cffffffff" or "|cffbbbbbb", entry.text))
            item:Show()
        end
        for i = #list + 1, #items do
            items[i]:Hide()
            items[i].value = nil
        end

        menu:SetSize(width, math.max(#list, 1) * ITEM_HEIGHT + 12)
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        catcher:Show()
        menu:Show()
    end

    function button:CloseMenu()
        menu:Hide()
        catcher:Hide()
    end

    function button:ToggleMenu()
        if menu:IsShown() then self:CloseMenu() else self:OpenMenu() end
    end

    button:SetScript("OnClick", function(self) self:ToggleMenu() end)
    button:Refresh()
    return button
end

--- Measured height of a font string, with an estimate when the client cannot
--- measure it yet (and in the offline test harness).
function Window:TextHeight(fontString, estimatedLines)
    local h = fontString and fontString.GetStringHeight and fontString:GetStringHeight()
    if type(h) == "number" and h > 0 then return h end
    return (estimatedLines or 1) * 13
end
