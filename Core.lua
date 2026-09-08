--[[
    LootCheck
    ---------
    Companion addon for Gargul + That's My BIS Export (TMBExport) on TBC Anniversary.

    1. Gargul keeps showing its normal TMB wishlist / prio-list tooltip lines.
    2. Gargul's "TMB Wish List" tooltip section is rebuilt from TMBExport's
       data (Gargul's format and settings), and raiders who already received
       the item are greyed out in it.
    3. /lchelp graph opens a bar graph of how many non-OS wishlist items each
       raider has been awarded.
    4. "Is this on their wishlist?" is answered by TMBExport's data
       (TMBExportDB), NOT by Gargul's own TMB import, so a stale Gargul import
       in a PUG does not skew the numbers. "Was it awarded?" is answered by
       Gargul's AwardHistory.

    Nothing is written to Gargul's data. The only TMBExport setting touched is its
    "show tooltip" flag (switched off once, so the list is not shown twice).
]]

local ADDON_NAME = ...

LootCheck = LootCheck or {}
local LC = LootCheck

--- The .toc is the single source of truth for the version: the packager and
--- CurseForge read it from there, so keeping a second copy here would only
--- give it something to drift out of step with.
local function AddonVersion()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, version = pcall(function() return get and get(ADDON_NAME, "Version") end)
    if ok and type(version) == "string" and version ~= "" and not version:find("@", 1, true) then
        return version
    end
    return "dev" -- running from source, before the packager substitutes it
end

LC.version = AddonVersion()
LC.PREFIX  = "|cff33ccffLootCheck|r: "
LC.GREY    = "7f7f7f" -- hex colour used for greyed-out names on tooltips

local DEFAULTS = {
    settings = {
        greyOSAwards   = true,  -- tooltip: also grey names that received the item via an OS roll/award
        receivedSuffix = "",    -- tooltip: text appended after a greyed name, e.g. " (received)"
        graphGroupOnly = false, -- graph: only show raiders currently in your group
        graphDays      = 0,     -- graph: only count awards from the last N days (0 = all time)
        graphPhase     = "",    -- graph: "" = all time, else a Phases key like "P3"
        auditWishlistOnly = false, -- audit page: hide awards that were not on the winner's wishlist
        shareEdits     = false, -- pass giveitem/removeitem/addwlitem/removewlitem on to your share list
        dropsIncludeRare = false, -- raid drops list: show blue items as well as epics
    },
    tmbTooltipHandled = false, -- set once TMBExport's duplicate tooltip list has been switched off
    history = {},              -- award checksum -> wishlist match LootCheck has seen (all-time count, see Data.lua)
    overrides = {},            -- manual wishlist edits, per wishlist source (see Wishlist.lua)
    imports = {},              -- named That's My BIS CSV imports + which one is active (see Imports.lua)
    shareWith = {},            -- normName -> true: who you send data to and share edits with (see Comm.lua)
    manualAwards = {},         -- /lchelp giveitem: items marked as received by hand (see Awards.lua)
    ignoredAwards = {},        -- /lchelp removeitem: Gargul awards LootCheck should ignore (see Awards.lua)
    auditLog = {},             -- manual-edit commands, shown on the Audit page (see Audit.lua)
    drops = {},                -- items that dropped in the raid, per raid week (see Drops.lua)
    phaseDates = {},           -- phase key -> date you set by hand (see Phases.lua)
}

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------

function LC:Print(msg)
    print(self.PREFIX .. tostring(msg))
end

--- Remove WoW colour escape sequences from a string
function LC:StripColorCodes(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

--- "Zhorax-Firemaw", "zhorax(os)", " Zhorax " -> "zhorax"
--- Used so names from TMBExport (no realm) and Gargul (realm appended) compare equal.
function LC:NormalizeName(name)
    if type(name) ~= "string" then return "" end
    name = name:lower()
    name = name:gsub("%s+", "")
    name = name:gsub("%(os%)", "")
    name = name:match("^([^%-]+)") or name
    return name
end

function LC:Capitalize(name)
    if type(name) ~= "string" or name == "" then return "" end
    return name:sub(1, 1):upper() .. name:sub(2)
end

function LC:ItemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

--- Whole-word containment on two already-lowercased strings.
--- Prevents "thor" matching inside "thoraxx".
function LC:ContainsWholeWord(haystack, needle)
    if type(haystack) ~= "string" or type(needle) ~= "string" or needle == "" then
        return false
    end

    local start = 1
    while true do
        local s, e = haystack:find(needle, start, true)
        if not s then return false end

        local before = s > 1 and haystack:sub(s - 1, s - 1) or ""
        local after  = haystack:sub(e + 1, e + 1)
        if not before:match("%a") and not after:match("%a") then
            return true
        end

        start = e + 1
    end
end

local CLASS_TOKENS = {
    warrior = "WARRIOR", paladin = "PALADIN", hunter = "HUNTER",
    rogue = "ROGUE", priest = "PRIEST", shaman = "SHAMAN",
    mage = "MAGE", warlock = "WARLOCK", druid = "DRUID",
}

--- Accepts "Warrior" (TMBExport style) or "WARRIOR" (Gargul style). Returns r, g, b.
function LC:ClassColor(className)
    if type(className) == "string" and className ~= "" then
        local token = CLASS_TOKENS[className:lower()] or className:upper()
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
        if c then return c.r, c.g, c.b end
    end
    return 0.8, 0.8, 0.8
end

--- "RRGGBB" for Gargul-style |c00RRGGBB colour codes; white when the class is unknown
function LC:ClassHex(className)
    if type(className) == "string" and className ~= "" then
        local token = CLASS_TOKENS[className:lower()] or className:upper()
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
        if c then
            return ("%02X%02X%02X"):format(
                math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
        end
    end
    return "FFFFFF"
end

------------------------------------------------------------------------------
-- Access to the other addons (always re-checked, never cached, so a late
-- load or a /reload of either addon is handled gracefully)
------------------------------------------------------------------------------

--- Gargul exposes itself as _G.Gargul
function LC:Gargul()
    local GL = _G.Gargul
    if type(GL) == "table" and type(GL.DB) == "table" then
        return GL
    end
    return nil
end

--- TMBExport stores its wishlist import in the TMBExportDB saved variable
function LC:TMBExportDB()
    local db = _G.TMBExportDB
    if type(db) ~= "table" and type(_G.TMBExport) == "table" then
        db = _G.TMBExport.db
    end
    if type(db) == "table" and type(db.wishlists) == "table" then
        return db
    end
    return nil
end

--- The wishlist LootCheck works with: the active LootCheck import ("raid"),
--- or TMBExport's data as a fallback while no import exists.
--- Returns { wishlists = rows, source = display name, id = key } or nil.
function LC:WishlistData()
    local imp = self.Imports and self.Imports:Active()
    if imp and type(imp.entries) == "table" then
        return { wishlists = imp.entries, source = imp.name, id = imp.id }
    end

    local db = self:TMBExportDB()
    if db then
        return { wishlists = db.wishlists, source = "TMBExport", id = "tmbexport" }
    end
    return nil
end

------------------------------------------------------------------------------
-- Initialisation
------------------------------------------------------------------------------

local function CopyDefaults(dst, src)
    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then dst[key] = {} end
            CopyDefaults(dst[key], value)
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        LootCheckDB = LootCheckDB or {}
        CopyDefaults(LootCheckDB, DEFAULTS)
        LC.db = LootCheckDB
    elseif event == "PLAYER_LOGIN" then
        LC:OnLogin()
    end
end)

--- PLAYER_LOGIN fires after every addon finished loading, which guarantees our
--- tooltip hook runs AFTER Gargul's (so its lines already exist when we look).
function LC:OnLogin()
    self.db = self.db or LootCheckDB or {}
    CopyDefaults(self.db, DEFAULTS)

    if self.Tooltip then
        self.Tooltip:Hook()
        self.Tooltip:SuppressTMBExportTooltip()
    end

    if self.Comm then
        self.Comm:Init()
    end

    -- Drop our caches whenever Gargul awards/edits loot or TMB data changes
    local GL = self:Gargul()
    if GL and GL.Events and GL.Events.register then
        local events = {
            "GL.ITEM_AWARDED", "GL.ITEM_UNAWARDED", "GL.ITEM_AWARD_EDITED",
            "GL.TMB_IMPORTED", "GL.TMB_CLEARED",
        }
        for _, eventName in ipairs(events) do
            pcall(GL.Events.register, GL.Events, "LootCheck" .. eventName, eventName, function(_, AwardEntry)
                if eventName == "GL.ITEM_UNAWARDED" and type(AwardEntry) == "table" then
                    LC.Data:ForgetAward(AwardEntry.checksum)
                end
                LC.Data:Invalidate()
                if eventName == "GL.ITEM_AWARDED" then
                    -- Log the new award against the current wishlist right away (see Data:History)
                    pcall(LC.Data.WishlistAwardCounts, LC.Data, {})
                end
                if LC.Graph then LC.Graph:RefreshIfShown() end
            end)
        end
    end

    local data = self:WishlistData()
    if not GL then
        self:Print(("v%s loaded, but Gargul was not found - tooltip integration and award history are disabled."):format(self.version))
    elseif not data then
        self:Print(("v%s loaded. No wishlist data yet: |cff33ccff/lchelp imports|r to paste a That's My BIS CSV export."):format(self.version))
    elseif data.id == "tmbexport" then
        self:Print(("v%s loaded, using TMBExport's wishlist data (no LootCheck import yet - |cff33ccff/lchelp imports|r to manage raids)."):format(self.version))
    else
        self:Print(("v%s loaded. Active raid: |cffffffff%s|r (%d wishlist entries). |cff33ccff/lchelp|r opens the window, |cff33ccff/lchelp help|r the command list."):format(
            self.version, data.source, #data.wishlists))
    end
end

------------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------------

function LC:PrintHelp()
    if self.Help and self.Help.PrintToChat then
        self.Help:PrintToChat()
    else
        self:Print("v" .. self.version .. " - type /lchelp to open the window.")
    end
end

function LC:PrintStatus()
    local GL = self:Gargul()
    local db = self:WishlistData()

    self:Print("status")
    if GL then
        local count = 0
        for _ in pairs(self.Data:AwardIndexFlat()) do count = count + 1 end
        print(("  Gargul: |cff00ff00found|r (v%s) - %d award history entries"):format(tostring(GL.version), count))
    else
        print("  Gargul: |cffff0000not found|r")
    end

    if db then
        local roster = self.Data:Roster()
        local players, groups = 0, {}
        for _, r in pairs(roster) do
            players = players + 1
            for g in pairs(r.groups) do groups[g] = true end
        end
        local groupList = {}
        for g in pairs(groups) do tinsert(groupList, g) end
        table.sort(groupList)
        local stored = self.Imports and #self.Imports:List() or 0
        print(("  Wishlist source: |cffffffff%s|r - %d wishlist entries, %d characters (%d raid import%s stored)"):format(
            db.source, #db.wishlists, players, stored, stored == 1 and "" or "s"))
        if #groupList > 0 then
            print("  Rosters: " .. table.concat(groupList, ", "))
        end
    else
        print("  Wishlist source: |cffff0000none|r - /lchelp imports to paste a That's My BIS CSV export")
    end
    print("  TMBExport addon: " .. (self:TMBExportDB() and "found" or "not found"))

    if GL and db then
        local current, allTime = 0, 0
        for _, row in ipairs(self.Data:WishlistAwardCounts({ days = self.db.settings.graphDays })) do
            current = current + row.count
            allTime = allTime + row.history
        end
        local logged = 0
        for _ in pairs(self.db.history or {}) do logged = logged + 1 end
        print(("  Non-OS wishlist items awarded: %d against the current wishlist, %d all time"):format(current, allTime))
        print(("  History log: %d matches remembered by LootCheck (the rest of all-time comes from Gargul's WL stamps)"):format(logged))
    end

    if self.Wishlist then
        local added, removed = self.Wishlist:Counts()
        if added + removed > 0 then
            print(("  Manual wishlist edits: %d added, %d removed (/lchelp overrides)"):format(added, removed))
        end
    end
    if self.Awards then
        local marks, hidden = self.Awards:Counts()
        if marks + hidden > 0 then
            print(("  Manual received marks: %d, hidden Gargul awards: %d (/lchelp overrides)"):format(marks, hidden))
        end
    end
    if self.Tooltip.integrated then
        print("  Gargul tooltip: |cff00ff00integrated|r - TMBExport data is shown inside Gargul's TMB section")
    else
        print("  Gargul tooltip: |cffff0000not integrated|r (Gargul missing?) - only greying Gargul's own lines")
    end
    local tmbTip = self.Tooltip:TMBExportTooltipEnabled()
    if tmbTip ~= nil then
        print("  TMBExport's own tooltip list: " .. (tmbTip and "|cffffff00on|r (duplicate)" or "off"))
    end

    local s = self.db.settings
    print(("  Settings: greyOSAwards=%s, graphDays=%d, graphGroupOnly=%s"):format(
        tostring(s.greyOSAwards), s.graphDays or 0, tostring(s.graphGroupOnly)))
end

--- /lchelp check <item link or item id>
function LC:PrintItemCheck(arg)
    local itemID = self:ItemIDFromLink(arg) or tonumber(arg)
    if not itemID then
        self:Print("Usage: /lchelp check <item link>  (shift-click an item into the chat box)")
        return
    end

    local link = arg:match("(|c%x+|Hitem:%d+[^|]*|h%[.-%]|h|r)") or ("item:" .. itemID)
    self:Print("check " .. link)

    local wish = self.Data:WishlistIndex()[itemID]
    if wish then
        local names = {}
        for _, p in pairs(wish) do tinsert(names, p) end
        table.sort(names, function(a, b) return (a.bestPrio or 99) < (b.bestPrio or 99) end)
        print("  TMBExport wishlist:")
        for _, p in ipairs(names) do
            local spec = p.mainSpec > 0 and "MS" or "OS only"
            print(("    %s - prio %s (%s)"):format(p.displayName, tostring(p.bestPrio or "?"), spec))
        end
    else
        print("  TMBExport wishlist: nobody")
    end

    local awards = self.Data:AwardsForItem(itemID)
    if awards then
        local flat = {}
        for _, list in pairs(awards) do
            for _, a in ipairs(list) do tinsert(flat, a) end
        end
        table.sort(flat, function(a, b) return a.timestamp < b.timestamp end)

        print("  Gargul awards:")
        for _, a in ipairs(flat) do
            local when = a.timestamp > 0 and date("%Y-%m-%d %H:%M", a.timestamp) or "?"
            print(("    %s - %s (%s%s)"):format(self:Capitalize(self:NormalizeName(a.awardedTo)), when,
                a.OS and "OS" or "MS", a.manual and ", manual mark" or ""))
        end
    else
        print("  Gargul awards: none")
    end
end

SLASH_LOOTCHECK1 = "/lchelp"
SLASH_LOOTCHECK2 = "/lootcheck"

--- Shorthands that jump straight to a page. Anything typed after them is
--- passed through, so "/lchg 30" works exactly like "/lchelp graph 30".
local function RegisterShorthand(key, token, forward)
    _G["SLASH_" .. key .. "1"] = token
    SlashCmdList[key] = function(msg)
        msg = (msg or ""):match("^%s*(.-)%s*$")
        SlashCmdList["LOOTCHECK"]((forward .. " " .. msg):match("^%s*(.-)%s*$"))
    end
end

RegisterShorthand("LOOTCHECKMENU", "/lch", "")
RegisterShorthand("LOOTCHECKGRAPH", "/lchg", "graph")
RegisterShorthand("LOOTCHECKAUDIT", "/lcha", "audit")
RegisterShorthand("LOOTCHECKCOUNCIL", "/lchc", "council")
SlashCmdList["LOOTCHECK"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = rest or ""

    if cmd == "" or cmd == "config" or cmd == "options" then
        LC.Window:Toggle("home")

    elseif cmd == "audit" then
        LC.Audit:Toggle()

    elseif cmd == "help" or cmd == "commands" then
        if rest:lower() == "chat" then
            LC:PrintHelp()
        else
            LC.Help:Toggle()
        end

    elseif cmd == "graph" then
        local days = tonumber(rest)
        if days then
            LC.db.settings.graphDays = math.max(0, math.floor(days))
            LC:Print(days > 0
                and ("graph now counts awards from the last %d days."):format(LC.db.settings.graphDays)
                or "graph now counts all awards.")
            LC.Graph:Open()
        else
            LC.Graph:Toggle()
        end

    elseif cmd == "phase" or cmd == "phases" then
        local key, date = rest:match("^(%S+)%s*(.-)$")
        if not key or key == "" then
            LC.Phases:Print()
        else
            local ok, message = LC.Phases:Set(key:upper(), date ~= "" and date or nil)
            LC:Print(message)
            if ok and LC.Graph then LC.Graph:RefreshIfShown() end
        end

    elseif cmd == "council" or cmd == "members" then
        LC.Council:Toggle()

    elseif cmd == "drops" then
        if rest:lower() == "clear" then
            LC:Print(("forgot %d recorded raid drop(s)."):format(LC.Drops:Clear()))
        else
            LC.Drops.weekOffset = 0
            LC.Graph:Open()
        end

    -- Deliberately absent from Help.COMMANDS: a testing aid, not a feature.
    -- It fills the drops list with fake entries so the page can be exercised
    -- outside a raid; every one of them is flagged and removable.
    elseif cmd == "testdrops" then
        local arg = rest:lower()
        if arg == "true" or arg == "on" or arg == "1" then
            local added = LC.Drops:AddTestData()
            LC:Print(("added %d test drop(s), spread over this week and last. |cff33ccff/lchelp testdrops false|r removes them."):format(added))
            LC.Drops.weekOffset = 0
            LC.Graph:Open()
        elseif arg == "false" or arg == "off" or arg == "0" then
            LC:Print(("removed %d test drop(s). Real drops were left alone."):format(LC.Drops:RemoveTestData()))
        else
            LC:Print(("usage: |cff33ccff/lchelp testdrops true|r or |cff33ccff/lchelp testdrops false|r - %d test drop(s) stored right now."):format(LC.Drops:TestDataCount()))
        end

    elseif cmd == "grouponly" then
        LC.db.settings.graphGroupOnly = not LC.db.settings.graphGroupOnly
        LC:Print("graph group-only filter " .. (LC.db.settings.graphGroupOnly and "|cff00ff00on|r" or "|cffff0000off|r"))
        LC.Graph:RefreshIfShown()

    elseif cmd == "greyos" then
        LC.db.settings.greyOSAwards = not LC.db.settings.greyOSAwards
        LC:Print("names awarded via OS are " .. (LC.db.settings.greyOSAwards and "greyed out" or "NOT greyed out"))

    elseif cmd == "tmbtooltip" then
        local enabled = LC.Tooltip:TMBExportTooltipEnabled()
        if enabled == nil then
            LC:Print("TMBExport not found.")
        else
            LC.Tooltip:SetTMBExportTooltip(not enabled)
            LC.db.tmbTooltipHandled = true
            LC:Print("TMBExport's own tooltip list is now " .. (not enabled and "|cff00ff00on|r" or "|cffff0000off|r"))
        end

    elseif cmd == "imports" or cmd == "import" or cmd == "raids" or cmd == "data" then
        LC.Imports:Toggle()

    elseif cmd == "shareedits" then
        LC.db.settings.shareEdits = not LC.db.settings.shareEdits
        LC.Comm:AnnounceSharing()

    elseif cmd == "send" then
        LC.Imports:Open()
        LC.Imports:ShowSend()

    elseif cmd == "use" then
        LC.Imports:SetActiveByName(rest)

    elseif cmd == "giveitem" then
        LC.Awards:GiveItem(rest)

    elseif cmd == "removeitem" then
        LC.Awards:RemoveItem(rest)

    elseif cmd == "addwlitem" or cmd == "additem" or cmd == "addwish" then
        LC.Wishlist:AddWishItem(rest)

    elseif cmd == "removewlitem" or cmd == "removewish" then
        LC.Wishlist:RemoveWishItem(rest)

    elseif cmd == "wishlist" then
        LC.Wishlist:PrintWishlist(rest)

    elseif cmd == "overrides" then
        LC.Wishlist:PrintOverrides()

    elseif cmd == "clearoverrides" then
        LC.Wishlist:ClearOverrides(rest)

    elseif cmd == "check" then
        LC:PrintItemCheck(rest)

    elseif cmd == "status" then
        LC:PrintStatus()

    else
        LC:Print("unknown command '" .. cmd .. "' - /lchelp help lists them.")
    end
end
