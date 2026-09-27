# Heritage reading room — how it is built

`/heritage/` puts every issue of *Heritage*, the Society's magazine, on the
museum's own site instead of only on Issuu. Each issue gets:

- **A reader** (`heritage/issue-N.html`) with two views. **Read text** shows
  the page's text on a paper-colored sheet, sized for the screen, with
  adjustable type. **Page scans** shows the original pages. Any page opens full
  size, with next/previous and zoom. "Cont. on page 13" lines link to that page.
- **A PDF** (`heritage/pdf/`) of the whole issue for download or printing.

`heritage/index.html` is the shelf of all issues.

## Pipeline

1. **`fetch.sh`** — reads each issue's public Issuu reader manifest
   (`reader3.isu.pub/fghms/<doc>/reader3_4.json`) and downloads every page
   scan (1156×1496 JPEG) plus the page's text layer.

2. **`issuu-text.pl`** (with **`issuu-layer.pl`**) — decodes a text layer.
   Issuu stores the PDF's text as protobuf: text runs with a position matrix
   and per-glyph offsets. The script joins runs into lines, and lines into
   paragraphs and headings by font size and spacing. It also rejoins
   hyphenated words, expands ligatures, and drops running heads and folios.
   Output is one block per line: `H<TAB>heading` or `P<TAB>paragraph`.

3. **`thumbs.ps1`** — makes the 360px thumbnails in `heritage/issue-N/thumbs/`
   (Windows PowerShell, System.Drawing):

   ```powershell
   foreach ($n in 1..3) { .\tools\heritage\thumbs.ps1 -src heritage\issue-$n -dst heritage\issue-$n\thumbs -width 360 -quality 70 }
   ```

4. **`build.pl`** — writes the readers, the shelf, `heritage.css`, and the
   PDFs (via **`mkpdf.pl`**, which wraps each JPEG in a US Letter page with
   no re-encoding). Issue titles, seasons and the "In this issue" lists live at
   the top of `build.pl`. The lists for issues 1 and 2 come from the printed
   tables of contents; issue 3 has none, so its list follows the page headlines.

   ```bash
   perl tools/heritage/build.pl
   ```

## Correcting the text

`tools/heritage/text/issue-N/pNN.txt` is the source for the text view. Fix a
typo or a merged word there, then run `build.pl` again. Re-running `fetch.sh`
overwrites these files.

Pages with little or no text (covers, photo spreads, and pages Issuu has only
as a picture, such as issue 3 page 15) show the page scan in the text view too.

## Adding an issue

Add it to the list in `fetch.sh` and to `@ISSUES` in `build.pl`, then run all
four steps. The *Shaping Space Operations* issue is shown as "coming soon" on
the shelf until it is published online.
