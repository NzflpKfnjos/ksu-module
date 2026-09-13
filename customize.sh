#!/system/bin/sh

# The outer KernelSU installer has already extracted this module before sourcing
# customize.sh. Nested module archives are handed back to ksud so they receive
# the normal KernelSU installation flow and lifecycle scripts.

KSU_DAEMON="${KSU_DAEMON:-/data/adb/ksud}"
PM="${PM:-/system/bin/pm}"
SDCARD_DIR="${SDCARD_DIR:-/sdcard}"
ARCHIVE_LIST="$MODPATH/.ksu-bundle-archives"
APK_LIST="$MODPATH/.ksu-bundle-apks"
SDCARD_LIST="$MODPATH/.ksu-bundle-sdcard"
ID_LIST="$MODPATH/.ksu-bundle-ids"

ui_print ""
ui_print "== KSU Bundle Installer =="

sort_by_name() {
  input=$1
  output=$2

  while IFS= read -r item; do
    printf '%s\t%s\n' "${item##*/}" "$item"
  done < "$input" > "$output.names" || abort "! Cannot prepare the file list"
  sort -t "$(printf '\t')" -k 1,1 -k 2,2 "$output.names" \
    | cut -f 2- > "$output" || abort "! Cannot sort the file list"
  rm -f "$output.names"
}

# Find nested KernelSU modules. They must be directly inside modules/.
: > "$ARCHIVE_LIST" || abort "! Cannot create the module list"
if [ -d "$MODPATH/modules" ]; then
  find "$MODPATH/modules" -maxdepth 1 -type f -iname '*.zip' -print \
    >> "$ARCHIVE_LIST" 2>/dev/null
fi

# Find APKs. They must be directly inside apks/.
: > "$APK_LIST" || abort "! Cannot create the APK list"
if [ -d "$MODPATH/apks" ]; then
  find "$MODPATH/apks" -maxdepth 1 -type f -iname '*.apk' -print \
    >> "$APK_LIST" 2>/dev/null
fi

if [ ! -s "$ARCHIVE_LIST" ] && [ ! -s "$APK_LIST" ] \
  && [ ! -d "$MODPATH/sdcard" ]; then
  abort "! No modules, APKs, or sdcard files were found"
fi

if [ -s "$ARCHIVE_LIST" ]; then
  sort_by_name "$ARCHIVE_LIST" "$ARCHIVE_LIST.sorted"
  mv -f "$ARCHIVE_LIST.sorted" "$ARCHIVE_LIST" \
    || abort "! Cannot prepare the module list"
  : > "$ID_LIST" || abort "! Cannot create the module ID list"

  if [ ! -x "$KSU_DAEMON" ]; then
    abort "! /data/adb/ksud was not found or is not executable"
  fi

  count=0
  while IFS= read -r archive; do
    [ -n "$archive" ] || continue

    if ! unzip -t "$archive" >/dev/null 2>&1; then
      abort "! Invalid ZIP archive: ${archive##*/}"
    fi

    prop=$(unzip -p "$archive" module.prop 2>/dev/null) || prop=
    id=$(printf '%s\n' "$prop" | sed -n 's/^id=//p' | head -n 1 | tr -d '\r')

    if ! printf '%s\n' "$id" | grep -Eq '^[A-Za-z][A-Za-z0-9._-]+$'; then
      abort "! Invalid or missing module ID in: ${archive##*/}"
    fi
    if [ "$id" = "ksu-bundle-installer" ]; then
      abort "! A nested archive cannot use the bundle installer ID"
    fi
    if grep -Fqx "$id" "$ID_LIST"; then
      abort "! Duplicate module ID '$id'"
    fi
    printf '%s\n' "$id" >> "$ID_LIST"

    ui_print "- Installing module ${archive##*/} [$id]"
    if ! "$KSU_DAEMON" module install "$archive"; then
      abort "! Module installation failed: ${archive##*/}"
    fi
    count=$((count + 1))
  done < "$ARCHIVE_LIST"
  ui_print "- Installed $count KSU module(s)"
fi

if [ -s "$APK_LIST" ]; then
  sort_by_name "$APK_LIST" "$APK_LIST.sorted"
  mv -f "$APK_LIST.sorted" "$APK_LIST" \
    || abort "! Cannot prepare the APK list"

  if [ ! -x "$PM" ]; then
    abort "! $PM was not found or is not executable"
  fi

  apk_count=0
  while IFS= read -r apk; do
    [ -n "$apk" ] || continue
    ui_print "- Installing APK ${apk##*/}"
    if ! "$PM" install -r "$apk"; then
      abort "! APK installation failed: ${apk##*/}"
    fi
    apk_count=$((apk_count + 1))
  done < "$APK_LIST"
  ui_print "- Installed $apk_count APK(s)"
fi

move_sdcard_item() {
  source=$1
  relative=${source#"$MODPATH/sdcard"/}
  target="$SDCARD_DIR/$relative"

  if [ -d "$source" ] && [ ! -L "$source" ]; then
    if [ -e "$target" ] && [ ! -d "$target" ]; then
      abort "! Cannot move directory over non-directory: $target"
    fi
    mkdir -p "$target" || abort "! Cannot create directory: $target"
    cp -af "$source"/. "$target"/ \
      || abort "! Cannot copy files to: $target"
    rm -rf "$source" || abort "! Cannot remove staged directory: $source"
  else
    parent=${target%/*}
    mkdir -p "$parent" || abort "! Cannot create directory: $parent"
    if [ -d "$target" ] && [ ! -L "$target" ]; then
      abort "! Cannot move file over directory: $target"
    fi
    rm -f "$target"
    cp -af "$source" "$target" \
      || abort "! Cannot copy file to: $target"
    rm -f "$source" || abort "! Cannot remove staged file: $source"
  fi
}

if [ -d "$MODPATH/sdcard" ]; then
  : > "$SDCARD_LIST" || abort "! Cannot create the sdcard file list"
  find "$MODPATH/sdcard" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' -print \
    > "$SDCARD_LIST" 2>/dev/null
  sdcard_count=0
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    ui_print "- Moving ${item##*/} to /sdcard/"
    move_sdcard_item "$item"
    sdcard_count=$((sdcard_count + 1))
  done < "$SDCARD_LIST"
  ui_print "- Moved $sdcard_count item(s) to /sdcard/"
fi

# The payload has served its purpose. Keep the installed outer module small;
# nested modules are now independent modules and sdcard files are persistent.
rm -rf "$MODPATH/modules" "$MODPATH/apks" "$MODPATH/sdcard"
rm -f "$ARCHIVE_LIST" "$APK_LIST" "$SDCARD_LIST" "$ID_LIST"
