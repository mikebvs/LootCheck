--[[
    LootCheck - Window.lua

    The single LootCheck window. Every screen is a "page" registered here
    (home, graph, imports, audit, help). The window shows one page at a time
    under a shared title bar with a "< Back" button (to the home page) and a
    close button; Escape closes the window.

    The window is resizable by the grip in its bottom-right corner. There is
    one size for the whole window rather than one per page, so the size you
    drag to carries over when you switch pages. Its floor is whatever the most
    demanding page needs (the wishlist graph, with its two columns), which is
    what lets a single size suit every page. Sizes are clamped to the screen,
    so one saved on a bigger monitor cannot leave the window larger than the
    display.

    Pages register themselves at load time:
        LC.Window:RegisterPage("graph", {
            title = "...", frameName = "LootCheckGraphFrame", width = 500, height = 540,
            minWidth = 420, minHeight = 300,        -- optional, defaults below
            build = function(pageFrame) ... end,    -- called once, lazily
            onShow = function() ... end,            -- called every time the page is shown
            layout = function(pageFrame, w, h) end, -- called on show and while resizing
        })

    A page's `layout` is handed the content size (the window minus the title
    bar) rather than being asked to measure frames itself, so it behaves the
    same in game and in the offline harness, where frames have no geometry.
]]

local LC = LootCheck
local Window = {}
LC.Window = Window

local FRAME_NAME = "LootCheckWindow"
local HEADER = 44 -- title bar height; page content starts below it

local MIN_WIDTH, MIN_HEIGHT = 420, 280
local MAX_WIDTH, MAX_HEIGHT = 2400, 1600

local pages = {}
local frame, current
local width, height = 500, 400 -- the current window size, tracked so pages can
                               -- lay out from a number rather than by measuring

function Window:RegisterPage(key, def)
    def.key = key
    pages[key] = def
end

------------------------------------------------------------------------------
-- Size
------------------------------------------------------------------------------

--- The space a page has to work with: the window minus the title bar.
function Window:ContentSize()
    return width, height - HEADER
end

--- One size for the whole window, not one per page: drag it on any page and
--- every other page opens at that size. Sizes from before this was shared were
--- stored per page, so the largest of them is carried over rather than lost.
local function SavedSize()
    LC.db = LC.db or LootCheckDB or {}
    local saved = LC.db.windowSize

    if type(saved) ~= "table" then
        saved = {}
    elseif type(saved.width) ~= "number" then
        local w, h
        for _, entry in pairs(saved) do
            if type(entry) == "table" and tonumber(entry.width) then
                w = math.max(w or 0, entry.width)
                h = math.max(h or 0, entry.height or 0)
            end
        end
        saved = (w and { width = w, height = h }) or {}
    end

    LC.db.windowSize = saved
    return saved
end

--- The smallest the window may be: whatever the most demanding page needs.
--- That is the wishlist graph, which has to fit two columns side by side, so
--- every page can be switched to without the window having to change size.
function Window:MinimumSize()
    local w, h = MIN_WIDTH, MIN_HEIGHT
    for _, def in pairs(pages) do
        w = math.max(w, def.minWidth or 0)
        -- Pages state what their *content* needs; the title bar sits on top
        h = math.max(h, (def.minHeight or 0) + HEADER)
    end
    return w, h
end

--- Keep the client's resize bounds in step with what the pages need, and make
--- sure the current size is inside them.
---
--- These two disagreeing is what makes a window jump the instant sizing
--- starts: the client enforces the bounds at that moment, so a frame sitting
--- below its own minimum is snapped up to it and the drag appears to begin
--- with a lurch. Called before every resize and on every page change, so the
--- two can never drift apart.
function Window:ApplyBounds()
    if not frame then return end

    local minW, minH = self:MinimumSize()
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minW, minH, MAX_WIDTH, MAX_HEIGHT)
    else
        -- Classic clients have the older pair
        if frame.SetMinResize then frame:SetMinResize(minW, minH) end
        if frame.SetMaxResize then frame:SetMaxResize(MAX_WIDTH, MAX_HEIGHT) end
    end

    -- Measure the frame rather than trusting the tracked numbers. The two can
    -- disagree - the client resizes the frame itself in ways nothing here sees
    -- - and it is the frame's real size the client checks against the bounds
    -- when sizing starts. Comparing the tracked values instead left the very
    -- case this guards against undetected.
    local realW = (frame.GetWidth and frame:GetWidth()) or width
    local realH = (frame.GetHeight and frame:GetHeight()) or height

    if realW < minW or realH < minH or width < minW or height < minH then
        self:Resize(math.max(realW, width), math.max(realH, height))
    end
end

--- Nothing may end up bigger than the screen, whatever a saved size says: a
--- size carried over from a larger monitor would otherwise be undraggable.
local function Clamp(w, h)
    local maxW, maxH = MAX_WIDTH, MAX_HEIGHT
    if UIParent and UIParent.GetWidth then
        maxW = math.min(maxW, UIParent:GetWidth() or maxW)
        maxH = math.min(maxH, UIParent:GetHeight() or maxH)
    end

    local minW, minH = Window:MinimumSize()
    minW, minH = math.min(minW, maxW), math.min(minH, maxH)

    w = math.max(minW, math.min(w or minW, maxW))
    h = math.max(minH, math.min(h or minH, maxH))
    return w, h
end

------------------------------------------------------------------------------
-- Resize diagnostics (/lchelp sizedebug)
------------------------------------------------------------------------------
--
-- Resizing is driven by the client, so when the window misbehaves there is
-- nothing in the addon's own state to inspect afterwards. This prints what the
-- frame and the client actually think at each step of a drag.

Window.debug = false

local function Num(value)
    return type(value) == "number" and ("%.0f"):format(value) or "?"
end

--- One line of state, printed at each step of a drag while debugging is on
function Window:Trace(label)
    if not self.debug or not frame then return end

    print(("|cff33ccffLootCheck|r [%s] tracked %sx%s | frame %sx%s | anchors %s"):format(
        label, Num(width), Num(height),
        Num(frame.GetWidth and frame:GetWidth()), Num(frame.GetHeight and frame:GetHeight()),
        Num(frame.GetNumPoints and frame:GetNumPoints())))
end

--- Everything that does not change during a drag, printed once
function Window:DumpSizeState()
    if not frame then
        LC:Print("open the window first, then run this again.")
        return
    end

    local minW, minH = self:MinimumSize()
    LC:Print("resize diagnostics:")
    print(("  page            %s"):format(tostring(current)))
    print(("  tracked size    %s x %s"):format(Num(width), Num(height)))
    print(("  frame size      %s x %s"):format(
        Num(frame.GetWidth and frame:GetWidth()), Num(frame.GetHeight and frame:GetHeight())))
    print(("  minimum wanted  %s x %s"):format(Num(minW), Num(minH)))

    if frame.GetResizeBounds then
        local a, b, c, d = frame:GetResizeBounds()
        print(("  client bounds   %s x %s .. %s x %s (GetResizeBounds)"):format(Num(a), Num(b), Num(c), Num(d)))
    elseif frame.GetMinResize then
        local a, b = frame:GetMinResize()
        local c, d = frame.GetMaxResize and frame:GetMaxResize()
        print(("  client bounds   %s x %s .. %s x %s (GetMinResize)"):format(Num(a), Num(b), Num(c), Num(d)))
    else
        print("  client bounds   neither GetResizeBounds nor GetMinResize exists")
    end

    print(("  setter used     %s"):format(
        frame.SetResizeBounds and "SetResizeBounds" or (frame.SetMinResize and "SetMinResize" or "none available")))

    local point, relTo, relPoint, x, y = frame:GetPoint()
    print(("  anchored        %s of %s to %s at %s, %s (%s point(s))"):format(
        tostring(point), tostring(relTo and relTo.GetName and relTo:GetName() or relTo), tostring(relPoint),
        Num(x), Num(y), Num(frame.GetNumPoints and frame:GetNumPoints())))

    print(("  scale           frame %s, effective %s, UIParent %s"):format(
        tostring(frame.GetScale and frame:GetScale()),
        tostring(frame.GetEffectiveScale and frame:GetEffectiveScale()),
        tostring(UIParent.GetEffectiveScale and UIParent:GetEffectiveScale())))
    print(("  UIParent        %s x %s"):format(
        Num(UIParent.GetWidth and UIParent:GetWidth()), Num(UIParent.GetHeight and UIParent:GetHeight())))
    print(("  resizable       %s"):format(tostring(frame.IsResizable and frame:IsResizable())))
end

function Window:ToggleDebug()
    self.debug = not self.debug
    LC:Print(self.debug
        and "resize diagnostics on - drag the grip, then paste the lines here. |cff33ccff/lchelp sizedebug|r again turns it off."
        or "resize diagnostics off.")
    if self.debug then self:DumpSizeState() end
    return self.debug
end

--- Tell the current page how much room it has, then let it refresh.
local function ApplyLayout()
    local def = current and pages[current]
    if not def or not def.frame then return end
    if def.layout then
        local ok, err = pcall(def.layout, def.frame, width, height - HEADER)
        if not ok then LC:Print("layout error on " .. tostring(current) .. ": " .. tostring(err)) end
    end
end

local function SaveSize()
    local saved = SavedSize()
    saved.width, saved.height = width, height
end

--- Resize the window and re-lay the page out. Used by the grip and on show.
function Window:Resize(w, h)
    if not frame then return end

    width, height = Clamp(w, h)
    frame:SetSize(width, height)
    ApplyLayout()
end

--- Pin the top-left corner before sizing from the bottom-right one.
---
--- A frame anchored by its centre keeps that centre fixed while a corner is
--- dragged, so both corners move and the frame resizes at twice the speed of
--- the cursor. Anchoring to TOPLEFT first pins the corner that should stay
--- still, which is the standard way to make a corner-resizable frame behave
--- and keeps the position saved afterwards meaningful.
local function AnchorTopLeft()
    if not frame then return end

    local left, top = frame:GetLeft(), frame:GetTop()
    if not left or not top then return end

    -- GetLeft/GetTop are in the frame's own coordinate space; UIParent may be
    -- on a different one, so convert before anchoring across
    local mine = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    local theirs = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local ratio = (theirs ~= 0) and (mine / theirs) or 1

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * ratio, top * ratio)
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

    -- The floor is whatever the most demanding page needs, so one size carries
    -- from page to page without any of them being squeezed. Window:ApplyBounds
    -- keeps the client in step with it.
    f:SetResizable(true)

    local grip = CreateFrame("Button", FRAME_NAME .. "Grip", f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -6, 6)
    grip:EnableMouse(true)

    local gripTexture = grip:CreateTexture(nil, "OVERLAY")
    gripTexture:SetAllPoints()
    gripTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip.texture = gripTexture

    -- Sizing begins on a drag, not on a mouse-down. Starting it on mouse-down
    -- meant a plain click already put the frame into sizing mode, so the
    -- smallest twitch of the cursor resized it, and the client snapped the
    -- frame up to its minimum the moment sizing began if it happened to be
    -- smaller than that.
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnMouseDown", function() Window:Trace("grip mouse down") end)
    grip:SetScript("OnDragStart", function()
        Window:Trace("drag start, before")
        Window:ApplyBounds()
        AnchorTopLeft()
        f:StartSizing("BOTTOMRIGHT")
        Window:Trace("drag start, after")
    end)
    grip:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        Window:Trace("drag stop, before")

        -- Trust the frame's own size after a drag, then clamp and store it
        local w = (f.GetWidth and f:GetWidth()) or width
        local h = (f.GetHeight and f:GetHeight()) or height
        Window:Resize(w, h)
        SaveSize()
        SavePosition() -- sizing from a corner moves the anchor too
        Window:Trace("drag stop, after")
    end)
    f.grip = grip

    -- Re-lay out live while the grip is being dragged, not only when released
    f:SetScript("OnSizeChanged", function(self, w, h)
        if not current then return end
        width = w or width
        height = h or height
        Window:Trace("size changed")
        ApplyLayout()
    end)

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

    -- The size you last dragged the window to, whichever page you did it on,
    -- else this page's natural size
    local saved = SavedSize()
    width, height = Clamp(saved.width or def.width or 500,
                          saved.height or def.height or 400)
    frame:SetSize(width, height)

    frame.title:SetText(def.title or "LootCheck")
    if key == "home" then frame.back:Hide() else frame.back:Show() end

    frame:Show()
    def.frame:Show()
    self:ApplyBounds()
    ApplyLayout()
    if def.onShow then def.onShow() end
    return true
end

--- Forget the dragged size and go back to the current page's natural one.
function Window:ResetSize()
    local def = current and pages[current]
    if not def then return false end

    LC.db.windowSize = {}
    self:Resize(def.width or 500, def.height or 400)
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

--- How many rows of `rowHeight` fit into `available` pixels. Pages call this
--- from their layout so a taller window shows more rows rather than more
--- empty inset.
function Window:RowCount(available, rowHeight, minimum)
    local count = math.floor((available or 0) / (rowHeight or 1))
    return math.max(minimum or 1, count)
end

--- The button half of a dropdown: a dark panel with a left-aligned label and
--- an arrow. Deliberately not UIPanelButtonTemplate, so it reads as a field to
--- pick from rather than as an action button like "< Back", and so it matches
--- the menu that drops out of it.
--- Shared by Window:CreateDropdown and the Wishlist Data raid picker.
function Window:CreateDropdownButton(parent, name, width)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local button = CreateFrame("Button", name, parent, template)
    button:SetSize(width or 150, 22)

    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        if button.SetBackdropColor then button:SetBackdropColor(0.04, 0.04, 0.04, 0.96) end
        if button.SetBackdropBorderColor then button:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9) end
    end

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", 3, -3)
    highlight:SetPoint("BOTTOMRIGHT", -3, 3)
    highlight:SetColorTexture(1, 1, 1, 0.08)

    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    arrow:SetSize(16, 16)
    arrow:SetPoint("RIGHT", -4, -1)

    -- Its own label: without a template there is no font string to borrow
    button.label = self:Text(button, "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", 8, 0)
    button.label:SetPoint("RIGHT", arrow, "LEFT", -2, 0)

    function button:SetText(text) self.label:SetText(text) end
    function button:GetText() return self.label:GetText() end

    return button
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

    local button = self:CreateDropdownButton(parent, name, width)

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
