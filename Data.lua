--[[
    LootCheck - Data.lua

    Read-only views over the two data sources:

      * LC:WishlistData()      (active raid import, or TMBExport) -> who wants what
      * Gargul.DB.AwardHistory (Gargul)                -> who got what

    Both are indexed lazily and cached for a second so hovering items stays
    cheap. Caches are also dropped whenever Gargul fires an award/TMB event
    (see Core.lua).
]]

local LC = LootCheck
local Data = {}
LC.Data = Data

local CACHE_TTL = 1.0 -- seconds

local wishIndex, roster, rosterCount, wishBuiltAt
local awardIndex, awardBuiltAt

local function Stale(builtAt)
    return not builtAt or (GetTime() - builtAt) > CACHE_TTL
end

function Data:Invalidate()
    wishBuiltAt, awardBuiltAt = nil, nil
end

------------------------------------------------------------------------------
-- Wishlist (TMBExport)
------------------------------------------------------------------------------

--- wishIndex[itemID][normName] = {
---     normName, displayName, itemName, bestPrio,
---     entries  = { { prio, os, group, manual }, ... }   (one per wishlist row)
---     mainSpec = <number of non-OS wishlist entries>,
---     offSpec  = <number of OS wishlist entries>,
--- }
--- roster[normName] = { normName, displayName, class, groups = { [rosterName] = true } }
local function BuildWishlist()
    wishIndex, roster, rosterCount = {}, {}, 0
    local data = LC:WishlistData()
    local imported = data and data.wishlists or {}
    if LC.Wishlist then
        imported = LC.Wishlist:MergeOverrides(imported) -- manual /lchelp giveitem + removeitem edits
    end

    local seen, rosterNames = {}, {}
    for _, entry in ipairs(imported) do
        local itemID = tonumber(entry.item_id)
        local norm = LC:NormalizeName(entry.character_name)

        if itemID and itemID > 0 and norm ~= "" then
            -- The same (character, item, prio, spec) row can appear once per roster export; only count it once
            local key = ("%s|%d|%s|%s"):format(norm, itemID, tostring(entry.sort_order), tostring(entry.is_offspec and 1 or 0))

            if not seen[key] then
                seen[key] = true

                local rawName = tostring(entry.character_name or ""):match("^%s*([^%-%s]+)") or norm
                local display = LC:Capitalize(rawName)

                local r = roster[norm]
                if not r then
                    r = { normName = norm, displayName = display, class = entry.character_class, groups = {} }
                    roster[norm] = r
                end
                if entry.raid_group_name and entry.raid_group_name ~= "" then
                    r.groups[entry.raid_group_name] = true
                    rosterNames[entry.raid_group_name] = true
                end
                if (not r.class or r.class == "") and entry.character_class and entry.character_class ~= "" then
                    r.class = entry.character_class
                end

                local byItem = wishIndex[itemID]
                if not byItem then
                    byItem = {}
                    wishIndex[itemID] = byItem
                end

                local p = byItem[norm]
                if not p then
                    p = { normName = norm, displayName = display, itemName = entry.item_name, mainSpec = 0, offSpec = 0, entries = {} }
                    byItem[norm] = p
                end

                if entry.is_offspec then
                    p.offSpec = p.offSpec + 1
                else
                    p.mainSpec = p.mainSpec + 1
                end
                tinsert(p.entries, {
                    prio = tonumber(entry.sort_order),
                    os = entry.is_offspec and true or false,
                    group = entry.raid_group_name,
                    manual = entry.manual and true or nil,
                })

                local prio = tonumber(entry.sort_order)
                if prio and (not p.bestPrio or prio < p.bestPrio) then
                    p.bestPrio = prio
                end
                if (not p.itemName or p.itemName == "") and entry.item_name and entry.item_name ~= "" then
                    p.itemName = entry.item_name
                end
            end
        end
    end

    for _ in pairs(rosterNames) do rosterCount = rosterCount + 1 end
    wishBuiltAt = GetTime()
end

--- Number of distinct raid groups / rosters in the TMBExport data
function Data:RosterCount()
    if Stale(wishBuiltAt) then BuildWishlist() end
    return rosterCount
end

function Data:WishlistIndex()
    if Stale(wishBuiltAt) then BuildWishlist() end
    return wishIndex
end

function Data:Roster()
    if Stale(wishBuiltAt) then BuildWishlist() end
    return roster
end

------------------------------------------------------------------------------
-- Awards (Gargul)
------------------------------------------------------------------------------

--- awardIndex[itemID][normName] = { { OS, WL, timestamp, awardedTo, itemLink, checksum, manual }, ... } (oldest first)
local function BuildAwards()
    awardIndex = {}

    local GL = LC:Gargul()
    local history = GL and GL.DB and GL.DB.AwardHistory
    if type(history) ~= "table" and GL and GL.DB and GL.DB.get then
        local ok, result = pcall(GL.DB.get, GL.DB, "AwardHistory", {})
        if ok then history = result end
    end

    if type(history) == "table" then
        for checksum, loot in pairs(history) do
            if type(loot) == "table" and not (LC.Awards and LC.Awards:IsIgnored(checksum)) then
                local itemID = tonumber(loot.itemID) or LC:ItemIDFromLink(loot.itemLink)
                local norm = LC:NormalizeName(loot.awardedTo)

                if itemID and norm ~= "" then
                    local byItem = awardIndex[itemID]
                    if not byItem then
                        byItem = {}
                        awardIndex[itemID] = byItem
                    end

                    local list = byItem[norm]
                    if not list then
                        list = {}
                        byItem[norm] = list
                    end

                    tinsert(list, {
                        OS = loot.OS and true or false,
                        WL = loot.WL and true or false, -- Gargul's own "was on the winner's TMB wishlist" stamp
                        timestamp = tonumber(loot.timestamp) or 0,
                        awardedTo = loot.awardedTo,
                        itemLink = loot.itemLink,
                        checksum = checksum,
                        winnerClass = loot.winnerClass,
                    })
                end
            end
        end

    end

    -- Manual "received" marks (/lchelp giveitem) look like awards too
    if LC.Awards then
        for id, m in pairs(LC.Awards:Manual()) do
            local itemID = tonumber(m.itemID)
            local norm = m.norm or LC:NormalizeName(m.character)
            if itemID and norm and norm ~= "" then
                local byItem = awardIndex[itemID]
                if not byItem then
                    byItem = {}
                    awardIndex[itemID] = byItem
                end
                local list = byItem[norm]
                if not list then
                    list = {}
                    byItem[norm] = list
                end
                tinsert(list, {
                    OS = m.OS and true or false,
                    WL = false,
                    timestamp = tonumber(m.timestamp) or 0,
                    awardedTo = m.character,
                    itemLink = m.itemLink,
                    checksum = id,
                    manual = true,
                })
            end
        end
    end

    for _, byItem in pairs(awardIndex) do
        for _, list in pairs(byItem) do
            table.sort(list, function(a, b) return a.timestamp < b.timestamp end)
        end
    end

    awardBuiltAt = GetTime()
end

function Data:AwardIndex()
    if Stale(awardBuiltAt) then BuildAwards() end
    return awardIndex
end

--- Flat iterator helper used by /lchelp status: checksum -> award
function Data:AwardIndexFlat()
    local flat = {}
    for _, byItem in pairs(self:AwardIndex()) do
        for _, list in pairs(byItem) do
            for _, a in ipairs(list) do
                flat[a.checksum] = a
            end
        end
    end
    return flat
end

--- Gargul links some IDs together (tier tokens, normal/heroic variants).
--- Returns a list of IDs that should be treated as "this item".
function Data:LinkedItemIDs(itemID)
    local GL = LC:Gargul()
    if GL and GL.getLinkedItemsForID then
        local ok, ids = pcall(GL.getLinkedItemsForID, GL, itemID)
        if ok and type(ids) == "table" and #ids > 0 then
            return ids
        end
    end
    return { itemID }
end

--- awards[normName] = { award, award, ... } merged across linked item IDs, or nil
function Data:AwardsForItem(itemID)
    local index = self:AwardIndex()
    local merged

    for _, id in ipairs(self:LinkedItemIDs(itemID)) do
        local byItem = index[tonumber(id)]
        if byItem then
            merged = merged or {}
            for norm, list in pairs(byItem) do
                merged[norm] = merged[norm] or {}
                for _, a in ipairs(list) do
                    tinsert(merged[norm], a)
                end
            end
        end
    end

    return merged
end

--- Has this player been awarded this item? includeOS=false ignores OS awards.
function Data:PlayerReceivedItem(awardsForItem, normName, includeOS)
    local list = awardsForItem and awardsForItem[normName]
    if not list then return false end

    for _, a in ipairs(list) do
        if includeOS or not a.OS then
            return true
        end
    end
    return false
end

--- How many times this player was awarded this item (OS awards only if includeOS)
function Data:ReceivedCount(awardsForItem, normName, includeOS)
    local list = awardsForItem and awardsForItem[normName]
    if not list then return 0 end

    local count = 0
    for _, a in ipairs(list) do
        if includeOS or not a.OS then
            count = count + 1
        end
    end
    return count
end

------------------------------------------------------------------------------
-- Group helpers
------------------------------------------------------------------------------

--- set[normName] = true for everyone in the current raid/party (including you)
function Data:GroupMembers()
    local set = {}

    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    if count > 0 then
        local prefix = (IsInRaid and IsInRaid()) and "raid" or "party"
        for i = 1, count do
            local name = UnitName(prefix .. i)
            if name then set[LC:NormalizeName(name)] = true end
        end
    end

    local me = UnitName("player")
    if me then set[LC:NormalizeName(me)] = true end

    return set
end

------------------------------------------------------------------------------
-- The number the graph is built on
------------------------------------------------------------------------------

--- Matches between Gargul awards and the wishlist LootCheck currently sees.
--- matches[normName] = { { checksum, itemID, itemLink, itemName, timestamp, prio }, ... }
---
--- An award matches when
---   * the item is on the player's wishlist as a NON off-spec entry, and
---   * the award itself was not flagged OS by Gargul (i.e. not just an OS roll win)
--- capped at the number of non-OS wishlist entries they have for that item
--- (so a dual-wield double wishlist can count twice, but a single wish can't).
local function ComputeMatches(self, cutoff)
    local matches = {}

    for itemID, players in pairs(self:WishlistIndex()) do
        local awardsForItem = self:AwardsForItem(itemID)
        if awardsForItem then
            for norm, p in pairs(players) do
                local list = p.mainSpec > 0 and awardsForItem[norm]
                if list then
                    local matched = 0
                    for _, a in ipairs(list) do
                        if matched >= p.mainSpec then break end
                        if not a.OS and a.timestamp >= cutoff then
                            matched = matched + 1
                            matches[norm] = matches[norm] or {}
                            tinsert(matches[norm], {
                                checksum = a.checksum,
                                itemID = itemID,
                                itemLink = a.itemLink,
                                itemName = p.itemName,
                                timestamp = a.timestamp,
                                prio = p.bestPrio,
                            })
                        end
                    end
                end
            end
        end
    end

    return matches
end

------------------------------------------------------------------------------
-- All-time history
--
-- Wishlists get replaced every phase, so "was this award wishlisted?" has to
-- be remembered when it is observed. LootCheckDB.history keeps one entry per
-- Gargul award checksum that ever matched a wishlist LootCheck saw (imported
-- or manual). Gargul's own WL stamp on awards (set at award time from its TMB
-- import) fills in phases from before LootCheck was installed.
------------------------------------------------------------------------------

function Data:RecordMatches(matches)
    if not LC.db then return end
    LC.db.history = LC.db.history or {}
    local log = LC.db.history

    for norm, items in pairs(matches) do
        for _, m in ipairs(items) do
            if m.checksum and not log[m.checksum] then
                log[m.checksum] = {
                    norm = norm,
                    itemID = m.itemID,
                    itemLink = m.itemLink,
                    itemName = m.itemName,
                    timestamp = m.timestamp,
                    prio = m.prio,
                    recordedAt = GetServerTime and GetServerTime() or 0,
                }
            end
        end
    end
end

--- Gargul un-awarded (deleted) an award
function Data:ForgetAward(checksum)
    if LC.db and LC.db.history and checksum then
        LC.db.history[checksum] = nil
    end
end

--- history[normName] = { count, items = { { checksum, itemLink, itemName, timestamp, prio, source }, ... } }
--- source is "log" (seen by LootCheck) or "gargul" (Gargul's WL stamp only)
function Data:History()
    local byChecksum = {}
    for itemID, byItem in pairs(self:AwardIndex()) do
        for norm, list in pairs(byItem) do
            for _, a in ipairs(list) do
                byChecksum[a.checksum] = { award = a, norm = norm, itemID = itemID }
            end
        end
    end

    local set = {}
    local log = (LC.db and LC.db.history) or {}
    for checksum, entry in pairs(log) do
        local current = byChecksum[checksum]
        if LC.Awards and LC.Awards:IsIgnored(checksum) then
            log[checksum] = nil -- hidden via /lchelp removeitem
        elseif current and (current.norm ~= entry.norm or current.award.OS) then
            -- The award was edited to another winner since we logged it: stale
            log[checksum] = nil
        else
            set[checksum] = {
                checksum = checksum,
                norm = entry.norm,
                itemLink = entry.itemLink,
                itemName = entry.itemName,
                timestamp = tonumber(entry.timestamp) or 0,
                prio = entry.prio,
                source = "log",
            }
        end
    end

    for checksum, c in pairs(byChecksum) do
        if not set[checksum] and c.award.WL and not c.award.OS then
            set[checksum] = {
                checksum = checksum,
                norm = c.norm,
                itemLink = c.award.itemLink,
                timestamp = c.award.timestamp,
                source = "gargul",
            }
        end
    end

    local history = {}
    for _, e in pairs(set) do
        local h = history[e.norm]
        if not h then
            h = { count = 0, items = {} }
            history[e.norm] = h
        end
        h.count = h.count + 1
        tinsert(h.items, e)
    end
    for _, h in pairs(history) do
        table.sort(h.items, function(a, b) return a.timestamp > b.timestamp end)
    end

    return history
end

------------------------------------------------------------------------------
-- The numbers the graph is built on
------------------------------------------------------------------------------

--- One row per TMBExport character:
---   { normName, displayName, class,
---     count, items          - matches against the CURRENT wishlist (this phase), see ComputeMatches
---     history, historyItems - all-time wishlisted receipts, see Data:History }
--- sorted by count (desc), then history (desc), then name.
function Data:WishlistAwardCounts(opts)
    opts = opts or {}
    local days = tonumber(opts.days) or 0
    local cutoff = days > 0 and (GetServerTime() - days * 86400) or 0
    local group = opts.groupOnly and self:GroupMembers() or nil

    -- Every match against the current wishlist is logged, whatever the display window
    local allMatches = ComputeMatches(self, 0)
    self:RecordMatches(allMatches)
    local matches = cutoff > 0 and ComputeMatches(self, cutoff) or allMatches
    local history = self:History()

    local list = {}
    for norm, r in pairs(self:Roster()) do
        if not group or group[norm] then
            local items = matches[norm] or {}
            table.sort(items, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)

            local h = history[norm]
            tinsert(list, {
                normName = norm,
                displayName = r.displayName,
                class = r.class,
                count = #items,
                items = items,
                history = math.max(h and h.count or 0, #items),
                historyItems = h and h.items or {},
            })
        end
    end

    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        if a.history ~= b.history then return a.history > b.history end
        return a.displayName < b.displayName
    end)

    return list
end
