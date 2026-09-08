--[[
    LootCheck - Help.lua

    The "Slash Commands" page (/lchelp help, or the Commands button on the
    home page), laid out like Gargul's own page: command in yellow,
    shorthands in pink, description underneath.

    Each entry's height is measured after its text is set, so descriptions
    that wrap onto several lines never overlap the next command.

    COMMANDS below is the single source of truth; LC:PrintHelp() (used by
    "/lchelp help chat") prints from the same table.
]]

local LC = LootCheck
local Help = {}
LC.Help = Help

local PAGE = "help"
local WIDTH, HEIGHT = 600, 520
local MARGIN = 22
local CONTENT_WIDTH = WIDTH - MARGIN * 2 - 40

Help.COMMANDS = {
    { cmd = "/lchelp", aliases = { "/lch", "/lootcheck", "/lchelp config", "/lchelp options" },
      desc = "Open the LootCheck window on its home page: status, basic settings, and buttons to the wishlist graph, wishlist data, audit and this list. Every page lives in this one window; < Back returns home." },
    { cmd = "/lchelp help", aliases = { "/lchelp commands" },
      desc = "Open this list. \"/lchelp help chat\" prints it to the chat frame instead." },
    { cmd = "/lchelp graph", args = "[days]", aliases = { "/lchg" },
      desc = "Open the wishlist award graph. The bars count awards that match the wishlist you currently have imported. The < > buttons filter by content phase instead (see /lchelp phase), and a number limits the bars to awards from the last that many days (0 = no limit). Both are remembered." },
    { cmd = "/lchelp phase", args = "[P4] [YYYY-MM-DD | reset]", aliases = { "/lchelp phases" },
      desc = "Show the content phase dates, or set one. Dates only drive the graph's phase filter (the < > buttons); they have nothing to do with the \"current wishlist\" number, which counts against the wishlist you have imported and changes when you re-import. P4 (Zul'Aman) and P5 (Sunwell) have no announced date yet, so set them yourself when Blizzard says: \"/lchelp phase P4 2026-10-15\". Your dates are remembered, and \"reset\" restores the default." },
    { cmd = "/lchelp council", aliases = { "/lchc", "/lchelp members" },
      desc = "Open the Loot Council page: who else is running LootCheck and which version, so you can see whether the council is on the same build. Opening it asks your group and every guild member who is online; replies arrive over a second or two, so use Check again if someone is missing. Anyone on an older version is flagged, and a check box also lists the players who were asked but did not answer." },
    { cmd = "/lchelp drops", args = "[clear]",
      desc = "Open the wishlist graph, whose right-hand column lists every rare and epic item that dropped in the raid this week, newest first, with who picked it up and who Gargul assigned it to. Those are separate columns on purpose: an item is often looted by whoever had bag space and only assigned later. Drops are read from the loot window and from loot messages in chat, which every client in the raid sees, so no addon-to-addon communication is needed. The arrows step back through earlier weeks; the list rolls over at the Tuesday raid reset. Hovering a drop shows its tooltip, so the wishlist is right there. \"clear\" forgets every recorded drop." },
    { cmd = "/lchelp grouponly",
      desc = "Toggle showing only raiders who are in your current group on the graph." },
    { cmd = "/lchelp audit", aliases = { "/lcha" },
      desc = "Open the Audit page: every item award in chronological order, newest first - Gargul awards including plain MS / OS roll wins, manual received marks, and your giveitem / removeitem / addwlitem / removewlitem commands. A check box hides awards whose item was not on the winner's wishlist." },
    { cmd = "/lchelp imports", aliases = { "/lchelp data", "/lchelp raids" },
      desc = "Open the Wishlist Data page: pick the active raid from the dropdown, paste a new That's My BIS CSV export as a named import, delete one, or Export the active dataset (manual edits included) as text another LootCheck user can paste into New import to sync with you." },
    { cmd = "/lchelp send",
      desc = "Open the Wishlist Data page's send list: tick the players in your group who should receive the active raid's wishlist data and press Send. It goes to those players only, as a whisper, and each of them chooses whether to save it as a new raid, merge it into the one they are on, or discard it. Players already running LootCheck are marked in the list." },
    { cmd = "/lchelp shareedits",
      desc = "Turn sharing of your manual edits on or off. While it is on, every giveitem, removeitem, addwlitem and removewlitem you run is passed to the players ticked in the send list and applied on their end, announced in their chat and recorded in their audit log against your name. You only receive their edits if you have ticked them too, so it takes both sides. Wishlist edits are only applied by players working from the same dataset you are." },
    { cmd = "/lchelp use", args = "<raid name>",
      desc = "Switch the active raid from chat. An exact name or a unique part of it works." },
    { cmd = "/lchelp giveitem", args = "<character> <item> [os] [force]",
      desc = "Mark an item as received by a character: they are greyed out on Gargul's TMB tooltip and it counts in the graph and the all-time history like a Gargul award. \"os\" records an off-spec receipt (greys, never counts). A duplicate is refused unless you add \"force\". If Gargul's award of that item to them was hidden with removeitem, this restores it. <item> can be a shift-clicked link, an item ID or a unique part of the name." },
    { cmd = "/lchelp removeitem", args = "<character> <item>",
      desc = "Undo giveitem. If there is no manual mark but Gargul recorded the award, hides that Gargul award from LootCheck instead - Gargul's own records are untouched." },
    { cmd = "/lchelp addwlitem", args = "<character> <item> [#prio] [os]", aliases = { "/lchelp additem", "/lchelp addwish" },
      desc = "Put an item on a character's wishlist for the active raid, e.g. for a PUG who is not in the export. Prio defaults to their next free slot; their class colour is picked up if they are in your group." },
    { cmd = "/lchelp removewlitem", args = "<character> <item>", aliases = { "/lchelp removewish" },
      desc = "Take an item off a character's wishlist. An imported entry is hidden (addwlitem puts it back); a manual one is deleted." },
    { cmd = "/lchelp wishlist", args = "<character>",
      desc = "Show a character's wishlist as LootCheck sees it: received items greyed, OS and manual entries tagged, plus their current-wishlist and all-time counts." },
    { cmd = "/lchelp check", args = "<item link>",
      desc = "Show who wishlists an item and who was awarded it (Gargul awards and manual marks)." },
    { cmd = "/lchelp overrides",
      desc = "List the manual wishlist edits for the active raid, the manual received marks and the hidden Gargul awards. \"/lchelp clearoverrides confirm\" wipes the active raid's wishlist edits." },
    { cmd = "/lchelp status",
      desc = "Show what LootCheck can see: Gargul, the wishlist source, tooltip integration, counts and settings." },
    { cmd = "/lchelp greyos",
      desc = "Toggle whether names that got the item via an OS roll are greyed out too (default: on)." },
    { cmd = "/lchelp tmbtooltip",
      desc = "Toggle TMBExport's own, separate tooltip list. LootCheck switches it off once so the wishlist is not shown twice." },
}

local rows = {}
Help._rows = rows -- exposed for tests

--- Rendered width of a one-line font string, with an estimate as a fallback
local function TextWidth(fontString, text, perChar)
    local w = fontString.GetStringWidth and fontString:GetStringWidth()
    if type(w) == "number" and w > 0 then return w end
    return #tostring(text) * (perChar or 7)
end

local function BuildPage(page)
    local inset = LC.Window:CreateInset(page, "LootCheckHelpFrameInset")
    inset:SetPoint("TOPLEFT", MARGIN - 4, -8)
    inset:SetPoint("BOTTOMRIGHT", -MARGIN, 18)

    local scroll = CreateFrame("ScrollFrame", "LootCheckHelpFrameScroll", inset, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(CONTENT_WIDTH, 10)
    scroll:SetScrollChild(content)

    local y = 2
    local intro = LC.Window:Text(content, "GameFontHighlight", CONTENT_WIDTH - 8)
    intro:SetPoint("TOPLEFT", 2, -y)
    intro:SetText("Every command can be typed as /lchelp <command> or /lootcheck <command>. Items can be given as a shift-clicked link, an item ID, or a unique part of the item's name.")
    y = y + LC.Window:TextHeight(intro, 3) + 16

    for _, c in ipairs(Help.COMMANDS) do
        local cmdText = c.cmd .. ((c.args and c.args ~= "") and (" |cffaaaaaa" .. c.args .. "|r") or "")
        local cmd = LC.Window:Text(content, "GameFontNormal")
        cmd:SetPoint("TOPLEFT", 2, -y)
        cmd:SetText(cmdText)

        -- Shorthands sit beside the command when they fit, on their own line otherwise
        local shorthand, ownLine
        if c.aliases and #c.aliases > 0 then
            local shorthandText = "|cffff7fd2Shorthands: " .. table.concat(c.aliases, ", ") .. "|r"
            shorthand = LC.Window:Text(content, "GameFontNormalSmall")
            shorthand:SetText(shorthandText)

            local cmdWidth = TextWidth(cmd, c.cmd .. " " .. (c.args or ""), 7)
            local shorthandWidth = TextWidth(shorthand, shorthandText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), 6)
            ownLine = (cmdWidth + 16 + shorthandWidth) > (CONTENT_WIDTH - 8)

            if ownLine then
                y = y + LC.Window:TextHeight(cmd, 1) + 2
                shorthand:SetPoint("TOPLEFT", 10, -y)
            else
                shorthand:SetPoint("LEFT", cmd, "RIGHT", 16, 0)
            end
        end

        y = y + LC.Window:TextHeight(ownLine and shorthand or cmd, 1) + 4

        local desc = LC.Window:Text(content, "GameFontHighlightSmall", CONTENT_WIDTH - 20)
        desc:SetPoint("TOPLEFT", 10, -y)
        desc:SetText(c.desc)
        desc:SetTextColor(0.82, 0.82, 0.82)
        y = y + LC.Window:TextHeight(desc, math.max(1, math.ceil(#c.desc / 88))) + 18

        tinsert(rows, { cmd = cmd, shorthand = shorthand, desc = desc, data = c })
    end

    content:SetHeight(y + 8)
end

function Help:Open()
    LC.Window:Show(PAGE)
end

function Help:Toggle()
    if LC.Window:IsShowing(PAGE) then
        LC.Window:Hide()
    else
        self:Open()
    end
end

--- Chat version of the same list (/lchelp help chat)
function Help:PrintToChat()
    LC:Print("v" .. tostring(LC.version) .. " commands (/lootcheck works too):")
    for _, c in ipairs(self.COMMANDS) do
        local args = (c.args and c.args ~= "") and (" " .. c.args) or ""
        local aliases = (c.aliases and #c.aliases > 0) and (" |cffff7fd2(" .. table.concat(c.aliases, ", ") .. ")|r") or ""
        print(("  |cff33ccff%s|r%s%s - %s"):format(c.cmd, args, aliases, c.desc))
    end
end

LC.Window:RegisterPage(PAGE, {
    title = "LootCheck - Slash Commands",
    frameName = "LootCheckHelpFrame",
    width = WIDTH,
    height = HEIGHT,
    build = BuildPage,
})
