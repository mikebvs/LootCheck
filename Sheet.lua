--[[
    LootCheck - Sheet.lua

    The "Character Sheet" page: pick a raider from the wishlist data and see
    what they want in each equipment slot, with the priority they gave it.

    Working out an item's slot takes two routes:

      * Tier tokens are not equippable, so the client has no slot for them.
        Their name says it though - "Pauldrons of the Fallen Defender" is a
        shoulder - and the token names come from TierTokens.lua, so this is
        exact rather than a guess.
      * Everything else asks the client, which only knows about items it has
        cached. Uncached items are requested and the page redraws when the
        data arrives (GET_ITEM_INFO_RECEIVED); until then they sit under
        "Slot not known yet" rather than being dropped.
]]

local LC = LootCheck
local Sheet = {}
LC.Sheet = Sheet

local PAGE = "sheet"
local WIDTH, HEIGHT = 640, 560
local MARGIN = 22
local ROW_HEIGHT, ROWS, HEAD_HEIGHT = 18, 22, 14
local RESERVED = 92
local SLOT_WIDTH, PRIO_WIDTH = 96, 74

local frame
local rows = {}
Sheet._rows = rows -- exposed for tests
Sheet.rowCount = ROWS

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

--- The slot an item belongs in, or "unknown" when the client cannot say yet.
function Sheet:SlotFor(itemID, itemName)
    local tokenName = LC:TokenName(itemID)
    if tokenName then
        -- "Pauldrons of the Fallen Defender" -> shoulder
        return TOKEN_SLOTS[tokenName:match("^(%a+)") or ""] or "unknown"
    end

    if type(GetItemInfo) == "function" then
        local ok, _, _, _, _, _, _, _, equipLoc = pcall(GetItemInfo, itemID)
        if ok and type(equipLoc) == "string" and EQUIP_LOC[equipLoc] then
            return EQUIP_LOC[equipLoc]
        end
    end

    -- Names follow the same shape as the tokens often enough to be worth a try
    if type(itemName) == "string" then
        local first = itemName:match("^(%a+)")
        if first and TOKEN_SLOTS[first] then return TOKEN_SLOTS[first] end
    end

    return "unknown"
end

--- Ask the client to load anything it has not cached, so the page fills in.
local function RequestUncached(itemIDs)
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
    RequestUncached(uncached)

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
-- Page
------------------------------------------------------------------------------

local function BuildPage(page)
    frame = page

    local picker = LC.Window:CreateDropdown(page, "LootCheckSheetFramePicker", {
        width = 168,
        items = function() return Sheet:Characters() end,
        selected = function() return Sheet:Selected() end,
        onSelect = function(value) Sheet:Select(value) end,
        emptyText = "No wishlist data",
    })
    picker:SetPoint("TOPLEFT", MARGIN, -6)
    page.picker = picker

    page.summary = LC.Window:Text(page, "GameFontHighlightSmall")
    page.summary:SetPoint("LEFT", picker, "RIGHT", 10, 0)
    page.summary:SetPoint("RIGHT", page, "RIGHT", -MARGIN, 0)

    local inset = LC.Window:CreateInset(page, "LootCheckSheetFrameInset")
    inset:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", -4, -6)
    inset:SetPoint("BOTTOMRIGHT", -MARGIN, 18)
    page.inset = inset

    local scroll = CreateFrame("ScrollFrame", "LootCheckSheetFrameScroll", inset, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() Sheet:Refresh() end)
    end)
    page.scroll = scroll

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
    row:SetScript("OnEnter", function(self) Sheet:ShowRowTooltip(self) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
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

function Sheet:Layout(page, w, h)
    self.rowCount = LC.Window:RowCount(h - RESERVED, ROW_HEIGHT, 3)
    self:Refresh()
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

function Sheet:Refresh()
    if not frame then return end

    frame.picker:Refresh()
    local norm = self:Selected()
    local list = norm and self:Rows(norm) or {}
    self._rows_data = list

    if norm then
        local wanted, received = self:Summary(norm)
        local roster = LC.Data:Roster()[norm]
        frame.summary:SetText(("|cff%s%s|r - %d wishlist entries, %d received"):format(
            LC:ClassHex(roster and roster.class), (roster and roster.displayName) or LC:Capitalize(norm),
            wanted, received))
    else
        frame.summary:SetText("")
    end

    FauxScrollFrame_Update(frame.scroll, #list, self.rowCount, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(frame.scroll) or 0

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
            row:Hide()
            row.data = nil
        end
    end

    for i = self.rowCount + 1, #rows do
        rows[i]:Hide()
        rows[i].data = nil
    end

    if #list == 0 then
        frame.empty:SetText(norm
            and "This raider has no wishlist entries."
            or "No wishlist data. Go back and open Wishlist Data to paste a That's My BIS CSV export.")
        frame.empty:Show()
    else
        frame.empty:Hide()
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

function Sheet:RefreshIfShown()
    if LC.Window and LC.Window:IsShowing(PAGE) then self:Refresh() end
end

--- Open the page, optionally on a particular raider
function Sheet:Open(norm)
    if norm and norm ~= "" then Settings().sheetCharacter = norm end
    LC.Data:Invalidate()
    LC.Window:Show(PAGE)
end

function Sheet:Toggle(norm)
    if LC.Window:IsShowing(PAGE) and not norm then
        LC.Window:Hide()
    else
        self:Open(norm)
    end
end

-- Item data arrives asynchronously, so a slot we could not name a moment ago
-- may be known now
local itemInfoFrame = CreateFrame("Frame")
itemInfoFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemInfoFrame:SetScript("OnEvent", function()
    if LC.Sheet then LC.Sheet:RefreshIfShown() end
end)

LC.Window:RegisterPage(PAGE, {
    title = "LootCheck - Character Sheet",
    frameName = "LootCheckSheetFrame",
    width = WIDTH,
    height = HEIGHT,
    build = BuildPage,
    layout = function(page, w, h) Sheet:Layout(page, w, h) end,
    onShow = function() Sheet:Refresh() end,
})
