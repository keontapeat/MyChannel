#!/bin/bash
# faststart-upload.sh
# Usage: ./scripts/faststart-upload.sh "gs://mychannel-ca26d.firebasestorage.app/YourVideo.mp4"
# OR:    ./scripts/faststart-upload.sh "https://firebasestorage.googleapis.com/v0/b/...?alt=media&token=..."
#
# What it does:
#   1. Downloads the video from Firebase Storage
#   2. Re-encodes with -movflags +faststart (moov atom at front = instant autoplay)
#   3. Re-uploads to the same path, replacing the original
#
set -euo pipefail

INPUT="$1"
TMP_DIR=$(mktemp -d)
ORIGINAL="$TMP_DIR/original.mp4"
FASTSTART="$TMP_DIR/faststart.mp4"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# ── Resolve gs:// path ──────────────────────────────────────────────────────
if [[ "$INPUT" == gs://* ]]; then
    GS_PATH="$INPUT"
    echo "⬇️  Downloading from $GS_PATH ..."
    gsutil cp "$GS_PATH" "$ORIGINAL"
elif [[ "$INPUT" == https://* ]]; then
    # Extract bucket + object path from signed URL
    # e.g. https://firebasestorage.googleapis.com/v0/b/BUCKET/o/PATH?alt=media&token=...
    BUCKET=$(echo "$INPUT" | sed -n 's|.*firebasestorage.googleapis.com/v0/b/\([^/]*\)/o/.*|\1|p')
    OBJECT_ENCODED=$(echo "$INPUT" | sed -n 's|.*firebasestorage.googleapis.com/v0/b/[^/]*/o/\([^?]*\).*|\1|p')
    OBJECT=$(python3 -c "import urllib.parse, sys; print(urllib.parse.unquote(sys.argv[1]))" "$OBJECT_ENCODED")
    GS_PATH="gs://$BUCKET/$OBJECT"
    echo "⬇️  Downloading from $GS_PATH ..."
    gsutil cp "$GS_PATH" "$ORIGINAL"
else
    echo "❌  Pass a gs:// path or a firebasestorage.googleapis.com URL"
    exit 1
fi

# ── Re-encode with faststart ────────────────────────────────────────────────
SIZE_BEFORE=$(du -sh "$ORIGINAL" | cut -f1)
echo "🎬  Re-encoding with faststart (was $SIZE_BEFORE) ..."
ffmpeg -i "$ORIGINAL" \
    -c:v libx264 -preset fast -crf 23 \
    -profile:v high -level 4.1 \
    -c:a aac -b:a 128k \
    -movflags +faststart \
    -y "$FASTSTART" 2>&1 | grep -E "frame=|fps=|time=|size=|error" || true

SIZE_AFTER=$(du -sh "$FASTSTART" | cut -f1)
echo "✅  Done: $SIZE_BEFORE → $SIZE_AFTER"

# ── Re-upload to same path ──────────────────────────────────────────────────
echo "⬆️  Uploading back to $GS_PATH ..."
gsutil cp "$FASTSTART" "$GS_PATH"

echo ""
echo "🚀  Faststart upload complete: $GS_PATH"
echo "    AVPlayer will now start playing after just the first ~100KB downloads."
