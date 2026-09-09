--[[
    LootCheck - Contested.lua

    The "Contested Items" page: every item anyone has wishlisted, with how many
    raiders want it, so the items several people are waiting on stand out
    before the raid rather than during it.

    Two numbers per item, because they answer different questions:

      * wanted    - how many raiders have it on their wishlist at all
      * still     - how many of those have not received it yet

    The list is ordered by the second one. An item six people wishlisted but
    five already hold is not contested any more, and sorting by the raw total
    would keep it at the top all phase.
]]

local LC = LootCheck
local Contested = {}
LC.Contested = Contested

local PAGE = "contested"
local WIDTH, HEIGHT = 660, 560
local MARGIN = 22
local ROW_HEIGHT, ROWS, HEAD_HEIGHT = 18, 22, 14
local RESERVED = 92
local WANTED_WIDTH, STILL_WIDTH = 70, 88

local frame
local rows = {}
Contested._rows = rows -- exposed for tests
Contested.rowCount = ROWS

local function Settings()
    LC.db = LC.db or LootCheckDB or {}
    LC.db.settings = LC.db.settings or {}
    return LC.db.settings
end

------------------------------------------------------------------------------
-- The list
------------------------------------------------------------------------------

--- One row per wishlisted item:
---   { itemID, itemName, wanted, still, wanters = { { norm, displayName, class, prio, os, received } } }
--- opts.groupOnly counts only raiders who are in your group right now.
function Contested:Rows(opts)
    opts = opts or {}
    local group = opts.groupOnly and LC.Data:GroupMembers() or nil
    local includeOS = Settings().greyOSAwards ~= false
    local roster = LC.Data:Roster()
    local out = {}

    for itemID, players in pairs(LC.Data:WishlistIndex()) do
        local awards = LC.Data:AwardsForItem(itemID)
        local wanters, still, itemName = {}, 0, nil

        for norm, p in pairs(players) do
            if not group or group[norm] then
                -- A raider counts once however many entries they have for the
                -- item; they have it when they have received as many as they
                -- asked for, so a double ring wish needs two rings to settle
                local receivedCount = LC.Data:ReceivedCount(awards, norm, includeOS)
                local received = receivedCount >= #p.entries

                local anyMainSpec = p.mainSpec > 0
                tinsert(wanters, {
                    norm = norm,
                    displayName = p.displayName or LC:Capitalize(norm),
                    class = roster[norm] and roster[norm].class,
                    prio = p.bestPrio,
                    os = not anyMainSpec,
                    received = received,
                })
                if not received then still = still + 1 end
                itemName = itemName or p.itemName
            end
        end

        if #wanters > 0 then
            table.sort(wanters, function(a, b)
                if a.received ~= b.received then return b.received end
                if (a.prio or 999) ~= (b.prio or 999) then return (a.prio or 999) < (b.prio or 999) end
                return tostring(a.displayName) < tostring(b.displayName)
            end)

            tinsert(out, {
                itemID = itemID,
                itemName = itemName or (LC.Wishlist and LC.Wishlist:ItemName(itemID)) or ("item:" .. itemID),
                wanted = #wanters,
                still = still,
                wanters = wanters,
            })
        end
    end

    -- Live contention first: what is still being fought over
    table.sort(out, function(a, b)
        if a.still ~= b.still then return a.still > b.still end
        if a.wanted ~= b.wanted then return a.wanted > b.wanted end
        return tostring(a.itemName) < tostring(b.itemName)
    end)
    return out
end

------------------------------------------------------------------------------
-- Page
------------------------------------------------------------------------------

local function BuildPage(page)
    frame = page

    page.subtitle = LC.Window:Text(page, "GameFontHighlightSmall", WIDTH - MARGIN * 2)
    page.subtitle:SetPoint("TOPLEFT", MARGIN, -6)
    page.subtitle:SetJustifyH("CENTER")

    local groupOnly = CreateFrame("CheckButton", "LootCheckContestedFrameGroupOnly", page, "UICheckButtonTemplate")
    groupOnly:SetPoint("TOPLEFT", page.subtitle, "BOTTOMLEFT", -4, -6)
    groupOnly:SetSize(24, 24)
    groupOnly:SetScript("OnClick", function(self)
        Settings().contestedGroupOnly = self:GetChecked() and true or false
        Contested:Refresh()
    end)
    page.groupOnly = groupOnly

    local groupLabel = LC.Window:Text(page, "GameFontHighlight")
    groupLabel:SetPoint("LEFT", groupOnly, "RIGHT", 4, 0)
    groupLabel:SetPoint("RIGHT", page, "RIGHT", -MARGIN, 0)
    groupLabel:SetText("Only count raiders in my current group")

    local inset = LC.Window:CreateInset(page, "LootCheckContestedFrameInset")
    inset:SetPoint("TOPLEFT", groupOnly, "BOTTOMLEFT", 4, -4)
    inset:SetPoint("BOTTOMRIGHT", -MARGIN, 18)
    page.inset = inset

    local scroll = CreateFrame("ScrollFrame", "LootCheckContestedFrameScroll", inset, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() Contested:Refresh() end)
    end)
    page.scroll = scroll

    local head = CreateFrame("Frame", nil, inset)
    head:SetHeight(HEAD_HEIGHT)
    head:SetPoint("TOPLEFT", 8, -5)
    head:SetPoint("RIGHT", inset, "RIGHT", -30, 0)

    head.still = LC.Window:Text(head, "GameFontDisableSmall")
    head.still:SetPoint("RIGHT", head, "RIGHT", -2, 0)
    head.still:SetWidth(STILL_WIDTH)
    head.still:SetJustifyH("RIGHT")
    head.still:SetText("Still want")

    head.wanted = LC.Window:Text(head, "GameFontDisableSmall")
    head.wanted:SetPoint("RIGHT", head.still, "LEFT", -6, 0)
    head.wanted:SetWidth(WANTED_WIDTH)
    head.wanted:SetJustifyH("RIGHT")
    head.wanted:SetText("Wanted by")

    head.item = LC.Window:Text(head, "GameFontDisableSmall")
    head.item:SetPoint("LEFT", head, "LEFT", 2, 0)
    head.item:SetPoint("RIGHT", head.wanted, "LEFT", -6, 0)
    head.item:SetText("Item")
    page.head = head

    page.rowParent = inset

    page.empty = LC.Window:Text(inset, "GameFontHighlight", WIDTH - MARGIN * 2 - 60)
    page.empty:SetPoint("TOPLEFT", 12, -12 - HEAD_HEIGHT)
    page.empty:SetPoint("RIGHT", inset, "RIGHT", -12, 0)
    page.empty:Hide()
end

local function GetRow(index)
    if rows[index] then return rows[index] end

    local inset = frame.rowParent
    local row = CreateFrame("Frame", nil, inset)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 8, -6 - HEAD_HEIGHT - (index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", inset, "RIGHT", -30, 0)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) Contested:ShowRowTooltip(self) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.04 or 0)

    row.still = LC.Window:Text(row, "GameFontHighlightSmall")
    row.still:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.still:SetWidth(STILL_WIDTH)
    row.still:SetJustifyH("RIGHT")

    row.wanted = LC.Window:Text(row, "GameFontHighlightSmall")
    row.wanted:SetPoint("RIGHT", row.still, "LEFT", -6, 0)
    row.wanted:SetWidth(WANTED_WIDTH)
    row.wanted:SetJustifyH("RIGHT")

    row.item = LC.Window:Text(row, "GameFontHighlightSmall")
    row.item:SetPoint("LEFT", 2, 0)
    row.item:SetPoint("RIGHT", row.wanted, "LEFT", -6, 0)

    row:Hide()
    rows[index] = row
    return row
end

function Contested:Layout(page, w, h)
    self.rowCount = LC.Window:RowCount(h - RESERVED, ROW_HEIGHT, 3)
    if frame then
        frame.subtitle:SetWidth(w - MARGIN * 2)
        self:Refresh()
    end
end

function Contested:Refresh()
    if not frame then return end

    local groupOnly = Settings().contestedGroupOnly and true or false
    frame.groupOnly:SetChecked(groupOnly)

    local list = self:Rows({ groupOnly = groupOnly })
    self._list = list

    local contested = 0
    for _, r in ipairs(list) do
        if r.still > 1 then contested = contested + 1 end
    end

    local data = LC:WishlistData()
    frame.subtitle:SetText(("%s%d wishlisted items, %d wanted by more than one raider%s"):format(
        data and (data.source .. ": ") or "", #list, contested,
        groupOnly and " (current group only)" or ""))

    FauxScrollFrame_Update(frame.scroll, #list, self.rowCount, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(frame.scroll) or 0

    for i = 1, self.rowCount do
        local r, row = list[offset + i], GetRow(i)
        if r then
            row.item:SetText(r.itemName)
            row.wanted:SetText(("|cffaaaaaa%d|r"):format(r.wanted))

            -- The colour carries the same message as the number, so the worst
            -- contention is findable without reading every row
            local colour = (r.still > 2 and "ff4040") or (r.still == 2 and "ffd100") or "7f7f7f"
            row.still:SetText(("|cff%s%d|r"):format(colour, r.still))

            row.data = r
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
        frame.empty:SetText(groupOnly
            and "Nobody in your current group has anything wishlisted in the active raid."
            or "No wishlist data. Go back and open Wishlist Data to paste a That's My BIS CSV export.")
        frame.empty:Show()
    else
        frame.empty:Hide()
    end
end

function Contested:ShowRowTooltip(row)
    local r = row.data
    if not r then return end

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if r.itemID and GameTooltip.SetItemByID then
        pcall(GameTooltip.SetItemByID, GameTooltip, r.itemID)
    else
        GameTooltip:AddLine(r.itemName or "?")
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(("Wanted by %d, %d still waiting:"):format(r.wanted, r.still), 1, 1, 1)

    for _, w in ipairs(r.wanters) do
        local label = w.displayName .. (w.os and " |cff7f7f7f(OS)|r" or "")
        local prio = w.prio and ("#" .. w.prio) or "?"
        if w.received then
            GameTooltip:AddDoubleLine(("|cff%s%s|r"):format(LC.GREY, label), "|cff5f5f5freceived|r")
        else
            local hex = LC:ClassHex(w.class)
            GameTooltip:AddDoubleLine(("|cff%s%s|r"):format(hex, label), ("|cffffd100%s|r"):format(prio))
        end
    end

    GameTooltip:Show()
end

function Contested:RefreshIfShown()
    if LC.Window and LC.Window:IsShowing(PAGE) then self:Refresh() end
end

function Contested:Open()
    LC.Data:Invalidate()
    LC.Window:Show(PAGE)
end

function Contested:Toggle()
    if LC.Window:IsShowing(PAGE) then
        LC.Window:Hide()
    else
        self:Open()
    end
end

LC.Window:RegisterPage(PAGE, {
    title = "LootCheck - Contested Items",
    frameName = "LootCheckContestedFrame",
    width = WIDTH,
    height = HEIGHT,
    build = BuildPage,
    layout = function(page, w, h) Contested:Layout(page, w, h) end,
    onShow = function() Contested:Refresh() end,
})
