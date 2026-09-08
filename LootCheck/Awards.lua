--[[
    LootCheck - Awards.lua

    Manual "received" marks: awards LootCheck knows about that Gargul does not,
    and Gargul awards you want LootCheck to ignore.

        /lchelp giveitem   <character> <item name or link> [os] [force]
            - mark the item as received by that character (greys them on the
              tooltip, counts in the graph / all-time history like a Gargul award)
            - if Gargul's award of that item to them was hidden earlier, restores it
        /lchelp removeitem <character> <item name or link>
            - removes the manual mark(s) again
            - with no manual mark: hides Gargul's latest award of that item to them
              (Gargul's own data is untouched; giveitem puts it back)

    Stored globally (awards are facts about the player, not about one raid import):
        LootCheckDB.manualAwards  = { [id] = { id, norm, character, itemID, itemName, itemLink, OS, timestamp } }
        LootCheckDB.ignoredAwards = { [gargulChecksum] = { checksum, norm, itemID, itemName, timestamp, hiddenAt } }

    Data.lua folds manual marks into the award index (they look like Gargul
    awards with checksum = id, manual = true) and drops ignored ones, so the
    tooltip greying, the graph and the all-time history all follow.
]]

local LC = LootCheck
local Awards = {}
LC.Awards = Awards

local function Trim(s)
    return (tostring(s or ""):match("^%s*(.-)%s*$"))
end

local function Now()
    return GetServerTime and GetServerTime() or 0
end

local function ManualStore()
    LC.db = LC.db or LootCheckDB or {}
    if type(LC.db.manualAwards) ~= "table" then LC.db.manualAwards = {} end
    return LC.db.manualAwards
end

local function IgnoredStore()
    LC.db = LC.db or LootCheckDB or {}
    if type(LC.db.ignoredAwards) ~= "table" then LC.db.ignoredAwards = {} end
    return LC.db.ignoredAwards
end

local function Changed()
    LC.Data:Invalidate()
    if LC.Graph then LC.Graph:RefreshIfShown() end
end

local function NewID()
    Awards._seq = (Awards._seq or 0) + 1
    return ("manual-%d-%d-%d"):format(Now(), math.random(0, 9999), Awards._seq)
end

local function DisplayName(norm)
    local r = LC.Data:Roster()[norm]
    return r and r.displayName or LC:Capitalize(norm)
end

local function When(ts)
    return (ts and ts > 0) and date("%Y-%m-%d", ts) or "?"
end

------------------------------------------------------------------------------
-- Accessors used by Data.lua / Core.lua
------------------------------------------------------------------------------

--- id -> manual award record
function Awards:Manual()
    return ManualStore()
end

function Awards:IsIgnored(checksum)
    return checksum ~= nil and IgnoredStore()[checksum] ~= nil
end

--- number of manual marks, number of hidden Gargul awards
function Awards:Counts()
    local marks, hidden = 0, 0
    for _ in pairs(ManualStore()) do marks = marks + 1 end
    for _ in pairs(IgnoredStore()) do hidden = hidden + 1 end
    return marks, hidden
end

------------------------------------------------------------------------------
-- Argument parsing
------------------------------------------------------------------------------

--- "<item text> [os] [force]" - flags may come in any order at the end
local function ParseFlags(text)
    text = Trim(text)
    local os, force
    while true do
        local rest = text:match("^(.-)%s+[oO][sS]$")
        if rest then
            text, os = rest, true
        else
            local rest2 = text:match("^(.-)%s+[fF][oO][rR][cC][eE]$")
            if rest2 then
                text, force = rest2, true
            else
                break
            end
        end
    end
    return Trim(text), os, force
end

local function SplitArgs(args)
    return Trim(args):match("^(%S+)%s+(.+)$")
end

local function ItemLinkIn(text)
    return text:match("(|c%x+|Hitem:%d+[^|]*|h%[.-%]|h|r)") or text:match("(|Hitem:%d+[^|]*|h%[.-%]|h)")
end

------------------------------------------------------------------------------
-- State changes
--
-- Every change to a received mark goes through one of these four, so your own
-- slash command and an edit shared by another council member take exactly the
-- same path. `from` names the player who shared it; when it is nil the edit is
-- yours and gets passed on to whoever you share edits with (see Comm.lua).
------------------------------------------------------------------------------

local function Share(kind, fields)
    if LC.Comm and LC.Comm.ShareEdit then LC.Comm:ShareEdit(kind, fields) end
end

--- The existing award of this item to this player at the same spec, if any
function Awards:AlreadyReceived(norm, itemID, os)
    local awards = LC.Data:AwardsForItem(itemID)
    for _, a in ipairs(awards and awards[norm] or {}) do
        if (a.OS and true or false) == (os and true or false) then return a end
    end
    return nil
end

--- Put back a Gargul award that removeitem hid. Returns its timestamp, or nil.
function Awards:ApplyUnhide(norm, itemID, itemName, itemLink, from)
    local ignored = IgnoredStore()
    local restore
    for _, info in pairs(ignored) do
        if info.norm == norm and info.itemID == itemID
            and (not restore or (info.timestamp or 0) > (restore.timestamp or 0))
        then
            restore = info
        end
    end
    if not restore then return nil end

    ignored[restore.checksum] = nil
    Changed()
    pcall(LC.Data.WishlistAwardCounts, LC.Data, {}) -- re-log the match for the all-time count

    if LC.Audit then
        LC.Audit:Log("giveitem", { norm = norm, character = DisplayName(norm), itemID = itemID,
            itemName = itemName, itemLink = itemLink, from = from,
            detail = "restored Gargul's award of " .. When(restore.timestamp) })
    end
    if not from then
        Share("unhide", { norm = norm, itemID = itemID, itemName = itemName })
    end

    return restore.timestamp
end

--- Record that a player received an item. Returns true.
function Awards:ApplyMark(norm, itemID, itemName, itemLink, os, timestamp, from)
    local id = NewID()
    local mark = {
        id = id,
        norm = norm,
        character = DisplayName(norm),
        itemID = itemID,
        itemName = itemName,
        itemLink = itemLink,
        OS = os and true or false,
        timestamp = tonumber(timestamp) or Now(),
    }
    ManualStore()[id] = mark

    Changed()
    pcall(LC.Data.WishlistAwardCounts, LC.Data, {}) -- log the match right away (see Data:History)

    if LC.Audit then
        LC.Audit:Log("giveitem", { norm = norm, character = mark.character, itemID = itemID,
            itemName = itemName, itemLink = itemLink, from = from,
            detail = os and "marked received (OS)" or "marked received" })
    end
    if not from then
        Share("mark", { norm = norm, itemID = itemID, os = os, timestamp = mark.timestamp,
            itemName = itemName, itemLink = itemLink })
    end

    return true
end

--- Drop every manual mark of this item for this player. Returns how many went.
function Awards:ApplyUnreceive(norm, itemID, itemName, itemLink, from)
    local manual = ManualStore()
    local removed = 0

    for id, m in pairs(manual) do
        if m.norm == norm and m.itemID == itemID then
            manual[id] = nil
            LC.Data:ForgetAward(id)
            removed = removed + 1
        end
    end
    if removed < 1 then return 0 end

    Changed()
    if LC.Audit then
        LC.Audit:Log("removeitem", { norm = norm, character = DisplayName(norm), itemID = itemID,
            itemName = itemName, itemLink = itemLink, from = from,
            detail = ("removed %d manual mark%s"):format(removed, removed == 1 and "" or "s") })
    end
    if not from then
        Share("unreceive", { norm = norm, itemID = itemID, itemName = itemName })
    end

    return removed
end

--- Hide this player's most recent Gargul award of the item. Returns it, or nil.
function Awards:ApplyHide(norm, itemID, itemName, from)
    local awards = LC.Data:AwardsForItem(itemID)
    local latest
    for _, a in ipairs(awards and awards[norm] or {}) do
        if not a.manual and (not latest or a.timestamp > latest.timestamp) then
            latest = a
        end
    end
    if not latest then return nil end

    IgnoredStore()[latest.checksum] = {
        checksum = latest.checksum,
        norm = norm,
        itemID = itemID,
        itemName = itemName,
        timestamp = latest.timestamp,
        hiddenAt = Now(),
    }
    LC.Data:ForgetAward(latest.checksum)
    Changed()

    if LC.Audit then
        LC.Audit:Log("removeitem", { norm = norm, character = DisplayName(norm), itemID = itemID,
            itemName = itemName, itemLink = latest.itemLink, from = from,
            detail = "hid Gargul's award of " .. When(latest.timestamp) })
    end
    if not from then
        Share("hide", { norm = norm, itemID = itemID, itemName = itemName })
    end

    return latest
end

------------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------------

local USAGE_GIVE = "Usage: /lchelp giveitem <character> <item name or link> [os] [force]  - marks the item as received"
local USAGE_REMOVE = "Usage: /lchelp removeitem <character> <item name or link>  - un-marks it (or hides Gargul's award of it)"

function Awards:GiveItem(args)
    local character, itemText = SplitArgs(args)
    if not character then
        LC:Print(USAGE_GIVE)
        return
    end

    local os, force
    itemText, os, force = ParseFlags(itemText)
    local itemID, itemName = LC.Wishlist:ResolveItem(itemText)
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

    -- A Gargul award of this item to them was hidden earlier: put it back
    local restored = self:ApplyUnhide(norm, itemID, itemName, ItemLinkIn(itemText))
    if restored then
        LC:Print(("restored Gargul's award of %s to %s (%s)."):format(itemName, display, When(restored)))
        return
    end

    -- Already received (Gargul or manual) with the same spec? Refuse unless forced.
    if not force then
        local existing = self:AlreadyReceived(norm, itemID, os)
        if existing then
            LC:Print(("%s is already marked as received by %s (%s%s, %s). Add 'force' to record it again."):format(
                itemName, display, existing.manual and "manual mark" or "Gargul award",
                existing.OS and ", OS" or "", When(existing.timestamp)))
            return
        end
    end

    self:ApplyMark(norm, itemID, itemName, ItemLinkIn(itemText), os)

    local wished = LC.Data:WishlistIndex()[itemID]
    wished = wished and wished[norm] ~= nil
    LC:Print(("marked %s as received by %s%s.%s"):format(
        itemName, display, os and " (OS)" or "",
        wished and "" or " It is not on their wishlist, so this greys nothing and does not count in the graph."))
end

function Awards:RemoveItem(args)
    local character, itemText = SplitArgs(args)
    if not character then
        LC:Print(USAGE_REMOVE)
        return
    end

    local itemID, itemName = LC.Wishlist:ResolveItem((ParseFlags(itemText)))
    if not itemID then
        LC:Print(itemName)
        return
    end

    local norm = LC:NormalizeName(character)
    local display = DisplayName(norm)

    -- Manual marks first
    local removed = self:ApplyUnreceive(norm, itemID, itemName, ItemLinkIn(itemText))
    if removed > 0 then
        LC:Print(("removed %d manual received mark%s of %s for %s."):format(
            removed, removed == 1 and "" or "s", itemName, display))
        return
    end

    -- No manual mark: hide Gargul's most recent award of this item to them
    local latest = self:ApplyHide(norm, itemID, itemName)
    if latest then
        LC:Print(("hidden Gargul's award of %s to %s (%s). Gargul's own records are untouched; |cff33ccff/lchelp giveitem|r puts it back."):format(
            itemName, display, When(latest.timestamp)))
        return
    end

    LC:Print(("%s is not marked as received by %s."):format(itemName, display))
end

--- Appended to /lchelp overrides
function Awards:PrintOverrides()
    local marks, hidden = self:Counts()
    if marks + hidden == 0 then return end

    LC:Print(("manual received marks: %d, hidden Gargul awards: %d"):format(marks, hidden))

    local list = {}
    for _, m in pairs(ManualStore()) do tinsert(list, m) end
    table.sort(list, function(a, b) return (a.timestamp or 0) < (b.timestamp or 0) end)
    for _, m in ipairs(list) do
        print(("  |cff00ff00+|r %s received %s%s (%s)"):format(
            tostring(m.character), tostring(m.itemLink or m.itemName), m.OS and " (OS)" or "", When(m.timestamp)))
    end

    list = {}
    for _, h in pairs(IgnoredStore()) do tinsert(list, h) end
    table.sort(list, function(a, b) return (a.timestamp or 0) < (b.timestamp or 0) end)
    for _, h in ipairs(list) do
        print(("  |cffff0000-|r hidden: Gargul's award of %s to %s (%s)"):format(
            tostring(h.itemName), DisplayName(h.norm or ""), When(h.timestamp)))
    end
end
