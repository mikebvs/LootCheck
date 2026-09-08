# LootCheck

A companion addon for **[Gargul](https://www.curseforge.com/wow/addons/gargul)** and That's My BIS, for World of Warcraft: The Burning Crusade (Anniversary, Interface 20506).

It answers the two questions a loot council asks all night:

- **Has this raider already had this item?** Names on Gargul's TMB wishlist tooltip grey out once they have been awarded it.
- **What dropped, and where did it go?** Every rare and epic item that drops is listed per raid week, with who picked it up and who it was assigned to.

## What it does

| | |
|---|---|
| **One TMB list on the tooltip** | Gargul's "TMB Wish List" block is rebuilt from your own wishlist data in Gargul's format, honouring Gargul's TMB settings. TMBExport's duplicate block is switched off. |
| **Greys out names that already got the item** | Grey means exactly one thing: received. Everything else is class-coloured. |
| **Wishlist award graph** | `4 (22)` = 4 this phase, 22 all time. Hover a bar for the items and dates. |
| **Raid drops, per week** | Read from the loot window *and* from loot messages in chat, so every council member builds the same list with no addon-to-addon traffic. Rolls over at the Tuesday reset. |
| **LootCheck owns the wishlist data** | Paste That's My BIS CSV exports as named raids. A stale Gargul TMB import in a PUG cannot skew the tooltip or the numbers. |
| **Share with your council** | Whisper the active dataset to chosen players in your group; they save it as a new raid or merge it. Manual edits can be shared live with the same players. |

LootCheck never writes to Gargul's data.

**Full documentation, including every slash command, lives in [LootCheck/README.md](LootCheck/README.md).**

## Install

Copy the `LootCheck` folder into `World of Warcraft\_anniversary_\Interface\AddOns\`, so that `Interface\AddOns\LootCheck\LootCheck.toc` exists. Then `/lchelp`.

Gargul is required for award history and the tooltip integration. That's My BIS Export is optional — only a fallback for wishlist data before you paste your first import.

## Repository layout

```
LootCheck/     the addon, exactly as it ships
  Libs/        bundled libraries (see THIRD-PARTY-LICENSES.md)
tests/         an offline test suite that runs outside the game
```

## Tests

There is no Lua interpreter requirement and no WoW needed: `tests/harness.py` drives the addon inside a real Lua 5.1 VM (a `lua51.dll` borrowed from other installed software) behind a stub layer of the WoW API, using **real Gargul and TMBExport saved variables as fixtures** so the assertions face the data shapes the addon actually meets in game.

```bash
python tests/harness.py
```

Point it somewhere else with environment variables if the defaults do not find things:

| Variable | Meaning |
|---|---|
| `LOOTCHECK_SV` | A `WTF/Account/<account>/SavedVariables` folder holding `Gargul.lua` and `TMBExport.lua` |
| `LOOTCHECK_WOW` | A WoW install to search for the above |
| `LOOTCHECK_LUA_DLL` | A Lua 5.1 / LuaJIT shared library to run in |
| `LOOTCHECK_ADDON` | The addon folder to load |

The harness also greps the source for Blizzard's `UIDropDownMenu` and `StaticPopupDialogs`. **LootCheck must never use either**: they taint the secure UI, and doing so once stopped the game menu's Log Out button from working.

## Licence

MIT — see [LICENSE](LICENSE). Bundled libraries keep their own licences, listed in [LootCheck/THIRD-PARTY-LICENSES.md](LootCheck/THIRD-PARTY-LICENSES.md).
