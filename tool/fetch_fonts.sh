#!/usr/bin/env bash
# Downloads the Amiri Arabic font (SIL OFL: free to bundle in commercial apps) into assets/fonts
# and registers it in pubspec.yaml. Safe to run many times. NEVER fails the build:
# if the download fails, the app simply falls back to the system Arabic font.
set -u
cd "$(dirname "$0")/.."
BASE="${AMIRI_BASE_URL:-https://github.com/google/fonts/raw/main/ofl/amiri}"
DIR="assets/fonts"
mkdir -p "$DIR"

# valid TrueType = bigger than 100 KB and starts with 00 01 00 00
is_ttf() {
  [ -s "$1" ] \
    && [ "$(wc -c < "$1" | tr -d ' ')" -gt 100000 ] \
    && [ "$(head -c4 "$1" | od -An -tx1 | tr -d ' \n')" = "00010000" ]
}

ok=1
for f in Amiri-Regular.ttf Amiri-Bold.ttf; do
  if ! is_ttf "$DIR/$f"; then
    echo "↓ downloading $f"
    curl -fsSL --retry 3 --retry-delay 2 -o "$DIR/$f" "$BASE/$f" || true
  fi
  if is_ttf "$DIR/$f"; then
    echo "✓ $f ($(wc -c < "$DIR/$f" | tr -d ' ') bytes)"
  else
    echo "✗ $f missing/invalid"; rm -f "$DIR/$f"; ok=0
  fi
done
[ -s "$DIR/OFL.txt" ] || curl -fsSL -o "$DIR/OFL.txt" "$BASE/OFL.txt" || true

if [ "$ok" = 1 ]; then
  if ! grep -q "family: Amiri" pubspec.yaml; then
    cat >> pubspec.yaml <<'PUBSPEC_FONTS'
  fonts:
    - family: Amiri
      fonts:
        - asset: assets/fonts/Amiri-Regular.ttf
        - asset: assets/fonts/Amiri-Bold.ttf
          weight: 700
PUBSPEC_FONTS
    echo "✓ Amiri registered in pubspec.yaml"
  else
    echo "✓ Amiri already registered in pubspec.yaml"
  fi
else
  echo "⚠ Amiri NOT bundled: the tagline will use the system Arabic font (build continues)."
fi
exit 0
