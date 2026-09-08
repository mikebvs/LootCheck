--[[
    LootCheck - Tooltip.lua

    Integrates with Gargul's TMB tooltip section instead of adding a second list.

    Gargul builds its tooltip lines with GL.TMB:tooltipLines(itemLink) and
    appends them to the tooltip itself (bootstrap.lua). We replace that method:

      * everything Gargul would show ABOVE its "TMB Wish List" section (item
        tier / note, prio list) is kept as-is
      * the wishlist section itself is rebuilt from the active wishlist
        import (see Imports.lua; TMBExport's data while none exists), in
        Gargul's own format ("    Name[prio]", "    Name (OS)[prio]"), honouring
        Gargul's TMB settings (raiders-only filter, max entries, OS sorting,
        raid-group suffix)
      * players who already received the item are greyed. Class colours come
        from the import, so grey unambiguously means "received" (Gargul itself
        uses grey for "class unknown")

    If there is no wishlist data, or Gargul's data came from DFT / CPR / RRobin,
    Gargul's original lines are returned untouched and a fallback pass greys
    received names inside them. Any error in our code falls back to Gargul's
    own output, so a bug here can never blank the tooltip.
]]

local LC = LootCheck
local Tooltip = {}
LC.Tooltip = Tooltip

Tooltip.integrated = false

local hooked = {}
local original -- Gargul's TMB:tooltipLines, captured when the override is installed

--- Gargul's localisation table (falls back to the key itself, like Gargul does)
local function L(key)
    local loc = _G.Gargul_L
    local value = loc and loc[key]
    return type(value) == "string" and value or key
end

local function GargulSetting(GL, key, default)
    if GL and GL.Settings and GL.Settings.get then
        local ok, value = pcall(GL.Settings.get, GL.Settings, key)
        if ok and value ~= nil then return value end
    end
    return default
end

--- Grey a single Gargul-style "[prio]" line if it names somebody who received the item
local function GreyIfReceived(text, awards, includeOS, suffix)
    if type(text) ~= "string" or not text:find("[", 1, true) then return text end

    local plain = LC:StripColorCodes(text)
    local lower = plain:lower()
    for norm in pairs(awards) do
        if LC:ContainsWholeWord(lower, norm) and LC.Data:PlayerReceivedItem(awards, norm, includeOS) then
            return ("|cff%s%s%s|r"):format(LC.GREY, plain, suffix)
        end
    end
    return text
end

------------------------------------------------------------------------------
-- Wishlist section built from the active wishlist import, in Gargul's format
------------------------------------------------------------------------------

function Tooltip:WishlistLines(GL, itemID)
    local settings = (LC.db and LC.db.settings) or {}
    local includeOS = settings.greyOSAwards ~= false
    local suffix = settings.receivedSuffix or ""

    -- Gather wishlist entries across Gargul's linked item IDs (tier tokens etc.)
    local wish = LC.Data:WishlistIndex()
    local players = {}
    for _, id in ipairs(LC.Data:LinkedItemIDs(itemID)) do
        for norm, p in pairs(wish[tonumber(id)] or {}) do
            players[norm] = players[norm] or p
        end
    end
    if not next(players) then return {} end

    -- Gargul's own filters / settings
    local raidersOnly = true
    if GL.TMB and GL.TMB.shouldOnlyIncludeRaiders then
        local ok, value = pcall(GL.TMB.shouldOnlyIncludeRaiders, GL.TMB)
        if ok then raidersOnly = value and true or false end
    end
    local group = raidersOnly and LC.Data:GroupMembers() or nil
    local osLower = GargulSetting(GL, "TMB.OSHasLowerPriority", true)
    local maxEntries = tonumber(GargulSetting(GL, "TMB.maximumNumberOfTooltipEntries", 35)) or 35
    local showGroup = GargulSetting(GL, "TMB.showRaidGroup", false) and LC.Data:RosterCount() > 1

    local awards = LC.Data:AwardsForItem(itemID)
    local roster = LC.Data:Roster()

    local entries = {}
    for norm, p in pairs(players) do
        if not group or group[norm] then
            local classHex = LC:ClassHex(roster[norm] and roster[norm].class)
            local receivedCount = LC.Data:ReceivedCount(awards, norm, includeOS)

            -- A player can wish for the same item more than once (dual wield);
            -- grey as many of their entries as they have received, best prio first
            local own = {}
            for _, e in ipairs(p.entries) do
                tinsert(own, {
                    sortKey = (e.prio or 1000) + ((e.os and osLower) and 100 or 0),
                    prio = e.prio,
                    os = e.os,
                    group = e.group,
                })
            end
            table.sort(own, function(a, b) return a.sortKey < b.sortKey end)

            for i, e in ipairs(own) do
                local name = p.displayName .. (e.os and (" " .. L("(OS)")) or "")
                local groupString = (showGroup and e.group and e.group ~= "") and (" - " .. e.group) or ""
                local text = ("    %s[%s]%s"):format(name, tostring(e.prio or "?"), groupString)

                local line
                if i <= receivedCount then
                    line = ("|cff%s%s%s|r"):format(LC.GREY, text, suffix)
                else
                    line = ("|c00%s%s|r"):format(classHex, text)
                end
                tinsert(entries, { sortKey = e.sortKey, name = name:lower(), line = line })
            end
        end
    end
    if #entries == 0 then return {} end

    table.sort(entries, function(a, b)
        if a.sortKey ~= b.sortKey then return a.sortKey < b.sortKey end
        return a.name < b.name
    end)

    local Lines = { ("\n|c00FFFFFF%s|r"):format(L("TMB Wish List")) }
    for i, e in ipairs(entries) do
        if i > maxEntries then break end
        tinsert(Lines, e.line)
    end
    return Lines
end

------------------------------------------------------------------------------
-- The replacement for GL.TMB:tooltipLines
------------------------------------------------------------------------------

function Tooltip:IntegratedLines(TMB, itemLink)
    local origLines = original(TMB, itemLink) or {}

    local GL = LC:Gargul()
    if not GL or not LC:WishlistData() then return origLines end

    -- Gargul renders DFT / CPR / RRobin data in other formats; leave those alone
    for _, fn in ipairs({ "wasImportedFromDFT", "wasImportedFromCPR", "wasImportedFromRRobin" }) do
        if type(TMB[fn]) == "function" then
            local ok, value = pcall(TMB[fn], TMB)
            if ok and value then return origLines end
        end
    end

    local itemID = LC:ItemIDFromLink(itemLink)
    if not itemID then return origLines end

    local settings = (LC.db and LC.db.settings) or {}
    local includeOS = settings.greyOSAwards ~= false
    local suffix = settings.receivedSuffix or ""
    local awards = LC.Data:AwardsForItem(itemID)

    -- Keep everything above Gargul's wishlist section (tier, note, prio list),
    -- greying received names in the prio list as well
    local header = ("\n|c00FFFFFF%s|r"):format(L("TMB Wish List"))
    local Lines = {}
    for _, line in ipairs(origLines) do
        if line == header then break end
        tinsert(Lines, awards and GreyIfReceived(line, awards, includeOS, suffix) or line)
    end

    -- Mirror Gargul's own "should the wishlist be shown at all" rules
    local inGroup = GL.User and GL.User.isInGroup
    if inGroup == nil then
        inGroup = (GetNumGroupMembers and GetNumGroupMembers() or 0) > 0
    end
    local showWhenSolo = GargulSetting(GL, "TMB.showEntriesWhenSolo", false)

    if not inGroup and GargulSetting(GL, "TMB.hideInfoOfPeopleNotInGroup", true) and not showWhenSolo then
        return Lines
    end
    if not (GargulSetting(GL, "TMB.showWishListInfoOnTooltips", true) or (not inGroup and showWhenSolo)) then
        return Lines
    end
    if GargulSetting(GL, "TMB.hideWishListInfoIfPriorityIsPresent", false) and (inGroup or not showWhenSolo) then
        local source = "TMB"
        if type(TMB.source) == "function" then
            local ok, value = pcall(TMB.source, TMB)
            if ok and type(value) == "string" then source = value end
        end
        local prioHeader = (L("%s Prio List")):format(source)
        for _, line in ipairs(Lines) do
            if line:find(prioHeader, 1, true) then return Lines end
        end
    end

    for _, line in ipairs(self:WishlistLines(GL, itemID)) do
        tinsert(Lines, line)
    end
    return Lines
end

function Tooltip:InstallOverride()
    if original then return end

    local GL = LC:Gargul()
    if not GL or type(GL.TMB) ~= "table" or type(GL.TMB.tooltipLines) ~= "function" then return end

    original = GL.TMB.tooltipLines
    GL.TMB.tooltipLines = function(TMB, itemLink)
        local ok, lines = pcall(Tooltip.IntegratedLines, Tooltip, TMB, itemLink)
        if ok and type(lines) == "table" then return lines end

        if not ok and not Tooltip.reportedError then
            Tooltip.reportedError = true
            LC:Print("tooltip integration error (showing Gargul's own list instead): " .. tostring(lines))
        end

        local ok2, origLines = pcall(original, TMB, itemLink)
        return (ok2 and type(origLines) == "table") and origLines or {}
    end

    self.integrated = true
end

------------------------------------------------------------------------------
-- Fallback: grey names inside Gargul's own lines when integration is not active
------------------------------------------------------------------------------

function Tooltip:Process(tooltip)
    if self.integrated and LC:WishlistData() then return end -- lines were built by us already
    if not tooltip or not tooltip.GetItem or not tooltip.NumLines then return end

    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    if not ok then return end

    local itemID = LC:ItemIDFromLink(link)
    if not itemID then return end

    local awards = LC.Data:AwardsForItem(itemID)
    if not awards then return end -- nobody has been awarded this item

    local frameName = tooltip:GetName()
    if not frameName then return end

    local settings = (LC.db and LC.db.settings) or {}
    local includeOS = settings.greyOSAwards ~= false
    local suffix = settings.receivedSuffix or ""

    for i = 2, tooltip:NumLines() do
        local fontString = _G[frameName .. "TextLeft" .. i]
        local text = fontString and fontString:GetText()
        if text then
            local replacement = GreyIfReceived(text, awards, includeOS, suffix)
            if replacement ~= text then
                fontString:SetText(replacement)
            end
        end
    end
end

function Tooltip:Hook()
    self:InstallOverride()

    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
        local frame = _G[name]
        if frame and frame.HookScript and not hooked[name] then
            frame:HookScript("OnTooltipSetItem", function(self)
                Tooltip:Process(self)
            end)
            hooked[name] = true
        end
    end
end

------------------------------------------------------------------------------
-- TMBExport's own tooltip block would duplicate ours; switch it off once
------------------------------------------------------------------------------

--- true / false, or nil when TMBExport is not available
function Tooltip:TMBExportTooltipEnabled()
    local db = LC:TMBExportDB()
    if not db then return nil end
    db.settings = db.settings or {}
    return db.settings.showTooltip ~= false
end

function Tooltip:SetTMBExportTooltip(enabled)
    local db = LC:TMBExportDB()
    if not db then return false end
    db.settings = db.settings or {}
    db.settings.showTooltip = enabled and true or false
    return true
end

function Tooltip:SuppressTMBExportTooltip()
    if not self.integrated or not LC.db or LC.db.tmbTooltipHandled then return end

    local enabled = self:TMBExportTooltipEnabled()
    if enabled == nil then return end -- TMBExport not here (yet); try again next login

    if enabled then
        self:SetTMBExportTooltip(false)
        LC:Print("TMBExport's separate tooltip list is now off - its wishlist data shows inside Gargul's TMB section instead. |cff33ccff/lchelp tmbtooltip|r turns it back on.")
    end
    LC.db.tmbTooltipHandled = true
end
