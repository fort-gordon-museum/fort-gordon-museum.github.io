#!/bin/bash
# For pages whose ~2020 capture landed on CMH's Azure-migration 404, walk back
# through the archive's 200-status snapshots until a real record turns up.
TMP="$1"
for f in $(cat "$TMP/missing.txt"); do
  [ -z "$f" ] && continue
  out="$TMP/raw/$f"
  [ -s "$out" ] && continue
  base="${f%.htm}"
  # newest first, de-duplicated
  tss=$(curl -s --max-time 90 "https://web.archive.org/cdx/search/cdx?url=history.army.mil/html/forcestruc/lineages/branches/sc/$f&output=text&fl=timestamp&filter=statuscode:200&matchType=exact" \
        | sort -u -r | head -14)
  got=0
  for ts in $tss; do
    curl -s -L --max-time 90 -o "$out.part" \
      "https://web.archive.org/web/${ts}id_/http://www.history.army.mil/html/forcestruc/lineages/branches/sc/$f"
    if [ -s "$out.part" ] \
       && grep -qi "Lineage And Honors Information\|Lineage and Honors Information" "$out.part" \
       && ! grep -qi "Error 404\|404 Not Found" "$out.part"; then
      mv "$out.part" "$out"
      printf '%s\t%s\n' "$f" "$ts" >> "$TMP/snapshots.tsv"
      echo "ok $f @ $ts"
      got=1; break
    fi
    rm -f "$out.part"
    sleep 3
  done
  [ $got -eq 0 ] && echo "STILL-MISSING $f"
  sleep 2
done
echo "GAPFILL-DONE have=$(ls "$TMP/raw" | grep -c '[.]htm$')"
