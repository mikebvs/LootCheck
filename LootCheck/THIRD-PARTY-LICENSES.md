# Third-party code in LootCheck

LootCheck is MIT licensed (see [LICENSE](LICENSE)). It also ships several
libraries and contains code ported from another addon. Each of those keeps its
own licence, recorded here.

## Bundled libraries (`Libs/`)

| Library | Author | Licence |
|---|---|---|
| LibStub | Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke | Public domain, stated at the top of the file |
| CallbackHandler-1.0 | The Ace3 team | Ace3 Style BSD |
| AceComm-3.0 | The Ace3 team | Ace3 Style BSD |
| ChatThrottleLib | Mikk | Public domain, stated at the top of the file |
| LibDeformat-3.0 | MIT | ckknight | Parses Blizzard's loot chat messages back into item link + player name |
| LibDeflate | Haoqian He | zlib licence, copyright 2018-2020 |

All five are permissive and allow redistribution inside another addon, which is
how nearly every WoW addon ships them. The files are included unmodified, so
each keeps its original header. Full terms:

- Ace3: <https://www.wowace.com/projects/ace3> (licence: Ace3 Style BSD)
- LibDeflate: <https://github.com/SafeteeWoW/LibDeflate> (zlib licence)

## Code ported from TMBExport

Two parts of LootCheck are derived from **TMBExport** by Centpoursang -
Spineshatter:

- `TierTokens.lua`: the tier piece to token table and `RemapTierPieces`
- the CSV parser in `Imports.lua`

TMBExport is MIT licensed, which permits this provided its notice travels with
the code. Reproduced in full as that licence requires:

```
MIT License

Copyright (c) 2026 Centpoursang - Spineshatter

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Addons LootCheck works with

Gargul and TMBExport are read at runtime but not redistributed, so their
licences do not apply to this package.
