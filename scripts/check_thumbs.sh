#!/bin/bash
# Audit all Live TV channel thumbnails: extract name+id+file+line, check HTTP status.
cd /Users/keonta/Documents/MyChannel/MyChannel/Core/Models || exit 1

OUT=/Users/keonta/Documents/MyChannel/build-verify/ltv_thumb_report.txt
DEAD=/Users/keonta/Documents/MyChannel/build-verify/ltv_dead.txt
: > "$OUT"
: > "$DEAD"

for f in LiveTVChannel+SampleData_c0*.swift; do
  awk -v file="$f" '
    /name: "/ {
      line=$0
      sub(/.*name: "/,"",line); sub(/".*/,"",line);
      curname=line
    }
    /i\.ytimg\.com\/vi\// {
      l=$0
      match(l, /i\.ytimg\.com\/vi\/[A-Za-z0-9_-]+\//)
      seg=substr(l, RSTART, RLENGTH)
      gsub(/i\.ytimg\.com\/vi\//,"",seg); gsub(/\//,"",seg)
      print file "|" NR "|" curname "|" seg
    }
  ' "$f" >> "$OUT"
done

TOTAL=$(wc -l < "$OUT")
echo "Total thumbnails: $TOTAL"

while IFS='|' read -r file line name id; do
  read code size < <(curl -s --max-time 10 -o /dev/null -w "%{http_code} %{size_download}" "https://i.ytimg.com/vi/$id/hqdefault.jpg")
  if [ "$code" != "200" ] || [ "$size" -lt 2000 ]; then
    echo "$file:$line | $name | $id | http=$code size=$size" >> "$DEAD"
  fi
done < "$OUT"

echo "Dead count: $(wc -l < "$DEAD")"
echo "--- DEAD LIST ---"
cat "$DEAD"
