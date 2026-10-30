#!/usr/bin/env bash
#
# Render a markdown resume or letter to PDF: pandoc -> docx -> Pages.
#
#   md2letter.sh <input.md> [output-basename] [top/bottom-margin-twips]
#
# Styling (Georgia headings, Arial body, 0.7in margins, paragraph spacing)
# all comes from resume-reference.docx. The only override is the top/bottom
# margin, because letters usually want to be tighter than the resume.
# Left/right margins always come from the reference doc.
#
#   1440 twips = 1 inch.  Default 1008 = 0.7in (same as the reference, so
#   nothing is patched).  864 = 0.6in suits a dense one-page letter.
#
# Pages is used rather than a pandoc PDF engine because Google Docs' exporter
# emits every glyph as a separate positioned Tj above ~16pt, which makes resume
# parsers split words ("Ch ad Walker"). Pages writes proper TJ arrays. To check
# a PDF, count single-glyph ops -- it should be zero:
#   pdftotext file.pdf - | head   # sanity
#   (see git log for the full analysis)
#
set -euo pipefail

SRC="$1"
OUT="${2:-${SRC%.md}}"
MARGIN="${3:-1008}"
REF="$HOME/.dotfiles/resume-reference.docx"

[ -f "$SRC" ] || { echo "md2letter: no such file: $SRC" >&2; exit 1; }
[ -f "$REF" ] || { echo "md2letter: missing reference doc: $REF" >&2; exit 1; }

OUT_DIR="$(cd "$(dirname "$OUT")" && pwd)"
BASE="$(basename "$OUT")"
DOCX="$OUT_DIR/$BASE.docx"
PDF="$OUT_DIR/$BASE.pdf"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pandoc "$SRC" -o "$DOCX" --reference-doc="$REF"

if [ "$MARGIN" != "1008" ]; then
  unzip -q "$DOCX" -d "$TMP"
  python3 - "$TMP" "$MARGIN" <<'PY'
import sys, re, pathlib
tmp, margin = sys.argv[1], sys.argv[2]
doc = pathlib.Path(tmp) / 'word/document.xml'
s = doc.read_text(encoding='utf-8')
s = re.sub(r'w:top="\d+"',    f'w:top="{margin}"',    s)
s = re.sub(r'w:bottom="\d+"', f'w:bottom="{margin}"', s)
doc.write_text(s, encoding='utf-8')
PY
  ( cd "$TMP" \
    && zip -X -q -D -0 repacked.zip '[Content_Types].xml' \
    && zip -X -q -D -9 -r repacked.zip . -x '[Content_Types].xml' repacked.zip )
  cp "$TMP/repacked.zip" "$DOCX"
fi

# Pages must already be running; `open` inside the tell block is unreliable.
open -a Pages
for _ in $(seq 1 40); do pgrep -x Pages >/dev/null && break; sleep 0.25; done
sleep 2

rm -f "$PDF"
osascript <<AS
tell application "Pages"
    set d to open POSIX file "$DOCX"
    delay 1
    export d to POSIX file "$PDF" as PDF
    close d saving no
end tell
AS

printf '%s -> %s (%s pages)\n' "$SRC" "$PDF" "$(pdfinfo "$PDF" | awk '/^Pages/{print $2}')"
