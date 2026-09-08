# Changelog

All notable changes to LootCheck are recorded here.
This project follows [Semantic Versioning](https://semver.org/).

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

[1.0.1]: https://github.com/mikebvs/LootCheck/releases/tag/v1.0.1
[1.0.0]: https://github.com/mikebvs/LootCheck/releases/tag/v1.0.0
