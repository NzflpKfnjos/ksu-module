#!/system/bin/sh

# The outer KernelSU installer has already extracted this module before sourcing
# customize.sh. Each nested archive is then handed back to ksud so it receives
# the normal KernelSU installation flow and lifecycle scripts.

KSU_DAEMON="${KSU_DAEMON:-/data/adb/ksud}"
ARCHIVE_LIST="$MODPATH/.ksu-bundle-archives"
ARCHIVE_NAMES="$MODPATH/.ksu-bundle-archive-names"
ID_LIST="$MODPATH/.ksu-bundle-ids"

ui_print ""
ui_print "== KSU Bundle Installer =="

if [ ! -x "$KSU_DAEMON" ]; then
  abort "! /data/adb/ksud was not found or is not executable"
fi

: > "$ARCHIVE_LIST" || abort "! Cannot create the archive list"
find "$MODPATH" -maxdepth 1 -type f -name '*.zip' -print >> "$ARCHIVE_LIST" 2>/dev/null
if [ -d "$MODPATH/packages" ]; then
  find "$MODPATH/packages" -maxdepth 1 -type f -name '*.zip' -print >> "$ARCHIVE_LIST" 2>/dev/null
fi

if [ ! -s "$ARCHIVE_LIST" ]; then
  abort "! No nested .zip files were found"
fi

while IFS= read -r archive; do
  printf '%s\t%s\n' "${archive##*/}" "$archive"
done < "$ARCHIVE_LIST" > "$ARCHIVE_NAMES" || abort "! Cannot prepare the archive names"
sort -t "$(printf '\t')" -k 1,1 -k 2,2 "$ARCHIVE_NAMES" | cut -f 2- > "$ARCHIVE_LIST.sorted" || abort "! Cannot sort the archive list"
mv -f "$ARCHIVE_LIST.sorted" "$ARCHIVE_LIST" || abort "! Cannot prepare the archive list"
rm -f "$ARCHIVE_NAMES"
: > "$ID_LIST" || abort "! Cannot create the module ID list"

count=0
while IFS= read -r archive; do
  [ -n "$archive" ] || continue

  if ! unzip -t "$archive" >/dev/null 2>&1; then
    abort "! Invalid ZIP archive: $(basename "$archive")"
  fi

  prop=$(unzip -p "$archive" module.prop 2>/dev/null) || prop=
  id=$(printf '%s\n' "$prop" | sed -n 's/^id=//p' | head -n 1 | tr -d '\r')

  if ! printf '%s\n' "$id" | grep -Eq '^[A-Za-z][A-Za-z0-9._-]+$'; then
    abort "! Invalid or missing module ID in: $(basename "$archive")"
  fi
  if [ "$id" = "ksu-bundle-installer" ]; then
    abort "! A nested archive cannot use the bundle installer ID"
  fi
  if grep -Fqx "$id" "$ID_LIST"; then
    abort "! Duplicate module ID '$id'"
  fi
  printf '%s\n' "$id" >> "$ID_LIST"

  ui_print "- Installing $(basename "$archive") [$id]"
  if ! "$KSU_DAEMON" module install "$archive"; then
    abort "! Installation failed for $(basename "$archive"); bundle stopped"
  fi
  count=$((count + 1))
done < "$ARCHIVE_LIST"

ui_print "- Installed $count bundled module(s)"
rm -f "$ARCHIVE_LIST" "$ARCHIVE_NAMES" "$ID_LIST"
