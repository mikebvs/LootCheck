--[[
    LootCheck - Audit.lua

    The Audit page: every item award in chronological order, newest first -
    Gargul awards (including plain MS / OS roll wins), manual received marks
    (/lchelp giveitem) and the manual-edit commands you ran (giveitem,
    removeitem, addwlitem, removewlitem). A check box hides awards whose item
    was not on the winner's wishlist.

    Command entries are kept in LootCheckDB.auditLog (capped at MAX_LOG).
]]

local LC = LootCheck
local Audit = {}
LC.Audit = Audit

local PAGE = "audit"
local WIDTH, HEIGHT = 680, 540
local MARGIN = 22
local ROW_HEIGHT, ROWS = 20, 20
local TIME_WIDTH = 92
local DAY = 86400

Audit.MAX_LOG = 500

--- The time ranges the dropdown offers. "This phase" and "Last phase" are the
--- dated content phases from Phases.lua, not the graph's wishlist-relative
--- count, which is a different thing entirely.
Audit.RANGES = {
    { value = "week", text = "Past week" },
    { value = "month", text = "Past month" },
    { value = "phase", text = "This phase" },
    { value = "lastphase", text = "Last phase" },
    { value = "all", text = "All" },
}

local frame
local rows = {}
Audit._rows = rows -- exposed for tests

local function Log()
    LC.db = LC.db or LootCheckDB or {}
    if type(LC.db.auditLog) ~= "table" then LC.db.auditLog = {} end
    return LC.db.auditLog
end

local function Settings()
    LC.db = LC.db or LootCheckDB or {}
    LC.db.settings = LC.db.settings or {}
    return LC.db.settings
end

------------------------------------------------------------------------------
-- Command log (written by Awards.lua / Wishlist.lua)
------------------------------------------------------------------------------

--- info = { norm, character, itemID, itemName, itemLink, detail }
function Audit:Log(cmd, info)
    local log = Log()
    tinsert(log, {
        t = GetServerTime and GetServerTime() or 0,
        cmd = cmd,
        norm = info.norm,
        character = info.character,
        itemID = info.itemID,
        itemName = info.itemName,
        itemLink = info.itemLink,
        detail = info.detail,
        from = info.from,
    })
    while #log > self.MAX_LOG do
        table.remove(log, 1)
    end
    self:RefreshIfShown()
end

------------------------------------------------------------------------------
-- Time ranges
------------------------------------------------------------------------------

function Audit:Range()
    local value = Settings().auditRange
    for _, range in ipairs(self.RANGES) do
        if range.value == value then return value end
    end
    return "all"
end

function Audit:RangeText(value)
    for _, range in ipairs(self.RANGES) do
        if range.value == value then return range.text end
    end
    return "All"
end

--- from (inclusive), to (exclusive) for a range. Both nil means everything.
--- The phase ranges follow whatever dates are set, so a phase whose date you
--- corrected with /lchelp phase moves this list with it.
function Audit:RangeBounds(value)
    value = value or self:Range()
    local now = GetServerTime and GetServerTime() or 0

    if value == "week" then
        return now - 7 * DAY, nil
    elseif value == "month" then
        return now - 30 * DAY, nil
    elseif value == "phase" then
        local current = LC.Phases and LC.Phases:Current()
        if current then return LC.Phases:Bounds(current.key) end
        return nil, nil
    elseif value == "lastphase" then
        local list = LC.Phases and LC.Phases:List() or {}
        local current = LC.Phases and LC.Phases:Current()
        if not current then return nil, nil end

        local previous
        for _, phase in ipairs(list) do
            if phase.key == current.key then break end
            if phase.announced then previous = phase end
        end
        -- Before the second phase started there is no "last phase" to show
        if not previous then return math.huge, nil end
        return LC.Phases:Bounds(previous.key)
    end

    return nil, nil
end

------------------------------------------------------------------------------
-- Entries
------------------------------------------------------------------------------

--- Newest first. opts.wishlistOnly drops awards whose item was not on the winner's wishlist.
--- award entry:   { kind = "award", t, norm, display, classHex, itemID, itemLink, itemName, OS, wishlisted, hidden, manual }
--- command entry: { kind = "command", t, cmd, norm, display, classHex, itemLink, itemName, detail }
function Audit:Entries(opts)
    opts = opts or {}
    local entries = {}
    local roster = LC.Data:Roster()
    local wish = LC.Data:WishlistIndex()

    -- Awards that ever matched a wishlist (LootCheck's log + Gargul's WL stamps), see Data:History
    local everWishlisted = {}
    for _, h in pairs(LC.Data:History()) do
        for _, item in ipairs(h.items) do
            if item.checksum then everWishlisted[item.checksum] = true end
        end
    end

    local function isWishlisted(checksum, norm, itemID, WL)
        if everWishlisted[checksum] or WL then return true end
        local players = wish[itemID]
        return players ~= nil and players[norm] ~= nil
    end

    local function classHex(norm)
        local r = roster[norm]
        return LC:ClassHex(r and r.class)
    end

    local GL = LC:Gargul()
    local history = GL and GL.DB and GL.DB.AwardHistory
    if type(history) == "table" then
        for checksum, loot in pairs(history) do
            if type(loot) == "table" then
                local itemID = tonumber(loot.itemID) or LC:ItemIDFromLink(loot.itemLink)
                local norm = LC:NormalizeName(loot.awardedTo)
                if itemID and norm ~= "" then
                    tinsert(entries, {
                        kind = "award",
                        t = tonumber(loot.timestamp) or 0,
                        norm = norm,
                        display = (roster[norm] and roster[norm].displayName) or LC:Capitalize(norm),
                        classHex = classHex(norm),
                        itemID = itemID,
                        itemLink = loot.itemLink,
                        itemName = (type(loot.itemLink) == "string" and loot.itemLink:match("%[(.-)%]")) or ("item:" .. itemID),
                        OS = loot.OS and true or false,
                        wishlisted = isWishlisted(checksum, norm, itemID, loot.WL),
                        hidden = LC.Awards and LC.Awards:IsIgnored(checksum) or false,
                        manual = false,
                    })
                end
            end
        end
    end

    if LC.Awards then
        for id, m in pairs(LC.Awards:Manual()) do
            local norm = m.norm or LC:NormalizeName(m.character)
            tinsert(entries, {
                kind = "award",
                t = tonumber(m.timestamp) or 0,
                norm = norm,
                display = m.character or LC:Capitalize(norm),
                classHex = classHex(norm),
                itemID = m.itemID,
                itemLink = m.itemLink,
                itemName = m.itemName,
                OS = m.OS and true or false,
                wishlisted = isWishlisted(id, norm, m.itemID, false),
                hidden = false,
                manual = true,
            })
        end
    end

    for _, c in ipairs(Log()) do
        tinsert(entries, {
            kind = "command",
            t = tonumber(c.t) or 0,
            cmd = c.cmd,
            norm = c.norm,
            display = c.character or LC:Capitalize(c.norm or "?"),
            classHex = classHex(c.norm or ""),
            itemLink = c.itemLink,
            itemName = c.itemName,
            detail = c.detail,
            from = c.from,
        })
    end

    if opts.wishlistOnly then
        local kept = {}
        for _, e in ipairs(entries) do
            if e.kind ~= "award" or e.wishlisted then tinsert(kept, e) end
        end
        entries = kept
    end

    if opts.from or opts.to then
        local from, to = opts.from or 0, opts.to
        local kept = {}
        for _, e in ipairs(entries) do
            local t = e.t or 0
            if t >= from and (not to or t < to) then tinsert(kept, e) end
        end
        entries = kept
    end

    table.sort(entries, function(a, b)
        if a.t ~= b.t then return a.t > b.t end
        return tostring(a.itemName) < tostring(b.itemName)
    end)
    return entries
end

local function RowText(e)
    local who = ("|cff%s%s|r"):format(e.classHex or "FFFFFF", tostring(e.display or "?"))
    local item = e.itemLink or e.itemName or "?"

    if e.kind == "command" then
        return ("|cff33ccff/lchelp %s|r %s %s%s%s"):format(
            tostring(e.cmd), who, item,
            e.detail and (" |cffaaaaaa" .. e.detail .. "|r") or "",
            e.from and (" |cff9999ff(from %s)|r"):format(e.from) or "")
    end

    local tags = { e.OS and "OS" or "MS" }
    if not e.wishlisted then tinsert(tags, "not on wishlist") end
    if e.manual then tinsert(tags, "manual mark") end
    if e.hidden then tinsert(tags, "hidden") end
    return ("%s received %s |cffaaaaaa(%s)|r"):format(who, item, table.concat(tags, ", "))
end

------------------------------------------------------------------------------
-- Page
------------------------------------------------------------------------------

local function BuildPage(page)
    frame = page

    -- Time range, as a plain-frame dropdown (Window:CreateDropdown explains why
    -- Blizzard's UIDropDownMenu is off limits here)
    local range = LC.Window:CreateDropdown(page, "LootCheckAuditFrameRange", {
        width = 132,
        items = function() return Audit.RANGES end,
        selected = function() return Audit:Range() end,
        onSelect = function(value)
            Settings().auditRange = value
            Audit:Refresh()
        end,
    })
    range:SetPoint("TOPLEFT", MARGIN, -6)
    page.range = range

    page.count = LC.Window:Text(page, "GameFontHighlightSmall")
    page.count:SetPoint("RIGHT", page, "RIGHT", -MARGIN - 4, 0)
    page.count:SetPoint("TOP", range, "TOP", 0, -4)
    page.count:SetJustifyH("RIGHT")

    local box = CreateFrame("CheckButton", "LootCheckAuditFrameWishlistOnly", page, "UICheckButtonTemplate")
    box:SetPoint("TOPLEFT", range, "BOTTOMLEFT", -4, -2)
    box:SetSize(24, 24)
    box:SetScript("OnClick", function(self)
        Settings().auditWishlistOnly = self:GetChecked() and true or false
        Audit:Refresh()
    end)

    -- Bounded on the right so a longer label cannot run off the page
    local label = LC.Window:Text(page, "GameFontHighlight")
    label:SetPoint("LEFT", box, "RIGHT", 4, 0)
    label:SetPoint("RIGHT", page, "RIGHT", -MARGIN, 0)
    label:SetText("Hide awards that were not on the winner's wishlist")
    page.wishlistOnly = box
    page.wishlistOnlyLabel = label

    -- The list sits on a dark inset so it reads as a panel of its own
    local list = LC.Window:CreateInset(page, "LootCheckAuditFrameInset")
    list:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 4, -4)
    list:SetPoint("BOTTOMRIGHT", -MARGIN, 18)
    page.list = list

    local scroll = CreateFrame("ScrollFrame", "LootCheckAuditFrameScroll", list, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() Audit:Refresh() end)
    end)
    page.scroll = scroll

    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, list)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 8, -8 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", list, "RIGHT", -30, 0)

        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)

        row.time = LC.Window:Text(row, "GameFontDisableSmall")
        row.time:SetPoint("LEFT", 2, 0)
        row.time:SetWidth(TIME_WIDTH)

        -- One line per entry: long item names are truncated, never wrapped
        row.text = LC.Window:Text(row, "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row.time, "RIGHT", 8, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)

        row:Hide()
        rows[i] = row
    end

    page.empty = LC.Window:Text(list, "GameFontHighlight", WIDTH - MARGIN * 2 - 40)
    page.empty:SetPoint("TOPLEFT", 12, -12)
    page.empty:SetText("Nothing to show yet.")
    page.empty:Hide()
end

function Audit:Refresh()
    if not frame then return end

    local s = Settings()
    frame.wishlistOnly:SetChecked(s.auditWishlistOnly and true or false)
    frame.range:Refresh()

    local range = self:Range()
    local from, to = self:RangeBounds(range)
    local entries = self:Entries({ wishlistOnly = s.auditWishlistOnly, from = from, to = to })
    self._entries = entries

    FauxScrollFrame_Update(frame.scroll, #entries, ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(frame.scroll) or 0

    for i = 1, ROWS do
        local e = entries[offset + i]
        local row = rows[i]
        if e then
            row.time:SetText(e.t > 0 and date("%Y-%m-%d %H:%M", e.t) or "?")
            row.text:SetText(RowText(e))
            row:Show()
        else
            row:Hide()
        end
    end

    frame.count:SetText(("%d entries |cff7f7f7f(%s)|r"):format(#entries, self:RangeText(range):lower()))

    if #entries == 0 then
        frame.empty:SetText(range == "all"
            and "Nothing to show yet."
            or ("Nothing in the %s. Change the range above to look further back."):format(self:RangeText(range):lower()))
        frame.empty:Show()
    else
        frame.empty:Hide()
    end
end

function Audit:RefreshIfShown()
    if LC.Window and LC.Window:IsShowing(PAGE) then self:Refresh() end
end

function Audit:Open()
    LC.Data:Invalidate()
    LC.Window:Show(PAGE)
end

function Audit:Toggle()
    if LC.Window:IsShowing(PAGE) then
        LC.Window:Hide()
    else
        self:Open()
    end
end

LC.Window:RegisterPage(PAGE, {
    title = "LootCheck - Audit",
    frameName = "LootCheckAuditFrame",
    width = WIDTH,
    height = HEIGHT,
    build = BuildPage,
    onShow = function() Audit:Refresh() end,
})
