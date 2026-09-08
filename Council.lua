--[[
    LootCheck - Council.lua

    The "Loot Council" page: who else is running LootCheck and what version,
    so you can see at a glance whether the council is on the same build.

    Opening the page pings your group and your guild. Every client running
    LootCheck whispers back its version (see Comm.lua), and the replies fill
    the list in over the next second or two, which is why there is a Check
    again button and why an empty list right after opening means nothing yet.

    Only online players can answer, so the roster is your group plus the
    online half of your guild. Someone with no reply is shown as such rather
    than as "not installed": they may be loading, or their reply may still be
    in flight.
]]

local LC = LootCheck
local Council = {}
LC.Council = Council

local PAGE = "council"
local WIDTH, HEIGHT = 620, 500
local MARGIN = 22
local ROW_HEIGHT, ROWS, HEAD_HEIGHT = 20, 17, 14 -- ROWS at the natural height
local RESERVED = 96 -- subtitle, check box row, column headings and padding
local NAME_WIDTH, VERSION_WIDTH, WHERE_WIDTH = 150, 90, 96

-- How long after a ping to stop expecting more replies
Council.SETTLE = 3

local frame
local rows = {}
Council._rows = rows -- exposed for tests
Council.rowCount = ROWS -- recalculated from the window height, see Layout

local function Settings()
    LC.db = LC.db or LootCheckDB or {}
    LC.db.settings = LC.db.settings or {}
    return LC.db.settings
end

------------------------------------------------------------------------------
-- The list
------------------------------------------------------------------------------

--- Everyone who could be running LootCheck, with what they answered.
--- opts.everyone keeps players who have not replied.
function Council:List(opts)
    opts = opts or {}
    local peers = LC.Comm.peers or {}
    local mine = tostring(LC.version)
    local out = {}

    for _, member in ipairs(LC.Comm:PingableRoster()) do
        local peer = peers[member.norm]
        local entry = {
            name = member.name,
            norm = member.norm,
            class = member.class,
            where = member.where,
            version = peer and peer.version or nil,
            at = peer and peer.at or nil,
            incompatible = peer and peer.incompatible or nil,
        }

        if peer then
            local diff = LC.Comm:CompareVersions(peer.version, mine)
            entry.state = (diff < 0 and "behind") or (diff > 0 and "ahead") or "current"
            if peer.version == "?" then entry.state = "unknown" end
        else
            entry.state = "silent"
        end

        if peer or opts.everyone then tinsert(out, entry) end
    end

    -- Replies first, then the silent ones, each alphabetically
    table.sort(out, function(a, b)
        local aSilent, bSilent = a.state == "silent", b.state == "silent"
        if aSilent ~= bSilent then return bSilent end
        return tostring(a.name) < tostring(b.name)
    end)
    return out
end

--- Counts for the summary line: how many replied, and how many are behind.
function Council:Summary()
    local list = self:List({ everyone = true })
    local running, behind, silent = 0, 0, 0
    for _, entry in ipairs(list) do
        if entry.state == "silent" then
            silent = silent + 1
        else
            running = running + 1
            if entry.state == "behind" or entry.incompatible then behind = behind + 1 end
        end
    end
    return running, behind, silent, #list
end

local STATE_TEXT = {
    current = "|cff40c040up to date|r",
    behind = "|cffff4040out of date|r",
    ahead = "|cffffd100newer than yours|r",
    unknown = "|cff7f7f7fversion unknown|r",
    silent = "|cff5f5f5fno reply|r",
}

------------------------------------------------------------------------------
-- Page
------------------------------------------------------------------------------

local function BuildPage(page)
    frame = page

    page.subtitle = LC.Window:Text(page, "GameFontHighlightSmall", WIDTH - MARGIN * 2)
    page.subtitle:SetPoint("TOPLEFT", MARGIN, -6)
    page.subtitle:SetJustifyH("CENTER")

    local everyone = CreateFrame("CheckButton", "LootCheckCouncilFrameEveryone", page, "UICheckButtonTemplate")
    everyone:SetPoint("TOPLEFT", page.subtitle, "BOTTOMLEFT", -4, -6)
    everyone:SetSize(24, 24)
    everyone:SetScript("OnClick", function(self)
        Settings().councilShowEveryone = self:GetChecked() and true or false
        Council:Refresh()
    end)
    page.everyone = everyone

    local everyoneLabel = LC.Window:Text(page, "GameFontHighlight")
    everyoneLabel:SetPoint("LEFT", everyone, "RIGHT", 4, 0)
    everyoneLabel:SetPoint("RIGHT", page, "RIGHT", -MARGIN - 110, 0)
    everyoneLabel:SetText("Also show players who did not answer")

    local check = CreateFrame("Button", "LootCheckCouncilFrameCheck", page, "UIPanelButtonTemplate")
    check:SetSize(96, 22)
    check:SetPoint("TOPRIGHT", page.subtitle, "BOTTOMRIGHT", 0, -7)
    check:SetText("Check again")
    check:SetScript("OnClick", function() Council:Check() end)
    page.check = check

    local inset = LC.Window:CreateInset(page, "LootCheckCouncilFrameInset")
    inset:SetPoint("TOPLEFT", everyone, "BOTTOMLEFT", 4, -4)
    inset:SetPoint("BOTTOMRIGHT", -MARGIN, 18)
    page.inset = inset

    local scroll = CreateFrame("ScrollFrame", "LootCheckCouncilFrameScroll", inset, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() Council:Refresh() end)
    end)
    page.scroll = scroll

    -- Column headings, anchored like a row so they line up with it
    local head = CreateFrame("Frame", nil, inset)
    head:SetHeight(HEAD_HEIGHT)
    head:SetPoint("TOPLEFT", 8, -5)
    head:SetPoint("RIGHT", inset, "RIGHT", -30, 0)

    head.name = LC.Window:Text(head, "GameFontDisableSmall")
    head.name:SetPoint("LEFT", head, "LEFT", 2, 0)
    head.name:SetWidth(NAME_WIDTH)
    head.name:SetText("Player")

    head.version = LC.Window:Text(head, "GameFontDisableSmall")
    head.version:SetPoint("LEFT", head.name, "RIGHT", 6, 0)
    head.version:SetWidth(VERSION_WIDTH)
    head.version:SetText("Version")

    head.where = LC.Window:Text(head, "GameFontDisableSmall")
    head.where:SetPoint("LEFT", head.version, "RIGHT", 6, 0)
    head.where:SetWidth(WHERE_WIDTH)
    head.where:SetText("Seen in")

    head.state = LC.Window:Text(head, "GameFontDisableSmall")
    head.state:SetPoint("LEFT", head.where, "RIGHT", 6, 0)
    head.state:SetPoint("RIGHT", head, "RIGHT", -2, 0)
    head.state:SetText("Status")
    page.head = head

    page.rowParent = inset

    page.empty = LC.Window:Text(inset, "GameFontHighlight", WIDTH - MARGIN * 2 - 60)
    page.empty:SetPoint("TOPLEFT", 12, -12 - HEAD_HEIGHT)
    page.empty:SetPoint("RIGHT", inset, "RIGHT", -12, 0)
    page.empty:Hide()
end

--- Ask the group and the guild who is running LootCheck.
function Council:Check()
    local asked = LC.Comm and LC.Comm:PingAll() or 0
    self.lastCheck = GetServerTime and GetServerTime() or 0
    self.checking = asked > 0

    self:Refresh()

    -- Replies arrive over the next second or two; tidy the wording up after
    if asked > 0 and C_Timer and C_Timer.After then
        C_Timer.After(self.SETTLE, function()
            self.checking = false
            self:RefreshIfShown()
        end)
    else
        self.checking = false
    end

    return asked
end

--- Built on demand, so a taller window simply shows more of the roster.
local function GetRow(index)
    if rows[index] then return rows[index] end

    local inset = frame.rowParent
    local row = CreateFrame("Frame", nil, inset)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 8, -6 - HEAD_HEIGHT - (index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", inset, "RIGHT", -30, 0)

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.04 or 0)

    row.name = LC.Window:Text(row, "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 2, 0)
    row.name:SetWidth(NAME_WIDTH)

    row.version = LC.Window:Text(row, "GameFontHighlightSmall")
    row.version:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    row.version:SetWidth(VERSION_WIDTH)

    row.where = LC.Window:Text(row, "GameFontDisableSmall")
    row.where:SetPoint("LEFT", row.version, "RIGHT", 6, 0)
    row.where:SetWidth(WHERE_WIDTH)

    row.state = LC.Window:Text(row, "GameFontHighlightSmall")
    row.state:SetPoint("LEFT", row.where, "RIGHT", 6, 0)
    row.state:SetPoint("RIGHT", row, "RIGHT", -2, 0)

    row:Hide()
    rows[index] = row
    return row
end

function Council:Layout(page, w, h)
    self.rowCount = LC.Window:RowCount(h - RESERVED, ROW_HEIGHT, 3)
    if frame then
        frame.subtitle:SetWidth(w - MARGIN * 2)
        self:Refresh()
    end
end

function Council:Refresh()
    if not frame then return end

    local showEveryone = Settings().councilShowEveryone and true or false
    frame.everyone:SetChecked(showEveryone)

    local list = self:List({ everyone = showEveryone })
    self._list = list

    local running, behind, silent = self:Summary()
    local mine = tostring(LC.version)
    if self.checking then
        frame.subtitle:SetText(("You are on |cffffffffv%s|r - asking your group and guild..."):format(mine))
    elseif behind > 0 then
        frame.subtitle:SetText(("You are on |cffffffffv%s|r - %d running LootCheck, |cffff4040%d not up to date|r, %d did not answer"):format(
            mine, running, behind, silent))
    else
        frame.subtitle:SetText(("You are on |cffffffffv%s|r - %d running LootCheck, all up to date, %d did not answer"):format(
            mine, running, silent))
    end

    FauxScrollFrame_Update(frame.scroll, #list, self.rowCount, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(frame.scroll) or 0

    for i = 1, self.rowCount do
        local entry, row = list[offset + i], GetRow(i)
        if entry then
            row.name:SetText(("|cff%s%s|r"):format(LC:ClassHex(entry.class), tostring(entry.name)))
            row.version:SetText(entry.version and ("v" .. entry.version) or "|cff5f5f5f-|r")
            row.where:SetText(entry.where)
            row.state:SetText(entry.incompatible
                and "|cffff4040cannot sync|r"
                or (STATE_TEXT[entry.state] or entry.state))
            row.data = entry
            row:Show()
        else
            row:Hide()
            row.data = nil
        end
    end

    for i = self.rowCount + 1, #rows do
        rows[i]:Hide()
        rows[i].data = nil
    end

    if #list == 0 then
        if not (LC.Comm and LC.Comm:Available()) then
            frame.empty:SetText("Sync is unavailable, so LootCheck cannot ask anyone.")
        elseif #LC.Comm:PingableRoster() == 0 then
            frame.empty:SetText("You are not in a group, and nobody in your guild is online.")
        elseif self.checking then
            frame.empty:SetText("Asking...")
        else
            frame.empty:SetText("Nobody answered. Tick the box above to see who was asked.")
        end
        frame.empty:Show()
    else
        frame.empty:Hide()
    end
end

function Council:RefreshIfShown()
    if LC.Window and LC.Window:IsShowing(PAGE) then self:Refresh() end
end

function Council:Open()
    LC.Window:Show(PAGE)
end

function Council:Toggle()
    if LC.Window:IsShowing(PAGE) then
        LC.Window:Hide()
    else
        self:Open()
    end
end

LC.Window:RegisterPage(PAGE, {
    title = "LootCheck - Loot Council",
    frameName = "LootCheckCouncilFrame",
    width = WIDTH,
    height = HEIGHT,
    minWidth = 520,
    build = BuildPage,
    layout = function(page, w, h) Council:Layout(page, w, h) end,
    -- Opening the page asks; the list fills in as replies arrive
    onShow = function() Council:Check() end,
})
