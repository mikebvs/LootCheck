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
    { cmd = "/lchelp resetsize",
      desc = "Forget the size you dragged the window to and go back to the current page's natural size. The window is resizable by the grip in its bottom-right corner, and there is one size for the whole window: drag it on any page and every other page opens at that size. It cannot go below what the wishlist graph needs for its two columns." },
    { cmd = "/lchelp phase", args = "[P4] [YYYY-MM-DD | reset]", aliases = { "/lchelp phases" },
      desc = "Show the content phase dates, or set one. Dates only drive the graph's phase filter (the < > buttons); they have nothing to do with the \"current wishlist\" number, which counts against the wishlist you have imported and changes when you re-import. P4 (Zul'Aman) and P5 (Sunwell) have no announced date yet, so set them yourself when Blizzard says: \"/lchelp phase P4 2026-10-15\". Your dates are remembered, and \"reset\" restores the default." },
    { cmd = "/lchelp contested", aliases = { "/lchelp competition" },
      desc = "Open the Contested Items page: every wishlisted item with how many raiders want it and how many of those are still waiting. Ordered by who is still waiting rather than by the raw total, since an item five people wishlisted but four already hold is not contested any more. Hovering a row lists the raiders with their priorities, received ones greyed. A check box narrows it to your current group." },
    { cmd = "/lchelp sheet", args = "[character]", aliases = { "/lchs", "/lchelp character", "/lchelp char" },
      desc = "Open the Character Sheet page: pick a raider and see what they want in each equipment slot and the rank they gave it. Slots with nothing on their wishlist are shown empty, so a gap is as visible as a want, and received items are greyed exactly as on the tooltip. Tier tokens are placed by name, since the client has no slot for an item that is not equippable; anything else the client has not cached yet waits under \"Slot not known yet\" and moves up once the data arrives. Clicking a raider on the wishlist graph opens their sheet." },
    { cmd = "/lchelp council", aliases = { "/lchc", "/lchelp members" },
      desc = "Open the Loot Council page: who else is running LootCheck and which version, so you can see whether the council is on the same build. Opening it asks your group and every guild member who is online; replies arrive over a second or two, so use Check again if someone is missing. Anyone on an older version is flagged, and a check box also lists the players who were asked but did not answer." },
    { cmd = "/lchelp drops", args = "[clear]",
      desc = "Open the wishlist graph, whose right-hand column lists every rare and epic item that dropped in the raid this week, newest first, with who picked it up and who Gargul assigned it to. Those are separate columns on purpose: an item is often looted by whoever had bag space and only assigned later. Drops are read from the loot window and from loot messages in chat, which every client in the raid sees, so no addon-to-addon communication is needed. The arrows step back through earlier weeks; the list rolls over at the Tuesday raid reset. Hovering a drop shows its tooltip, so the wishlist is right there. \"clear\" forgets every recorded drop." },
    { cmd = "/lchelp grouponly",
      desc = "Toggle showing only raiders who are in your current group on the graph." },
    { cmd = "/lchelp audit", aliases = { "/lcha" },
      desc = "Open the Audit page: every item award in chronological order, newest first - Gargul awards including plain MS / OS roll wins, manual received marks, and your giveitem / removeitem / addwlitem / removewlitem commands. A dropdown limits the list to the past week, the past month, this content phase, last phase, or all of it, and a check box hides awards whose item was not on the winner's wishlist." },
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
    page.content = content

    page.intro = LC.Window:Text(content, "GameFontHighlight", CONTENT_WIDTH - 8)
    page.intro:SetText("Every command can be typed as /lchelp <command> or /lootcheck <command>. Items can be given as a shift-clicked link, an item ID, or a unique part of the item's name.")

    for _, c in ipairs(Help.COMMANDS) do
        local cmd = LC.Window:Text(content, "GameFontNormal")
        cmd:SetText(c.cmd .. ((c.args and c.args ~= "") and (" |cffaaaaaa" .. c.args .. "|r") or ""))

        local shorthand
        if c.aliases and #c.aliases > 0 then
            shorthand = LC.Window:Text(content, "GameFontNormalSmall")
            shorthand:SetText("|cffff7fd2Shorthands: " .. table.concat(c.aliases, ", ") .. "|r")
        end

        local desc = LC.Window:Text(content, "GameFontHighlightSmall", CONTENT_WIDTH - 20)
        desc:SetText(c.desc)
        desc:SetTextColor(0.82, 0.82, 0.82)

        tinsert(rows, { cmd = cmd, shorthand = shorthand, desc = desc, data = c })
    end

    Help:Stack(page, CONTENT_WIDTH)
end

--- Position every row top-down for a given content width. Re-run on resize,
--- because a narrower page wraps descriptions onto more lines and a wider one
--- lets shorthands sit beside their command instead of below it.
function Help:Stack(page, contentWidth)
    local content = page.content
    if not content then return end

    content:SetWidth(contentWidth)
    page.intro:SetWidth(contentWidth - 8)
    page.intro:ClearAllPoints()

    local y = 2
    page.intro:SetPoint("TOPLEFT", 2, -y)
    y = y + LC.Window:TextHeight(page.intro, 3) + 16

    for _, row in ipairs(rows) do
        local c = row.data
        row.cmd:ClearAllPoints()
        row.cmd:SetPoint("TOPLEFT", 2, -y)

        -- Shorthands sit beside the command when they fit, on their own line otherwise
        local ownLine
        if row.shorthand then
            row.shorthand:ClearAllPoints()
            local plain = (row.shorthand:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local cmdWidth = TextWidth(row.cmd, c.cmd .. " " .. (c.args or ""), 7)
            ownLine = (cmdWidth + 16 + TextWidth(row.shorthand, plain, 6)) > (contentWidth - 8)

            if ownLine then
                y = y + LC.Window:TextHeight(row.cmd, 1) + 2
                row.shorthand:SetPoint("TOPLEFT", 10, -y)
            else
                row.shorthand:SetPoint("LEFT", row.cmd, "RIGHT", 16, 0)
            end
        end

        y = y + LC.Window:TextHeight(ownLine and row.shorthand or row.cmd, 1) + 4

        row.desc:SetWidth(contentWidth - 20)
        row.desc:ClearAllPoints()
        row.desc:SetPoint("TOPLEFT", 10, -y)
        -- Roughly 88 characters fit per line at the natural width
        local perLine = math.max(20, math.floor(88 * contentWidth / CONTENT_WIDTH))
        y = y + LC.Window:TextHeight(row.desc, math.max(1, math.ceil(#c.desc / perLine))) + 18
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

function Help:Layout(page, w)
    self:Stack(page, w - MARGIN * 2 - 40)
end

LC.Window:RegisterPage(PAGE, {
    title = "LootCheck - Slash Commands",
    frameName = "LootCheckHelpFrame",
    width = WIDTH,
    height = HEIGHT,
    build = BuildPage,
    layout = function(page, w) Help:Layout(page, w) end,
})
