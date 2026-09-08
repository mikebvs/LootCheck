# Changelog

All notable changes to LootCheck are recorded here.
This project follows [Semantic Versioning](https://semver.org/).

## [1.4.2] - 2026-09-08

### Fixed

- Clicking the resize grip made the window jump wider before any dragging.
  Sizing began on mouse-down, so a plain click already put the frame into
  sizing mode and the client applied the resize bounds at that instant,
  snapping a frame that sat below its minimum up to it. Sizing now begins on a
  drag, so a click on the grip does nothing on its own.
- The resize bounds were set once when the window was built and never again,
  so they could disagree with what the pages actually need. They are now
  reapplied on every page change and before every resize, and the frame is
  raised into them if it is ever outside.
- A page's `minHeight` is now read as what its content needs, with the title
  bar added on top, rather than being taken as the whole window's height.

## [1.4.1] - 2026-09-08

### Changed

- **One size for the whole window instead of one per page.** Drag it on any
  page and every other page opens at that size, so switching pages no longer
  resizes the window under you. A size saved per page by 1.4.0 is carried over
  rather than lost: the largest of them becomes the shared one.
- The minimum size is now whatever the most demanding page needs, which is the
  wishlist graph and its two columns. It is derived from the pages rather than
  hard-coded, so it follows the graph if its columns ever need more room. This
  is what makes a single shared size safe: every page can be switched to
  without the window having to change size to fit it.

## [1.4.0] - 2026-09-08

### Added

- **The window is resizable**, by the grip in its bottom-right corner. Each
  page remembers its own size, sizes are clamped to the screen so one saved on
  a larger monitor cannot outgrow the display, and `/lchelp resetsize` puts the
  current page back to how it shipped.
- Pages reflow rather than stretch. The audit, raid drops and loot council
  lists show more rows when the window is taller; the graph's two columns split
  proportionally with a floor on each, and the bars scale with their column;
  the commands page re-wraps and re-stacks at its new width.

## [1.3.1] - 2026-09-08

### Changed

- Dropdowns are now dark fields with a border and an arrow rather than
  `UIPanelButtonTemplate` buttons, which made them read as action buttons like
  "< Back" instead of as something to pick from. Both the Audit page's range
  dropdown and the Wishlist Data raid picker use the same shared button, so
  they match, and the layout suite asserts the styling.

## [1.3.0] - 2026-09-08

### Added

- **A time range dropdown on the Audit page**: past week, past month, this
  phase, last phase, or all. The two phase options use the dates from
  `/lchelp phase`, so correcting a date moves the list with it. The choice is
  remembered, and the entry count names the range it is showing.
- `Window:CreateDropdown` builds a dropdown out of plain frames, so a second
  one did not mean a second copy of the picker code. Blizzard's
  `UIDropDownMenu` stays out of the addon, as it must.

## [1.2.1] - 2026-09-08

### Fixed

- The graph's "Wishlist items awarded" column heading had no right bound, so it
  ran on into the raid drops list beside it. It is now bounded by the bar
  column and shortened to "Awarded: current wishlist (all time)".
- Bounded three more single-line labels that sat at the end of a row and could
  overrun their neighbour the same way: the graph's group check box, the audit
  page's hide-non-wishlist label, and the drops list's blue items label. The
  layout suite now asserts all of them.

## [1.2.0] - 2026-09-08

### Added

- **Content phase dates** and a phase filter on the graph. The `< >` buttons
  limit the bars to awards from one phase, which is a real date window. P1, P2
  and P3 carry their announced Anniversary dates; P4 (Zul'Aman) and P5 (Sunwell)
  have none yet and show no awards until you set one with
  `/lchelp phase P4 2026-10-15`. Your dates are remembered, so no addon update
  is needed when Blizzard announces them.
- `/lchelp phase` lists the table and marks the phase you are in.

### Changed

- The graph's main number is now labelled **current wishlist** rather than
  "this phase". Its behaviour is unchanged: it has always counted awards
  against the wishlist you have imported, never a date range, and the old label
  implied otherwise. The same wording is corrected on the home page, in
  `/lchelp status` and in `/lchelp wishlist`.
- A chosen phase takes precedence over the "last N days" filter, rather than
  the two intersecting.

## [1.1.0] - 2026-09-08

### Added

- **Loot Council page** (`/lchc`, or the button on the home page): who else is
  running LootCheck and which version, so you can check the council is on the
  same build. Opening it pings your group and every online guild member;
  anyone behind your version is flagged, and a check box also lists the players
  who were asked but did not answer.
- Shorthand slash commands: `/lch` (menu), `/lchg` (graph), `/lcha` (audit) and
  `/lchc` (loot council). Arguments pass through, so `/lchg 30` works.

### Changed

- A ping and its reply now cross protocol versions, so someone running a build
  that cannot exchange data with yours is visible on the Loot Council page as
  "cannot sync" instead of being invisible. Everything that moves data still
  requires a matching protocol.

## [1.0.2] - 2026-09-08

No changes to how the addon behaves in game. Fixes the release pipeline.

### Fixed

- The release workflow passed the CurseForge token as `CF_API_TOKEN`, but the
  pinned `packager@v2` reads only `CF_API_KEY`, so the upload was skipped while
  the run still reported success. Both names are now set.
- The packaged changelog was being generated from commit messages, overwriting
  this file. `.pkgmeta` now points at it explicitly.

## [1.0.1] - 2026-09-08

No changes to how the addon behaves in game. This is the first release built
and published automatically from a git tag.

### Changed

- The version is read from `LootCheck.toc` at load instead of being repeated in
  `Core.lua`, so the number shown in chat and sent to other LootCheck users
  cannot drift from the one the packager and CurseForge publish.

## [1.0.0] - 2026-09-08

First public release.

### Tooltips

- Gargul's "TMB Wish List" block is rebuilt from LootCheck's own wishlist data, in Gargul's format and honouring Gargul's TMB settings (raiders-only filter, maximum entries, OS sorting, raid-group suffix). Gargul's tier, note and prio-list lines are left alone.
- Raiders who have already been awarded an item are greyed out in that block. Everyone else stays class-coloured, so grey means exactly one thing: received.
- TMBExport's separate tooltip list is switched off once, with a chat notice, so nothing is shown twice. `/lchelp tmbtooltip` turns it back on.

### Wishlist data

- Paste That's My BIS CSV exports into LootCheck as named raids and pick the active one. A stale Gargul TMB import in a PUG can no longer skew the tooltip or the numbers.
- Export the active dataset as text, or whisper it straight to chosen players in your group. Each recipient chooses to save it as a new raid, merge it into theirs, or discard it.
- Manual edits (`giveitem`, `removeitem`, `addwlitem`, `removewlitem`) can be shared live with the same players. Both sides must opt in, received edits run the same code as local ones, and edits are never relayed.

### Reporting

- **Wishlist graph**: one bar per raider showing non-OS wishlist items awarded, as `4 (22)` — 4 this phase, 22 all time. Hover for the items and dates.
- **Raid drops**: every rare and epic item that dropped, per raid week, with who picked it up and who it was assigned to in separate columns. Read from the loot window and from loot messages in chat, so every council member builds the same list with no addon-to-addon traffic. Rolls over at the Tuesday raid reset, with 8 weeks of history.
- **Audit**: every award in chronological order, including plain MS/OS roll wins, manual received marks, and the manual-edit commands you ran.

### Notes

- LootCheck never writes to Gargul's data.
- It deliberately avoids Blizzard's `UIDropDownMenu` and `StaticPopupDialogs`: both taint the secure UI, which stopped the game menu's Log Out button working during development. The test suite fails if either is reintroduced.

[1.4.2]: https://github.com/mikebvs/LootCheck/releases/tag/v1.4.2
[1.4.1]: https://github.com/mikebvs/LootCheck/releases/tag/v1.4.1
[1.4.0]: https://github.com/mikebvs/LootCheck/releases/tag/v1.4.0
[1.3.1]: https://github.com/mikebvs/LootCheck/releases/tag/v1.3.1
[1.3.0]: https://github.com/mikebvs/LootCheck/releases/tag/v1.3.0
[1.2.1]: https://github.com/mikebvs/LootCheck/releases/tag/v1.2.1
[1.2.0]: https://github.com/mikebvs/LootCheck/releases/tag/v1.2.0
[1.1.0]: https://github.com/mikebvs/LootCheck/releases/tag/v1.1.0
[1.0.2]: https://github.com/mikebvs/LootCheck/releases/tag/v1.0.2
[1.0.1]: https://github.com/mikebvs/LootCheck/releases/tag/v1.0.1
[1.0.0]: https://github.com/mikebvs/LootCheck/releases/tag/v1.0.0
