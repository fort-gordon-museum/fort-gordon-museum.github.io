#!/usr/bin/env bash
# Pulls every page of the Heritage issues from Issuu's public reader:
# the page scans into heritage/issue-N/ and the page text into
# tools/heritage/text/issue-N/ (via Issuu's text layer, see issuu-text.pl).
#
#   bash tools/heritage/fetch.sh
#
# Re-running overwrites the text files, so any hand corrections made there
# are lost. Run it only to add an issue or to start over.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$here/../.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# issue number, Issuu document name (issuu.com/fghms/docs/<name>)
issues=(
  "1 fghms_2020_1st_edition_final"
  "2 fghms_2021_2nd_edition"
  "3 fghms_2021_3rd_edition_sof"
)

for entry in "${issues[@]}"; do
  read -r n doc <<<"$entry"
  echo "issue $n: $doc"
  mkdir -p "$root/heritage/issue-$n" "$here/text/issue-$n"
  curl -fsS -A "Mozilla/5.0" "https://reader3.isu.pub/fghms/$doc/reader3_4.json" | gunzip -c 2>/dev/null > "$work/$doc.json" \
    || curl -fsS -A "Mozilla/5.0" "https://reader3.isu.pub/fghms/$doc/reader3_4.json" > "$work/$doc.json"
  # one line per page: <number> <image url> <text layer url or ->
  perl -ne 'while (/"imageUri":\s*"([^"]+page_(\d+)\.jpg)"(.*?)(?="imageUri"|$)/g) { my ($u, $p, $r) = ($1, $2, $3); my ($l) = $r =~ /"uri":\s*"([^"]+)"/; print "$p $u ", ($l // "-"), "\n" }' \
    "$work/$doc.json" > "$work/$doc.pages"
  while read -r p img layer; do
    pp=$(printf 'p%02d' "$p")
    curl -fsS "https://$img" -o "$root/heritage/issue-$n/$pp.jpg"
    if [ "$layer" != "-" ]; then
      curl -fsS "https://$layer" | gunzip -c > "$work/$pp.bin"
      perl "$here/issuu-text.pl" "$work/$pp.bin" > "$here/text/issue-$n/$pp.txt"
    fi
  done < "$work/$doc.pages"
  echo "  $(wc -l < "$work/$doc.pages") pages"
done
echo "Next: make thumbnails (thumbs.ps1), then run build.pl."
