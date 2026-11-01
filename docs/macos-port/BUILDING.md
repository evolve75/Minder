# Building Minder on macOS

Requires Homebrew and Xcode command-line tools.

```sh
brew bundle --file=Brewfile        # toolchain and libraries
source macos/env.sh                # keg-only pkg-config paths
meson setup build-mac -Dgranite=false -Dlatex=false -Dwebkit=false
meson compile -C build-mac
meson test -C build-mac            # minder-regress
```

## Unsigned `.app` bundle

```sh
macos/make-app.sh                  # -> build-app/Minder.app
open build-app/Minder.app
```

The bundle contains the binary, its Homebrew dylibs (via `dylibbundler`), the
gdk-pixbuf loaders, GtkSourceView data, the Adwaita icon theme and compiled
GSettings schemas, plus a registered `.minder` document type (Finder opens files with
Minder and shows a document icon). Icons are built from `macos/icons/*.svg` and the shared
bubble artwork. The launcher points `XDG_DATA_DIRS`, `GSETTINGS_SCHEMA_DIR`
and `GDK_PIXBUF_MODULE_FILE` at the bundle. It is not signed or notarized.

## Build options

| Option | Default | Effect when false |
|---|---|---|
| `granite` | true | Build the in-tree compat shim (`src/compat/Granite.vala`) over GTK4/libadwaita. |
| `latex` | true | Formulas are shown as plain text (no Lasem). |
| `webkit` | true | Release notes open in the system browser. |
| `primary-modifier` | auto | `auto` = Command on macOS, Control elsewhere. |

## Known limitations

- LaTeX rendering is unavailable (Lasem is not packaged for macOS).
- GTK4 draws its own menus and window chrome; there is no native menubar.
- Shortcut handling assumes GTK reports Command as `META_MASK` (unverified
  interactively).

## Signing and notarization

`macos/make-app.sh` signs the bundle ad hoc by default, which is enough to run it on
the machine that built it. For distribution you need an Apple Developer ID:

```sh
MINDER_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" macos/make-app.sh
xcrun notarytool store-credentials minder-notary --apple-id <id> --team-id <team> --password <app-specific-password>
macos/notarize.sh                  # submits, waits, staples, runs a Gatekeeper check
```

With an identity set, every library, loader, the binaries and the bundle are signed
with the hardened runtime and a secure timestamp. The launcher (`macos/launcher.c`) is a
Mach-O so that the main executable can be signed. `MINDER_ENTITLEMENTS` and
`MINDER_HARDENED_RUNTIME=1` are available for testing. Not yet tried with a real Developer
ID, which this machine does not have.
