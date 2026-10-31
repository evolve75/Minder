#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Build an unsigned, self-contained Minder.app from the current checkout using
# the Homebrew dependencies in the Brewfile. The bundle is for local use: it is
# not code-signed or notarized.
#
# Usage: macos/make-app.sh [output-dir]   (default: build-app/)

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-${repo}/build-app}"
brew_prefix="$(brew --prefix)"
app_id="io.github.phase1geo.minder"
version="$(sed -n "s/^ *version *: *'\([0-9.]*\)'.*/\1/p" "${repo}/meson.build" | head -n 1)"

build="${out}/meson"
stage="${out}/stage"
app="${out}/Minder.app"
contents="${app}/Contents"
res="${contents}/Resources"

# shellcheck source=macos/env.sh
source "${repo}/macos/env.sh"

echo "==> Building ${app_id} ${version}"
rm -rf "${build}" "${stage}" "${app}"
meson setup "${build}" "${repo}" --prefix=/usr/local --buildtype=release \
  -Dgranite=false -Dlatex=false -Dwebkit=false >/dev/null
meson compile -C "${build}" >/dev/null
DESTDIR="${stage}" meson install -C "${build}" >/dev/null

mkdir -p "${contents}/MacOS" "${contents}/Frameworks" "${res}/share"
cp "${stage}/usr/local/bin/${app_id}" "${contents}/MacOS/${app_id}"
cp -R "${stage}/usr/local/share/." "${res}/share/"

echo "==> Bundling shared libraries"
dylibbundler -od -b -x "${contents}/MacOS/${app_id}" \
  -d "${contents}/Frameworks" -p "@executable_path/../Frameworks" >/dev/null

echo "==> Bundling gdk-pixbuf loaders"
loader_src="${brew_prefix}/lib/gdk-pixbuf-2.0/2.10.0/loaders"
loader_dst="${res}/lib/gdk-pixbuf-2.0/loaders"
mkdir -p "${loader_dst}"
for loader in "${loader_src}"/*.so; do
  cp -L "${loader}" "${loader_dst}/"
  # </dev/null: dylibbundler prompts on stdin for libraries it cannot find
  dylibbundler -of -b -x "${loader_dst}/$(basename "${loader}")" \
    -d "${contents}/Frameworks" -p "@executable_path/../Frameworks" \
    -s "${brew_prefix}/lib" -s "${brew_prefix}/opt/librsvg/lib" >/dev/null 2>&1 </dev/null
done
# The loader cache holds absolute paths; store a placeholder that the launcher
# rewrites to the bundle's real location at startup.
# Query the original Homebrew loaders (the relocated copies cannot be loaded
# from here), then rewrite their directory.
gdk-pixbuf-query-loaders "${loader_src}"/*.so \
  | sed "s|${loader_src}|@RES@/lib/gdk-pixbuf-2.0/loaders|g" > "${res}/lib/gdk-pixbuf-2.0/loaders.cache.in"

echo "==> Copying runtime data"
# GtkSourceView language specs/styles and the Adwaita icon theme are found via
# XDG_DATA_DIRS, which the launcher points at the bundle.
cp -RL "${brew_prefix}/share/gtksourceview-5" "${res}/share/"
mkdir -p "${res}/share/icons"
cp -RL "${brew_prefix}/share/icons/Adwaita" "${res}/share/icons/"
glib-compile-schemas "${res}/share/glib-2.0/schemas"
gtk4-update-icon-cache -q -t -f "${res}/share/icons/hicolor" || true

echo "==> Writing launcher and Info.plist"
cat > "${contents}/MacOS/Minder" <<'LAUNCHER'
#!/usr/bin/env bash
# Launcher: point GLib/GTK at the bundled data, then run the real binary.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
res="${here}/../Resources"
export XDG_DATA_DIRS="${res}/share"
export GSETTINGS_SCHEMA_DIR="${res}/share/glib-2.0/schemas"
cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/minder"
mkdir -p "${cache_dir}"
sed "s|@RES@|${res}|g" "${res}/lib/gdk-pixbuf-2.0/loaders.cache.in" > "${cache_dir}/loaders.cache"
export GDK_PIXBUF_MODULE_FILE="${cache_dir}/loaders.cache"
exec "${here}/io.github.phase1geo.minder" "$@"
LAUNCHER
chmod +x "${contents}/MacOS/Minder"

icon_svg="${repo}/data/icons/scalable/${app_id}.svg"
iconset="${out}/Minder.iconset"
rm -rf "${iconset}"
mkdir -p "${iconset}"
for size in 16 32 128 256 512; do
  rsvg-convert -w "${size}" -h "${size}" "${icon_svg}" -o "${iconset}/icon_${size}x${size}.png"
  rsvg-convert -w "$((size * 2))" -h "$((size * 2))" "${icon_svg}" -o "${iconset}/icon_${size}x${size}@2x.png"
done
iconutil -c icns "${iconset}" -o "${res}/Minder.icns"

cat > "${contents}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Minder</string>
  <key>CFBundleDisplayName</key><string>Minder</string>
  <key>CFBundleIdentifier</key><string>${app_id}</string>
  <key>CFBundleVersion</key><string>${version}</string>
  <key>CFBundleShortVersionString</key><string>${version}</string>
  <key>CFBundleExecutable</key><string>Minder</string>
  <key>CFBundleIconFile</key><string>Minder</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

echo "==> Done: ${app}"
