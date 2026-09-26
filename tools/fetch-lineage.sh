#!/bin/bash
TMP="$1"
BASE="https://history.army.mil/html/forcestruc/lineages/branches/sc"
ok=0; fail=0
: > "$TMP/snapshots.tsv"
: > "$TMP/failed.txt"
# keep timestamps for anything already fetched
while read -r f; do
  [ -z "$f" ] && continue
  out="$TMP/raw/$f"
  if [ -s "$out" ]; then ok=$((ok+1)); continue; fi
  got=0
  for attempt in 1 2 3 4 5; do
    eff=$(curl -s -L --max-time 90 --retry 0 -o "$out.part" -w '%{url_effective}' \
          "https://web.archive.org/web/2020id_/$BASE/$f")
    if [ -s "$out.part" ] && grep -qi "Lineage" "$out.part"; then
      mv "$out.part" "$out"
      ts=$(echo "$eff" | sed -n 's|.*/web/\([0-9]\{14\}\)id_/.*|\1|p')
      printf '%s\t%s\n' "$f" "$ts" >> "$TMP/snapshots.tsv"
      ok=$((ok+1)); got=1; break
    fi
    rm -f "$out.part"
    sleep $((attempt * 8))
  done
  if [ $got -eq 0 ]; then echo "$f" >> "$TMP/failed.txt"; fail=$((fail+1)); fi
  sleep 2
done < "$TMP/pages.txt"
echo "DONE ok=$ok fail=$fail"
