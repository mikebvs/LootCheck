--[[
    LootCheck - Comm.lua

    Sending the active wishlist dataset to chosen players in your group.

        /lchelp send            - open the Wishlist Data page's "Send to" list
        Wishlist Data > Send to - tick the players, press Send

    The wire format is the same CSV the Export button produces, compressed with
    LibDeflate and sent with AceComm as a WHISPER to each chosen player, so
    nobody else in the raid receives it. On the other end LootCheck asks the
    player what to do with it: save it as a new raid, merge it into the raid
    they are on, or discard it. Nothing is ever applied without them choosing.

    The same ticked list is also your share list: with "share my manual edits"
    turned on, every giveitem / removeitem / addwlitem / removewlitem you run is
    whispered to those players and applied on their end.

    Messages (protocol 1):
        P|1              "who here has LootCheck?", sent to the group
        R|1|<version>    the reply, whispered back
        D|1|<payload>    a dataset, whispered to one player
        E|1|<kind>|...   one manual edit, whispered to your share list

    Datasets are only accepted from someone in your own group, and only after
    the receiving player picks an option, because addon messages are not
    authenticated: anything arriving here is treated as a proposal, not a fact.
]]

local LC = LootCheck
local Comm = {}
LC.Comm = Comm

local PREFIX = "LootCheck"
local PROTOCOL = 1
local MAX_TEXT = 400000 -- refuse absurd payloads rather than chew through memory

local AceComm = LibStub and LibStub("AceComm-3.0", true)
local LibDeflate = LibStub and LibStub("LibDeflate", true)

Comm.peers = {}  -- normName -> { version, at, source, protocol, incompatible } for players who answered a ping
Comm.queue = {}  -- datasets waiting for this player to choose what to do
Comm.ready = false

local prompt -- the "someone sent you data" frame, built lazily

local function Now()
    return GetServerTime and GetServerTime() or 0
end

local function MyName()
    return LC:NormalizeName(UnitName and UnitName("player") or "")
end

------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------

function Comm:Init()
    if not AceComm or not LibDeflate then
        self.disabledReason = "the AceComm / LibDeflate libraries did not load"
        return false
    end

    AceComm:Embed(self)
    self:RegisterComm(PREFIX, "OnCommReceived")
    self.ready = true
    return true
end

--- true, or false plus the reason sending is unavailable
function Comm:Available()
    if self.ready then return true end
    return false, self.disabledReason or "sync is not initialised"
end

------------------------------------------------------------------------------
-- Payload encoding (the Export text, compressed for the addon channel)
------------------------------------------------------------------------------

function Comm:Encode(text)
    local compressed = LibDeflate:CompressDeflate(text, { level = 5 })
    return LibDeflate:EncodeForWoWAddonChannel(compressed)
end

function Comm:Decode(payload)
    local compressed = LibDeflate:DecodeForWoWAddonChannel(payload)
    if not compressed then return nil end
    return LibDeflate:DecompressDeflate(compressed)
end

------------------------------------------------------------------------------
-- Group roster
------------------------------------------------------------------------------

--- Everyone in your group except you: { { name, norm, class }, ... } sorted by name.
--- `name` keeps the realm when there is one, so whispers reach cross-realm players.
function Comm:GroupRoster()
    local list, seen = {}, {}
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    if count < 1 then return list end

    local unitPrefix = (IsInRaid and IsInRaid()) and "raid" or "party"
    local me = MyName()

    for i = 1, count do
        local unit = unitPrefix .. i
        local name = (GetUnitName and GetUnitName(unit, true)) or (UnitName and UnitName(unit))
        local norm = LC:NormalizeName(name or "")

        if norm ~= "" and norm ~= me and not seen[norm] then
            seen[norm] = true
            local _, class = UnitClass and UnitClass(unit)
            tinsert(list, { name = name, norm = norm, class = class })
        end
    end

    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return list
end

--- Guild members who are online, except you: { { name, norm, class }, ... }.
--- Offline members cannot answer a ping, so they are left out.
function Comm:GuildRoster()
    local list, seen = {}, {}
    if not (IsInGuild and IsInGuild()) then return list end

    -- Ask the server to refresh the roster; the reply lands asynchronously, so
    -- this call is for next time as much as for now
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        pcall(C_GuildInfo.GuildRoster)
    elseif GuildRoster then
        pcall(GuildRoster)
    end

    local total = GetNumGuildMembers and GetNumGuildMembers() or 0
    local me = MyName()

    for i = 1, total do
        local name, _, _, _, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
        local norm = LC:NormalizeName(name or "")

        if online and norm ~= "" and norm ~= me and not seen[norm] then
            seen[norm] = true
            tinsert(list, { name = name, norm = norm, class = class })
        end
    end

    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return list
end

--- Everyone who could answer a ping: group and online guild, merged.
--- `where` says which of the two (or "group+guild") each player came from.
function Comm:PingableRoster()
    local merged, order = {}, {}

    local function add(member, where)
        local existing = merged[member.norm]
        if existing then
            if not existing.where:find(where, 1, true) then
                existing.where = existing.where .. "+" .. where
            end
            existing.class = existing.class or member.class
            return
        end
        merged[member.norm] = {
            name = member.name, norm = member.norm, class = member.class, where = where,
        }
        tinsert(order, member.norm)
    end

    for _, member in ipairs(self:GroupRoster()) do add(member, "group") end
    for _, member in ipairs(self:GuildRoster()) do add(member, "guild") end

    local list = {}
    for _, norm in ipairs(order) do tinsert(list, merged[norm]) end
    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return list
end

function Comm:InGroup(norm)
    for _, member in ipairs(self:GroupRoster()) do
        if member.norm == norm then return true end
    end
    return false
end

--- Has this player answered a ping recently?
function Comm:HasAddon(norm)
    local peer = self.peers[norm]
    return peer ~= nil, peer and peer.version or nil
end

--- Remember who answered a ping and what they are running.
function Comm:RecordPeer(norm, version, theirProtocol)
    self.peers[norm] = {
        version = (version ~= nil and version ~= "" and version) or "?",
        at = Now(),
        protocol = theirProtocol,
        -- They have the addon, they just cannot exchange data with this build
        incompatible = (theirProtocol ~= PROTOCOL) or nil,
    }

    if LC.Imports and LC.Imports.RefreshSendList then LC.Imports:RefreshSendList() end
    if LC.Council and LC.Council.RefreshIfShown then LC.Council:RefreshIfShown() end
end

--- Compare two version strings numerically: -1, 0 or 1.
--- "1.0.10" is newer than "1.0.9", which a plain string compare gets wrong.
function Comm:CompareVersions(a, b)
    local function parts(v)
        local out = {}
        for n in tostring(v or ""):gmatch("%d+") do tinsert(out, tonumber(n)) end
        return out
    end

    local left, right = parts(a), parts(b)
    for i = 1, math.max(#left, #right) do
        local x, y = left[i] or 0, right[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

------------------------------------------------------------------------------
-- Sending
------------------------------------------------------------------------------

--- Ask the group who else is running LootCheck; replies fill Comm.peers
function Comm:Ping()
    if not self.ready then return false end

    local channel
    if IsInRaid and IsInRaid() then
        channel = "RAID"
    elseif (GetNumGroupMembers and GetNumGroupMembers() or 0) > 0 then
        channel = "PARTY"
    end
    if not channel then return false end

    self:SendCommMessage(PREFIX, ("P|%d"):format(PROTOCOL), channel, nil, "ALERT")
    return true
end

--- Ask the guild the same question. One message reaches every online member.
function Comm:PingGuild()
    if not self.ready then return false end
    if not (IsInGuild and IsInGuild()) then return false end

    self:SendCommMessage(PREFIX, ("P|%d"):format(PROTOCOL), "GUILD", nil, "ALERT")
    return true
end

--- Ping the group and the guild. Returns how many channels were asked, so the
--- caller can say "you are not in a group or a guild" rather than fail silently.
function Comm:PingAll()
    local asked = 0
    if self:Ping() then asked = asked + 1 end
    if self:PingGuild() then asked = asked + 1 end
    return asked
end

--- Send the active dataset to the named players (one whisper stream each)
function Comm:SendDataset(targets)
    local ok, reason = self:Available()
    if not ok then
        LC:Print("cannot send: " .. tostring(reason) .. ".")
        return false
    end

    targets = targets or {}
    if #targets < 1 then
        LC:Print("pick at least one player to send to.")
        return false
    end

    local text = LC.Imports:ExportText()
    if not text then
        LC:Print("there is no wishlist data to send.")
        return false
    end

    local data = LC:WishlistData()
    local payload = ("D|%d|%s"):format(PROTOCOL, self:Encode(text))
    local names = {}

    self.progress = {}
    for _, name in ipairs(targets) do
        tinsert(names, LC:Capitalize(LC:NormalizeName(name)))
        self.progress[name] = 0

        self:SendCommMessage(PREFIX, payload, "WHISPER", name, "BULK", function(_, sent, total)
            Comm.progress[name] = (total or 0) > 0 and (sent / total) or 1
            if LC.Imports and LC.Imports.RefreshSendStatus then
                LC.Imports:RefreshSendStatus()
            end
        end, name)
    end

    LC:Print(("sending |cffffffff%s|r (%d entries, %d bytes on the wire) to %s."):format(
        tostring(data and data.source or "?"), #data.wishlists, #payload, table.concat(names, ", ")))
    return true
end

------------------------------------------------------------------------------
-- Receiving
------------------------------------------------------------------------------

function Comm:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= PREFIX or type(message) ~= "string" or type(sender) ~= "string" then return end

    local norm = LC:NormalizeName(sender)
    if norm == "" or norm == MyName() then return end

    local kind, protocol, body = message:match("^(%a)|(%d+)|?(.*)$")
    if not kind then return end

    local theirProtocol = tonumber(protocol)

    -- Pings and their replies still cross protocol versions on purpose: seeing
    -- who is on an incompatible one is exactly what the Loot Council page is
    -- for. Everything that moves data needs a protocol we actually understand.
    if theirProtocol ~= PROTOCOL and kind ~= "P" and kind ~= "R" then
        if not self.warnedAboutProtocol then
            self.warnedAboutProtocol = true
            LC:Print(("%s is running a different LootCheck sync version, so data cannot be exchanged."):format(LC:Capitalize(norm)))
        end
        return
    end

    if kind == "P" then
        self:SendCommMessage(PREFIX, ("R|%d|%s"):format(PROTOCOL, tostring(LC.version)), "WHISPER", sender, "ALERT")

    elseif kind == "R" then
        self:RecordPeer(norm, body, theirProtocol)

    elseif kind == "D" then
        self:ReceiveDataset(norm, body)

    elseif kind == "E" then
        self:ReceiveEdit(norm, body)
    end
end

function Comm:ReceiveDataset(norm, payload)
    -- Only from someone in your own group: addon messages are not authenticated
    if not self:InGroup(norm) then return end

    local text = payload ~= "" and self:Decode(payload) or nil
    if not text or #text > MAX_TEXT then
        LC:Print(("could not read the wishlist data %s sent."):format(LC:Capitalize(norm)))
        return
    end

    local entries, _, headerOK, meta = LC.Imports:ParseCSV(text)
    if not headerOK or #entries == 0 then
        LC:Print(("%s sent wishlist data that LootCheck could not read."):format(LC:Capitalize(norm)))
        return
    end

    local characters = {}
    for _, e in ipairs(entries) do characters[LC:NormalizeName(e.character_name)] = true end
    local characterCount = 0
    for _ in pairs(characters) do characterCount = characterCount + 1 end

    tinsert(self.queue, {
        from = LC:Capitalize(norm),
        name = (meta.name and meta.name ~= "") and meta.name or (LC:Capitalize(norm) .. "'s raid"),
        entries = entries,
        characters = characterCount,
        shareId = meta.share,
    })

    LC:Print(("%s sent you wishlist data: |cffffffff%s|r (%d entries)."):format(
        LC:Capitalize(norm), self.queue[#self.queue].name, #entries))
    self:ShowPrompt()
end

------------------------------------------------------------------------------
-- Sharing manual edits
--
-- giveitem / removeitem / addwlitem / removewlitem are passed on to the players
-- on your share list, which is the same list of ticked players you send data to.
-- Both ends must have each other ticked with sharing on, so an edit can never
-- arrive from someone you have not chosen. Received edits run through exactly
-- the same code your own commands do (Awards:Apply*, Wishlist:Apply*), are
-- announced in chat and recorded in the audit log against the sender.
------------------------------------------------------------------------------

--- normName -> true for the players you share with (the send list's tick boxes)
function Comm:ShareList()
    LC.db = LC.db or LootCheckDB or {}
    if type(LC.db.shareWith) ~= "table" then LC.db.shareWith = {} end
    return LC.db.shareWith
end

function Comm:SharingEnabled()
    return LC.db and LC.db.settings and LC.db.settings.shareEdits and true or false
end

--- The players on your share list who are in the group right now, by full name
function Comm:SharePartners()
    local partners = {}
    if not self:SharingEnabled() then return partners end

    local list = self:ShareList()
    for _, member in ipairs(self:GroupRoster()) do
        if list[member.norm] then tinsert(partners, member.name) end
    end
    return partners
end

local EDIT_KINDS = {
    mark = true, unreceive = true, hide = true, unhide = true,
    wladd = true, wlremove = true,
}

--- Say who edits are being shared with, after the setting is toggled
function Comm:AnnounceSharing()
    if not self:SharingEnabled() then
        LC:Print("your manual edits are no longer shared.")
        return
    end

    local partners = self:SharePartners()
    if #partners < 1 then
        LC:Print("edit sharing is on, but nobody in your group is ticked yet.")
        return
    end

    local names = {}
    for _, name in ipairs(partners) do tinsert(names, LC:Capitalize(LC:NormalizeName(name))) end
    LC:Print(("your manual edits are now shared with %s (and theirs with you)."):format(table.concat(names, ", ")))
end

--- Pass one of your own edits on. Called by Awards.lua / Wishlist.lua.
function Comm:ShareEdit(kind, fields)
    if not self.ready or not EDIT_KINDS[kind] then return false end

    local partners = self:SharePartners()
    if #partners < 1 then return false end

    fields = fields or {}
    local message = ("E|%d|%s|%s|%s|%d|%d|%s|%s|%s|%s"):format(
        PROTOCOL,
        kind,
        tostring(LC.Imports:ActiveShareId() or "-"),
        tostring(fields.norm or ""),
        tonumber(fields.itemID) or 0,
        fields.os and 1 or 0,
        tostring(tonumber(fields.prio) or ""),
        tostring(tonumber(fields.timestamp) or ""),
        tostring(fields.class or ""),
        tostring(fields.itemName or ""))

    for _, target in ipairs(partners) do
        self:SendCommMessage(PREFIX, message, "WHISPER", target, "NORMAL")
    end
    return true
end

--- Apply an edit shared by someone else
function Comm:ReceiveEdit(senderNorm, body)
    if not self:SharingEnabled() then
        if not self.warnedAboutSharing then
            self.warnedAboutSharing = true
            LC:Print(("%s is sharing manual edits with you. To accept them, tick them in Wishlist Data > Send to and turn on 'share my manual edits'."):format(
                LC:Capitalize(senderNorm)))
        end
        return false
    end

    -- Only from someone you chose, who is in your group
    if not self:ShareList()[senderNorm] or not self:InGroup(senderNorm) then return false end

    local kind, shareId, norm, itemID, os, prio, timestamp, class, itemName =
        body:match("^(%a+)|([^|]*)|([^|]*)|(%d+)|(%d)|([^|]*)|([^|]*)|([^|]*)|(.*)$")

    itemID = tonumber(itemID)
    if not kind or not EDIT_KINDS[kind] or not itemID or norm == "" then return false end

    os = os == "1"
    prio = tonumber(prio)
    timestamp = tonumber(timestamp)
    itemName = (itemName ~= "" and itemName) or LC.Wishlist:ItemName(itemID)
    local from = LC:Capitalize(senderNorm)
    local who = LC:Capitalize(norm)

    -- Wishlist edits belong to one dataset: only apply them to the same one
    if kind == "wladd" or kind == "wlremove" then
        local match = LC.Imports:FindByShareId(shareId)
        local active = LC.Imports:Active()
        local activeId = active and active.id or (LC:TMBExportDB() and "tmbexport" or nil)

        if not match or match.id ~= activeId then
            if not self.warnedAboutDataset then
                self.warnedAboutDataset = true
                LC:Print(("%s is editing a wishlist you are not on right now, so those edits were skipped."):format(from))
            end
            return false
        end
    end

    if kind == "mark" then
        if LC.Awards:AlreadyReceived(norm, itemID, os) then return false end
        LC.Awards:ApplyMark(norm, itemID, itemName, nil, os, timestamp, from)
        LC:Print(("%s marked %s as received by %s%s."):format(from, itemName, who, os and " (OS)" or ""))

    elseif kind == "unreceive" then
        local removed = LC.Awards:ApplyUnreceive(norm, itemID, itemName, nil, from)
        if removed < 1 then return false end
        LC:Print(("%s un-marked %s for %s."):format(from, itemName, who))

    elseif kind == "hide" then
        local latest = LC.Awards:ApplyHide(norm, itemID, itemName, from)
        if not latest then return false end
        LC:Print(("%s hid Gargul's award of %s to %s."):format(from, itemName, who))

    elseif kind == "unhide" then
        if not LC.Awards:ApplyUnhide(norm, itemID, itemName, nil, from) then return false end
        LC:Print(("%s restored Gargul's award of %s to %s."):format(from, itemName, who))

    elseif kind == "wladd" then
        local outcome, detail = LC.Wishlist:ApplyAdd(norm, itemID, itemName, prio, os, class ~= "" and class or nil, from)
        if not outcome then return false end
        LC:Print(("%s put %s on %s's wishlist (prio %s)."):format(
            from, itemName, who, tostring(outcome == "restored" and detail or prio or "?")))

    elseif kind == "wlremove" then
        local removedManual, removedImported = LC.Wishlist:ApplyRemove(norm, itemID, itemName, from)
        if removedManual == 0 and not removedImported then return false end
        LC:Print(("%s took %s off %s's wishlist."):format(from, itemName, who))
    end

    return true
end

------------------------------------------------------------------------------
-- "Someone sent you data" prompt
------------------------------------------------------------------------------

local function BuildPrompt()
    local f = LC.Window:CreateInset(UIParent, "LootCheckCommPrompt")
    f:SetSize(430, 150)
    f:SetPoint("CENTER", 0, 120)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdropColor then f:SetBackdropColor(0.04, 0.04, 0.04, 0.97) end
    f:Hide()

    f.title = LC.Window:Text(f, "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -14)
    f.title:SetJustifyH("CENTER")
    f.title:SetText("LootCheck")

    f.text = LC.Window:Text(f, "GameFontHighlight", 390)
    f.text:SetPoint("TOP", f.title, "BOTTOM", 0, -10)
    f.text:SetJustifyH("CENTER")

    f.saveButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.saveButton:SetSize(120, 24)
    f.saveButton:SetPoint("BOTTOMLEFT", 18, 16)
    f.saveButton:SetText("Save as new")
    f.saveButton:SetScript("OnClick", function() Comm:Resolve("save") end)

    f.mergeButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.mergeButton:SetSize(150, 24)
    f.mergeButton:SetPoint("LEFT", f.saveButton, "RIGHT", 8, 0)
    f.mergeButton:SetText("Merge into mine")
    f.mergeButton:SetScript("OnClick", function() Comm:Resolve("merge") end)

    f.discardButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.discardButton:SetSize(100, 24)
    f.discardButton:SetPoint("LEFT", f.mergeButton, "RIGHT", 8, 0)
    f.discardButton:SetText("Discard")
    f.discardButton:SetScript("OnClick", function() Comm:Resolve("discard") end)

    tinsert(UISpecialFrames, "LootCheckCommPrompt")
    return f
end

function Comm:ShowPrompt()
    local item = self.queue[1]
    if not item then
        if prompt then prompt:Hide() end
        return
    end

    if not prompt then prompt = BuildPrompt() end
    self._prompt = prompt

    local active = LC.Imports:Active()
    local queued = #self.queue > 1 and ("|n|cffaaaaaa%d more waiting|r"):format(#self.queue - 1) or ""

    prompt.text:SetText(("|cffffffff%s|r sent you wishlist data:|n|cffffffff%s|r - %d entries, %d characters%s"):format(
        item.from, item.name, #item.entries, item.characters, queued))

    if active then
        prompt.mergeButton:SetText(("Merge into %s"):format(active.name))
        prompt.mergeButton:Show()
    else
        prompt.mergeButton:Hide()
    end

    prompt:Show()
end

--- "save", "merge" or "discard" the dataset at the front of the queue
function Comm:Resolve(choice)
    local item = table.remove(self.queue, 1)
    if not item then
        if prompt then prompt:Hide() end
        return false
    end

    if choice == "save" then
        LC.Imports:AddEntries(("%s (from %s)"):format(item.name, item.from), item.entries, 0, item.shareId)

    elseif choice == "merge" then
        local active = LC.Imports:Active()
        if not active then
            LC:Print("there is no raid to merge into, saving it as a new one instead.")
            LC.Imports:AddEntries(("%s (from %s)"):format(item.name, item.from), item.entries, 0, item.shareId)
        else
            local added, skipped = LC.Imports:Merge(active.id, item.entries, item.from, item.shareId)
            LC:Print(("merged %s's data into |cffffffff%s|r: %d new entries, %d duplicates skipped."):format(
                item.from, active.name, added or 0, skipped or 0))
        end

    else
        LC:Print(("discarded the wishlist data from %s."):format(item.from))
    end

    self:ShowPrompt()
    return true
end
