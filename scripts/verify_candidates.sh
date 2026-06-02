#!/bin/bash
# Verify candidate YouTube thumbnail IDs. Prints ALIVE only for ids that return
# a real (>=2KB) 200 image at hqdefault. Format: "name|id"
candidates=(
  "Martin|kc5MShTBW9w"
  "Martin|Mnk3eMUFh2k"
  "Everybody Hates Chris|2yIA0GZJlGk"
  "Everybody Hates Chris|0wY3W5x0pZA"
  "NBA TV|jSL6kbpQpQ4"
  "NBA TV|RnXjAEgEEbY"
  "CBS News|gA0OZHJjMnY"
  "CBS News|tWLZUKDp4ZU"
  "Forensic Files|7p3kdq7Cvgo"
  "Forensic Files|5Ggik1rly3k"
  "Family Guy|fkc88dbDFGw"
  "South Park|B3Mj8Ht0g8M"
  "King of the Hill|qsdoZ9pXf9I"
  "Bob's Burgers|XJBPmFDqWVE"
  "Regular Show|kpsZBPj_Wis"
  "Adventure Time|FF2qHbExc9I"
)
for entry in "${candidates[@]}"; do
  name="${entry%%|*}"
  id="${entry##*|}"
  read code size < <(curl -s --max-time 10 -o /dev/null -w "%{http_code} %{size_download}" "https://i.ytimg.com/vi/$id/hqdefault.jpg")
  status="DEAD"
  if [ "$code" = "200" ] && [ "$size" -ge 2000 ]; then status="ALIVE"; fi
  echo "$status | $name | $id | http=$code size=$size"
done
