--[[
    LootCheck - Sheet.lua

    The character sheet: pick a raider and see what they want in each equipment
    slot, with the priority they gave it.

    This is not a page of its own. It is the popout column on the right of the
    Wishlist Awards page (Graph.lua), which owns the button that opens it and
    hands this module a container to fill, exactly as it does for Drops.lua.
    Keeping it there means a raider's sheet can be read next to their bar and
    the week's drops rather than instead of them.

    Working out an item's slot takes two routes:

      * Tier tokens are not equippable, so the client has no slot for them.
        Their name says it though - "Pauldrons of the Fallen Defender" is a
        shoulder - and the token names come from TierTokens.lua, so this is
        exact rather than a guess.
      * Everything else asks the client, which only knows about items it has
        cached. Uncached items are requested and the panel redraws when the
        data arrives (GET_ITEM_INFO_RECEIVED); until then they sit under
        "Slot not known yet" rather than being dropped.
]]

local LC = LootCheck
local Sheet = {}
LC.Sheet = Sheet

local PAGE = "graph" -- the page the panel lives on
local ROW_HEIGHT, ROWS, HEAD_HEIGHT = 18, 21, 14
local RESERVED = 52 -- picker row, column headings and padding
local SLOT_WIDTH, PRIO_WIDTH = 92, 44
local PICKER_WIDTH = 150

local panel -- the container Graph.lua hands us
local rows = {}
Sheet._rows = rows -- exposed for tests
Sheet.rowCount = ROWS -- recalculated from the container height, see Layout

--- Character sheet order, not alphabetical: this is meant to be read like the
--- paper doll, so a missing head slot is obvious at a glance.
Sheet.SLOTS = {
    { key = "head", label = "Head" },
    { key = "neck", label = "Neck" },
    { key = "shoulder", label = "Shoulder" },
    { key = "back", label = "Back" },
    { key = "chest", label = "Chest" },
    { key = "wrist", label = "Wrist" },
    { key = "hands", label = "Hands" },
    { key = "waist", label = "Waist" },
    { key = "legs", label = "Legs" },
    { key = "feet", label = "Feet" },
    { key = "finger", label = "Rings" },
    { key = "trinket", label = "Trinkets" },
    { key = "mainhand", label = "Main hand" },
    { key = "offhand", label = "Off hand" },
    { key = "ranged", label = "Ranged / Relic" },
    { key = "unknown", label = "Slot not known yet" },
}

-- What the client calls each slot -> ours
local EQUIP_LOC = {
    INVTYPE_HEAD = "head",
    INVTYPE_NECK = "neck",
    INVTYPE_SHOULDER = "shoulder",
    INVTYPE_CLOAK = "back",
    INVTYPE_CHEST = "chest",
    INVTYPE_ROBE = "chest",
    INVTYPE_WRIST = "wrist",
    INVTYPE_HAND = "hands",
    INVTYPE_WAIST = "waist",
    INVTYPE_LEGS = "legs",
    INVTYPE_FEET = "feet",
    INVTYPE_FINGER = "finger",
    INVTYPE_TRINKET = "trinket",
    INVTYPE_WEAPON = "mainhand",
    INVTYPE_2HWEAPON = "mainhand",
    INVTYPE_WEAPONMAINHAND = "mainhand",
    INVTYPE_WEAPONOFFHAND = "offhand",
    INVTYPE_SHIELD = "offhand",
    INVTYPE_HOLDABLE = "offhand",
    INVTYPE_RANGED = "ranged",
    INVTYPE_RANGEDRIGHT = "ranged",
    INVTYPE_THROWN = "ranged",
    INVTYPE_RELIC = "ranged",
}

-- Tier tokens are not equippable, so their name is the only slot they have
local TOKEN_SLOTS = {
    Helm = "head",
    Pauldrons = "shoulder",
    Chestguard = "chest",
    Bracers = "wrist",
    Gloves = "hands",
    Belt = "waist",
    Leggings = "legs",
    Boots = "feet",
}

local function Settings()
    LC.db = LC.db or LootCheckDB or {}
    LC.db.settings = LC.db.settings or {}
    return LC.db.settings
end

------------------------------------------------------------------------------
-- Slots
------------------------------------------------------------------------------

--- The equipment location the client has for an item, or nil when it has not
--- cached it yet. Shared with Drops:IsGear, which asks the same question for a
--- different reason.
---
--- itemEquipLoc is GetItemInfo's 9th return. Naming it by position in a pcall's
--- result list is one blank away from silently reading itemStackCount instead,
--- which is what happened here, so select() says which value is wanted rather
--- than leaving it to be counted.
function Sheet:EquipLocation(itemID)
    if type(GetItemInfo) ~= "function" then return nil end

    local ok, equipLoc = pcall(function() return select(9, GetItemInfo(itemID)) end)
    if ok and type(equipLoc) == "string" then return equipLoc end
    return nil
end

--- The slot an item belongs in, or "unknown" when the client cannot say yet.
function Sheet:SlotFor(itemID, itemName)
    local tokenName = LC:TokenName(itemID)
    if tokenName then
        -- "Pauldrons of the Fallen Defender" -> shoulder
        return TOKEN_SLOTS[tokenName:match("^(%a+)") or ""] or "unknown"
    end

    local equipLoc = self:EquipLocation(itemID)
    if equipLoc and EQUIP_LOC[equipLoc] then return EQUIP_LOC[equipLoc] end

    -- Names follow the same shape as the tokens often enough to be worth a try
    if type(itemName) == "string" then
        local first = itemName:match("^(%a+)")
        if first and TOKEN_SLOTS[first] then return TOKEN_SLOTS[first] end
    end

    return "unknown"
end

--- Ask the client to load anything it has not cached, so the panel fills in.
function Sheet:RequestUncached(itemIDs)
    if type(C_Item) ~= "table" or type(C_Item.RequestLoadItemDataByID) ~= "function" then return end
    for itemID in pairs(itemIDs) do
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
end

------------------------------------------------------------------------------
-- The list
------------------------------------------------------------------------------

--- Every raider in the wishlist data, for the picker
function Sheet:Characters()
    local list = {}
    for norm, r in pairs(LC.Data:Roster()) do
        tinsert(list, { value = norm, text = r.displayName or LC:Capitalize(norm), class = r.class })
    end
    table.sort(list, function(a, b) return tostring(a.text) < tostring(b.text) end)
    return list
end

function Sheet:Selected()
    local chosen = Settings().sheetCharacter
    local list = self:Characters()

    for _, entry in ipairs(list) do
        if entry.value == chosen then return chosen end
    end
    return list[1] and list[1].value or nil
end

function Sheet:Select(norm)
    Settings().sheetCharacter = norm
    self:RefreshIfShown()
end

--- One row per slot, plus one per wishlist entry in that slot. Slots with
--- nothing wanted still get a row, because an empty slot is information.
function Sheet:Rows(norm)
    if not norm then return {} end

    local wishlist = LC.Wishlist:ForCharacter(norm)
    local bySlot, uncached = {}, {}

    for _, entry in ipairs(wishlist) do
        local slot = self:SlotFor(entry.itemID, entry.name)
        if slot == "unknown" then uncached[entry.itemID] = true end
        bySlot[slot] = bySlot[slot] or {}
        tinsert(bySlot[slot], entry)
    end
    self:RequestUncached(uncached)

    local out = {}
    for _, slot in ipairs(self.SLOTS) do
        local entries = bySlot[slot.key]

        if entries then
            table.sort(entries, function(a, b)
                if a.prio ~= b.prio then return a.prio < b.prio end
                return tostring(a.name) < tostring(b.name)
            end)
            for i, entry in ipairs(entries) do
                tinsert(out, {
                    slot = slot.key,
                    -- The slot is named once and left blank on its other rows,
                    -- so a slot with three rings still reads as one slot
                    slotLabel = (i == 1) and slot.label or "",
                    entry = entry,
                })
            end
        elseif slot.key ~= "unknown" then
            tinsert(out, { slot = slot.key, slotLabel = slot.label, empty = true })
        end
    end

    return out
end

--- wanted, received - for the summary line
function Sheet:Summary(norm)
    local wanted, received = 0, 0
    for _, entry in ipairs(norm and LC.Wishlist:ForCharacter(norm) or {}) do
        wanted = wanted + 1
        if entry.received then received = received + 1 end
    end
    return wanted, received
end

------------------------------------------------------------------------------
-- The panel on the Wishlist Awards page
------------------------------------------------------------------------------

function Sheet:BuildPanel(container)
    panel = container

    local picker = LC.Window:CreateDropdown(container, "LootCheckSheetPicker", {
        width = PICKER_WIDTH,
        items = function() return Sheet:Characters() end,
        selected = function() return Sheet:Selected() end,
        onSelect = function(value) Sheet:Select(value) end,
        emptyText = "No wishlist data",
    })
    picker:SetPoint("TOPLEFT", 0, 0)
    container.picker = picker

    -- Right-aligned and bounded, so a raider with a long wishlist cannot push
    -- the count out through the edge of the column
    container.summary = LC.Window:Text(container, "GameFontHighlightSmall")
    container.summary:SetPoint("LEFT", picker, "RIGHT", 6, 0)
    container.summary:SetPoint("RIGHT", container, "RIGHT", -2, 0)
    container.summary:SetJustifyH("RIGHT")

    local inset = LC.Window:CreateInset(container, "LootCheckSheetInset")
    inset:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", -4, -6)
    inset:SetPoint("BOTTOMRIGHT", 0, 0)
    container.inset = inset

    local scroll = CreateFrame("ScrollFrame", "LootCheckSheetScroll", inset, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() Sheet:RefreshPanel() end)
    end)
    container.scroll = scroll

    local head = CreateFrame("Frame", nil, inset)
    head:SetHeight(HEAD_HEIGHT)
    head:SetPoint("TOPLEFT", 8, -5)
    head:SetPoint("RIGHT", inset, "RIGHT", -30, 0)

    head.slot = LC.Window:Text(head, "GameFontDisableSmall")
    head.slot:SetPoint("LEFT", head, "LEFT", 2, 0)
    head.slot:SetWidth(SLOT_WIDTH)
    head.slot:SetText("Slot")

    head.prio = LC.Window:Text(head, "GameFontDisableSmall")
    head.prio:SetPoint("RIGHT", head, "RIGHT", -2, 0)
    head.prio:SetWidth(PRIO_WIDTH)
    head.prio:SetJustifyH("RIGHT")
    head.prio:SetText("Rank")

    head.item = LC.Window:Text(head, "GameFontDisableSmall")
    head.item:SetPoint("LEFT", head.slot, "RIGHT", 6, 0)
    head.item:SetPoint("RIGHT", head.prio, "LEFT", -6, 0)
    head.item:SetText("Wishlist item")
    container.head = head

    container.rowParent = inset

    container.empty = LC.Window:Text(inset, "GameFontHighlight", 200)
    container.empty:SetPoint("TOPLEFT", 12, -12 - HEAD_HEIGHT)
    container.empty:SetPoint("RIGHT", inset, "RIGHT", -12, 0)
    container.empty:Hide()
end

local function GetRow(index)
    if rows[index] then return rows[index] end

    local inset = panel.rowParent
    local row = CreateFrame("Frame", nil, inset)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 8, -6 - HEAD_HEIGHT - (index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", inset, "RIGHT", -30, 0)
    row:EnableMouse(true)
    LC.Window:AddRowGuides(row)
    row:SetScript("OnEnter", function(self)
        -- Guides go up even on an empty slot, where there is no tooltip: the
        -- point is following the row across, not the item
        self:SetGuides(true)
        Sheet:ShowRowTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        self:SetGuides(false)
        GameTooltip:Hide()
    end)
    row:SetScript("OnMouseUp", function(self)
        if self.data and self.data.entry and HandleModifiedItemClick then
            local link = self.data.entry.itemLink
            if link then HandleModifiedItemClick(link) end
        end
    end)

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.04 or 0)

    row.slot = LC.Window:Text(row, "GameFontNormalSmall")
    row.slot:SetPoint("LEFT", 2, 0)
    row.slot:SetWidth(SLOT_WIDTH)

    row.prio = LC.Window:Text(row, "GameFontHighlightSmall")
    row.prio:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.prio:SetWidth(PRIO_WIDTH)
    row.prio:SetJustifyH("RIGHT")

    row.item = LC.Window:Text(row, "GameFontHighlightSmall")
    row.item:SetPoint("LEFT", row.slot, "RIGHT", 6, 0)
    row.item:SetPoint("RIGHT", row.prio, "LEFT", -6, 0)

    row:Hide()
    rows[index] = row
    return row
end

--- Fit as many slots as the column is now tall enough for
function Sheet:Layout(height)
    self.rowCount = LC.Window:RowCount((height or 0) - RESERVED, ROW_HEIGHT, 3)
    self:RefreshPanel()
end

local function ItemText(entry)
    local name = entry.name or ("item:" .. tostring(entry.itemID))
    local tags = {}
    if entry.os then tinsert(tags, "OS") end
    if entry.manual then tinsert(tags, "manual") end
    local suffix = (#tags > 0) and (" |cff7f7f7f(" .. table.concat(tags, ", ") .. ")|r") or ""

    -- Received items are greyed, exactly as they are on the tooltip
    if entry.received then
        return ("|cff%s%s|r%s"):format(LC.GREY, name, suffix)
    end
    return name .. suffix
end

function Sheet:RefreshPanel()
    if not panel then return end

    panel.picker:Refresh()
    local norm = self:Selected()
    local list = norm and self:Rows(norm) or {}
    self._rows_data = list

    -- The picker already names the raider, so this only has to say how much of
    -- their list is still outstanding
    if norm then
        local wanted, received = self:Summary(norm)
        panel.summary:SetText(("%d of %d received"):format(received, wanted))
    else
        panel.summary:SetText("")
    end

    FauxScrollFrame_Update(panel.scroll, #list, self.rowCount, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(panel.scroll) or 0

    for i = 1, self.rowCount do
        local data, row = list[offset + i], GetRow(i)
        if data then
            row.slot:SetText(data.slotLabel or "")
            if data.empty then
                row.item:SetText("|cff5f5f5f-|r")
                row.prio:SetText("")
            else
                row.item:SetText(ItemText(data.entry))
                local prio = data.entry.prio
                row.prio:SetText((prio and prio < 1000)
                    and ("|cffffd100#%d|r"):format(prio)
                    or "|cff7f7f7f?|r")
            end
            row.data = data
            row:Show()
        else
            row:SetGuides(false)
            row:Hide()
            row.data = nil
        end
    end

    -- A row hidden under the cursor never gets its OnLeave, so clear it here
    for i = self.rowCount + 1, #rows do
        rows[i]:SetGuides(false)
        rows[i]:Hide()
        rows[i].data = nil
    end

    if #list == 0 then
        panel.empty:SetText(norm
            and "This raider has no wishlist entries."
            or "No wishlist data. Go back and open Wishlist Data to paste a That's My BIS CSV export.")
        panel.empty:Show()
    else
        panel.empty:Hide()
    end
end

function Sheet:ShowRowTooltip(row)
    local data = row.data
    if not data or data.empty or not data.entry then return end

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if data.entry.itemID and GameTooltip.SetItemByID then
        pcall(GameTooltip.SetItemByID, GameTooltip, data.entry.itemID)
    else
        GameTooltip:AddLine(data.entry.name or "?")
    end
    GameTooltip:Show()
end

--- Only worth redrawing while the popout is actually on screen.
function Sheet:RefreshIfShown()
    if LC.Window and LC.Window:IsShowing(PAGE) and LC.Graph and LC.Graph:SheetOpen() then
        self:RefreshPanel()
    end
end

------------------------------------------------------------------------------
-- Getting to it
------------------------------------------------------------------------------

--- Open the wishlist graph with the character popout out, optionally on a
--- particular raider. There is no separate sheet page any more: the sheet is
--- read next to the bars and the week's drops.
function Sheet:Open(norm)
    if norm and norm ~= "" then Settings().sheetCharacter = norm end
    LC.Data:Invalidate()
    LC.Graph:Open()
    LC.Graph:SetSheetOpen(true)
end

function Sheet:Toggle(norm)
    -- Named raider: always open on them, even if the popout is already out
    if not norm and LC.Window:IsShowing(PAGE) and LC.Graph:SheetOpen() then
        LC.Window:Hide()
        return
    end
    self:Open(norm)
end

-- Item data arrives asynchronously, so a slot we could not name a moment ago
-- may be known now, and an item Drops could not tell was gear may be placed.
-- A wishlist can hold hundreds of items and the event fires once per item, so
-- redraws are coalesced rather than run for each one.
local pendingRedraw = false

local itemInfoFrame = CreateFrame("Frame")
itemInfoFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemInfoFrame:SetScript("OnEvent", function()
    if pendingRedraw or not (LC.Window and LC.Window:IsShowing(PAGE)) then return end

    local function redraw()
        if LC.Sheet then LC.Sheet:RefreshIfShown() end
        if LC.Drops then LC.Drops:RefreshIfShown() end
    end

    if C_Timer and C_Timer.After then
        pendingRedraw = true
        C_Timer.After(0.2, function()
            pendingRedraw = false
            redraw()
        end)
    else
        redraw()
    end
end)
