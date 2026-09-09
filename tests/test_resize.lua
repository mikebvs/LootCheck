-- Resizing: the grip, the one shared size carried between pages, and the
-- pages reflowing to fit it.
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
-- Sizing must begin on a drag, not a click: on mouse-down a plain click put
-- the frame into sizing mode and the client snapped it to its minimum
assert(frame.grip._scripts.OnDragStart and frame.grip._scripts.OnDragStop, "the grip sizes on drag")

local beforeW, beforeH = Window:ContentSize()
if frame.grip._scripts.OnMouseDown then
    frame.grip._scripts.OnMouseDown(frame.grip)
end
local afterW, afterH = Window:ContentSize()
assert(afterW == beforeW and afterH == beforeH,
    ("clicking the grip must not resize: %sx%s became %sx%s"):format(beforeW, beforeH, afterW, afterH))
assert(frame._scripts.OnSizeChanged, "the window reacts to being resized")

section("the floor is whatever the most demanding page needs")
-- The graph has to fit two columns, so its minimum is the window's minimum,
-- which is what lets one size suit every page
local minW, minH = Window:MinimumSize()
assert(minW >= 320 + 360 + 22 * 2 + 14, "the floor covers the graph's two columns, got " .. minW)
assert(minH >= 360, "and its height, got " .. minH)

LootCheckDB.windowSize = {}
Window:Show("audit")
local w = select(1, Window:ContentSize())
assert(w >= minW, "even a narrow page opens at least at the floor, got " .. w)

section("a drag follows the cursor, and never jumps when it starts")
-- This is the bug that took four attempts: grabbing the grip resized the
-- window before the cursor had moved at all. Driving the size from the cursor
-- rather than handing the frame to the client's StartSizing makes the first
-- update a delta of zero, so a jump is not possible.
Window:Show("audit")
Window:Resize(900, 600)
SetTestCursor(1500, 1000)

local grabbedW, grabbedH = Window:ContentSize()
frame.grip._scripts.OnDragStart(frame.grip)
local startedW, startedH = Window:ContentSize()
assert(startedW == grabbedW and startedH == grabbedH,
    ("starting a drag must not resize: %sx%s became %sx%s"):format(grabbedW, grabbedH, startedW, startedH))

-- Still nothing while the cursor is where it was
frame._scripts.OnUpdate(frame)
assert(select(1, Window:ContentSize()) == grabbedW, "no movement, no resize")

-- Drag right and down: wider by the same amount, taller by it too (y is inverted)
SetTestCursor(1500 + 120, 1000 - 80)
frame._scripts.OnUpdate(frame)
local draggedW, draggedH = Window:ContentSize()
assert(draggedW == grabbedW + 120, ("width follows the cursor: %s, expected %s"):format(draggedW, grabbedW + 120))
assert(draggedH == grabbedH + 80, ("height follows it downwards: %s, expected %s"):format(draggedH, grabbedH + 80))

-- Dragging back up and left shrinks it again
SetTestCursor(1500 - 60, 1000 + 40)
frame._scripts.OnUpdate(frame)
assert(select(1, Window:ContentSize()) == grabbedW - 60, "and shrinks when dragged back")

frame.grip._scripts.OnDragStop(frame.grip)
assert(frame._scripts.OnUpdate == nil, "the drag handler is removed on release")
frame._scripts.OnUpdate = nil
SetTestCursor(0, 0)

section("the size you drag to carries to every other page")
Window:Resize(900, 700)
local newW, newH = Window:ContentSize()
assert(newW == 900, "resized width, got " .. newW)
assert(newH == 700 - 44, "content height is the window minus the title bar, got " .. newH)

-- The grip stores it on release
frame.grip._scripts.OnDragStop(frame.grip)
assert(LootCheckDB.windowSize.width == 900, "one shared size was stored, not one per page")

Window:Hide()
Window:Show("audit")
assert(select(1, Window:ContentSize()) == 900, "it opens at the size you left it")

for _, key in ipairs({ "home", "graph", "council", "help", "imports" }) do
    Window:Show(key)
    local pageW, pageH = Window:ContentSize()
    assert(pageW == 900, key .. " inherited the dragged width, got " .. pageW)
    assert(pageH == 700 - 44, key .. " inherited the dragged height, got " .. pageH)
end

section("a size stored per page before the change is carried over, not lost")
LootCheckDB.windowSize = {
    audit = { width = 820, height = 640 },
    graph = { width = 1100, height = 700 },
}
Window:Hide()
Window:Show("home")
assert(select(1, Window:ContentSize()) == 1100, "the largest old size became the shared one")
assert(LootCheckDB.windowSize.width == 1100, "and was rewritten in the new shape")
assert(LootCheckDB.windowSize.audit == nil, "the per-page entries are gone")

section("the frame is never left below the bounds sizing will enforce")
-- A frame smaller than its own minimum is snapped up by the client the moment
-- sizing begins, which reads as the window lurching wider on the first click
Window:Show("audit")
local floorMinW, floorMinH = Window:MinimumSize()
Window:Resize(floorMinW - 300, floorMinH - 200)
local heldW, heldH = Window:ContentSize()
assert(heldW >= floorMinW, "width never goes below the floor, got " .. heldW)
assert(heldH + 44 >= floorMinH, "nor height, got " .. (heldH + 44))

Window:ApplyBounds()
assert(select(1, Window:ContentSize()) >= floorMinW, "and bounds keep it there")

-- The client can resize the frame without anything here seeing it, so the
-- tracked numbers and the frame's real size can disagree. It is the frame the
-- client checks against the bounds, so that is what has to be measured.
frame._width, frame._height = 200, 150 -- as if the client had shrunk it
Window:ApplyBounds()
assert(frame:GetWidth() >= floorMinW,
    "a frame smaller than the bounds is raised even when the tracked size looks fine, got " .. frame:GetWidth())
assert(frame:GetHeight() >= floorMinH, "and its height, got " .. frame:GetHeight())

section("sizes are clamped, so a saved one cannot outgrow the screen")
UIParent:SetSize(1200, 800)
Window:Show("audit")
Window:Resize(5000, 5000)
local clampedW, clampedH = Window:ContentSize()
assert(clampedW <= 1200, "width clamped to the screen, got " .. clampedW)
assert(clampedH + 44 <= 800, "height clamped to the screen, got " .. (clampedH + 44))

Window:Resize(10, 10)
local floorW, floorH = Window:ContentSize()
local wantW, wantH = Window:MinimumSize()
assert(floorW >= math.min(wantW, 1200), "the floor is enforced, got " .. floorW)
assert(floorH + 44 >= math.min(wantH, 800), "and its height, got " .. (floorH + 44))
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
Window:Resize(Window:MinimumSize(), 600) -- anything narrower is clamped to the floor
local narrowW = select(1, Window:ContentSize())
assert(narrowW < 900, "the window did get narrower, got " .. narrowW)
assert(content._width == narrowW - 22 * 2 - 40, "and the content narrowed with it, got " .. tostring(content._width))
assert(content._height >= wideHeight, "a narrower page wraps onto more lines, so it gets taller")

section("resetting forgets the dragged size")
Window:Show("audit")
Window:Resize(1000, 800)
assert(Window:ResetSize(), "reset ran")
assert(LootCheckDB.windowSize.width == nil, "the dragged size is gone")
-- Back to the audit page's own size, raised to the floor it cannot go below
assert(select(1, Window:ContentSize()) == math.max(680, select(1, Window:MinimumSize())),
    "back to its natural size, or the floor")

section("cleanup")
Window:Hide()
LootCheckDB.windowSize = {}
LootCheck.db.settings.auditRange = "all"

print("\nRESIZE TESTS PASSED")
