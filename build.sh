#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT=${1:-"$ROOT/dist/ksu-bundle-installer.zip"}

case "$OUT" in
  /*) ;;
  *) OUT="$ROOT/$OUT" ;;
esac

found=false
if [ -n "$(find "$ROOT/modules" -maxdepth 1 -type f -iname '*.zip' \
  -print 2>/dev/null | head -n 1)" ]; then
  found=true
fi
if [ "$found" = false ] && [ -n "$(find "$ROOT/apks" -maxdepth 1 -type f -iname '*.apk' \
  -print 2>/dev/null | head -n 1)" ]; then
  found=true
fi
if [ "$found" = false ] && [ -d "$ROOT/sdcard" ] \
  && [ -n "$(find "$ROOT/sdcard" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' \
    -print 2>/dev/null | head -n 1)" ]; then
  found=true
fi
if [ "$found" != true ]; then
  printf 'No payload found. Put module ZIPs in modules/, APKs in apks/, or files in sdcard/.\n' >&2
  exit 1
fi

OUT_DIR=${OUT%/*}
mkdir -p "$OUT_DIR"
rm -f "$OUT"

cd "$ROOT"
zip -9 -r "$OUT" . \
  -x './.git/*' './.DS_Store' './.gitignore' './build.sh' './dist/*' \
     './tests/*' './update.json' "./${OUT#"$ROOT"/}" >/dev/null

printf 'Built %s\n' "$OUT"
