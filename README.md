# LootCheck

Companion addon for **[Gargul](https://www.curseforge.com/wow/addons/gargul)** + **That's My BIS Export (TMBExport)** on WoW TBC Anniversary (Interface 20506).

It answers the two questions a loot council asks all night: *has this raider already had this item?*, and *what dropped tonight and where did it go?*

## What it does

1. **One TMB list on the tooltip, inside Gargul's own section.** Gargul's "TMB Wish List" block is rebuilt from TMBExport's data (names, priorities, `(OS)` markers) in Gargul's own format, honouring Gargul's TMB settings (raiders-only filter, max entries, OS sorting, raid-group suffix). Gargul's tier / note / prio-list lines above it are kept. TMBExport's separate "TMB Wishlist" block is switched off so nothing is shown twice.
2. **Greys out names that already got the item.** Once Gargul has awarded an item to a raider, that raider's line in the section turns grey. Every other name is class-coloured (classes come from TMBExport), so grey means exactly one thing: received.
3. **`/lchelp graph`** opens a bar graph of how many *non-OS wishlist* items each raider has been awarded: `4 / 2 (22)` = 4 against the current wishlist, 2 tier tokens, 22 all time. Hover a bar to see the items, the tokens and their dates.
4. **Every rare and epic item that dropped, per raid week.** The graph page's right-hand column lists the raid's drops newest first, with **who picked each one up** and **who it was assigned to** in separate columns. It rolls over at the Tuesday raid reset and the arrows step back through earlier weeks. Nothing is sent between addons: the data comes from loot messages every client in the raid already receives.
5. **LootCheck owns the wishlist data.** Paste That's My BIS CSV exports into LootCheck as named imports ("raids") and pick the active one from a dropdown (`/lchelp imports`). "Is this on their wishlist?" is answered from the active import, not Gargul's own TMB import, so a stale Gargul import in a PUG does not skew the tooltip or the numbers. "Was it awarded?" comes from Gargul's own award history. While no import exists, TMBExport's data is used as a fallback if that addon is installed.

LootCheck never writes to Gargul's data. The only thing it touches in TMBExport is its "show tooltip" setting (once, with a chat notice; `/lchelp tmbtooltip` turns it back on).

## Requirements

- Gargul (tested with v7.8.2)
- A That's My BIS CSV export (thatsmybis.com > Export > CSV). TMBExport is optional: if it is installed and LootCheck has no import yet, its data is used and the window offers "Copy from TMBExport".

## Commands

| Command | What it does |
|---|---|
| `/lchelp` | Open the LootCheck window: status, basic settings, and buttons to the other pages (`config` / `options` do the same). Every page lives in this one window; `< Back` returns home |
| `/lchelp audit` | Audit page: every item award newest first (Gargul awards incl. MS/OS rolls, manual marks, your manual-edit commands); a dropdown picks the time range and a check box hides awards that were not on the winner's wishlist |
| `/lchelp help` | Open the command reference window (`/lchelp help chat` prints it to chat instead) |
| `/lchelp graph` | Toggle the wishlist award graph |
| `/lchelp graph 30` | Only count awards from the last 30 days (`0` = all time). Setting is remembered. |
| `/lchelp grouponly` | Toggle showing only raiders currently in your group |
| `/lchelp drops` | Open the graph page and its raid drops list (`/lchelp drops clear` forgets them) |
| `/lchelp council` | Loot Council page: who is running LootCheck and on what version (`members` does the same) |
| `/lchelp sheet [character]` | Character Sheet: a raider's wishlist laid out by equipment slot (`character` / `char` do the same) |
| `/lchelp contested` | Contested Items: every wishlisted item and how many raiders want it (`competition` does the same) |
| `/lchelp phase` | Show the content phase dates, or set one (`/lchelp phase P4 2026-10-15`) |
| `/lchelp resetsize` | Put the current page back to its designed size |
| `/lchelp check <item link>` | Print wishlist + award data for one item (shift-click the item into chat) |
| `/lchelp status` | Show what data LootCheck can see and whether the tooltip integration is active |
| `/lchelp greyos` | Toggle whether names awarded via an **OS** roll are also greyed on tooltips (default: on) |
| `/lchelp imports` | Wishlist Data page: active-raid dropdown, New import, Delete, Export (`data` / `raids` do the same) |
| `/lchelp use <raid name>` | Switch the active raid from chat (exact or unique partial name) |
| `/lchelp send` | Send the active raid's wishlist data to chosen players in your group |
| `/lchelp shareedits` | Turn sharing of your manual edits with those players on or off |
| `/lchelp tmbtooltip` | Toggle TMBExport's own (separate) tooltip list back on / off |
| `/lchelp giveitem <character> <item> [os] [force]` | Mark an item as received by a character (see below) |
| `/lchelp removeitem <character> <item>` | Undo that, or hide Gargul's award of that item to them |
| `/lchelp addwlitem <character> <item> [#prio] [os]` | Put an item on a character's wishlist (see below) |
| `/lchelp removewlitem <character> <item>` | Take an item off a character's wishlist |
| `/lchelp wishlist <character>` | Show a character's wishlist as LootCheck sees it (received items greyed, manual edits tagged) |
| `/lchelp overrides` | List manual wishlist edits; `/lchelp clearoverrides confirm` wipes them |

`/lootcheck` works as an alias of `/lchelp`. Four shorthands jump straight to a page, and pass anything typed after them through, so `/lchg 30` is exactly `/lchelp graph 30`:

| Shorthand | Same as |
|---|---|
| `/lch` | `/lchelp` (the menu) |
| `/lchg` | `/lchelp graph` |
| `/lcha` | `/lchelp audit` |
| `/lchc` | `/lchelp council` |
| `/lchs` | `/lchelp sheet` |

## Wishlist Data (raid imports)

`/lchelp imports` (or the **Wishlist Data** button on the home page) opens the page:

- **Active raid** dropdown: whichever import is selected is what Gargul's TMB tooltip section, the graph and the manual edits use. Switching is instant.
- **New import**: give it a name, paste the That's My BIS CSV export (thatsmybis.com > Export > CSV) as-is, click Import. Only `wishlist` rows are kept (`received` / `prio` rows are skipped and reported); tier set pieces are rewritten to their tokens so they match what actually drops. The new import becomes active.
- **Delete** removes the selected import (with a confirm) together with its manual edits.
- **Copy from TMBExport** (shown when that addon has data) turns TMBExport's current import into a LootCheck raid.
- **Send to...** lists everyone in your group with a tick box each, marking who already runs LootCheck. The dataset is whispered only to the players you tick, compressed: about 8KB and 34 messages for a 438-entry raid. Each receiver chooses **Save as new**, **Merge into their raid** (adding only entries they lack) or **Discard**. Nothing is applied without them choosing, and data is only accepted from someone in your own group.
- **Export** hands you the same dataset as text for pasting elsewhere.
- **Export** shows the active raid's *effective* dataset (imported entries minus your removals, plus your manual additions, tagged) as text. Select all, copy, and send it to another LootCheck user; they paste it into **New import** and get exactly the wishlist you are working from, name included. The text is a CSV LootCheck's importer recognises by its `# LootCheck wishlist export` header.

Imports live in `LootCheckDB.imports`. Manual wishlist edits (`addwlitem` / `removewlitem`) are stored per raid, so a PUG's additions do not leak into your guild raid's list. The all-time award history and manual received marks are global.

## Sharing manual edits

The players ticked in **Send to...** are also your share list. Tick *Also share my giveitem / addwlitem edits with the ticked players* (or run `/lchelp shareedits`) and every `giveitem`, `removeitem`, `addwlitem` and `removewlitem` you run is whispered to them and applied on their end.

- **It takes both sides.** You only accept an edit from someone you have ticked, with sharing on, who is in your group. Anything else is ignored.
- **Received edits run your own code.** They go through the same `Awards:Apply*` and `Wishlist:Apply*` functions your slash commands use, so behaviour is identical.
- **Everything is visible.** Each applied edit prints a line in chat and appears on the Audit page tagged `(from Steven)`.
- **Wishlist edits are dataset-scoped.** Every import carries a share id that travels with the data, so `addwlitem` only lands on players working from that same dataset. Received marks are not scoped, since an award is a fact about the player.
- **Edits are never relayed.** An edit you receive is not passed on again, so nothing loops. With a council who all tick each other, every edit reaches everyone directly.

## Merging a received dataset

A row counts as a duplicate when that character already wants that item at the same spec, whatever the priority, and the local row is the one kept. Tier set pieces are mapped to their tokens before comparing, so a wish for the piece and a wish for the token are recognised as the same thing. The result is reported as "N new entries, M duplicates skipped".

## Manual received marks

```
/lchelp giveitem Newguy Tsunami Talisman        -- Newguy got it: greyed on the tooltip, counts in the graph
/lchelp giveitem Newguy Tsunami Talisman os     -- an off-spec receipt: greys, does not count
/lchelp removeitem Newguy Tsunami Talisman      -- undo
```

- A manual mark behaves exactly like a Gargul award: it greys the name on Gargul's TMB tooltip, counts for this phase if the item is on their wishlist, and is remembered in the all-time history.
- `giveitem` refuses a duplicate (same character, item and spec) unless you add `force`.
- `removeitem` removes the manual mark(s). If there is none but **Gargul** recorded the award, it hides that Gargul award from LootCheck instead (Gargul's own records are untouched) - handy for fixing a mis-award. `giveitem` for the same character and item restores a hidden award.
- Marks are global (not per raid) and live in `LootCheckDB.manualAwards` / `ignoredAwards`. `/lchelp overrides` lists them.

## Manual wishlist edits

```
/lchelp addwlitem Newguy Tsunami Talisman          -- next free prio, main spec
/lchelp addwlitem Newguy Tsunami Talisman #3 os    -- prio 3, off-spec
/lchelp addwlitem Newguy [Tsunami Talisman]        -- shift-clicked item link always works
/lchelp removewlitem Newguy Tsunami Talisman
```

- `<item>` can be an item link, an item ID, or a name. Names resolve against TMBExport's entries, Gargul's award history and Gargul_ItemData's item cache; a unique partial name (`Tsunami`) is enough, an ambiguous one lists the candidates.
- The character does not have to be in the TMB export (PUGs). If they are in your group their class colour is picked up automatically.
- Edits are stored per raid in `LootCheckDB.overrides`, never inside the import itself, so they survive re-imports. `removewlitem` on an imported entry hides it; `addwlitem` on the same item puts the original imported entry back.
- The tooltip, the graph and `/lchelp check` all use the edited wishlist.

## Resizing

The window is resizable by the grip in its bottom-right corner. There is **one size for the whole window**: drag it on any page and every other page opens at that size, so navigating never resizes the window under you. `/lchelp resetsize` forgets it and returns to the current page's natural size.

The window cannot go below what the **wishlist graph** needs to show both its columns, because that is the most demanding page — which is exactly what lets a single size suit all of them.

Pages reflow rather than just stretching:

- Lists (audit, raid drops, loot council) show **more rows** when the window is taller, and fewer when it is shorter, down to a floor of three.
- The graph's two columns **split proportionally**, with a floor on each: the bars keep enough width to be worth comparing and the drops list keeps enough for its four columns. The bars themselves scale with the column.
- Wrapping text is handed its new width and re-measured, so the commands page re-stacks — a narrower page wraps descriptions onto more lines and pushes shorthands onto their own line.
- Sizes are clamped to your screen, so a size saved on a bigger monitor cannot leave the window larger than the display.
- The minimum is derived from the pages themselves rather than hard-coded, so it follows the graph if its columns ever need more room.

## Audit

`/lcha` lists every award in chronological order, newest first, including plain MS/OS roll wins, manual received marks and the manual-edit commands you ran.

- The **time range** dropdown offers *Past week*, *Past month*, *This phase*, *Last phase* and *All*. The two phase options follow the dates in `/lchelp phase`, so correcting a phase date moves this list with it.
- The **check box** hides awards whose item was not on the winner's wishlist.
- Both are remembered between sessions, and the entry count names the range it is showing.

## Contested Items

`/lchelp contested` (or the **Contested** button) lists every item anyone has wishlisted, so the ones several raiders are waiting on stand out before the raid rather than during it.

Two numbers per item, because they answer different questions:

| | |
|---|---|
| **Wanted by** | how many raiders have it on their wishlist at all |
| **Still want** | how many of those have not received it yet — amber at two, red above |

**The list is ordered by the second one.** An item six people wishlisted but five already hold is not contested any more, and sorting by the raw total would keep it near the top all phase.

A raider counts once however many entries they have for an item, and counts as settled when they have received as many as they asked for — so a double ring wish needs two rings before it stops being contested. Hovering a row names the raiders with their priorities, greying the ones who already have it. A check box narrows the whole page to your current group.

Hovering a row also draws a line above and below it, so the eye can follow across from the item name to the counts on the right.

## Character Sheet

`/lchs` (or the **Character** button, or clicking a raider's bar on the graph) lays one raider's wishlist out like a paper doll: every equipment slot, what they want in it, and the rank they gave it.

- **Empty slots are shown**, because a gap is as useful to know as a want.
- **A slot wanted several times** — three rings, say — is named once and its wants listed under it in rank order.
- **Received items are greyed**, exactly as on the tooltip.
- **Tier tokens are placed by name.** A token is not equippable, so the client has no slot for it; "Pauldrons of the Fallen Defender" is a shoulder, and the names come from the same map used at import, so this is exact rather than a guess.
- **Everything else asks the client**, which only knows items it has cached. Uncached items are requested and the page redraws when the data arrives, so anything sitting under *Slot not known yet* should move up within a moment of opening the page. Nothing is dropped for being unknown.
- **Hovering a row draws a line above and below it**, so the eye can follow across from the slot to the rank on the right.

## Loot Council

`/lchc` (or the **Loot Council** button) shows who else is running LootCheck and which version, so you can see whether the council is on the same build before a raid.

- **Who gets asked.** Opening the page pings your group *and* your guild. A guild ping is one message that reaches every online member, so this costs nothing extra as the guild grows. Offline members cannot answer and are not listed.
- **Replies take a moment.** They arrive over a second or two, which is why the list fills in after it opens and why there is a **Check again** button.
- **Grading.** Versions are compared numerically, so `1.0.10` is correctly newer than `1.0.9`. Anyone behind your version is flagged in red.
- **No reply is not the same as not installed.** Someone still loading, or whose reply is in flight, shows as *no reply*. Tick the box to list everyone who was asked.
- **Incompatible builds still show up.** A ping and its reply deliberately cross protocol versions, so someone on a build that cannot exchange data with yours appears as *cannot sync* rather than vanishing.

## Raid drops

The right-hand column of the graph page lists every item that dropped in the raid, newest first.

- **Where the data comes from.** Two sources, merged into one list. Gargul keeps neither: its dropped-loot ledger is in-memory only and its loot-window listener is commented out.
  - **The loot window** (`LOOT_READY` / `LOOT_OPENED`): everything sitting on the corpse, but only for whoever opened it.
  - **Chat** (`CHAT_MSG_LOOT`): everything anyone in the raid picked up. Every client in the raid receives these messages, so every council member builds the same list with **no addon-to-addon communication at all**.
- **A chat receipt for an item already seen on a corpse fills the looter in on that row** rather than listing it twice, as long as it arrives within 6 hours of the drop.
- **Looted by is not the same as assigned to.** Whoever had bag space picks the item up; the assignment happens later in Gargul and lands in the *Assigned* column on its own. The list shows both, and never assumes the looter is the winner.
- **When it resets.** Weeks run from the raid reset, Tuesday on US realms. The client is asked for the exact reset time where that API exists; otherwise LootCheck falls back to the most recent Tuesday 08:00. `<` and `>` step through the last 8 weeks, which is as far back as drops are kept.
- **What counts as a drop.** Anything of rare quality or better looted from a corpse while you are in a raid group or a raid instance. Coin and currency slots are skipped. Rares are always stored, and *Include blue items* only changes what the list shows, so ticking it later reveals blues that were recorded while it was off.
- **Who got it.** Each drop is matched with the Gargul award (or manual received mark) of that item that followed it, so two of the same item in a week line up with the two awards that followed. Where nothing has been awarded yet, the column instead shows how many raiders have it on their wishlist.
- **Hovering a drop** shows the item's own tooltip, wishlist section included, so the greyed-out names are right there. Shift-click links it into chat.

## Phases, and what "this phase" used to mean

The graph's main number counts awards **against the wishlist you currently have imported**. It has never involved a date: it changes when you re-import a new tier's data, which is exactly why the total drops when a new phase's wishlists land. The column is labelled *current wishlist* for that reason.

Separately, the `< >` buttons filter by **content phase**, which is a real date window:

| Phase | Content | Date |
|---|---|---|
| P1 | Karazhan, Gruul, Magtheridon | 2026-02-05 |
| P2 | Serpentshrine Cavern, Tempest Keep | 2026-05-14 |
| P3 | Black Temple, Mount Hyjal | 2026-08-27 |
| P4 | Zul'Aman | not announced |
| P5 | Sunwell Plateau | not announced |

- A phase runs from its own date until the next **announced** one, so the newest phase has no end.
- A phase with no date shows **no** awards, rather than falling back to everything.
- A chosen phase takes over from the `days` filter, so the two cannot silently intersect.
- Blizzard's roadmap numbers Zul'Aman as phase 3.5 and Sunwell as phase 4; the guild convention of P4 and P5 is used here.

Set a date yourself when one is announced, and it is remembered — no addon update needed:

```
/lchelp phase P4 2026-10-15
/lchelp phase P4 reset
```

## How the graph counts

Each row reads `4 / 2 (22)`:

| | |
|---|---|
| **4** | wishlist items awarded, against the wishlist you currently have imported (or the selected phase) |
| **2** | tier tokens awarded over the same window, in gold |
| **(22)** | all-time wishlisted items, across every phase |

Tier tokens are counted from Gargul's award history rather than through the wishlist, so a token handed to someone who never wishlisted it still counts — the question is how much tier they have had, not whether they asked. The token ids come from the same set-piece map used when importing, so the two cannot disagree. Hovering a bar lists the tokens with their dates.

**A phase counts only the tier it drops:**

| Phase | Tier | Tokens |
|---|---|---|
| P1 | T4 | Fallen Hero / Defender / Champion |
| P2 | T5 | Vanquished Hero / Defender / Champion |
| P3, P4, P5 | T6 | Forgotten Vanquisher / Conqueror / Protector |

With no phase selected, every tier counts. Zul'Aman and Sunwell keep the T6 tokens: Sunwell upgrades those pieces rather than introducing new ones.

The tier is read from the word after "of the" in the token's name, not by searching for a substring — T5 is *Vanquished* and T6 is *Forgotten Vanquisher*, so a substring match would put half of T6 into T5.


Each bar shows the **current wishlist** count: Gargul awards that match the raider's *current* wishlist data. Despite the old wording, this was never a date range. The number in parentheses is **all time**: every wishlisted item they have ever received, across phases. `4 (22)` = 4 this phase, 22 overall. Hover a bar for both lists.

An award matches the current wishlist when **all** of these are true:

- the item is on that raider's TMBExport wishlist as a **non off-spec** entry
- Gargul did **not** flag the award as OS (so an item merely won via an OS roll does not count)
- capped at the number of non-OS wishlist entries they have for that item (a double dual-wield wish can count twice; a single wish cannot)

Awards for items that are not on the raider's wishlist at all (plain MS/OS roll wins) are never counted.

The all-time number is the union of two sources, deduplicated per Gargul award:

- **LootCheck's own log** (`LootCheckDB.history`): every match LootCheck has observed against any wishlist it has seen, imported or manual. It is written whenever the graph or status is computed and on every Gargul award, so a later TMBExport re-import (new phase, cleaned-up lists) does not lose it. Un-awarding in Gargul removes the entry; editing an award to another winner drops the stale entry.
- **Gargul's own `WL` stamp** on each award (was the item on the winner's TMB wishlist per Gargul's import at award time). This covers phases before LootCheck was installed, but only as far back as Gargul had TMB data imported.

Awards from before either source existed cannot be counted as wishlisted.

## How the tooltip integration works

Gargul builds its tooltip block by calling `GL.TMB:tooltipLines(itemLink)`. LootCheck replaces that function:

- lines Gargul would show above its wishlist section (tier, note, prio list) pass through unchanged, with received names greyed
- the wishlist section is generated from TMBExport data; a player who wished for the same item twice gets two lines and only as many are greyed as they received
- if TMBExport has no data, or Gargul's data came from DFT / CPR / RRobin, Gargul's own lines are shown and only the greying is applied
- any error inside LootCheck falls back to Gargul's own list (reported once in chat)

Names are matched realm-insensitively (`Zhorax-Firemaw` == `zhorax`). Tier tokens follow Gargul's linked-ID table.

## Repository layout

The addon lives at the root of this repository, which is what the CurseForge packager expects, so a release zip is the repository with `tests/`, `tools/` and the CI files left out.

```
LootCheck.toc, *.lua   the addon
Libs/                  bundled libraries (see THIRD-PARTY-LICENSES.md)
tests/                 the offline test suite
tools/build-zip.py     builds a release zip by hand
.pkgmeta               tells the packager what to include
```

## Install

Copy the `LootCheck` folder into
`World of Warcraft\_anniversary_\Interface\AddOns\` and `/reload`.

## Settings

Stored in `LootCheckDB` (`WTF\Account\<account>\SavedVariables\LootCheck.lua`):

```lua
settings = {
    greyOSAwards   = true,  -- tooltip: also grey names that received the item via an OS roll/award
    receivedSuffix = "",    -- tooltip: text appended after a greyed name, e.g. " (received)"
    graphGroupOnly = false, -- graph: only show raiders currently in your group
    graphDays      = 0,     -- graph: only count awards from the last N days (0 = all time)
    dropsIncludeRare = false, -- raid drops list: show blue items as well as epics
}
```

## Licence

LootCheck's own code is MIT licensed: see [LICENSE](LICENSE). You may use, change and redistribute it, provided the copyright notice travels with it, and it comes with no warranty.

It also bundles LibStub, CallbackHandler-1.0, AceComm-3.0, ChatThrottleLib and LibDeflate, and contains code ported from TMBExport by Centpoursang - Spineshatter. Those keep their own licences, all of them permissive, recorded in [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md).

## Tests

```bash
python tests/harness.py
```

No Lua install and no running game are needed: the harness drives the addon inside a real Lua 5.1 VM (a `lua51.dll` borrowed from other installed software, such as OBS Studio) behind a stub layer of the WoW API. It runs against **real Gargul and TMBExport saved variables as fixtures**, so the assertions face the data shapes the addon actually meets in game rather than tidy invented ones. Tooltip output, greying, settings handling and the graph counts are all checked against an independent re-implementation.

Because the fixtures are real and change between phases, the suites discover the names and items they need at runtime instead of hardcoding them.

Point the harness elsewhere with environment variables if the defaults do not find things:

| Variable | Meaning |
|---|---|
| `LOOTCHECK_SV` | A `WTF/Account/<account>/SavedVariables` folder holding `Gargul.lua` and `TMBExport.lua` |
| `LOOTCHECK_WOW` | A WoW install to search for the above |
| `LOOTCHECK_LUA_DLL` | A Lua 5.1 / LuaJIT shared library to run in |
| `LOOTCHECK_ADDON` | The addon folder to load |

The harness also greps the source for Blizzard's `UIDropDownMenu` and `StaticPopupDialogs`. **LootCheck must never use either**: they taint the secure UI, and doing so once stopped the game menu's Log Out button from working.

## Releases

Pushing a tag builds the addon and uploads it to CurseForge:

```bash
git tag -a v1.0.1 -m "1.0.1" && git push origin v1.0.1
```

The tag must match the `## Version:` line in `LootCheck.toc`. `tools/build-zip.py` builds the same zip locally for a manual upload.
