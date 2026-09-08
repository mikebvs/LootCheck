-- Resizing: the grip, the per-page remembered size, and the pages reflowing.
local function section(t) print("\n=== " .. t .. " ===") end
local Window = LootCheck.Window

local function shownRows(list)
    local n = 0
    for _, row in ipairs(list) do
        if row:IsShown() then n = n + 1 end
    end
    return n
end

section("the window is resizable and has a grip")
LootCheck.Window:Show("audit")
local frame = LootCheckWindow
assert(frame.grip, "there is a resize grip")
assert(frame.grip._scripts.OnMouseDown and frame.grip._scripts.OnMouseUp, "the grip drives sizing")
assert(frame._scripts.OnSizeChanged, "the window reacts to being resized")

section("a page opens at its natural size, and remembers what you leave it at")
LootCheckDB.windowSize = {}
Window:Show("audit")
local w, h = Window:ContentSize()
assert(w == 680, "audit opens at its natural width, got " .. w)

Window:Resize(900, 700)
local newW, newH = Window:ContentSize()
assert(newW == 900, "resized width, got " .. newW)
assert(newH == 700 - 44, "content height is the window minus the title bar, got " .. newH)

-- The grip stores it on release
frame.grip._scripts.OnMouseUp(frame.grip)
assert(LootCheckDB.windowSize.audit, "the size was stored")
assert(LootCheckDB.windowSize.audit.width == 900, "stored width")

Window:Hide()
Window:Show("audit")
assert(select(1, Window:ContentSize()) == 900, "it opens at the size you left it")

section("each page keeps its own size")
Window:Show("home")
assert(select(1, Window:ContentSize()) == 600, "home is unaffected by the audit page's size")
Window:Show("audit")
assert(select(1, Window:ContentSize()) == 900, "and audit still has its own")

section("sizes are clamped, so a saved one cannot outgrow the screen")
UIParent:SetSize(1200, 800)
Window:Show("audit")
Window:Resize(5000, 5000)
local clampedW, clampedH = Window:ContentSize()
assert(clampedW <= 1200, "width clamped to the screen, got " .. clampedW)
assert(clampedH + 44 <= 800, "height clamped to the screen, got " .. (clampedH + 44))

Window:Resize(10, 10)
local minW, minH = Window:ContentSize()
assert(minW >= 420, "a minimum width is enforced, got " .. minW)
assert(minH + 44 >= 280, "and a minimum height, got " .. (minH + 44))
UIParent:SetSize(nil, nil)

section("a taller window shows more rows, a shorter one fewer")
LootCheckDB.windowSize = {}
LootCheck.db.settings.auditRange = "all"
Window:Show("audit")
local shortRows = LootCheck.Audit.rowCount
Window:Resize(900, 900)
local tallRows = LootCheck.Audit.rowCount
assert(tallRows > shortRows, ("a taller audit shows more rows: %d then %d"):format(shortRows, tallRows))
assert(shownRows(LootCheck.Audit._rows) > 0, "rows are actually on screen")

Window:Resize(900, 400)
assert(LootCheck.Audit.rowCount < tallRows, "and a shorter one fewer")
assert(LootCheck.Audit.rowCount >= 3, "never fewer than three")

section("the graph splits its two columns, and both keep a floor")
LootCheckDB.windowSize = {}
Window:Show("graph")
local page = LootCheckGraphFrame

Window:Resize(1400, 800)
local wideDrops = LootCheck.Drops.rowCount
assert(wideDrops > 0, "the drops list has rows")

-- Squeeze to the minimum: neither column may be starved
Window:Resize(100, 100)
local narrow = select(1, Window:ContentSize())
assert(narrow >= 320 + 360 + 22 * 2 + 14, "the graph enforces room for both columns, got " .. narrow)

Window:Resize(1400, 900)
assert(LootCheck.Drops.rowCount > wideDrops, "a taller graph shows more drops")

section("the council and commands pages reflow too")
LootCheckDB.windowSize = {}
Window:Show("council")
local councilShort = LootCheck.Council.rowCount
Window:Resize(900, 900)
assert(LootCheck.Council.rowCount > councilShort, "a taller council page lists more players")

Window:Show("help")
local content = LootCheckHelpFrame.content
Window:Resize(900, 600)
assert(content._width == 900 - 22 * 2 - 40, "the commands page widens its content, got " .. tostring(content._width))
local wideHeight = content._height
Window:Resize(520, 600)
assert(content._width == 520 - 22 * 2 - 40, "and narrows it again")
assert(content._height >= wideHeight, "a narrower page wraps onto more lines, so it gets taller")

section("resetting puts a page back to its designed size")
Window:Show("audit")
Window:Resize(1000, 800)
assert(Window:ResetSize(), "reset ran")
assert(select(1, Window:ContentSize()) == 680, "back to the natural width")
assert(LootCheckDB.windowSize.audit == nil, "and the remembered size is gone")

section("cleanup")
Window:Hide()
LootCheckDB.windowSize = {}
LootCheck.db.settings.auditRange = "all"

print("\nRESIZE TESTS PASSED")
