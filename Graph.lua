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
local GAP = 14
local MIN_LEFT = 320   -- narrower than this and the bars stop meaning anything
local MIN_DROPS = 360  -- narrower than this and the drops columns collide
local BAR_SHARE = 0.44 -- of the bar column, once the name and count have theirs

-- Recomputed on every resize, see Graph:Layout
local leftWidth = 394
local contentWidth = leftWidth - 40
local barMax = 160

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

    -- Refresh sits at the right edge of the bar column, not of the page, and is
    -- built first so the check box label can be bounded against it
    local refresh = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    refresh:SetSize(80, 22)
    refresh:SetPoint("TOPRIGHT", page.subtitle, "BOTTOMRIGHT", 0, -7) -- moved by Layout
    page.refresh = refresh
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function()
        LC.Data:Invalidate()
        LC.Drops:Prune()
        Graph:Refresh()
    end)

    local groupOnly = CreateFrame("CheckButton", "LootCheckGraphFrameGroupOnly", page, "UICheckButtonTemplate")
    groupOnly:SetPoint("TOPLEFT", page.subtitle, "BOTTOMLEFT", -4, -6)
    groupOnly:SetSize(24, 24)
    groupOnly:SetScript("OnClick", function(self)
        LC.db.settings.graphGroupOnly = self:GetChecked() and true or false
        Graph:Refresh()
    end)
    local groupLabel = LC.Window:Text(page, "GameFontHighlight")
    groupLabel:SetPoint("LEFT", groupOnly, "RIGHT", 4, 0)
    groupLabel:SetPoint("RIGHT", refresh, "LEFT", -6, 0)
    groupLabel:SetText("Current group only")
    page.groupOnly = groupOnly
    page.groupLabel = groupLabel

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
    page.phaseLabel:SetPoint("RIGHT", page, "LEFT", MARGIN + leftWidth, 0)

    local header = LC.Window:Text(page, "GameFontDisableSmall")
    header:SetPoint("TOPLEFT", prevPhase, "BOTTOMLEFT", 0, -6)
    header:SetText("Raider")
    page.header = header
    -- Bounded by the bar column's right edge: unbounded, this ran on into the
    -- raid drops list next to it
    local header2 = LC.Window:Text(page, "GameFontDisableSmall")
    header2:SetPoint("LEFT", header, "LEFT", NAME_WIDTH + 8, 0)
    header2:SetPoint("RIGHT", page, "LEFT", MARGIN + leftWidth, 0)
    header2:SetText("Awarded: wishlist / tokens (all time)")
    page.header2 = header2

    -- The list sits on a dark inset so it reads as a panel of its own
    local inset = LC.Window:CreateInset(page, "LootCheckGraphFrameInset")
    inset:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -4)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -MARGIN, 18) -- moved by Layout
    page.inset = inset

    local scroll = CreateFrame("ScrollFrame", "LootCheckGraphFrameScroll", inset, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(contentWidth, 10)
    scroll:SetScrollChild(content)
    page.content = content

    page.empty = LC.Window:Text(content, "GameFontHighlight", contentWidth - 12)
    page.empty:SetPoint("TOPLEFT", 2, -8)
    page.empty:Hide()

    -- Right column: Drops.lua fills this container itself
    local dropsColumn = CreateFrame("Frame", "LootCheckGraphFrameDrops", page)
    dropsColumn:SetPoint("TOPLEFT", page.subtitle, "BOTTOMLEFT", leftWidth + GAP, -8) -- moved by Layout
    dropsColumn:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -MARGIN, 18)
    page.dropsColumn = dropsColumn
    LC.Drops:BuildPanel(dropsColumn)
end

local function GetRow(index)
    if rows[index] then return rows[index] end

    local row = CreateFrame("Frame", nil, frame.content)
    row:SetSize(contentWidth, ROW_HEIGHT)
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
    row.track:SetSize(barMax, ROW_HEIGHT - 8)
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
-- Layout
------------------------------------------------------------------------------

--- Split the page between the bars and the drops list. Both have a floor, so
--- on a narrow window the drops column keeps enough room for its four columns
--- and the bars keep enough to be worth reading; below that the page simply
--- cannot go, which is what the window's minimum size is for.
function Graph:Layout(page, w, h)
    if not frame then return end

    local available = w - MARGIN * 2 - GAP
    leftWidth = math.max(MIN_LEFT, math.floor(available * 0.42))
    if available - leftWidth < MIN_DROPS then
        leftWidth = math.max(MIN_LEFT, available - MIN_DROPS)
    end

    contentWidth = leftWidth - 40
    barMax = math.max(60, math.floor((contentWidth - NAME_WIDTH - 70) * BAR_SHARE) + 60)

    local rightInset = w - MARGIN * 2 - leftWidth

    frame.subtitle:SetWidth(w - MARGIN * 2)

    frame.refresh:ClearAllPoints()
    frame.refresh:SetPoint("TOPRIGHT", frame.subtitle, "BOTTOMRIGHT", -rightInset, -7)

    frame.phaseLabel:ClearAllPoints()
    frame.phaseLabel:SetPoint("LEFT", frame.nextPhase, "RIGHT", 6, 0)
    frame.phaseLabel:SetPoint("RIGHT", page, "LEFT", MARGIN + leftWidth, 0)

    frame.header2:ClearAllPoints()
    frame.header2:SetPoint("LEFT", frame.header, "LEFT", NAME_WIDTH + 8, 0)
    frame.header2:SetPoint("RIGHT", page, "LEFT", MARGIN + leftWidth, 0)

    frame.inset:ClearAllPoints()
    frame.inset:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", -4, -4)
    frame.inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -MARGIN - rightInset, 18)

    frame.dropsColumn:ClearAllPoints()
    frame.dropsColumn:SetPoint("TOPLEFT", frame.subtitle, "BOTTOMLEFT", leftWidth + GAP, -8)
    frame.dropsColumn:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -MARGIN, 18)

    frame.content:SetWidth(contentWidth)
    frame.empty:SetWidth(contentWidth - 12)
    for _, row in ipairs(rows) do
        row:SetWidth(contentWidth)
        row.track:SetSize(barMax, ROW_HEIGHT - 8)
    end

    -- The drops column owns its own height, so hand it the room it now has
    if LC.Drops and LC.Drops.Layout then
        LC.Drops:Layout(h - 30)
    end

    self:Refresh()
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
        and ("Awarded: %s / tokens (all time)"):format(phase.key)
        or "Awarded: wishlist / tokens (all time)")

    for i, r in ipairs(list) do
        local row = GetRow(i)
        local cr, cg, cb = LC:ClassColor(r.class)

        row.name:SetText(r.displayName)
        row.name:SetTextColor(cr, cg, cb)

        local width = maxCount > 0 and (r.count / maxCount) * barMax or 0
        if width > 0 then
            row.bar:SetWidth(math.max(width, 2))
            row.bar:SetColorTexture(cr, cg, cb, 0.85)
            row.bar:Show()
        else
            row.bar:Hide()
        end

        -- items / tier tokens (all-time items)
        row.count:SetText(("%d |cff7f7f7f/|r |cffffd100%d|r |cffaaaaaa(%d)|r"):format(
            r.count, r.tokens or 0, r.history or 0))
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

    if (r.tokens or 0) > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(("%d tier token%s awarded:"):format(r.tokens, r.tokens == 1 and "" or "s"), 1, 0.82, 0)
        for _, item in ipairs(r.tokenItems or {}) do
            local when = (item.timestamp and item.timestamp > 0) and date("%Y-%m-%d", item.timestamp) or ""
            GameTooltip:AddDoubleLine(item.itemLink or item.itemName or "?", when, 1, 0.82, 0, 0.6, 0.6, 0.6)
        end
    else
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("No tier tokens awarded.", 0.7, 0.7, 0.7)
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
    -- Below this the two columns cannot both hold their contents
    minWidth = MIN_LEFT + MIN_DROPS + MARGIN * 2 + GAP,
    minHeight = 360,
    build = BuildPage,
    layout = function(page, w, h) Graph:Layout(page, w, h) end,
    onShow = function() Graph:Refresh() end,
})
