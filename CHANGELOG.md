# Changelog

All notable changes to LootCheck are recorded here.
This project follows [Semantic Versioning](https://semver.org/).

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

[1.3.0]: https://github.com/mikebvs/LootCheck/releases/tag/v1.3.0
[1.2.1]: https://github.com/mikebvs/LootCheck/releases/tag/v1.2.1
[1.2.0]: https://github.com/mikebvs/LootCheck/releases/tag/v1.2.0
[1.1.0]: https://github.com/mikebvs/LootCheck/releases/tag/v1.1.0
[1.0.2]: https://github.com/mikebvs/LootCheck/releases/tag/v1.0.2
[1.0.1]: https://github.com/mikebvs/LootCheck/releases/tag/v1.0.1
[1.0.0]: https://github.com/mikebvs/LootCheck/releases/tag/v1.0.0
