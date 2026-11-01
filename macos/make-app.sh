#!/usr/bin/env bash
# Copyright (C) 2026 Anupam Sengupta <anupamsg@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301 USA
#
# Authored by: Anupam Sengupta <anupamsg@gmail.com>
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
if ! meson compile -C "${build}" >"${out}/compile.log" 2>&1; then
  grep -a -m5 "error:" "${out}/compile.log" >&2 || tail -n 20 "${out}/compile.log" >&2
  exit 1
fi
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
# GTK itself needs its schemas (e.g. the file chooser's) in the same directory,
# because GSETTINGS_SCHEMA_DIR replaces the default search path.
cp "${brew_prefix}"/share/glib-2.0/schemas/*.gschema.xml "${res}/share/glib-2.0/schemas/"
glib-compile-schemas "${res}/share/glib-2.0/schemas"
gtk4-update-icon-cache -q -t -f "${res}/share/icons/hicolor" || true

echo "==> Building launcher and Info.plist"
# The main executable is a small Mach-O launcher (a script would not be
# signable/notarizable as a main executable); it points GLib/GTK at the bundle.
cc -O2 -Wall -o "${contents}/MacOS/Minder" "${repo}/macos/launcher.c"

# Build the application and document icons.  rsvg will not load images from
# outside an SVG's own directory, so inline the shared bubble artwork first.
bubble="${repo}/data/icons/scalable/${app_id}.svg"
bubble_b64="$(base64 < "${bubble}" | tr -d '\n')"
icon_tmp="${out}/icons"
rm -rf "${icon_tmp}"
mkdir -p "${icon_tmp}"

make_icns() {
  local name="${1}" icns="${2}"
  local svg="${icon_tmp}/${name}.svg"
  local iconset="${icon_tmp}/${name}.iconset"
  sed "s|../../data/icons/scalable/${app_id}.svg|data:image/svg+xml;base64,${bubble_b64}|" \
    "${repo}/macos/icons/${name}.svg" > "${svg}"
  mkdir -p "${iconset}"
  local size
  for size in 16 32 128 256 512; do
    rsvg-convert -w "${size}" -h "${size}" "${svg}" -o "${iconset}/icon_${size}x${size}.png"
    rsvg-convert -w "$((size * 2))" -h "$((size * 2))" "${svg}" -o "${iconset}/icon_${size}x${size}@2x.png"
  done
  iconutil -c icns "${iconset}" -o "${icns}"
}

make_icns AppIcon  "${res}/Minder.icns"
make_icns Document "${res}/MinderDocument.icns"

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
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>Minder Mind Map</string>
      <key>CFBundleTypeRole</key><string>Editor</string>
      <key>LSHandlerRank</key><string>Owner</string>
      <key>LSItemContentTypes</key>
      <array><string>io.github.phase1geo.minder.document</string></array>
      <key>CFBundleTypeIconFile</key><string>MinderDocument</string>
    </dict>
  </array>
  <key>UTExportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key><string>io.github.phase1geo.minder.document</string>
      <key>UTTypeDescription</key><string>Minder Mind Map</string>
      <key>UTTypeConformsTo</key>
      <array><string>public.data</string></array>
      <key>UTTypeIconFile</key><string>MinderDocument</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array><string>minder</string></array>
        <key>public.mime-type</key>
        <array><string>application/io.github.phase1geo.minder</string></array>
      </dict>
    </dict>
  </array>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

# Sign from the inside out: every library and loader, the binaries, then the
# bundle.  Ad-hoc by default; set MINDER_SIGN_IDENTITY to a "Developer ID
# Application: ..." identity to sign for distribution (hardened runtime and a
# secure timestamp are then enabled, as notarization requires).
identity="${MINDER_SIGN_IDENTITY:--}"
sign_args=(--force --sign "${identity}")
# MINDER_HARDENED_RUNTIME=1 enables the hardened runtime even for ad-hoc signing,
# to test that the bundle still loads its libraries under it.
if [[ "${identity}" != "-" || "${MINDER_HARDENED_RUNTIME:-0}" == "1" ]]; then
  sign_args+=(--options runtime)
  if [[ "${identity}" == Developer\ ID* ]]; then
    sign_args+=(--timestamp)
  else
    sign_args+=(--timestamp=none)
  fi
fi

if [[ -n "${MINDER_ENTITLEMENTS:-}" ]]; then
  sign_args+=(--entitlements "${MINDER_ENTITLEMENTS}")
fi

echo "==> Signing (identity: ${identity})"
find "${contents}" \( -name '*.dylib' -o -name '*.so' \) -type f \
  -exec codesign "${sign_args[@]}" {} \; 2>/dev/null
codesign "${sign_args[@]}" "${contents}/MacOS/${app_id}" 2>/dev/null
codesign "${sign_args[@]}" "${contents}/MacOS/Minder" 2>/dev/null
codesign "${sign_args[@]}" "${app}" 2>/dev/null
codesign --verify --deep --strict "${app}"

echo "==> Done: ${app}"
