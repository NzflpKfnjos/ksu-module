#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT=${1:-"$ROOT/dist/ksu-bundle-installer.zip"}

case "$OUT" in
  /*) ;;
  *) OUT="$ROOT/$OUT" ;;
esac

found=false
for archive in "$ROOT"/*.zip "$ROOT"/packages/*.zip; do
  [ -f "$archive" ] || continue
  [ "$archive" = "$OUT" ] && continue
  found=true
  break
done
if [ "$found" != true ]; then
  printf 'No nested .zip files found. Put the modules in the project root or packages/.\n' >&2
  exit 1
fi

OUT_DIR=${OUT%/*}
mkdir -p "$OUT_DIR"
rm -f "$OUT"

cd "$ROOT"
zip -9 -r "$OUT" . \
  -x './.git/*' './.DS_Store' './.gitignore' './build.sh' './dist/*' \
     './tests/*' "./${OUT#"$ROOT"/}" >/dev/null

printf 'Built %s\n' "$OUT"
