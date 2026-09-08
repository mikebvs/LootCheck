--[[
    LootCheck - Graph.lua

    The "Wishlist Awards" page, in two columns.

    Left: one horizontal bar per raider showing how many non-OS wishlist items
    Gargul has awarded them, with the all-time number in parentheses. Hovering
    a row lists the items.

    By default the bars count against the wishlist currently imported, which is
    what changes when you re-import a new tier's data. The < > buttons filter by
    content phase instead, which is a date window (see Phases.lua); the two are
    different questions and a chosen phase takes over from the day count.

    Right: everything that dropped in the raid this week (see Drops.lua),
    which owns that column and only gets a container frame from here.

    The header block is anchored top-down, so a subtitle that wraps pushes the
    list down instead of overlapping it.
]]

local LC = LootCheck
local Graph = {}
LC.Graph = Graph

local PAGE = "graph"
local WIDTH, HEIGHT = 1000, 560
local MARGIN = 22
local ROW_HEIGHT = 22
local NAME_WIDTH = 116
local BAR_MAX = 160
local LEFT_WIDTH = 394 -- the bar column; the drops list fills what is left
local GAP = 14
local CONTENT_WIDTH = LEFT_WIDTH - 40
-- Distance from the page's right edge back to the bar column's right edge
local RIGHT_INSET = WIDTH - MARGIN * 2 - LEFT_WIDTH

local frame -- the page
local rows = {}
Graph._rows = rows -- exposed for tests

------------------------------------------------------------------------------
-- Page construction
------------------------------------------------------------------------------

local function BuildPage(page)
    frame = page

    page.subtitle = LC.Window:Text(page, "GameFontHighlightSmall", WIDTH - MARGIN * 2)
    page.subtitle:SetPoint("TOPLEFT", MARGIN, -6)
    page.subtitle:SetJustifyH("CENTER")

    local groupOnly = CreateFrame("CheckButton", "LootCheckGraphFrameGroupOnly", page, "UICheckButtonTemplate")
    groupOnly:SetPoint("TOPLEFT", page.subtitle, "BOTTOMLEFT", -4, -6)
    groupOnly:SetSize(24, 24)
    groupOnly:SetScript("OnClick", function(self)
        LC.db.settings.graphGroupOnly = self:GetChecked() and true or false
        Graph:Refresh()
    end)
    local groupLabel = LC.Window:Text(page, "GameFontHighlight")
    groupLabel:SetPoint("LEFT", groupOnly, "RIGHT", 4, 0)
    groupLabel:SetText("Current group only")
    page.groupOnly = groupOnly

    -- Refresh sits at the right edge of the bar column, not of the page
    local refresh = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    refresh:SetSize(80, 22)
    refresh:SetPoint("TOPRIGHT", page.subtitle, "BOTTOMRIGHT", -RIGHT_INSET, -7)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function()
        LC.Data:Invalidate()
        LC.Drops:Prune()
        Graph:Refresh()
    end)

    -- Phase filter. A taint-free stepper rather than a dropdown, like the
    -- raid drops week picker; see the note in Imports.lua about UIDropDownMenu.
    local prevPhase = CreateFrame("Button", "LootCheckGraphFramePrevPhase", page, "UIPanelButtonTemplate")
    prevPhase:SetSize(22, 20)
    prevPhase:SetPoint("TOPLEFT", groupOnly, "BOTTOMLEFT", 4, -4)
    prevPhase:SetText("<")
    prevPhase:SetScript("OnClick", function() Graph:StepPhase(-1) end)
    page.prevPhase = prevPhase

    local nextPhase = CreateFrame("Button", "LootCheckGraphFrameNextPhase", page, "UIPanelButtonTemplate")
    nextPhase:SetSize(22, 20)
    nextPhase:SetPoint("LEFT", prevPhase, "RIGHT", 2, 0)
    nextPhase:SetText(">")
    nextPhase:SetScript("OnClick", function() Graph:StepPhase(1) end)
    page.nextPhase = nextPhase

    page.phaseLabel = LC.Window:Text(page, "GameFontNormalSmall")
    page.phaseLabel:SetPoint("LEFT", nextPhase, "RIGHT", 6, 0)
    page.phaseLabel:SetPoint("RIGHT", page, "LEFT", MARGIN + LEFT_WIDTH, 0)

    local header = LC.Window:Text(page, "GameFontDisableSmall")
    header:SetPoint("TOPLEFT", prevPhase, "BOTTOMLEFT", 0, -6)
    header:SetText("Raider")
    local header2 = LC.Window:Text(page, "GameFontDisableSmall")
    header2:SetPoint("LEFT", header, "LEFT", NAME_WIDTH + 8, 0)
    header2:SetText("Wishlist items awarded: current wishlist (all time)")
    page.header2 = header2

    -- The list sits on a dark inset so it reads as a panel of its own
    local inset = LC.Window:CreateInset(page, "LootCheckGraphFrameInset")
    inset:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -4)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -MARGIN - RIGHT_INSET, 18)
    page.inset = inset

    local scroll = CreateFrame("ScrollFrame", "LootCheckGraphFrameScroll", inset, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(CONTENT_WIDTH, 10)
    scroll:SetScrollChild(content)
    page.content = content

    page.empty = LC.Window:Text(content, "GameFontHighlight", CONTENT_WIDTH - 12)
    page.empty:SetPoint("TOPLEFT", 2, -8)
    page.empty:Hide()

    -- Right column: Drops.lua fills this container itself
    local dropsColumn = CreateFrame("Frame", "LootCheckGraphFrameDrops", page)
    dropsColumn:SetPoint("TOPLEFT", page.subtitle, "BOTTOMLEFT", LEFT_WIDTH + GAP, -8)
    dropsColumn:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -MARGIN, 18)
    page.dropsColumn = dropsColumn
    LC.Drops:BuildPanel(dropsColumn)
end

local function GetRow(index)
    if rows[index] then return rows[index] end

    local row = CreateFrame("Frame", nil, frame.content)
    row:SetSize(CONTENT_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) Graph:ShowRowTooltip(self) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.04 or 0)

    -- Names never wrap: a long one is truncated so the row keeps its height
    row.name = LC.Window:Text(row, "GameFontHighlight")
    row.name:SetPoint("LEFT", 2, 0)
    row.name:SetWidth(NAME_WIDTH)
    row.name:SetJustifyH("RIGHT")

    row.track = row:CreateTexture(nil, "BORDER")
    row.track:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.track:SetSize(BAR_MAX, ROW_HEIGHT - 8)
    row.track:SetColorTexture(1, 1, 1, 0.08)

    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetPoint("LEFT", row.track, "LEFT", 0, 0)
    row.bar:SetHeight(ROW_HEIGHT - 8)

    row.count = LC.Window:Text(row, "GameFontHighlight")
    row.count:SetPoint("LEFT", row.track, "RIGHT", 8, 0)

    rows[index] = row
    return row
end

------------------------------------------------------------------------------
-- Rendering
------------------------------------------------------------------------------

function Graph:Refresh()
    if not frame then return end

    local settings = LC.db.settings
    frame.groupOnly:SetChecked(settings.graphGroupOnly)

    local GL = LC:Gargul()
    local db = LC:WishlistData()

    -- A chosen phase is a date window and takes over from the rolling day count
    local phaseKey = settings.graphPhase
    local phase = (phaseKey and phaseKey ~= "") and LC.Phases:Get(phaseKey) or nil
    local from, to
    if phase then
        from, to = LC.Phases:Bounds(phase.key)
        -- A phase with no announced date has not happened, so nothing counts.
        -- Without this the window would be empty and fall back to "all time",
        -- which would show every award under a phase that has not started.
        if not from then from = math.huge end
    end

    frame.phaseLabel:SetText(phase
        and ("Phase: |cffffffff%s|r%s"):format(LC.Phases:Label(phase.key),
            phase.announced and "" or " |cffff4040(no date yet)|r")
        or "Phase: |cffffffffAll time|r")

    local list = {}
    if GL and db then
        list = LC.Data:WishlistAwardCounts({
            days = settings.graphDays,
            from = from,
            to = to,
            groupOnly = settings.graphGroupOnly,
        })
    end

    local maxCount, total, allTime = 0, 0, 0
    for _, r in ipairs(list) do
        total = total + r.count
        allTime = allTime + (r.history or 0)
        if r.count > maxCount then maxCount = r.count end
    end

    local window
    if phase then
        window = phase.announced and ("during " .. phase.key) or ("in " .. phase.key .. ", which has no date yet")
    elseif (settings.graphDays or 0) > 0 then
        window = "in the last " .. settings.graphDays .. " days"
    else
        window = "against the current wishlist"
    end
    frame.subtitle:SetText(("%s%d raiders - %d wishlist items awarded %s, %d all time"):format(
        db and (db.source .. ": ") or "", #list, total, window, allTime))

    frame.header2:SetText(phase
        and ("Wishlist items awarded: %s (all time)"):format(phase.key)
        or "Wishlist items awarded: current wishlist (all time)")

    for i, r in ipairs(list) do
        local row = GetRow(i)
        local cr, cg, cb = LC:ClassColor(r.class)

        row.name:SetText(r.displayName)
        row.name:SetTextColor(cr, cg, cb)

        local width = maxCount > 0 and (r.count / maxCount) * BAR_MAX or 0
        if width > 0 then
            row.bar:SetWidth(math.max(width, 2))
            row.bar:SetColorTexture(cr, cg, cb, 0.85)
            row.bar:Show()
        else
            row.bar:Hide()
        end

        row.count:SetText(("%d |cffaaaaaa(%d)|r"):format(r.count, r.history or 0))
        row.data = r
        row:Show()
    end

    for i = #list + 1, #rows do
        rows[i]:Hide()
        rows[i].data = nil
    end

    frame.content:SetHeight(math.max(#list * ROW_HEIGHT, 10))

    if #list == 0 then
        if not GL then
            frame.empty:SetText("Gargul was not found. LootCheck needs Gargul's award history.")
        elseif not db then
            frame.empty:SetText("No wishlist data. Go back and open Wishlist Data to paste a That's My BIS CSV export.")
        elseif settings.graphGroupOnly then
            frame.empty:SetText("Nobody in your current group has a wishlist in the active raid.")
        else
            frame.empty:SetText("No characters found in the active raid's wishlist data.")
        end
        frame.empty:Show()
    else
        frame.empty:Hide()
    end

    LC.Drops:RefreshPanel()
end

--- Cycle the phase filter: all time, then P1 upwards.
function Graph:StepPhase(by)
    local keys = LC.Phases:StepperKeys()
    local current = LC.db.settings.graphPhase or ""

    local index = 1
    for i, key in ipairs(keys) do
        if key == current then index = i break end
    end

    index = index + (by or 0)
    if index < 1 then index = #keys end
    if index > #keys then index = 1 end

    LC.db.settings.graphPhase = keys[index]
    self:Refresh()
end

function Graph:ShowRowTooltip(row)
    local r = row.data
    if not r then return end

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(r.displayName, LC:ClassColor(r.class))

    if r.count == 0 then
        GameTooltip:AddLine("No wishlist items awarded in this window.", 0.7, 0.7, 0.7)
    else
        GameTooltip:AddLine(("%d wishlist item%s awarded in this window:"):format(r.count, r.count == 1 and "" or "s"), 1, 1, 1)
        for _, item in ipairs(r.items) do
            local label = item.itemLink or item.itemName or "?"
            if item.prio then
                label = label .. (" |cff7f7f7f(prio %s)|r"):format(item.prio)
            end
            local when = (item.timestamp and item.timestamp > 0) and date("%Y-%m-%d", item.timestamp) or ""
            GameTooltip:AddDoubleLine(label, when, 1, 1, 1, 0.6, 0.6, 0.6)
        end
    end

    -- Everything else they ever received off a wishlist, outside this window
    local current = {}
    for _, item in ipairs(r.items) do
        if item.checksum then current[item.checksum] = true end
    end
    local earlier = {}
    for _, item in ipairs(r.historyItems or {}) do
        if not current[item.checksum] then tinsert(earlier, item) end
    end
    if #earlier > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(("%d more outside this window (%d all time):"):format(#earlier, r.history or 0), 1, 1, 1)
        for i, item in ipairs(earlier) do
            if i > 25 then
                GameTooltip:AddLine(("... and %d more"):format(#earlier - 25), 0.6, 0.6, 0.6)
                break
            end
            local when = (item.timestamp and item.timestamp > 0) and date("%Y-%m-%d", item.timestamp) or ""
            GameTooltip:AddDoubleLine(item.itemLink or item.itemName or "?", when, 0.8, 0.8, 0.8, 0.6, 0.6, 0.6)
        end
    end

    GameTooltip:Show()
end

------------------------------------------------------------------------------
-- Page management
------------------------------------------------------------------------------

function Graph:Open()
    LC.Data:Invalidate()
    LC.Window:Show(PAGE)
end

function Graph:Toggle()
    if LC.Window:IsShowing(PAGE) then
        LC.Window:Hide()
    else
        self:Open()
    end
end

function Graph:RefreshIfShown()
    if LC.Window:IsShowing(PAGE) then
        self:Refresh()
    end
end

LC.Window:RegisterPage(PAGE, {
    title = "LootCheck - Wishlist Awards and Raid Drops",
    frameName = "LootCheckGraphFrame",
    width = WIDTH,
    height = HEIGHT,
    build = BuildPage,
    onShow = function() Graph:Refresh() end,
})
