--[[
    LootCheck - Imports.lua

    The "Wishlist Data" page: named That's My BIS CSV imports ("raids"). One of
    them is the ACTIVE wishlist - the one Gargul's TMB tooltip section, the
    graph and the manual edits work against.

        /lchelp imports          - open the page (active-raid dropdown, New import, Delete, Export)
        /lchelp use <raid name>  - switch the active raid from chat

    Stored in LootCheckDB.imports = {
        active = <id>,
        [<id>] = { id, name, importedAt, remapped,
                   entries = { <TMBExport-shaped rows> },
                   stats = { entries, characters, rosters, received } },
    }

    Export produces the active raid's EFFECTIVE dataset (imported rows minus
    manual removals, plus manual additions, tagged) as a CSV another LootCheck
    user can paste into New import; the "# LootCheck wishlist export" header
    line carries the name.

    While no import exists, LootCheck falls back to TMBExport's data if that
    addon is installed (see LC:WishlistData in Core.lua).

    The CSV parser is ported from TMBExport
    (MIT License, Copyright (c) 2026 Centpoursang - Spineshatter).
]]

local LC = LootCheck
local Imports = {}
LC.Imports = Imports

local PAGE = "imports"
local WIDTH, HEIGHT = 660, 480
local MARGIN = 22
local SEND_ROWS, SEND_ROW_HEIGHT = 9, 24

local frame -- the page

local function Store()
    LC.db = LC.db or LootCheckDB or {}
    if type(LC.db.imports) ~= "table" then LC.db.imports = {} end
    return LC.db.imports
end

local function Trim(s)
    return (tostring(s or ""):match("^%s*(.-)%s*$"))
end

local function Now()
    return GetServerTime and GetServerTime() or 0
end

local function Changed()
    LC.Data:Invalidate()
    if LC.Graph then LC.Graph:RefreshIfShown() end
    Imports:RefreshUI()
end

------------------------------------------------------------------------------
-- CSV parsing (That's My BIS export, or a LootCheck export)
------------------------------------------------------------------------------

--- Split one CSV line, honouring quoted fields ("a, b" and doubled "" quotes)
local function ParseCSVLine(line)
    local fields = {}
    local pos = 1
    local len = #line

    while pos <= len do
        if line:sub(pos, pos) == '"' then
            local value = ""
            pos = pos + 1
            local startPos = pos
            local closed = false
            while pos <= len do
                if line:sub(pos, pos) == '"' then
                    if pos + 1 <= len and line:sub(pos + 1, pos + 1) == '"' then
                        value = value .. line:sub(startPos, pos)
                        pos = pos + 2
                        startPos = pos
                    else
                        value = value .. line:sub(startPos, pos - 1)
                        pos = pos + 1
                        closed = true
                        if pos <= len and line:sub(pos, pos) == "," then
                            pos = pos + 1
                        end
                        break
                    end
                else
                    pos = pos + 1
                end
            end
            if not closed then
                value = value .. line:sub(startPos)
            end
            tinsert(fields, value)
        else
            local nextComma = line:find(",", pos, true)
            if nextComma then
                tinsert(fields, line:sub(pos, nextComma - 1))
                pos = nextComma + 1
            else
                tinsert(fields, line:sub(pos))
                pos = len + 1
            end
        end
    end

    if len > 0 and line:sub(len, len) == "," then
        tinsert(fields, "")
    end

    return fields
end

--- Returns entries (wishlist rows only, TMBExport-shaped), stats, headerLooksRight, meta
--- meta.name is set when the text is a LootCheck export ("# ... | name=... | ...")
function Imports:ParseCSV(csvText)
    local entries = {}
    local stats = { rows = 0, wishlist = 0, received = 0, other = 0 }
    local meta = {}
    local headers, headerSet

    for line in tostring(csvText or ""):gmatch("[^\r\n]+") do
        line = Trim(line)
        if line:sub(1, 1) == "#" then
            local name = line:match("name=%s*([^|]+)")
            if name and not meta.name then meta.name = Trim(name) end
            local share = line:match("share=%s*([^|%s]+)")
            if share and not meta.share then meta.share = Trim(share) end
        elseif line ~= "" then
            local fields = ParseCSVLine(line)

            if not headers then
                headers, headerSet = {}, {}
                for i, h in ipairs(fields) do
                    headers[i] = Trim(h):lower()
                    headerSet[headers[i]] = true
                end
            else
                stats.rows = stats.rows + 1
                local row = {}
                for i, h in ipairs(headers) do
                    row[h] = fields[i] and Trim(fields[i]) or ""
                end

                local rowType = (row["type"] or ""):lower()
                if rowType == "wishlist" then
                    stats.wishlist = stats.wishlist + 1
                    tinsert(entries, {
                        raid_group_name = (row["raid_group_name"] ~= nil and row["raid_group_name"] ~= "") and row["raid_group_name"] or "No Roster",
                        character_name = row["character_name"] or "",
                        character_class = row["character_class"] or "",
                        member_name = row["member_name"] or "",
                        sort_order = tonumber(row["sort_order"]) or 99,
                        item_name = row["item_name"] or "",
                        item_id = tonumber(row["item_id"]) or 0,
                        is_offspec = (row["is_offspec"] == "1"),
                        instance_name = row["instance_name"] or "",
                        source_name = row["source_name"] or "",
                        received_at = row["received_at"] or "",
                        note = row["note"] or "",
                        item_prio_note = row["item_prio_note"] or "",
                        manual = (row["manual"] == "1") or nil,
                    })
                elseif rowType == "received" then
                    stats.received = stats.received + 1
                else
                    stats.other = stats.other + 1
                end
            end
        end
    end

    local headerOK = headerSet ~= nil and headerSet["item_id"] and headerSet["character_name"]
    return entries, stats, headerOK and true or false, meta
end

------------------------------------------------------------------------------
-- Store
------------------------------------------------------------------------------

local function NewID()
    Imports._seq = (Imports._seq or 0) + 1
    return ("%d-%d-%d"):format(Now(), math.random(0, 9999), Imports._seq)
end

--- All imports, sorted by name
function Imports:List()
    local list = {}
    for id, imp in pairs(Store()) do
        if id ~= "active" and type(imp) == "table" and imp.id then
            tinsert(list, imp)
        end
    end
    table.sort(list, function(a, b) return tostring(a.name):lower() < tostring(b.name):lower() end)
    return list
end

function Imports:Get(id)
    local s = Store()
    if id and type(s[id]) == "table" then return s[id] end
    return nil
end

function Imports:FindByName(name)
    name = Trim(name):lower()
    for _, imp in ipairs(self:List()) do
        if tostring(imp.name):lower() == name then return imp end
    end
    return nil
end

--- The active import, or nil when there is none (falls back to the first one if the active id vanished)
function Imports:Active()
    local s = Store()
    local imp = self:Get(s.active)
    if imp then return imp end

    local first = self:List()[1]
    if first then
        s.active = first.id
        return first
    end
    return nil
end

function Imports:SetActive(id, silent)
    local imp = self:Get(id)
    if not imp then return false end

    Store().active = id
    Changed()
    if not silent then
        LC:Print(("active raid is now '%s' (%d wishlist entries)."):format(imp.name, imp.stats.entries))
    end
    return true
end

--- exact (case-insensitive) name, else a unique partial match
function Imports:SetActiveByName(name)
    name = Trim(name):lower()
    if name == "" then
        LC:Print("Usage: /lchelp use <raid name>")
        return false
    end

    local exact, partial = nil, {}
    for _, imp in ipairs(self:List()) do
        local n = tostring(imp.name):lower()
        if n == name then
            exact = imp
        elseif n:find(name, 1, true) then
            tinsert(partial, imp)
        end
    end

    local pick = exact or (#partial == 1 and partial[1]) or nil
    if pick then
        return self:SetActive(pick.id)
    end

    if #partial > 1 then
        local names = {}
        for _, imp in ipairs(partial) do tinsert(names, imp.name) end
        LC:Print(("'%s' matches several raids: %s"):format(name, table.concat(names, ", ")))
    else
        LC:Print(("no raid import called '%s' - /lchelp imports lists them."):format(name))
    end
    return false
end

local function Stats(entries, received)
    local chars, rosters = {}, {}
    for _, e in ipairs(entries) do
        chars[LC:NormalizeName(e.character_name)] = true
        if e.raid_group_name and e.raid_group_name ~= "" then
            rosters[e.raid_group_name] = true
        end
    end
    local c, r = 0, 0
    for _ in pairs(chars) do c = c + 1 end
    for _ in pairs(rosters) do r = r + 1 end
    return { entries = #entries, characters = c, rosters = r, received = received or 0 }
end

--- Store already-parsed rows as a new import and make it active
function Imports:AddEntries(name, entries, received, shareId)
    name = Trim(name)
    if name == "" then name = "Raid " .. (#self:List() + 1) end

    local base, n = name, 2
    while self:FindByName(name) do
        name = ("%s (%d)"):format(base, n)
        n = n + 1
    end

    local remapped = LC.RemapTierPieces and LC:RemapTierPieces(entries) or 0
    local imp = {
        id = NewID(),
        shareId = shareId or NewID(), -- travels with the data, so edits can be matched to it
        shareIds = {},
        name = name,
        importedAt = Now(),
        entries = entries,
        stats = Stats(entries, received),
        remapped = remapped,
    }
    Store()[imp.id] = imp
    self:SetActive(imp.id, true)

    LC:Print(("imported '%s': %d wishlist entries, %d characters, %d roster%s%s%s. It is now the active raid."):format(
        name, imp.stats.entries, imp.stats.characters, imp.stats.rosters, imp.stats.rosters == 1 and "" or "s",
        remapped > 0 and (", %d tier pieces mapped to tokens"):format(remapped) or "",
        (received or 0) > 0 and (", %d received rows skipped"):format(received) or ""))
    return imp
end

local function MergeKey(entry)
    return ("%s|%s|%s"):format(
        LC:NormalizeName(entry.character_name),
        tostring(tonumber(entry.item_id) or 0),
        entry.is_offspec and "os" or "ms")
end

--- Add rows to an existing import, skipping ones it already has. A row counts
--- as a duplicate when that character already wants that item at the same spec,
--- whatever the priority, and the local row is the one kept.
--- Returns added, skipped.
function Imports:Merge(id, entries, sourceName, shareId)
    local imp = self:Get(id)
    if not imp or type(entries) ~= "table" then return nil end

    -- Edits shared for the incoming dataset should land here from now on
    if shareId and shareId ~= "" then
        imp.shareIds = imp.shareIds or {}
        imp.shareIds[shareId] = true
    end

    -- Tier pieces first, so a piece and its token count as the same wish
    if LC.RemapTierPieces then LC:RemapTierPieces(entries) end

    local seen = {}
    for _, e in ipairs(imp.entries) do seen[MergeKey(e)] = true end

    local added, skipped = 0, 0
    for _, e in ipairs(entries) do
        local key = MergeKey(e)
        if seen[key] then
            skipped = skipped + 1
        else
            seen[key] = true
            tinsert(imp.entries, e)
            added = added + 1
        end
    end

    imp.stats = Stats(imp.entries, imp.stats and imp.stats.received or 0)
    imp.mergedFrom = sourceName
    imp.mergedAt = Now()
    Changed()
    return added, skipped
end

--- Parse a pasted CSV (TMB export or LootCheck export) and store it. Returns the import, or nil after printing why not.
function Imports:Add(name, csvText)
    local entries, stats, headerOK, meta = self:ParseCSV(csvText)

    if not headerOK then
        LC:Print("that doesn't look like a That's My BIS CSV export (no item_id / character_name columns). On thatsmybis.com use Export > CSV and paste it as-is.")
        return nil
    end
    if #entries == 0 then
        LC:Print(("no wishlist rows found (%d rows: %d received, %d other)."):format(stats.rows, stats.received, stats.other))
        return nil
    end

    if Trim(name) == "" and meta.name and meta.name ~= "" then
        name = meta.name
    end
    return self:AddEntries(name, entries, stats.received, meta.share)
end

--- The share id of the data in use, generating one for the TMBExport fallback
function Imports:ActiveShareId()
    local active = self:Active()
    if active then
        active.shareId = active.shareId or NewID()
        return active.shareId
    end

    if LC:TMBExportDB() then
        LC.db.tmbexportShareId = LC.db.tmbexportShareId or NewID()
        return LC.db.tmbexportShareId
    end
    return nil
end

--- The import carrying this share id, whether it started with it or merged it in
function Imports:FindByShareId(shareId)
    if not shareId or shareId == "" then return nil end

    for _, imp in ipairs(self:List()) do
        if imp.shareId == shareId or (imp.shareIds and imp.shareIds[shareId]) then
            return imp
        end
    end

    if LC.db.tmbexportShareId == shareId and LC:TMBExportDB() and not self:Active() then
        return { id = "tmbexport", name = "TMBExport", shareId = shareId }
    end
    return nil
end

--- Turn TMBExport's current data into a LootCheck import
function Imports:CopyFromTMBExport(name)
    local db = LC:TMBExportDB()
    if not db or #db.wishlists == 0 then
        LC:Print("TMBExport has no wishlist data to copy.")
        return nil
    end

    local entries = {}
    for _, e in ipairs(db.wishlists) do
        local copy = {}
        for k, v in pairs(e) do copy[k] = v end
        tinsert(entries, copy)
    end

    return self:AddEntries(name or ("TMBExport " .. date("%Y-%m-%d")), entries, 0)
end

function Imports:Delete(id)
    local imp = self:Get(id)
    if not imp then return false end

    local s = Store()
    s[id] = nil
    if s.active == id then s.active = nil end
    if type(LC.db.overrides) == "table" then
        LC.db.overrides[id] = nil -- that raid's manual edits go with it
    end
    Changed()

    local now = self:Active()
    local tail
    if now then
        tail = (" Active raid is now '%s'."):format(now.name)
    elseif LC:TMBExportDB() then
        tail = " No imports left - falling back to TMBExport's data."
    else
        tail = " No wishlist data left - /lchelp imports to add one."
    end
    LC:Print(("deleted raid import '%s'.%s"):format(imp.name, tail))
    return true
end

------------------------------------------------------------------------------
-- Export (sync with another LootCheck user)
------------------------------------------------------------------------------

local EXPORT_COLUMNS = {
    "type", "raid_group_name", "member_name", "character_name", "character_class", "sort_order",
    "item_name", "item_id", "is_offspec", "instance_name", "source_name", "received_at", "note", "item_prio_note", "manual",
}

local function CsvField(value)
    value = tostring(value == nil and "" or value)
    if value:find('[,"\r\n]') then
        return '"' .. value:gsub('"', '""') .. '"'
    end
    return value
end

--- The active raid's effective dataset as text, or nil when there is no wishlist data
function Imports:ExportText()
    local data = LC:WishlistData()
    if not data then return nil end

    local effective = LC.Wishlist and LC.Wishlist:MergeOverrides(data.wishlists) or data.wishlists
    local lines = {
        ("# LootCheck wishlist export v1 | name=%s | share=%s | exported=%s | entries=%d"):format(
            tostring(data.source), tostring(self:ActiveShareId() or "-"), date("%Y-%m-%d %H:%M"), #effective),
        "# Paste this whole text into LootCheck: /lchelp imports > New import. Manual edits are included.",
        table.concat(EXPORT_COLUMNS, ","),
    }

    for _, e in ipairs(effective) do
        local row = {}
        for i, column in ipairs(EXPORT_COLUMNS) do
            local value
            if column == "type" then
                value = "wishlist"
            elseif column == "is_offspec" then
                value = e.is_offspec and "1" or "0"
            elseif column == "manual" then
                value = e.manual and "1" or "0"
            else
                value = e[column]
            end
            row[i] = CsvField(value)
        end
        tinsert(lines, table.concat(row, ","))
    end

    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- Raid picker and delete confirmation
--
-- Both are built from plain frames on purpose. Blizzard's UIDropDownMenu and
-- StaticPopup keep global state that the secure UI reads, so driving them from
-- an addon taints the game menu and "Log Out" silently stops working until you
-- reload. (Gargul ships its own copy of the dropdown code for the same reason.)
-- Nothing in LootCheck touches those systems.
------------------------------------------------------------------------------

local ITEM_HEIGHT = 18
local MENU_WIDTH = 210

local menu, catcher
local menuItems = {}
Imports._menuItems = menuItems -- exposed for tests

local function MenuItem(index)
    if menuItems[index] then return menuItems[index] end

    local item = CreateFrame("Button", nil, menu)
    item:SetHeight(ITEM_HEIGHT)
    item:SetPoint("TOPLEFT", 6, -(6 + (index - 1) * ITEM_HEIGHT))
    item:SetPoint("RIGHT", menu, "RIGHT", -6, 0)

    local highlight = item:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.15)

    item.text = LC.Window:Text(item, "GameFontHighlightSmall")
    item.text:SetPoint("LEFT", 6, 0)
    item.text:SetPoint("RIGHT", -6, 0)

    item:SetScript("OnClick", function(self)
        Imports:CloseMenu()
        if self.importID then Imports:SetActive(self.importID) end
    end)

    menuItems[index] = item
    return item
end

local function BuildPicker(page)
    -- Same dark field as the Audit page's range dropdown, so the two match
    local button = LC.Window:CreateDropdownButton(page, "LootCheckImportsFrameDropdown", MENU_WIDTH)
    button:SetText("No imports yet")
    button:SetScript("OnClick", function() Imports:ToggleMenu() end)

    -- Clicking anywhere else closes the menu
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", function() Imports:CloseMenu() end)
    catcher:Hide()

    menu = LC.Window:CreateInset(UIParent, "LootCheckImportsFrameMenu")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel((catcher.GetFrameLevel and catcher:GetFrameLevel() or 1) + 10)
    menu:SetSize(MENU_WIDTH, 40)
    if menu.SetBackdropColor then menu:SetBackdropColor(0.04, 0.04, 0.04, 0.96) end
    menu:Hide()
    Imports._menu = menu

    return button
end

function Imports:RefreshMenu()
    if not menu then return end

    local list = self:List()
    local active = self:Active()

    for i, imp in ipairs(list) do
        local item = MenuItem(i)
        local isActive = active ~= nil and imp.id == active.id
        item.importID = imp.id
        item.text:SetText(("%s%s|r  |cff888888%d|r"):format(
            isActive and "|cffffffff" or "|cffbbbbbb", tostring(imp.name), imp.stats.entries))
        item:Show()
    end

    for i = #list + 1, #menuItems do
        menuItems[i]:Hide()
        menuItems[i].importID = nil
    end

    menu:SetSize(MENU_WIDTH, math.max(#list, 1) * ITEM_HEIGHT + 12)
end

function Imports:OpenMenu()
    if not menu or not frame then return end

    if #self:List() == 0 then
        LC:Print("no raid imports yet - click New import and paste a That's My BIS CSV export.")
        return
    end

    self:RefreshMenu()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", frame.dropdown, "BOTTOMLEFT", 0, -2)
    catcher:Show()
    menu:Show()
end

function Imports:CloseMenu()
    if menu then menu:Hide() end
    if catcher then catcher:Hide() end
end

function Imports:ToggleMenu()
    if menu and menu:IsShown() then
        self:CloseMenu()
    else
        self:OpenMenu()
    end
end

local function BuildConfirm(page)
    local confirm = LC.Window:CreateInset(page, "LootCheckImportsFrameConfirm")
    confirm:SetSize(380, 112)
    confirm:SetPoint("CENTER", 0, 20)
    confirm:SetFrameStrata("DIALOG")
    confirm:SetFrameLevel((page.GetFrameLevel and page:GetFrameLevel() or 1) + 20)
    confirm:EnableMouse(true)
    if confirm.SetBackdropColor then confirm:SetBackdropColor(0.04, 0.04, 0.04, 0.97) end
    confirm:Hide()

    confirm.text = LC.Window:Text(confirm, "GameFontHighlight", 340)
    confirm.text:SetPoint("TOP", 0, -18)
    confirm.text:SetJustifyH("CENTER")

    confirm.yes = CreateFrame("Button", nil, confirm, "UIPanelButtonTemplate")
    confirm.yes:SetSize(96, 24)
    confirm.yes:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -6, 16)
    confirm.yes:SetText("Delete")
    confirm.yes:SetScript("OnClick", function()
        local id = Imports.pendingDelete
        Imports.pendingDelete = nil
        confirm:Hide()
        if id then Imports:Delete(id) end
    end)

    confirm.no = CreateFrame("Button", nil, confirm, "UIPanelButtonTemplate")
    confirm.no:SetSize(96, 24)
    confirm.no:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 6, 16)
    confirm.no:SetText("Cancel")
    confirm.no:SetScript("OnClick", function()
        Imports.pendingDelete = nil
        confirm:Hide()
    end)

    return confirm
end

--- Ask before deleting a raid import. Returns false when there is nothing to delete.
function Imports:ConfirmDelete(id)
    local imp = self:Get(id)
    if not imp or not frame then return false end

    self.pendingDelete = id
    frame.confirm.text:SetText(("Delete the wishlist import '%s'?|nIts manual edits go with it."):format(imp.name))
    frame.confirm:Show()
    return true
end

------------------------------------------------------------------------------
-- Page
------------------------------------------------------------------------------

local function BuildPage(page)
    frame = page

    -- Row 1: Active raid [dropdown] [New import] [Delete] [Export]
    local label = LC.Window:Text(page, "GameFontNormal")
    label:SetPoint("TOPLEFT", MARGIN, -16)
    label:SetText("Active raid:")

    local dropdown = BuildPicker(page)
    dropdown:SetPoint("LEFT", label, "RIGHT", 10, 0)
    page.dropdown = dropdown

    page.confirm = BuildConfirm(page)
    page:SetScript("OnHide", function()
        Imports:CloseMenu()
        Imports.pendingDelete = nil
        if page.confirm then page.confirm:Hide() end
    end)

    local newButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    newButton:SetSize(96, 22)
    newButton:SetPoint("LEFT", dropdown, "RIGHT", 6, 0)
    newButton:SetText("New import")
    newButton:SetScript("OnClick", function() Imports:ShowNewPanel(true) end)
    page.newButton = newButton

    local deleteButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    deleteButton:SetSize(64, 22)
    deleteButton:SetPoint("LEFT", newButton, "RIGHT", 6, 0)
    deleteButton:SetText("Delete")
    deleteButton:SetScript("OnClick", function()
        local active = Imports:Active()
        if active then Imports:ConfirmDelete(active.id) end
    end)
    page.deleteButton = deleteButton

    local exportButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    exportButton:SetSize(64, 22)
    exportButton:SetPoint("LEFT", deleteButton, "RIGHT", 6, 0)
    exportButton:SetText("Export")
    exportButton:SetScript("OnClick", function() Imports:ShowExport() end)
    page.exportButton = exportButton

    local sendButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    sendButton:SetSize(78, 22)
    sendButton:SetPoint("LEFT", exportButton, "RIGHT", 6, 0)
    sendButton:SetText("Send to...")
    sendButton:SetScript("OnClick", function() Imports:ShowSend() end)
    page.sendButton = sendButton

    -- Two info lines: each wraps, and everything below is anchored to them
    page.info = LC.Window:Text(page, "GameFontHighlightSmall", WIDTH - MARGIN * 2)
    page.info:SetPoint("TOPLEFT", MARGIN, -54)

    page.info2 = LC.Window:Text(page, "GameFontDisableSmall", WIDTH - MARGIN * 2)
    page.info2:SetPoint("TOPLEFT", page.info, "BOTTOMLEFT", 0, -3)

    local copyButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    copyButton:SetSize(170, 22)
    copyButton:SetPoint("TOPLEFT", page.info2, "BOTTOMLEFT", -2, -8)
    copyButton:SetText("Copy from TMBExport")
    copyButton:SetScript("OnClick", function() Imports:CopyFromTMBExport() end)
    page.copyButton = copyButton

    -- Import / export panel, always on screen so the page never looks empty
    local panel = CreateFrame("Frame", nil, page)
    panel:SetPoint("BOTTOMLEFT", MARGIN, 18)
    panel:SetPoint("BOTTOMRIGHT", -MARGIN, 18)
    page.panel = panel

    page.nameLabel = LC.Window:Text(panel, "GameFontNormal")
    page.nameLabel:SetPoint("TOPLEFT", 2, -2)
    page.nameLabel:SetText("Name:")

    local nameBox = CreateFrame("EditBox", "LootCheckImportsFrameNameBox", panel, "InputBoxTemplate")
    nameBox:SetSize(240, 20)
    nameBox:SetPoint("LEFT", page.nameLabel, "RIGHT", 12, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(40)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    page.nameBox = nameBox

    page.pasteLabel = LC.Window:Text(panel, "GameFontNormalSmall", WIDTH - MARGIN * 2 - 8)
    page.pasteLabel:SetTextColor(0.7, 0.7, 0.7)

    -- The text area itself, on a dark inset so it reads as an input box
    local inset = LC.Window:CreateInset(panel, "LootCheckImportsFrameInset")
    inset:SetPoint("BOTTOMLEFT", 0, 30)
    inset:SetPoint("BOTTOMRIGHT", 0, 30)
    page.inset = inset

    page.hint = LC.Window:Text(inset, "GameFontDisableSmall", WIDTH - MARGIN * 2 - 40)
    page.hint:SetPoint("TOPLEFT", 14, -12)
    page.hint:SetText("Click |cffffffffNew import|r to paste a That's My BIS CSV export (thatsmybis.com > Export > CSV), or |cffffffffExport|r to copy this raid's data out for another LootCheck user.")

    local scroll = CreateFrame("ScrollFrame", "LootCheckImportsFramePasteScroll", inset, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    page.scroll = scroll

    local pasteBox = CreateFrame("EditBox", "LootCheckImportsFramePasteBox", scroll)
    pasteBox:SetMultiLine(true)
    pasteBox:SetAutoFocus(false)
    pasteBox:SetFontObject(ChatFontNormal)
    pasteBox:SetWidth(scroll:GetWidth() or (WIDTH - 100))
    pasteBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(pasteBox)
    scroll:SetScript("OnSizeChanged", function(_, w) pasteBox:SetWidth(w) end)
    page.pasteBox = pasteBox

    -- "Send to" list: everyone in your group with a tick box each
    local sendList = CreateFrame("Frame", "LootCheckImportsFrameSendList", inset)
    sendList:SetPoint("TOPLEFT", 8, -8)
    sendList:SetPoint("BOTTOMRIGHT", -8, 8)
    sendList:Hide()
    page.sendList = sendList
    page.sendSelection = {}
    page.sendRows = {}

    local selectAll = CreateFrame("CheckButton", "LootCheckImportsFrameSelectAll", sendList, "UICheckButtonTemplate")
    selectAll:SetPoint("TOPLEFT", 2, -2)
    selectAll:SetSize(22, 22)
    selectAll:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        for _, member in ipairs(LC.Comm and LC.Comm:GroupRoster() or {}) do
            page.sendSelection[member.norm] = on or nil
        end
        Imports:RefreshSendList()
    end)
    page.selectAll = selectAll

    local selectAllLabel = LC.Window:Text(sendList, "GameFontHighlightSmall")
    selectAllLabel:SetPoint("LEFT", selectAll, "RIGHT", 2, 0)
    selectAllLabel:SetText("Everyone in the group")

    page.sendStatus = LC.Window:Text(sendList, "GameFontDisableSmall")
    page.sendStatus:SetPoint("TOPRIGHT", -26, -8)
    page.sendStatus:SetJustifyH("RIGHT")

    local sendScroll = CreateFrame("ScrollFrame", "LootCheckImportsFrameSendScroll", sendList, "FauxScrollFrameTemplate")
    sendScroll:SetPoint("TOPLEFT", 0, -28)
    sendScroll:SetPoint("BOTTOMRIGHT", -24, 0)
    sendScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, SEND_ROW_HEIGHT, function() Imports:RefreshSendList() end)
    end)
    page.sendScroll = sendScroll

    for i = 1, SEND_ROWS do
        local row = CreateFrame("CheckButton", "LootCheckImportsFrameSendRow" .. i, sendList, "UICheckButtonTemplate")
        row:SetSize(22, 22)
        row:SetPoint("TOPLEFT", 2, -28 - (i - 1) * SEND_ROW_HEIGHT)
        row:SetScript("OnClick", function(self)
            if self.norm then
                page.sendSelection[self.norm] = self:GetChecked() and true or nil
                Imports:RefreshSendStatus()
            end
        end)

        row.label = LC.Window:Text(row, "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row, "RIGHT", 2, 0)
        row.label:SetWidth(WIDTH - MARGIN * 2 - 100)

        row:Hide()
        page.sendRows[i] = row
    end

    local shareEdits = CreateFrame("CheckButton", "LootCheckImportsFrameShareEdits", panel, "UICheckButtonTemplate")
    shareEdits:SetPoint("BOTTOMLEFT", 2, 2)
    shareEdits:SetSize(24, 24)
    shareEdits:SetScript("OnClick", function(self)
        LC.db.settings.shareEdits = self:GetChecked() and true or false
        Imports:RefreshSendStatus()
        LC.Comm:AnnounceSharing()
    end)
    page.shareEdits = shareEdits

    local shareEditsLabel = LC.Window:Text(panel, "GameFontHighlightSmall")
    shareEditsLabel:SetPoint("LEFT", shareEdits, "RIGHT", 2, 0)
    shareEditsLabel:SetText("Also share my giveitem / addwlitem edits with the ticked players")
    page.shareEditsLabel = shareEditsLabel

    local sendNowButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    sendNowButton:SetSize(100, 24)
    sendNowButton:SetPoint("BOTTOMRIGHT", 0, 0)
    sendNowButton:SetText("Send")
    sendNowButton:SetScript("OnClick", function() Imports:SendToSelected() end)
    sendNowButton:Hide()
    page.sendNowButton = sendNowButton

    local importButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    importButton:SetSize(100, 24)
    importButton:SetPoint("BOTTOMRIGHT", 0, 0)
    importButton:SetText("Import")
    importButton:SetScript("OnClick", function() Imports:ImportFromUI() end)
    page.importButton = importButton

    local cancelButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    cancelButton:SetSize(80, 24)
    cancelButton:SetPoint("RIGHT", importButton, "LEFT", -6, 0)
    cancelButton:SetText("Cancel")
    cancelButton:SetScript("OnClick", function() Imports:ShowNewPanel(false) end)
    page.cancelButton = cancelButton

    Imports:SetMode(nil)
end

--- nil = idle (hint only), "import" = name + paste box, "export" = dataset to
--- copy out, "send" = pick who in your group receives it
function Imports:SetMode(mode)
    if not frame then return end
    frame.mode = mode

    local editing = mode ~= nil
    local naming = mode == "import"
    local sending = mode == "send"
    local showsText = editing and not sending

    if naming then
        frame.nameLabel:Show()
        frame.nameBox:Show()
        frame.pasteLabel:ClearAllPoints()
        frame.pasteLabel:SetPoint("TOPLEFT", frame.nameLabel, "BOTTOMLEFT", 0, -8)
    else
        frame.nameLabel:Hide()
        frame.nameBox:Hide()
        frame.pasteLabel:ClearAllPoints()
        frame.pasteLabel:SetPoint("TOPLEFT", frame.panel, "TOPLEFT", 2, -2)
    end

    -- The inset always fills what is left below the labels
    frame.inset:ClearAllPoints()
    frame.inset:SetPoint("BOTTOMLEFT", frame.panel, "BOTTOMLEFT", 0, editing and 30 or 0)
    frame.inset:SetPoint("BOTTOMRIGHT", frame.panel, "BOTTOMRIGHT", 0, editing and 30 or 0)
    if editing then
        frame.inset:SetPoint("TOPLEFT", frame.pasteLabel, "BOTTOMLEFT", -2, -6)
    else
        frame.inset:SetPoint("TOPLEFT", frame.panel, "TOPLEFT", 0, 0)
    end

    if editing then
        frame.pasteLabel:Show()
        frame.hint:Hide()
        frame.cancelButton:Show()
    else
        frame.pasteLabel:Hide()
        frame.hint:Show()
        frame.cancelButton:Hide()
    end

    if showsText then
        frame.scroll:Show()
        frame.pasteBox:Show()
    else
        frame.scroll:Hide()
        frame.pasteBox:Hide()
    end

    if sending then
        frame.sendList:Show()
        frame.shareEdits:Show()
        frame.shareEditsLabel:Show()
        frame.shareEdits:SetChecked(LC.Comm and LC.Comm:SharingEnabled() or false)
    else
        frame.sendList:Hide()
        frame.shareEdits:Hide()
        frame.shareEditsLabel:Hide()
    end
    if naming then frame.importButton:Show() else frame.importButton:Hide() end
    if sending then frame.sendNowButton:Show() else frame.sendNowButton:Hide() end

    frame.cancelButton:SetText((naming or sending) and "Cancel" or "Done")
end

--- Show the list of players who can receive the active dataset
function Imports:ShowSend()
    if not frame then return end

    if not LC:WishlistData() then
        LC:Print("there is no wishlist data to send yet.")
        return
    end

    local ok, reason = LC.Comm and LC.Comm:Available()
    if not ok then
        LC:Print("cannot send: " .. tostring(reason or "sync is unavailable") .. ".")
        return
    end

    self:SetMode("send")
    frame.sendSelection = LC.Comm:ShareList() -- remembered between sessions
    frame.selectAll:SetChecked(false)
    frame.pasteLabel:SetText("Pick your council. Press Send to give them this dataset, which each of them saves as a new raid or merges into theirs. Tick the box below to also pass your manual edits to the same players as you make them.")
    LC.Comm:Ping()
    self:RefreshSendList()
end

function Imports:RefreshSendList()
    if not frame or frame.mode ~= "send" then return end

    local roster = LC.Comm and LC.Comm:GroupRoster() or {}
    FauxScrollFrame_Update(frame.sendScroll, #roster, SEND_ROWS, SEND_ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(frame.sendScroll) or 0

    for i = 1, SEND_ROWS do
        local member = roster[offset + i]
        local row = frame.sendRows[i]

        if member then
            row.norm = member.norm
            row.playerName = member.name
            row:SetChecked(frame.sendSelection[member.norm] and true or false)

            local hasAddon = LC.Comm and LC.Comm:HasAddon(member.norm)
            row.label:SetText(("|cff%s%s|r%s"):format(
                LC:ClassHex(member.class), tostring(member.name),
                hasAddon and "   |cff00ff00LootCheck|r" or ""))
            row:Show()
        else
            row.norm = nil
            row:Hide()
        end
    end

    self:RefreshSendStatus()
end

function Imports:RefreshSendStatus()
    if not frame or frame.mode ~= "send" then return end

    local roster = LC.Comm and LC.Comm:GroupRoster() or {}
    local chosen = 0
    for _, member in ipairs(roster) do
        if frame.sendSelection[member.norm] then chosen = chosen + 1 end
    end

    if #roster == 0 then
        frame.sendStatus:SetText("you are not in a group")
    elseif LC.Comm and LC.Comm:SharingEnabled() then
        frame.sendStatus:SetText(("%d of %d selected, sharing edits"):format(chosen, #roster))
    else
        frame.sendStatus:SetText(("%d of %d selected"):format(chosen, #roster))
    end
end

--- The players ticked in the send list, by full name
function Imports:SelectedTargets()
    local targets = {}
    if not frame then return targets end

    for _, member in ipairs(LC.Comm and LC.Comm:GroupRoster() or {}) do
        if frame.sendSelection[member.norm] then tinsert(targets, member.name) end
    end
    return targets
end

function Imports:SendToSelected()
    if not LC.Comm then return end

    if LC.Comm:SendDataset(self:SelectedTargets()) then
        self:SetMode(nil)
    end
end

--- Import mode: name box + empty paste box
function Imports:ShowNewPanel(show)
    if not frame then return end
    if not show then
        self:SetMode(nil)
        return
    end

    self:SetMode("import")
    frame.nameBox:SetText("")
    frame.pasteBox:SetText("")
    frame.pasteLabel:SetText("Paste a That's My BIS CSV export, or another LootCheck user's export, below and click Import:")
    frame.nameBox:SetFocus()
end

--- Export mode: the active raid's dataset in the box, ready to copy
function Imports:ShowExport()
    if not frame then return end

    local text = self:ExportText()
    if not text then
        LC:Print("nothing to export - there is no wishlist data.")
        return
    end

    self:SetMode("export")
    frame.pasteLabel:SetText("Select all (Ctrl+A), copy (Ctrl+C) and send this to the other player. They paste it into New import and get exactly your dataset, manual edits included.")
    frame.pasteBox:SetText(text)
    frame.pasteBox:SetFocus()
    frame.pasteBox:HighlightText()
end

function Imports:ImportFromUI()
    if not frame or frame.mode ~= "import" then return end

    local csv = frame.pasteBox:GetText()
    if Trim(csv) == "" then
        LC:Print("paste the CSV export into the box first.")
        return
    end

    local imp = self:Add(frame.nameBox:GetText(), csv)
    if imp then
        frame.pasteBox:SetText("")
        frame.nameBox:SetText("")
        self:SetMode(nil)
        self:RefreshUI()
    end
end

function Imports:RefreshUI()
    if not frame or not LC.Window:IsShowing(PAGE) then return end

    local active = self:Active()
    frame.dropdown:SetText(active and active.name or "No imports yet")

    if active then
        local s = active.stats
        frame.info:SetText(("|cffffffff%s|r: %d wishlist entries, %d characters, %d roster%s"):format(
            active.name, s.entries, s.characters, s.rosters, s.rosters == 1 and "" or "s"))
        frame.info2:SetText(("Imported %s%s%s"):format(
            (active.importedAt or 0) > 0 and date("%Y-%m-%d %H:%M", active.importedAt) or "?",
            (active.remapped or 0) > 0 and ((" - %d tier pieces mapped to their tokens"):format(active.remapped)) or "",
            active.mergedFrom and ((" - merged with %s's data"):format(active.mergedFrom)) or ""))
        if frame.deleteButton.Enable then frame.deleteButton:Enable() end
        if frame.exportButton.Enable then frame.exportButton:Enable() end
    else
        frame.info:SetText(LC:TMBExportDB()
            and "|cffffffffNo LootCheck imports yet|r - using TMBExport's data."
            or "|cffff7f7fNo wishlist data yet.|r")
        frame.info2:SetText("Click New import and paste your That's My BIS CSV export.")
        if frame.deleteButton.Disable then frame.deleteButton:Disable() end
    end

    -- The panel starts below the info block (and below the copy button when it is there)
    frame.panel:ClearAllPoints()
    frame.panel:SetPoint("BOTTOMLEFT", MARGIN, 18)
    frame.panel:SetPoint("BOTTOMRIGHT", -MARGIN, 18)

    if LC:TMBExportDB() then
        frame.copyButton:Show()
        frame.panel:SetPoint("TOPLEFT", frame.copyButton, "BOTTOMLEFT", 2, -10)
    else
        frame.copyButton:Hide()
        frame.panel:SetPoint("TOPLEFT", frame.info2, "BOTTOMLEFT", 0, -10)
    end
end

function Imports:Open()
    LC.Window:Show(PAGE)
end

function Imports:Toggle()
    if LC.Window:IsShowing(PAGE) then
        LC.Window:Hide()
    else
        self:Open()
    end
end

LC.Window:RegisterPage(PAGE, {
    title = "LootCheck - Wishlist Data",
    frameName = "LootCheckImportsFrame",
    width = WIDTH,
    height = HEIGHT,
    build = BuildPage,
    onShow = function()
        Imports:RefreshUI()
        if not Imports:Active() then
            Imports:ShowNewPanel(true)
        else
            Imports:SetMode(nil)
        end
    end,
})
