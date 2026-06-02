#!/bin/bash
# Test stable, non-rotting image sources (TMDB still images / posters) for key shows.
# TMDB image paths are immutable once published. Format: label|url
urls=(
  "Martin_poster|https://image.tmdb.org/t/p/w500/8Lu4kVqQ4Z5xqzD6h4kqGm0Yx7f.jpg"
  "DBZ_yt|https://i.ytimg.com/vi/TZuJLX5sK14/hqdefault.jpg"
  "FreshPrince_yt|https://i.ytimg.com/vi/ghMFFe2Q9hA/hqdefault.jpg"
)
for entry in "${urls[@]}"; do
  label="${entry%%|*}"
  url="${entry##*|}"
  read code size < <(curl -s --max-time 12 -o /dev/null -w "%{http_code} %{size_download}" "$url")
  status="DEAD"
  if [ "$code" = "200" ] && [ "$size" -ge 2000 ]; then status="ALIVE"; fi
  echo "$status | $label | http=$code size=$size"
done
