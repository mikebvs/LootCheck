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

--- Measured height of a font string, with an estimate when the client cannot
--- measure it yet (and in the offline test harness).
function Window:TextHeight(fontString, estimatedLines)
    local h = fontString and fontString.GetStringHeight and fontString:GetStringHeight()
    if type(h) == "number" and h > 0 then return h end
    return (estimatedLines or 1) * 13
end
