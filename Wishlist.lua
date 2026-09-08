--[[
    LootCheck - Wishlist.lua

    Manual wishlist edits:

        /lchelp addwlitem    <character> <item name or link> [#prio] [os]
        /lchelp removewlitem <character> <item name or link>
        /lchelp wishlist   <character>
        /lchelp overrides
        /lchelp clearoverrides confirm

    Edits are stored per wishlist source (raid import id, or "tmbexport" for
    the fallback) in LootCheckDB.overrides[<source id>] - never inside the
    import itself - so they survive re-imports and can be undone:

        added   = { { character, norm, itemID, itemName, prio, os, class, group, addedAt }, ... }
        removed = { ["<norm>|<itemID>"] = { character, itemID, itemName, removedAt }, ... }

    Data.lua merges them into the wishlist index (MergeOverrides), so the
    tooltip, the graph and /lchelp check all see the edited wishlist.

    Item names resolve against TMBExport's entries, Gargul's award history and
    Gargul_ItemData's item cache; an item link (shift-click) always works.
]]

local LC = LootCheck
local Wishlist = {}
LC.Wishlist = Wishlist

--- The override bucket for the wishlist source that is active right now
local function Overrides()
    LC.db = LC.db or LootCheckDB or {}
    local all = LC.db.overrides
    if type(all) ~= "table" then
        all = {}
        LC.db.overrides = all
    end

    -- Legacy flat shape { added = {}, removed = {} } (before raid imports existed)
    -- belonged to the TMBExport data; move it under that key
    if type(all.added) == "table" or type(all.removed) == "table" then
        local legacy = all["tmbexport"] or { added = {}, removed = {} }
        for _, m in ipairs(all.added or {}) do tinsert(legacy.added, m) end
        for k, m in pairs(all.removed or {}) do legacy.removed[k] = legacy.removed[k] or m end
        all["tmbexport"] = legacy
        all.added, all.removed = nil, nil
    end

    local data = LC:WishlistData()
    local key = data and data.id or "none"
    local o = all[key]
    if type(o) ~= "table" then
        o = {}
        all[key] = o
    end
    if type(o.added) ~= "table" then o.added = {} end
    if type(o.removed) ~= "table" then o.removed = {} end
    return o
end

local function Key(norm, itemID)
    return norm .. "|" .. tostring(itemID)
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
end

------------------------------------------------------------------------------
-- Merge point used by Data.lua
------------------------------------------------------------------------------

--- imported TMBExport rows minus removed ones, plus manual rows shaped like TMBExport rows
function Wishlist:MergeOverrides(imported)
    local o = Overrides()
    local out = {}

    for _, e in ipairs(imported or {}) do
        if not o.removed[Key(LC:NormalizeName(e.character_name), tonumber(e.item_id) or 0)] then
            tinsert(out, e)
        end
    end

    for _, m in ipairs(o.added) do
        tinsert(out, {
            character_name = m.character,
            character_class = m.class,
            item_id = m.itemID,
            item_name = m.itemName,
            sort_order = m.prio,
            is_offspec = m.os and true or false,
            raid_group_name = m.group,
            manual = true,
        })
    end

    return out
end

--- number of manual adds, number of manual removals
function Wishlist:Counts()
    local o = Overrides()
    local removed = 0
    for _ in pairs(o.removed) do removed = removed + 1 end
    return #o.added, removed
end

------------------------------------------------------------------------------
-- Item name resolution
------------------------------------------------------------------------------

local knownItems, knownBuiltAt

--- { [itemID] = name } from TMBExport, manual adds, Gargul's award history and Gargul_ItemData
function Wishlist:KnownItems()
    if knownItems and knownBuiltAt and (GetTime() - knownBuiltAt) < 5 then
        return knownItems
    end
    knownItems = {}

    local db = LC:WishlistData()
    for _, e in ipairs(db and db.wishlists or {}) do
        local id = tonumber(e.item_id)
        if id and type(e.item_name) == "string" and e.item_name ~= "" then
            knownItems[id] = e.item_name
        end
    end

    for _, m in ipairs(Overrides().added) do
        if m.itemID and m.itemName and not knownItems[m.itemID] then
            knownItems[m.itemID] = m.itemName
        end
    end

    for _, byItem in pairs(LC.Data:AwardIndex()) do
        for _, list in pairs(byItem) do
            for _, a in ipairs(list) do
                local id = LC:ItemIDFromLink(a.itemLink)
                local name = type(a.itemLink) == "string" and a.itemLink:match("%[(.-)%]")
                if id and name and not knownItems[id] then
                    knownItems[id] = name
                end
            end
        end
    end

    local itemData = _G.Gargul_ItemData
    if type(itemData) == "table" and type(itemData._items) == "table" then
        for id, name in pairs(itemData._items) do
            id = tonumber(id)
            if id and type(name) == "string" and not knownItems[id] then
                knownItems[id] = name
            end
        end
    end

    knownBuiltAt = GetTime()
    return knownItems
end

function Wishlist:ItemName(itemID)
    local name = self:KnownItems()[itemID]
    if name then return name end

    if GetItemInfo then
        local ok, n = pcall(GetItemInfo, itemID)
        if ok and type(n) == "string" then return n end
    end
    return "item:" .. tostring(itemID)
end

--- Returns itemID, itemName - or nil, errorMessage
function Wishlist:ResolveItem(text)
    text = Trim(text)
    if text == "" then return nil, "no item given" end

    -- Item link
    local id = tonumber(text:match("|Hitem:(%d+)"))
    if id then
        return id, text:match("%[(.-)%]") or self:ItemName(id)
    end

    -- Raw item ID
    if text:match("^%d+$") then
        id = tonumber(text)
        return id, self:ItemName(id)
    end

    -- Name: exact match first, then unique substring match
    local names = self:KnownItems()
    local lower = text:lower()
    local exact, partial = {}, {}
    for itemID, name in pairs(names) do
        local ln = name:lower()
        if ln == lower then
            tinsert(exact, itemID)
        elseif ln:find(lower, 1, true) then
            tinsert(partial, itemID)
        end
    end
    local hits = (#exact > 0) and exact or partial

    if #hits == 1 then
        return hits[1], names[hits[1]]
    end

    if #hits == 0 then
        -- Last resort: the client's own item cache
        if GetItemInfo then
            local ok, name, link = pcall(GetItemInfo, text)
            local linkID = ok and LC:ItemIDFromLink(link)
            if linkID then return linkID, name end
        end
        return nil, ("unknown item '%s' - shift-click the item link into the command instead"):format(text)
    end

    table.sort(hits, function(a, b) return names[a] < names[b] end)
    local shown = {}
    for i = 1, math.min(#hits, 6) do tinsert(shown, names[hits[i]]) end
    return nil, ("'%s' matches %d items: %s%s - be more specific or use the item link"):format(
        text, #hits, table.concat(shown, ", "), #hits > 6 and ", ..." or "")
end

--- "<item text> [#prio] [os]" - flags may come in any order at the end
local function ParseFlags(text)
    text = Trim(text)
    local prio, os
    while true do
        local rest, p = text:match("^(.-)%s+#(%d+)$")
        if rest then
            text, prio = rest, tonumber(p)
        else
            local rest2 = text:match("^(.-)%s+[oO][sS]$")
            if rest2 then
                text, os = rest2, true
            else
                break
            end
        end
    end
    return Trim(text), prio, os
end

local function SplitArgs(args)
    return Trim(args):match("^(%S+)%s+(.+)$")
end

------------------------------------------------------------------------------
-- Character helpers
------------------------------------------------------------------------------

--- class token ("ROGUE") of a group member, if they are in the group right now
function Wishlist:GroupClass(norm)
    if not UnitClass or not UnitName then return nil end

    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    local prefix = (IsInRaid and IsInRaid()) and "raid" or "party"
    for i = 0, count do
        local unit = (i == 0) and "player" or (prefix .. i)
        local name = UnitName(unit)
        if name and LC:NormalizeName(name) == norm then
            local _, token = UnitClass(unit)
            return token
        end
    end
end

--- roster name to file a manual entry under: the character's own, else the biggest imported one
local function DefaultGroup(norm)
    local r = LC.Data:Roster()[norm]
    if r then
        for g in pairs(r.groups) do return g end
    end

    local counts = {}
    local db = LC:WishlistData()
    for _, e in ipairs(db and db.wishlists or {}) do
        local g = e.raid_group_name
        if g and g ~= "" then counts[g] = (counts[g] or 0) + 1 end
    end
    local best, bestCount
    for g, n in pairs(counts) do
        if not bestCount or n > bestCount then best, bestCount = g, n end
    end
    return best or "Manual"
end

function Wishlist:NextPrio(norm)
    local highest = 0
    for _, players in pairs(LC.Data:WishlistIndex()) do
        local p = players[norm]
        if p then
            for _, e in ipairs(p.entries) do
                if e.prio and e.prio > highest then highest = e.prio end
            end
        end
    end
    return highest + 1
end

local function DisplayName(norm)
    local r = LC.Data:Roster()[norm]
    return r and r.displayName or LC:Capitalize(norm)
end

------------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- State changes
--
-- Your own slash command and a wishlist edit shared by another council member
-- both come through here. `from` names the sharer; nil means the edit is yours
-- and gets passed on to whoever you share with (see Comm.lua).
------------------------------------------------------------------------------

local function Share(kind, fields)
    if LC.Comm and LC.Comm.ShareEdit then LC.Comm:ShareEdit(kind, fields) end
end

--- Put an item on a character's wishlist for the active raid.
--- Returns "restored" when it un-hid an imported entry, "added" for a new one,
--- or nil plus the clashing entry when they already want it at that spec.
function Wishlist:ApplyAdd(norm, itemID, itemName, prio, os, class, from)
    local o = Overrides()
    local k = Key(norm, itemID)
    local display = DisplayName(norm)

    -- Undo an earlier removal first: the imported entry comes straight back
    if o.removed[k] then
        o.removed[k] = nil
        Changed()

        local p = LC.Data:WishlistIndex()[itemID]
        p = p and p[norm]
        if p then
            if LC.Audit then
                LC.Audit:Log("addwlitem", { norm = norm, character = display, itemID = itemID,
                    itemName = itemName, from = from,
                    detail = ("restored imported entry (prio %s)"):format(tostring(p.bestPrio or "?")) })
            end
            if not from then
                Share("wladd", { norm = norm, itemID = itemID, itemName = itemName })
            end
            return "restored", p.bestPrio
        end
    end

    -- Already on the list at the same spec?
    local existing = LC.Data:WishlistIndex()[itemID]
    existing = existing and existing[norm]
    for _, e in ipairs(existing and existing.entries or {}) do
        if (e.os and true or false) == (os and true or false) then
            return nil, e
        end
    end

    prio = prio or self:NextPrio(norm)
    class = class or (function()
        local roster = LC.Data:Roster()[norm]
        return (roster and roster.class and roster.class ~= "" and roster.class) or self:GroupClass(norm)
    end)()

    tinsert(o.added, {
        character = display,
        norm = norm,
        itemID = itemID,
        itemName = itemName,
        prio = prio,
        os = os and true or false,
        class = class,
        group = DefaultGroup(norm),
        addedAt = Now(),
    })
    Changed()

    if LC.Audit then
        LC.Audit:Log("addwlitem", { norm = norm, character = display, itemID = itemID,
            itemName = itemName, from = from,
            detail = ("added to wishlist, prio %d%s"):format(prio, os and " (OS)" or "") })
    end
    if not from then
        Share("wladd", { norm = norm, itemID = itemID, itemName = itemName, prio = prio, os = os, class = class })
    end

    return "added", prio
end

--- Take an item off a character's wishlist. Returns manualRemoved, importedHidden.
function Wishlist:ApplyRemove(norm, itemID, itemName, from)
    local o = Overrides()
    local k = Key(norm, itemID)
    local display = DisplayName(norm)
    local removedManual, removedImported = 0, false

    -- Manual adds are simply deleted
    for i = #o.added, 1, -1 do
        local m = o.added[i]
        if m.norm == norm and m.itemID == itemID then
            table.remove(o.added, i)
            removedManual = removedManual + 1
        end
    end

    -- Imported entries are hidden behind a "removed" mark
    if not o.removed[k] then
        local db = LC:WishlistData()
        for _, e in ipairs(db and db.wishlists or {}) do
            if tonumber(e.item_id) == itemID and LC:NormalizeName(e.character_name) == norm then
                o.removed[k] = { character = display, itemID = itemID, itemName = itemName, removedAt = Now() }
                removedImported = true
                break
            end
        end
    end

    if removedManual == 0 and not removedImported then
        return 0, false
    end

    Changed()
    if LC.Audit then
        LC.Audit:Log("removewlitem", { norm = norm, character = display, itemID = itemID,
            itemName = itemName, from = from,
            detail = removedImported and "hid imported wishlist entry"
                or ("removed %d manual wishlist entr%s"):format(removedManual, removedManual == 1 and "y" or "ies") })
    end
    if not from then
        Share("wlremove", { norm = norm, itemID = itemID, itemName = itemName })
    end

    return removedManual, removedImported
end

------------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------------

local USAGE_GIVE = "Usage: /lchelp addwlitem <character> <item name or link> [#prio] [os]"
local USAGE_REMOVE = "Usage: /lchelp removewlitem <character> <item name or link>"

function Wishlist:AddWishItem(args)
    local character, itemText = SplitArgs(args)
    if not character then
        LC:Print(USAGE_GIVE)
        return
    end

    local prio, os
    itemText, prio, os = ParseFlags(itemText)
    local itemID, itemName = self:ResolveItem(itemText)
    if not itemID then
        LC:Print(itemName)
        return
    end

    local norm = LC:NormalizeName(character)
    if norm == "" then
        LC:Print(USAGE_GIVE)
        return
    end
    local display = DisplayName(norm)

    local outcome, detail = self:ApplyAdd(norm, itemID, itemName, prio, os)

    if outcome == "restored" then
        LC:Print(("restored %s on %s's wishlist (prio %s)."):format(itemName, display, tostring(detail or "?")))
    elseif outcome == "added" then
        LC:Print(("added %s to %s's wishlist as prio %d%s."):format(itemName, display, detail, os and " (OS)" or ""))
    else
        LC:Print(("%s is already on %s's wishlist (prio %s%s)."):format(
            itemName, display, tostring(detail and detail.prio or "?"), detail and detail.os and ", OS" or ""))
    end
end

function Wishlist:RemoveWishItem(args)
    local character, itemText = SplitArgs(args)
    if not character then
        LC:Print(USAGE_REMOVE)
        return
    end

    local itemID, itemName = self:ResolveItem((ParseFlags(itemText)))
    if not itemID then
        LC:Print(itemName)
        return
    end

    local norm = LC:NormalizeName(character)
    local display = DisplayName(norm)

    local removedManual, removedImported = self:ApplyRemove(norm, itemID, itemName)
    if removedManual == 0 and not removedImported then
        LC:Print(("%s is not on %s's wishlist."):format(itemName, display))
        return
    end

    LC:Print(("removed %s from %s's wishlist%s."):format(
        itemName, display, removedImported and " (/lchelp addwlitem puts the imported entry back)" or ""))
end

function Wishlist:PrintWishlist(args)
    local character = Trim(args):match("^(%S+)")
    if not character then
        LC:Print("Usage: /lchelp wishlist <character>")
        return
    end

    local norm = LC:NormalizeName(character)
    local display = DisplayName(norm)
    local includeOS = (LC.db and LC.db.settings and LC.db.settings.greyOSAwards) ~= false

    local rows = {}
    for itemID, players in pairs(LC.Data:WishlistIndex()) do
        local p = players[norm]
        if p then
            local receivedCount = LC.Data:ReceivedCount(LC.Data:AwardsForItem(itemID), norm, includeOS)
            local own = {}
            for _, e in ipairs(p.entries) do tinsert(own, e) end
            table.sort(own, function(a, b) return (a.prio or 1000) < (b.prio or 1000) end)
            for i, e in ipairs(own) do
                tinsert(rows, {
                    prio = e.prio or 1000,
                    os = e.os,
                    manual = e.manual,
                    name = p.itemName or self:ItemName(itemID),
                    received = i <= receivedCount,
                })
            end
        end
    end

    local removed = {}
    for k, m in pairs(Overrides().removed) do
        if k:match("^(.-)|") == norm then
            tinsert(removed, m.itemName or tostring(m.itemID))
        end
    end
    table.sort(removed)

    if #rows == 0 then
        LC:Print(("%s has no wishlist entries."):format(display))
        if #removed > 0 then print("  manually removed: " .. table.concat(removed, ", ")) end
        return
    end

    table.sort(rows, function(a, b)
        if a.prio ~= b.prio then return a.prio < b.prio end
        return a.name < b.name
    end)

    LC:Print(("%s's wishlist (%d entries):"):format(display, #rows))
    for _, r in ipairs(LC.Data:WishlistAwardCounts({})) do
        if r.normName == norm then
            print(("  wishlist items received: %d against the current wishlist, %d all time"):format(r.count, r.history or 0))
            break
        end
    end
    for _, r in ipairs(rows) do
        local tags = {}
        if r.os then tinsert(tags, "OS") end
        if r.manual then tinsert(tags, "manual") end
        local tagText = (#tags > 0) and (" |cff7f7f7f(" .. table.concat(tags, ", ") .. ")|r") or ""
        local prioText = (r.prio == 1000) and "?" or tostring(r.prio)

        if r.received then
            print(("|cff%s  [%s] %s (received)|r%s"):format(LC.GREY, prioText, r.name, tagText))
        else
            print(("  [%s] %s%s"):format(prioText, r.name, tagText))
        end
    end
    if #removed > 0 then
        print("  manually removed: " .. table.concat(removed, ", "))
    end
end

function Wishlist:PrintOverrides()
    local o = Overrides()
    local added, removed = self:Counts()
    local data = LC:WishlistData()
    if added + removed == 0 then
        LC:Print(("no manual wishlist edits for %s."):format(data and data.source or "?"))
        if LC.Awards then LC.Awards:PrintOverrides() end
        return
    end

    LC:Print(("manual wishlist edits for %s: %d added, %d removed"):format(data and data.source or "?", added, removed))
    for _, m in ipairs(o.added) do
        print(("  |cff00ff00+|r %s: %s (prio %s%s)"):format(
            tostring(m.character), tostring(m.itemName), tostring(m.prio), m.os and ", OS" or ""))
    end

    local rem = {}
    for _, m in pairs(o.removed) do tinsert(rem, m) end
    table.sort(rem, function(a, b)
        return (tostring(a.character) .. tostring(a.itemName)) < (tostring(b.character) .. tostring(b.itemName))
    end)
    for _, m in ipairs(rem) do
        print(("  |cffff0000-|r %s: %s"):format(tostring(m.character), tostring(m.itemName or m.itemID)))
    end

    if LC.Awards then LC.Awards:PrintOverrides() end
end

function Wishlist:ClearOverrides(args)
    local added, removed = self:Counts()
    if Trim(args):lower() ~= "confirm" then
        LC:Print(("this would drop %d added and %d removed entries. Type |cff33ccff/lchelp clearoverrides confirm|r to do it."):format(added, removed))
        return
    end

    local o = Overrides()
    o.added, o.removed = {}, {}
    Changed()
    LC:Print(("cleared %d added and %d removed manual wishlist edits."):format(added, removed))
end
