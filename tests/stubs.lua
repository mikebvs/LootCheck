-- Minimal WoW API stubs so the addon can run in plain Lua 5.1 / LuaJIT.

function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    io.write(table.concat(parts, " "), "\n")
    io.flush()
end

tinsert = table.insert
tremove = table.remove
strlower = string.lower
date = os.date
GetTime = os.clock
GetServerTime = os.time
UISpecialFrames = {}
SlashCmdList = {}
BackdropTemplateMixin = {}

RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00 }, SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
    DRUID = { r = 1.00, g = 0.49, b = 0.04 },
}

-- Group simulation --------------------------------------------------------
local groupMembers = {}
function SetTestGroup(list) groupMembers = list or {} end
function UnitName(unit)
    if unit == "player" then return "Steven" end
    if unit == "target" then return LootWindowSource and LootWindowSource() or nil end
    local idx = tonumber(unit:match("^raid(%d+)$") or unit:match("^party(%d+)$"))
    return idx and groupMembers[idx] or nil
end
function GetNumGroupMembers() return #groupMembers end
local unitClasses = {}
function SetTestClasses(map) unitClasses = map or {} end -- name -> class token, e.g. { Newguy = "ROGUE" }
function UnitClass(unit)
    local name = UnitName(unit)
    local token = name and unitClasses[name]
    if token then return token, token end
end
function GetItemInfo() return nil end -- nothing is cached client-side in the test VM

-- Loot window simulation ---------------------------------------------------
-- SetTestLoot{ guid = "Creature-1", source = "Prince Malchezaar", zone = "Karazhan",
--              items = { { id = 30627, name = "Tsunami Talisman", quality = 4, count = 1 }, ... } }
local lootWindow = { items = {} }
local instanceType = nil
LOOT_SLOT_ITEM = 1
function SetTestLoot(spec)
    lootWindow = spec or { items = {} }
    lootWindow.items = lootWindow.items or {}
end
function SetTestInstance(kind) instanceType = kind end
function IsInInstance()
    if not instanceType then return false, "none" end
    return true, instanceType
end
function GetNumLootItems() return #lootWindow.items end
function GetLootSlotType(slot)
    local item = lootWindow.items[slot]
    return item and (item.slotType or LOOT_SLOT_ITEM) or nil
end
function GetLootSlotLink(slot)
    local item = lootWindow.items[slot]
    if not item then return nil end
    return ("|cffa335ee|Hitem:%d::::::::70:::::|h[%s]|h|r"):format(item.id, item.name or ("item" .. item.id))
end
function GetLootSlotInfo(slot)
    local item = lootWindow.items[slot]
    if not item then return nil end
    return "texture", item.name, item.count or 1, nil, item.quality or 4
end
function GetLootSourceInfo(slot)
    local item = lootWindow.items[slot]
    return (item and item.guid) or lootWindow.guid
end
function GetRealZoneText() return lootWindow.zone end
function LootWindowSource() return lootWindow.source end
function UnitExists(unit) return unit == "target" and lootWindow.source ~= nil end
function UnitIsDead(unit) return unit == "target" and lootWindow.source ~= nil end
function UnitGUID(unit) return unit == "target" and lootWindow.guid or nil end
-- The enUS loot messages, as the client defines them
LOOT_ITEM = "%s receives loot: %s."
LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d."
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."

LootedItemLinks = {}
function HandleModifiedItemClick(link) tinsert(LootedItemLinks, link) end

-- Dropdown menus / popups / fonts used by the imports window
-- Blizzard's dropdown and popup systems taint the secure UI (they stopped the
-- game menu's Log Out button working), so LootCheck must never touch them:
-- calling one fails the test run instead of quietly working.
local function forbidden(name)
    return function()
        error("LootCheck must not use Blizzard's " .. name .. ": it taints the game menu", 2)
    end
end
UIDropDownMenu_Initialize = forbidden("UIDropDownMenu_Initialize")
UIDropDownMenu_CreateInfo = forbidden("UIDropDownMenu_CreateInfo")
UIDropDownMenu_AddButton = forbidden("UIDropDownMenu_AddButton")
UIDropDownMenu_SetText = forbidden("UIDropDownMenu_SetText")
UIDropDownMenu_SetWidth = forbidden("UIDropDownMenu_SetWidth")
UIDropDownMenu_JustifyText = forbidden("UIDropDownMenu_JustifyText")
UIDropDownMenu_SetSelectedValue = forbidden("UIDropDownMenu_SetSelectedValue")
StaticPopupDialogs = setmetatable({}, {
    __newindex = function() error("LootCheck must not add StaticPopupDialogs entries: they taint the game menu", 2) end,
})
function FauxScrollFrame_Update() end
function FauxScrollFrame_GetOffset(frame) return frame._offset or 0 end
function FauxScrollFrame_OnVerticalScroll() end
StaticPopup_Show = forbidden("StaticPopup_Show")
ChatFontNormal = {}
GameFontNormal = {}
function IsInRaid() return #groupMembers > 5 end
function IsInGroup() return #groupMembers > 0 end

-- Frames ------------------------------------------------------------------
EventFrames = {}

local Proto = {}
local noop = function() end
-- Frames answer any capitalised method name (no-op when unknown); plain data fields are nil like in WoW
local mt = { __index = function(_, key)
    if type(key) == "string" and key:match("^[A-Z]") then return Proto[key] or noop end
    return nil
end }

local function NewObject(kind, name)
    local obj = { _kind = kind, _name = name, _scripts = {}, _hooks = {}, _events = {}, _shown = false, _lines = 0 }
    return setmetatable(obj, mt)
end

function Proto:RegisterEvent(event)
    if not next(self._events) then tinsert(EventFrames, self) end
    self._events[event] = true
end
function Proto:UnregisterEvent(event) self._events[event] = nil end
function Proto:SetScript(name, fn) self._scripts[name] = fn end
function Proto:GetScript(name) return self._scripts[name] end
function Proto:HookScript(name, fn)
    self._hooks[name] = self._hooks[name] or {}
    tinsert(self._hooks[name], fn)
end
function Proto:Show() self._shown = true end
function Proto:Hide() self._shown = false end
function Proto:IsShown() return self._shown end
function Proto:GetName() return self._name end
function Proto:SetText(text) self._text = text end
function Proto:GetText() return self._text end
function Proto:SetChecked(v) self._checked = v and true or false end
function Proto:SetBackdrop(bd) self._backdrop = bd end
function Proto:GetBackdrop() return self._backdrop end
function Proto:SetBackdropColor(r, g, b, a) self._backdropColor = { r, g, b, a } end
function Proto:SetWordWrap(v) self._wordWrap = v and true or false end
function Proto:SetSpacing(v) self._spacing = v end
function Proto:GetChecked() return self._checked end
function Proto:SetWidth(w) self._width = w end
function Proto:SetHeight(h) self._height = h end
function Proto:SetSize(w, h) self._width, self._height = w, h end
function Proto:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
-- Anchors are remembered so the layout suite can assert that text which must
-- not run off a page is bounded on the right as well as the left
function Proto:SetPoint(...)
    self._points = self._points or {}
    tinsert(self._points, { ... })
end
function Proto:ClearAllPoints() self._points = {} end
function Proto:HasAnchor(point)
    for _, p in ipairs(self._points or {}) do
        if p[1] == point then return true end
    end
    return false
end
function Proto:CreateFontString(name) return NewObject("FontString", name) end
function Proto:CreateTexture(name) return NewObject("Texture", name) end
function Proto:NumLines() return self._lines end
function Proto:GetItem() return self._itemName, self._itemLink end
function Proto:ClearLines()
    for i = 1, self._lines do
        _G[self._name .. "TextLeft" .. i] = nil
        _G[self._name .. "TextRight" .. i] = nil
    end
    self._lines = 0
end
function Proto:AddLine(text)
    self._lines = self._lines + 1
    local fs = NewObject("FontString", self._name .. "TextLeft" .. self._lines)
    fs:SetText(text)
    _G[fs._name] = fs
end
function Proto:AddDoubleLine(left, right)
    self:AddLine(left)
    local fs = NewObject("FontString", self._name .. "TextRight" .. self._lines)
    fs:SetText(right)
    _G[fs._name] = fs
end

function CreateFrame(kind, name, parent, template)
    local obj = NewObject(kind, name)
    if name then _G[name] = obj end
    return obj
end

UIParent = CreateFrame("Frame", "UIParent")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip")

-- Test helpers ------------------------------------------------------------
function FireEvent(event, ...)
    for _, frame in ipairs(EventFrames) do
        if frame._events[event] and frame._scripts.OnEvent then
            frame._scripts.OnEvent(frame, event, ...)
        end
    end
end

--- Mimic Gargul: set the item, add the lines, then run every OnTooltipSetItem hook
function SimulateTooltip(tooltip, itemName, itemLink, lines)
    tooltip:ClearLines()
    tooltip._itemName, tooltip._itemLink = itemName, itemLink
    tooltip:AddLine(itemName)
    for _, line in ipairs(lines) do tooltip:AddLine(line) end
    for _, fn in ipairs(tooltip._hooks.OnTooltipSetItem or {}) do fn(tooltip) end
end

function DumpTooltip(tooltip)
    for i = 1, tooltip:NumLines() do
        print(("   line %d: %s"):format(i, tostring(_G[tooltip:GetName() .. "TextLeft" .. i]:GetText())))
    end
end
