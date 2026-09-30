# Lineage & Honors mirror — how it was built

`/lineage/` holds the museum's own copy of the official **lineage, campaign
participation credit, and unit citations** for the 171 Signal Regiment units the
Command Gallery roster links to. The records are compiled by the U.S. Army
Center of Military History (CMH) and are works of the U.S. Government.

## Why mirror them at all

The roster used to link straight to
`history.army.mil/html/forcestruc/lineages/branches/sc/<unit>.htm`. That host sits
behind an Akamai edge rule that answers **403 Access Denied** to a lot of
networks — including whole datacenter and VPN ranges — so those links were dead
for an unpredictable share of visitors. Each mirrored page still prints its
original CMH address and the archive snapshot it came from, so nothing is
laundered: the museum shows the record and says exactly where it came from.

## Pipeline

1. **`fetch-lineage.sh`** — pulls each file in `pages.txt` from the Internet
   Archive using the `id_` modifier, which returns the original bytes with no
   Wayback toolbar injected. Retries with backoff; the Archive throttles.

   ```bash
   bash tools/fetch-lineage.sh /tmp/lineage-work
   ```

2. **`fetch-fill-gaps.sh`** — some URLs' ~2020 captures landed on CMH's Azure
   migration 404 page. This walks that unit's 200-status snapshots newest-first
   until it finds a real record. Reads `missing.txt` in the work directory.

3. **`gen-lineage.pl`** — parses the raw captures and writes the styled pages.
   CMH published these in **three different markups** over the years and the
   parser handles all three:

   | Variant | Marker | Era |
   |---|---|---|
   | 1 | `p.header1` / `p.lindata` | late 1990s–2000s |
   | 2 | `p.unitz` + bare `<p>` + `<br>` lists | DA lineage certificate |
   | 3 | `h1` + `ul > li`, `li.lin_und` conflicts | 2010s |

   ```bash
   perl tools/gen-lineage.pl /tmp/lineage-work/raw lineage tools/snapshots.tsv
   ```

4. **`gen-index.pl`** — builds `lineage/index.html` (grouped, filterable) from
   the `manifest.tsv` that step 3 writes.

   ```bash
   perl tools/gen-index.pl lineage
   ```

## Files

- `pages.txt` — the 171 units, matching `LINEAGE_PAGES` in `index.html`.
- `snapshots.tsv` — `filename<TAB>archive timestamp` actually used per record,
  so every page can cite the exact capture it was built from.
- `lineage/manifest.tsv` — build output: file, unit, as-of date, and counts.

## Keeping it in sync

`lineageUrl()` in `index.html` maps a roster unit to `lineage/<file>`, and the
candidate filenames come from `LINEAGE_PAGES` in that same file. If you add a
unit to the roster, add its CMH filename to **both** `LINEAGE_PAGES` and
`pages.txt`, then re-run the pipeline.

Styling lives in `lineage/lineage.css` and mirrors the design tokens at the top
of `index.html`. If the museum's palette changes, change both.

## Unit Ready Room

Every unit page has a **Unit Ready Room** tile below its lineage record: photos, orders,
articles, films, magazine pages and stories about that unit, grouped by year with
a year filter. Units with nothing filed yet show an invitation and a pre-addressed
"Suggest material" email to the executive director.

The content lives in one file, **`lineage/readyroom.json`**, keyed by the unit's
lineage file name without `.htm` (`0501scbn` for `0501scbn.htm`). Adding material
needs no rebuild: add an entry and commit.

```json
"0501scbn": [
  {
    "year": 2004,
    "kind": "Photo",
    "title": "Lt. Col. Welton Chase, Jr. furls the 501st's colors, Mosul",
    "url": "https://www.defense.gov/observe/photo-gallery/igphoto/2001084839/",
    "source": "U.S. Department of Defense, Sgt. Robert Woodward",
    "date": "22 Jan 2004",
    "note": "Optional one-line note."
  }
]
```

- `year` is the year the material is **about**; use `null` for ongoing things such
  as an association's website. The page sorts years and lists `null` last as
  "Ongoing".
- `kind` is a short label: Exhibit, Article, Photo, Video, Magazine, Memorial,
  Record, Association, Oral history, Document.
- `url` may be external (opens in a new tab) or relative to `lineage/`, such as
  `../heritage/issue-3.html#p-12` for a magazine page or
  `../index.html#unit-501st-signal-battalion` for a section of the museum. The
  museum opens the room holding any element id given after `#`.
- Only add material the museum may show: public records, the Society's own
  publications, or items whose owners have given permission.

The tile markup and `readyroom.js` are part of the page template in
`gen-lineage.pl`, so regenerating the pages keeps them.
