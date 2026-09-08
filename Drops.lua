--[[
    LootCheck - Drops.lua

    Every item that dropped in the raid, kept per raid week and shown next to
    the bars on the Wishlist Awards page.

    Gargul does not store this: its DroppedLootLedger holds drops in memory
    only and its lootOpened() listener is commented out, so LootCheck reads
    the game itself, from two sources that back each other up:

      * the loot window (LOOT_READY / LOOT_OPENED) - everything on the corpse,
        but only for whoever opened it;
      * chat (CHAT_MSG_LOOT) - everything anyone in the raid picked up, which
        every client in the raid sees, so no addon-to-addon comms are needed.

    A chat receipt for an item already seen in a loot window fills the looter
    in on that row instead of listing it twice. Who *looted* an item and who it
    was *assigned* to are different facts and both are shown: the master
    looter's bags may be full, so an item is often picked up by another
    council member and only assigned in Gargul later that night.

    Weeks run from the raid reset (Tuesday on US realms). The client tells us
    when that is on builds that have the API; otherwise we fall back to the
    most recent Tuesday 08:00. KEEP_WEEKS of history are kept so the list can
    be stepped back, and anything older is pruned.

    Rare items and up are always recorded; the "Include blue items" box only
    changes what the list shows, so ticking it later still reveals drops that
    were stored while it was off.
]]

local LC = LootCheck
local Drops = {}
LC.Drops = Drops

local DAY, WEEK = 86400, 604800

Drops.RESET_WDAY = 3    -- date("*t").wday: 1 = Sunday, so 3 = Tuesday
Drops.RESET_HOUR = 8    -- US realms flip at 08:00 server time
Drops.KEEP_WEEKS = 8    -- raid weeks of history kept before pruning
Drops.MAX_ENTRIES = 2000
Drops.RECORD_QUALITY = 3 -- rare and up is stored...
Drops.SHOW_QUALITY = 4   -- ...epic and up is shown unless "include blue items" is ticked
Drops.AWARD_GRACE = 300  -- an award may be stamped slightly before the drop was seen
Drops.RECEIPT_WINDOW = 6 * 3600 -- how far back a chat receipt may attach to a drop already seen

Drops.weekOffset = 0 -- 0 = this raid week, 1 = last week, ... (not remembered between sessions)

local keyIndex -- key -> true, rebuilt lazily from the log

------------------------------------------------------------------------------
-- Storage
------------------------------------------------------------------------------

local function Log()
    LC.db = LC.db or LootCheckDB or {}
    if type(LC.db.drops) ~= "table" then LC.db.drops = {} end
    return LC.db.drops
end

local function Settings()
    LC.db = LC.db or LootCheckDB or {}
    LC.db.settings = LC.db.settings or {}
    return LC.db.settings
end

local function Now()
    return (GetServerTime and GetServerTime()) or time()
end

function Drops:Invalidate()
    keyIndex = nil
end

local function Keys()
    if not keyIndex then
        keyIndex = {}
        for _, d in ipairs(Log()) do
            if d.key then keyIndex[d.key] = true end
        end
    end
    return keyIndex
end

------------------------------------------------------------------------------
-- Raid weeks
------------------------------------------------------------------------------

--- The moment the raid week containing `now` began (i.e. the last reset).
function Drops:WeekStart(now)
    now = now or Now()

    -- The client knows the real reset on builds that have the API
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local ok, secs = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
        if ok and type(secs) == "number" and secs > 0 and secs <= WEEK then
            return now + secs - WEEK
        end
    end

    local t = date("*t", now)
    local intoDay = t.hour * 3600 + t.min * 60 + t.sec
    local sinceReset = (t.wday - self.RESET_WDAY) % 7
    local start = now - intoDay - sinceReset * DAY + self.RESET_HOUR * 3600
    if start > now then start = start - WEEK end -- Tuesday, but before the reset hour
    return start
end

--- from (inclusive), to (exclusive) for a raid week. 0 = this one, 1 = last week.
function Drops:WeekBounds(offset)
    local start = self:WeekStart() - (tonumber(offset) or 0) * WEEK
    return start, start + WEEK
end

--- "This week (09 Sep - 15 Sep)"
function Drops:WeekLabel(offset)
    offset = tonumber(offset) or 0
    local from, to = self:WeekBounds(offset)
    local name = "This week"
    if offset == 1 then
        name = "Last week"
    elseif offset > 1 then
        name = ("%d weeks ago"):format(offset)
    end
    return ("%s |cff7f7f7f(%s - %s)|r"):format(name, date("%d %b", from), date("%d %b", to - DAY))
end

------------------------------------------------------------------------------
-- Recording
------------------------------------------------------------------------------

--- Only log drops that happened in a raid: a raid group, or a raid instance.
function Drops:ShouldTrack()
    if IsInRaid and IsInRaid() then return true end
    if IsInInstance then
        local inside, kind = IsInInstance()
        if inside and kind == "raid" then return true end
    end
    return false
end

-- Item quality straight off the link's colour code: no item cache, no Gargul
local QUALITY_BY_HEX = {
    ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3,
    ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6, ["00ccff"] = 7,
}

function Drops:QualityFromLink(itemLink)
    if type(itemLink) ~= "string" then return nil end
    local hex = itemLink:match("|c%x%x(%x%x%x%x%x%x)")
    return hex and QUALITY_BY_HEX[hex:lower()] or nil
end

local function QualityOf(itemLink, reported)
    if type(reported) == "number" then return reported end

    local fromLink = Drops:QualityFromLink(itemLink)
    if fromLink then return fromLink end

    local GL = LC:Gargul()
    if GL and GL.getItemQualityFromLink then
        local ok, q = pcall(GL.getItemQualityFromLink, GL, itemLink)
        if ok and type(q) == "number" then return q end
    end
    if GetItemInfo then
        local q = select(3, GetItemInfo(itemLink))
        if type(q) == "number" then return q end
    end
    return 0
end

--- The corpse the loot came from, when the client lets us tell.
function Drops:SourceName(guid)
    if guid and UnitGUID and UnitGUID("target") == guid then
        return UnitName("target")
    end
    -- Whoever opens a corpse has it targeted, so this is right in practice
    if UnitExists and UnitExists("target") and UnitIsDead and UnitIsDead("target") then
        return UnitName("target")
    end
    return nil
end

--- Store one dropped item. Returns the stored entry, or nil when it was a
--- duplicate (the same corpse seen twice) or below RECORD_QUALITY.
function Drops:Record(entry)
    local itemID = tonumber(entry.itemID)
    local quality = tonumber(entry.quality) or 0
    if not itemID or quality < self.RECORD_QUALITY then return nil end

    local when = tonumber(entry.t) or Now()
    local key = entry.key
    if not key then
        -- The loot source GUID identifies the corpse, so reopening it (or
        -- LOOT_READY and LOOT_OPENED both firing) records nothing new.
        local corpse = entry.guid or ("t%d"):format(math.floor(when / 600))
        key = ("%s:%d:%s"):format(corpse, itemID, tostring(entry.slot or 1))
    end
    if Keys()[key] then return nil end

    local drop = {
        key = key,
        t = when,
        itemID = itemID,
        itemLink = entry.itemLink,
        itemName = entry.itemName or (type(entry.itemLink) == "string" and entry.itemLink:match("%[(.-)%]")) or nil,
        quality = quality,
        count = tonumber(entry.count) or 1,
        source = entry.source,
        zone = entry.zone,
        via = entry.via or "loot", -- "loot" = seen on a corpse, "chat" = seen in chat only
        lootedBy = entry.lootedBy, -- who physically picked it up, not who it was assigned to
        lootedNorm = entry.lootedNorm,
        lootedAt = entry.lootedAt,
        test = entry.test and true or nil, -- /lchelp testdrops, never a real drop
    }

    tinsert(Log(), drop)
    Keys()[key] = true
    self:Prune()
    self:RefreshIfShown()
    return drop
end

--- Read the open loot window. Returns how many new drops were stored.
function Drops:ScanLootWindow()
    if not self:ShouldTrack() then return 0 end
    if type(GetNumLootItems) ~= "function" then return 0 end

    local slots = GetNumLootItems() or 0
    if slots < 1 then return 0 end

    local zone = GetRealZoneText and GetRealZoneText() or nil
    local now, recorded = Now(), 0

    for slot = 1, slots do
        local isItem = true
        if GetLootSlotType then
            isItem = GetLootSlotType(slot) == (LOOT_SLOT_ITEM or 1) -- skip coin and currency
        end

        local itemLink = isItem and GetLootSlotLink and GetLootSlotLink(slot) or nil
        if itemLink then
            local _, itemName, count, _, quality = GetLootSlotInfo(slot)
            local guid = GetLootSourceInfo and GetLootSourceInfo(slot) or nil

            local stored = self:Record({
                t = now,
                itemID = LC:ItemIDFromLink(itemLink),
                itemLink = itemLink,
                itemName = itemName,
                quality = QualityOf(itemLink, quality),
                count = count,
                guid = guid,
                slot = slot,
                source = self:SourceName(guid),
                zone = zone,
            })
            if stored then recorded = recorded + 1 end
        end
    end

    return recorded
end

------------------------------------------------------------------------------
-- Chat receipts (CHAT_MSG_LOOT)
------------------------------------------------------------------------------

local function Deformat(message, fmt)
    if type(fmt) ~= "string" then return nil end
    local lib = LibStub and LibStub("LibDeformat-3.0", true)
    if not lib then return nil end
    return lib(message, fmt)
end

--- "Bob receives loot: [Item]x2." -> itemLink, "Bob", 2
--- The four shapes Blizzard uses; the globals carry the client's locale.
function Drops:ParseLootMessage(message)
    if type(message) ~= "string" then return nil end

    local who, link, count = Deformat(message, LOOT_ITEM_MULTIPLE)

    if not who then
        count = 1
        who, link = Deformat(message, LOOT_ITEM)
    end
    if not who then
        link, count = Deformat(message, LOOT_ITEM_SELF_MULTIPLE)
        if link then who = UnitName("player") end
    end
    if not link then
        count = 1
        link = Deformat(message, LOOT_ITEM_SELF)
        if link then who = UnitName("player") end
    end

    if not link or not who then return nil end
    return link, who, tonumber(count) or 1
end

--- The most recent drop of this item that we saw on a corpse and that nobody
--- has been recorded picking up yet.
function Drops:FindUnlooted(itemID, now)
    local best
    for _, d in ipairs(Log()) do
        local t = tonumber(d.t) or 0
        if d.itemID == itemID and not d.lootedBy and not d.test
            and t <= now and now - t <= self.RECEIPT_WINDOW
            and (not best or t > (tonumber(best.t) or 0)) then
            best = d
        end
    end
    return best
end

--- One CHAT_MSG_LOOT line. Everyone in the raid gets these, which is why the
--- list is the same on every council member's client without any comms.
function Drops:RecordReceipt(message)
    if not self:ShouldTrack() then return nil end

    local itemLink, looter, count = self:ParseLootMessage(message)
    if not itemLink then return nil end

    local itemID = LC:ItemIDFromLink(itemLink)
    local quality = QualityOf(itemLink)
    if not itemID or quality < self.RECORD_QUALITY then return nil end

    local now = Now()
    local norm = LC:NormalizeName(looter)

    -- Already on the list from its loot window: this is the same item being
    -- picked up, so fill the looter in rather than listing it a second time.
    local existing = self:FindUnlooted(itemID, now)
    if existing then
        existing.lootedBy = looter
        existing.lootedNorm = norm
        existing.lootedAt = now
        existing.itemLink = existing.itemLink or itemLink
        self:RefreshIfShown()
        return existing
    end

    return self:Record({
        key = ("chat:%d:%s:%d"):format(itemID, norm, now),
        t = now,
        itemID = itemID,
        itemLink = itemLink,
        quality = quality,
        count = count,
        via = "chat",
        lootedBy = looter,
        lootedNorm = norm,
        lootedAt = now,
        zone = GetRealZoneText and GetRealZoneText() or nil,
    })
end

--- Throw away weeks we no longer show, and cap the log.
function Drops:Prune()
    local log = Log()
    local cutoff = self:WeekStart() - (self.KEEP_WEEKS - 1) * WEEK

    local kept = {}
    for _, d in ipairs(log) do
        if (tonumber(d.t) or 0) >= cutoff then tinsert(kept, d) end
    end
    while #kept > self.MAX_ENTRIES do table.remove(kept, 1) end

    if #kept ~= #log then
        LC.db.drops = kept
        self:Invalidate()
    end
end

--- Forget every recorded drop. Returns how many were removed.
function Drops:Clear()
    local removed = #Log()
    LC.db.drops = {}
    self:Invalidate()
    self:RefreshIfShown()
    return removed
end

------------------------------------------------------------------------------
-- Test data (/lchelp testdrops true|false)
------------------------------------------------------------------------------
--
-- Fake drops so the list, the week stepper and the award pairing can be
-- exercised outside a raid. Everything written here is flagged `test` and
-- keyed with TEST_PREFIX, so removing it can never touch a real drop.

Drops.TEST_PREFIX = "test:"
Drops.TEST_AWARDS = 30 -- at most this many drops built from real awards

local function WishlistName(wishIndex, itemID)
    for _, p in pairs(wishIndex[itemID] or {}) do
        if p.itemName and p.itemName ~= "" then return p.itemName end
    end
    return "Test item " .. tostring(itemID)
end

local function CachedLink(itemID)
    if not GetItemInfo then return nil end
    local _, link = GetItemInfo(itemID)
    return link
end

--- Fill the log with test drops. Returns how many were added.
function Drops:AddTestData()
    self:RemoveTestData()

    local now = Now()
    local oldest = self:WeekStart() - (self.KEEP_WEEKS - 1) * WEEK
    local added = 0

    -- Real awards from the weeks we keep, each with a drop placed five minutes
    -- before it. The pairing code then lights the "awarded to" column up on
    -- its own instead of us faking the result.
    local awards = {}
    for _, a in pairs(LC.Data:AwardIndexFlat()) do
        local when = tonumber(a.timestamp) or 0
        if when > oldest and when <= now then tinsert(awards, a) end
    end
    table.sort(awards, function(x, y) return (x.timestamp or 0) > (y.timestamp or 0) end)

    for i, a in ipairs(awards) do
        if i > self.TEST_AWARDS then break end
        local itemID = tonumber(a.itemID) or LC:ItemIDFromLink(a.itemLink)
        -- Mostly picked up by the winner, but every third one is held by
        -- someone else: the case where the master looter's bags were full
        local heldBy = (i % 3 == 0) and UnitName("player") or a.awardedTo
        if itemID and self:Record({
            key = self.TEST_PREFIX .. "award:" .. tostring(a.checksum),
            t = (a.timestamp or now) - 300,
            itemID = itemID,
            itemLink = a.itemLink,
            quality = 4,
            source = "Test data",
            zone = "Test data",
            lootedBy = heldBy,
            lootedNorm = LC:NormalizeName(heldBy),
            lootedAt = a.timestamp or now,
            test = true,
        }) then
            added = added + 1
        end
    end

    -- Unawarded drops in this week and the last, off the active wishlist, so
    -- the "N want" column, the blue filter and the < stepper have something.
    local wishIndex = LC.Data:WishlistIndex()
    local ids = {}
    for itemID in pairs(wishIndex) do tinsert(ids, itemID) end
    table.sort(ids)

    local weekStart = self:WeekStart()
    local spots = {
        -- clamped so a drop "an hour ago" cannot fall before this week's reset
        { t = math.max(weekStart + 60, now - 3600), quality = 4 },
        { t = math.max(weekStart + 60, now - 2 * 3600), quality = 4 },
        { t = math.max(weekStart + 60, now - 3 * 3600), quality = 3 }, -- blue: hidden until the box is ticked
        { t = math.max(weekStart + 60, now - 4 * 3600), quality = 4, count = 2 },
        { t = weekStart - 2 * DAY, quality = 4 },
        { t = weekStart - 2 * DAY - 3600, quality = 4 },
        { t = weekStart - 2 * DAY - 7200, quality = 3 },
    }

    for i, spot in ipairs(spots) do
        local itemID = ids[i]
        -- Every other one is already in someone's bags but not yet assigned
        local heldBy = (i % 2 == 1) and UnitName("player") or nil
        if itemID and self:Record({
            key = self.TEST_PREFIX .. "wish:" .. i,
            t = spot.t,
            itemID = itemID,
            itemLink = CachedLink(itemID),
            itemName = WishlistName(wishIndex, itemID),
            quality = spot.quality,
            count = spot.count,
            source = "Test data",
            zone = "Test data",
            lootedBy = heldBy,
            lootedNorm = heldBy and LC:NormalizeName(heldBy) or nil,
            lootedAt = heldBy and spot.t or nil,
            test = true,
        }) then
            added = added + 1
        end
    end

    self:RefreshIfShown()
    return added
end

--- Take the test drops back out, leaving real ones alone. Returns how many.
function Drops:RemoveTestData()
    local log = Log()
    local kept, removed = {}, 0

    for _, d in ipairs(log) do
        if self:IsTest(d) then
            removed = removed + 1
        else
            tinsert(kept, d)
        end
    end

    if removed > 0 then
        LC.db.drops = kept
        self:Invalidate()
        self:RefreshIfShown()
    end
    return removed
end

function Drops:IsTest(drop)
    if type(drop) ~= "table" then return false end
    if drop.test then return true end
    return type(drop.key) == "string" and drop.key:sub(1, #self.TEST_PREFIX) == self.TEST_PREFIX
end

function Drops:TestDataCount()
    local n = 0
    for _, d in ipairs(Log()) do
        if self:IsTest(d) then n = n + 1 end
    end
    return n
end

------------------------------------------------------------------------------
-- The list
------------------------------------------------------------------------------

--- One raid week's drops, newest first. Each is paired with the award of that
--- item that followed it, so the list can say who ended up with it, and with
--- the raiders who have it on their wishlist.
function Drops:List(opts)
    opts = opts or {}
    local from, to = self:WeekBounds(opts.weekOffset or self.weekOffset)
    local minQuality = opts.minQuality or (Settings().dropsIncludeRare and self.RECORD_QUALITY or self.SHOW_QUALITY)

    local window = {}
    for _, d in ipairs(Log()) do
        local t = tonumber(d.t) or 0
        if t >= from and t < to and (tonumber(d.quality) or 0) >= minQuality then
            tinsert(window, d)
        end
    end

    -- Oldest first while pairing, so two of the same item line up with the
    -- two awards that followed them, in order
    table.sort(window, function(a, b)
        if (a.t or 0) ~= (b.t or 0) then return (a.t or 0) < (b.t or 0) end
        return tostring(a.key) < tostring(b.key)
    end)

    local awardIndex = LC.Data:AwardIndex()
    local wishIndex = LC.Data:WishlistIndex()
    local pools, claimed = {}, {}

    local function awardsFor(itemID)
        local list = pools[itemID]
        if list then return list end

        list = {}
        for _, id in ipairs(LC.Data:LinkedItemIDs(itemID)) do
            for _, entries in pairs(awardIndex[id] or {}) do
                for _, a in ipairs(entries) do tinsert(list, a) end
            end
        end
        table.sort(list, function(a, b) return (a.timestamp or 0) < (b.timestamp or 0) end)
        pools[itemID] = list
        return list
    end

    local rows = {}
    for _, d in ipairs(window) do
        local award
        for _, a in ipairs(awardsFor(d.itemID)) do
            local when = a.timestamp or 0
            if not claimed[a.checksum] and when >= d.t - self.AWARD_GRACE and when < to + DAY then
                award, claimed[a.checksum] = a, true
                break
            end
        end

        local wanters = {}
        for _, p in pairs(wishIndex[d.itemID] or {}) do
            tinsert(wanters, p)
        end
        table.sort(wanters, function(a, b)
            local pa, pb = a.bestPrio or 999, b.bestPrio or 999
            if pa ~= pb then return pa < pb end
            return tostring(a.displayName) < tostring(b.displayName)
        end)

        tinsert(rows, {
            t = d.t,
            itemID = d.itemID,
            itemLink = d.itemLink,
            itemName = d.itemName,
            quality = d.quality,
            count = d.count,
            source = d.source,
            zone = d.zone,
            via = d.via,
            lootedBy = d.lootedBy,
            lootedNorm = d.lootedNorm,
            lootedAt = d.lootedAt,
            test = d.test,
            award = award,
            wanters = wanters,
        })
    end

    -- Newest first for display
    local out = {}
    for i = #rows, 1, -1 do tinsert(out, rows[i]) end
    return out
end

------------------------------------------------------------------------------
-- The panel on the Wishlist Awards page
------------------------------------------------------------------------------

local ROW_HEIGHT, ROWS, HEAD_HEIGHT = 18, 21, 14
-- "Tue 09:41" needs the room: at 56 the date was truncating to "Tue 09..."
local TIME_WIDTH, LOOT_WIDTH, STATUS_WIDTH = 72, 88, 96

local panel -- the container Graph.lua hands us
local rows = {}
Drops._rows = rows -- exposed for tests

--- Class colour for a raider we know from the wishlist data
local function NameHex(norm)
    local entry = LC.Data:Roster()[norm or ""]
    return LC:ClassHex(entry and entry.class)
end

--- Who picked the item up (not who it ended up with)
local function LootedText(r)
    if not r.lootedBy then return "" end
    local who = LC:Capitalize(LC:NormalizeName(r.lootedBy))
    return ("|cff%s%s|r"):format(NameHex(r.lootedNorm), who)
end

--- Who Gargul assigned it to
local function StatusText(r)
    if r.award then
        local class = r.award.winnerClass
        local who = LC:Capitalize(LC:NormalizeName(r.award.awardedTo or "?"))
        return ("|cff%s%s|r%s"):format(LC:ClassHex(class), who, r.award.OS and " |cff7f7f7fOS|r" or "")
    end
    if #r.wanters > 0 then
        return ("|cffffd100%d want|r"):format(#r.wanters)
    end
    return "|cff5f5f5f-|r"
end

function Drops:BuildPanel(container)
    panel = container

    local prev = CreateFrame("Button", "LootCheckDropsPrevWeek", container, "UIPanelButtonTemplate")
    prev:SetSize(22, 20)
    prev:SetPoint("TOPLEFT", 0, 0)
    prev:SetText("<")
    prev:SetScript("OnClick", function() Drops:StepWeek(1) end)
    container.prevWeek = prev

    local nextWeek = CreateFrame("Button", "LootCheckDropsNextWeek", container, "UIPanelButtonTemplate")
    nextWeek:SetSize(22, 20)
    nextWeek:SetPoint("LEFT", prev, "RIGHT", 2, 0)
    nextWeek:SetText(">")
    nextWeek:SetScript("OnClick", function() Drops:StepWeek(-1) end)
    container.nextWeek = nextWeek

    -- The count is placed first so the week label can be bounded against it:
    -- without that the date range ran underneath the counts
    container.count = LC.Window:Text(container, "GameFontHighlightSmall")
    container.count:SetPoint("TOPRIGHT", 0, -4)
    container.count:SetJustifyH("RIGHT")

    container.week = LC.Window:Text(container, "GameFontNormalSmall")
    container.week:SetPoint("LEFT", nextWeek, "RIGHT", 6, 0)
    container.week:SetPoint("RIGHT", container.count, "LEFT", -8, 0)

    local includeRare = CreateFrame("CheckButton", "LootCheckDropsIncludeRare", container, "UICheckButtonTemplate")
    includeRare:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", -4, -2)
    includeRare:SetSize(24, 24)
    includeRare:SetScript("OnClick", function(self)
        Settings().dropsIncludeRare = self:GetChecked() and true or false
        Drops:RefreshPanel()
    end)
    container.includeRare = includeRare

    local rareLabel = LC.Window:Text(container, "GameFontHighlightSmall")
    rareLabel:SetPoint("LEFT", includeRare, "RIGHT", 2, 0)
    rareLabel:SetPoint("RIGHT", container, "RIGHT", -2, 0)
    rareLabel:SetText("Include blue items")
    container.rareLabel = rareLabel

    local inset = LC.Window:CreateInset(container, "LootCheckDropsInset")
    inset:SetPoint("TOPLEFT", includeRare, "BOTTOMLEFT", 4, -2)
    inset:SetPoint("BOTTOMRIGHT", 0, 0)
    container.inset = inset

    local scroll = CreateFrame("ScrollFrame", "LootCheckDropsScroll", inset, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() Drops:RefreshPanel() end)
    end)
    container.scroll = scroll

    -- Column headings, laid out with the same anchors as a row so they line up
    local head = CreateFrame("Frame", nil, inset)
    head:SetHeight(HEAD_HEIGHT)
    head:SetPoint("TOPLEFT", 8, -5)
    head:SetPoint("RIGHT", inset, "RIGHT", -30, 0)

    head.status = LC.Window:Text(head, "GameFontDisableSmall")
    head.status:SetPoint("RIGHT", head, "RIGHT", -2, 0)
    head.status:SetWidth(STATUS_WIDTH)
    head.status:SetJustifyH("RIGHT")
    head.status:SetText("Assigned")

    head.looted = LC.Window:Text(head, "GameFontDisableSmall")
    head.looted:SetPoint("RIGHT", head.status, "LEFT", -6, 0)
    head.looted:SetWidth(LOOT_WIDTH)
    head.looted:SetJustifyH("RIGHT")
    head.looted:SetText("Looted by")

    head.item = LC.Window:Text(head, "GameFontDisableSmall")
    head.item:SetPoint("LEFT", head, "LEFT", TIME_WIDTH + 6, 0)
    head.item:SetText("Item")
    container.head = head

    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, inset)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 8, -6 - HEAD_HEIGHT - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", inset, "RIGHT", -30, 0)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self) Drops:ShowRowTooltip(self) end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnMouseUp", function(self)
            -- Shift-click links it into chat, like any other item in the UI
            if self.data and self.data.itemLink and HandleModifiedItemClick then
                HandleModifiedItemClick(self.data.itemLink)
            end
        end)

        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)

        row.time = LC.Window:Text(row, "GameFontDisableSmall")
        row.time:SetPoint("LEFT", 2, 0)
        row.time:SetWidth(TIME_WIDTH)

        row.status = LC.Window:Text(row, "GameFontHighlightSmall")
        row.status:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row.status:SetWidth(STATUS_WIDTH)
        row.status:SetJustifyH("RIGHT")

        row.looted = LC.Window:Text(row, "GameFontHighlightSmall")
        row.looted:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
        row.looted:SetWidth(LOOT_WIDTH)
        row.looted:SetJustifyH("RIGHT")

        -- One line per drop: a long item name truncates rather than wrapping
        row.text = LC.Window:Text(row, "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row.time, "RIGHT", 6, 0)
        row.text:SetPoint("RIGHT", row.looted, "LEFT", -6, 0)

        row:Hide()
        rows[i] = row
    end

    container.empty = LC.Window:Text(inset, "GameFontHighlight", 200)
    container.empty:SetPoint("TOPLEFT", 12, -12)
    container.empty:SetPoint("RIGHT", inset, "RIGHT", -12, 0)
    container.empty:Hide()
end

function Drops:StepWeek(by)
    local offset = self.weekOffset + (by or 0)
    if offset < 0 then offset = 0 end
    if offset > self.KEEP_WEEKS - 1 then offset = self.KEEP_WEEKS - 1 end
    self.weekOffset = offset
    self:RefreshPanel()
end

function Drops:RefreshPanel()
    if not panel then return end

    panel.week:SetText(self:WeekLabel(self.weekOffset))
    panel.includeRare:SetChecked(Settings().dropsIncludeRare and true or false)
    if self.weekOffset <= 0 then panel.nextWeek:Disable() else panel.nextWeek:Enable() end
    if self.weekOffset >= self.KEEP_WEEKS - 1 then panel.prevWeek:Disable() else panel.prevWeek:Enable() end

    local list = self:List()
    self._list = list

    FauxScrollFrame_Update(panel.scroll, #list, ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(panel.scroll) or 0

    for i = 1, ROWS do
        local r, row = list[offset + i], rows[i]
        if r then
            row.time:SetText(date("%a %H:%M", r.t))
            local label = r.itemLink or r.itemName or ("item:" .. tostring(r.itemID))
            if (tonumber(r.count) or 1) > 1 then
                label = ("%s |cffaaaaaax%d|r"):format(label, r.count)
            end
            row.text:SetText(label)
            row.looted:SetText(LootedText(r))
            row.status:SetText(StatusText(r))
            row.data = r
            row:Show()
        else
            row:Hide()
            row.data = nil
        end
    end

    local awarded, fake = 0, 0
    for _, r in ipairs(list) do
        if r.award then awarded = awarded + 1 end
        if r.test then fake = fake + 1 end
    end
    -- Test data is called out so it is never mistaken for a real raid week
    panel.count:SetText(("%d dropped, %d awarded%s"):format(
        #list, awarded, fake > 0 and (" |cffff7f3f(%d test)|r"):format(fake) or ""))

    if #list == 0 then
        panel.empty:SetText(self.weekOffset == 0
            and "Nothing recorded yet this week. Drops are logged when you open a corpse in a raid."
            or "Nothing was recorded that week.")
        panel.empty:Show()
    else
        panel.empty:Hide()
    end
end

function Drops:ShowRowTooltip(row)
    local r = row.data
    if not r then return end

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if r.itemLink and GameTooltip.SetHyperlink then
        -- The item's own tooltip, so LootCheck's wishlist section shows up here too
        GameTooltip:SetHyperlink(r.itemLink)
    else
        GameTooltip:AddLine(r.itemName or ("item:" .. tostring(r.itemID)))
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(r.via == "chat" and "Looted" or "Dropped",
        date("%a %d %b, %H:%M", r.t), 1, 1, 1, 0.8, 0.8, 0.8)
    if r.source then
        GameTooltip:AddDoubleLine("From", r.source, 1, 1, 1, 0.8, 0.8, 0.8)
    end
    if r.zone then
        GameTooltip:AddDoubleLine("Zone", r.zone, 1, 1, 1, 0.8, 0.8, 0.8)
    end

    -- Who picked it up is a separate fact from who it was assigned to: the
    -- master looter's bags fill up, so items are often held by someone else
    if r.lootedBy then
        local who = LC:Capitalize(LC:NormalizeName(r.lootedBy))
        if r.lootedAt and r.lootedAt > r.t + 60 then
            who = ("%s, %s"):format(who, date("%H:%M", r.lootedAt))
        end
        GameTooltip:AddDoubleLine("Picked up by", who, 1, 1, 1, 0.8, 0.8, 0.8)
    else
        GameTooltip:AddDoubleLine("Picked up by", "nobody yet", 1, 1, 1, 0.7, 0.7, 0.7)
    end

    if r.award then
        local who = LC:Capitalize(LC:NormalizeName(r.award.awardedTo or "?"))
        GameTooltip:AddDoubleLine("Awarded to", who .. (r.award.OS and " (OS)" or ""), 1, 1, 1, LC:ClassColor(r.award.winnerClass))
    else
        GameTooltip:AddDoubleLine("Awarded to", "nobody yet", 1, 1, 1, 0.7, 0.7, 0.7)
    end

    GameTooltip:Show()
end

--- Only the drops column needs redrawing when a corpse is looted: rebuilding
--- the whole graph once per item in the loot window would be wasteful.
function Drops:RefreshIfShown()
    if LC.Window and LC.Window:IsShowing("graph") then self:RefreshPanel() end
end

------------------------------------------------------------------------------
-- Loot window
------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("LOOT_READY")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:SetScript("OnEvent", function(_, event, message)
    if event == "CHAT_MSG_LOOT" then
        pcall(Drops.RecordReceipt, Drops, message)
    else
        -- LOOT_READY and LOOT_OPENED both fire for the same corpse; the
        -- second one records nothing new
        pcall(Drops.ScanLootWindow, Drops)
    end
end)
