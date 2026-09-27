# Signal & Cyber Corps Museum Society — Virtual Museum

The online museum of the **Signal & Cyber Corps Museum Society**, formerly the
Fort Gordon Historical Museum Society — a 501(c)(3) of volunteers preserving the
history of Americans who served at Fort Eisenhower (formerly Fort Gordon), in the
Signal Regiment, and in the Army's Cyber Corps.

**Secure Our Story**

- **Virtual museum:** https://sc-museum.github.io
- **Society:** https://www.signalandcybercorpsmuseum.org/en
- **Donate:** https://givebutter.com/hpEeXi

The Signal Corps Museum on post closed on 25 February 2021 when base construction
took its building, and the collection has been in storage since. The Society is
raising $250,000 to buy and renovate a building outside the gates of Fort
Eisenhower. This virtual museum keeps the collection open to the public meanwhile.

## What is here

| Path | What it is |
|---|---|
| `index.html` | The museum itself — a single self-contained page. Images are embedded as base64, so there are no external asset requests. |
| `lineage/` | Mirror of the official lineage, campaign participation credit, and unit citations for the 171 Signal Regiment units in the Command Gallery roster, plus a filterable index. |
| `heritage/` | The Heritage magazine reading room: every issue as readable text and page scans, plus a PDF download of each. |
| `tools/` | Fetch and build scripts for the lineage mirror and the Heritage reading room (`tools/heritage/`), each with its own README. |

## A note on names

This is a history museum, so the two names are not interchangeable and the site
does not treat them as such:

- **Fort Gordon** is kept wherever the record uses it — Camp Gordon in the First
  World War, Fort Gordon as the Signal Corps' home, the 2013 stand-up of the
  Cyber Center of Excellence, and every line of official CMH lineage text.
- **Fort Eisenhower** is used for the present day. The post was redesignated on
  27 October 2023 for General of the Army Dwight D. Eisenhower.

Likewise **FGHMS** stays on the artifacts that carry it — the Society's own fact
sheets and the pages of *Heritage* — because those are documents, not branding.

## Editing

`index.html` is one large file (~12.8 MB, mostly embedded images). Edit it in
place; there is no build step. The `lineage/` pages are generated — change
`tools/gen-lineage.pl` or `tools/gen-index.pl` and re-run rather than editing the
output by hand. See `tools/README.md`.
