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
| `latex` | true | Formulas are shown as plain text when false (no Lasem). `macos/make-app.sh` turns it on when `lasem-0.6` is found. |
| `webkit` | true | Release notes open in the system browser. |
| `primary-modifier` | auto | `auto` = Command on macOS, Control elsewhere. |

## What differs from Linux

macOS-only behaviour is compiled in only on macOS (`PRIMARY_COMMAND`, `MACOS_PRINT`), so Linux
builds keep upstream behaviour.

- **Menu bar:** a full native menu bar (File, Edit, Format, View, Node, Insert, Arrange, Go,
  Table, Window, Help) built from the command list in `MainWindow.setup_macos_menubar()`.
  Shortcuts are shown as native key equivalents (so they can be remapped in System Settings).
  Each item's validity is evaluated live (`src/live-action.c`); plain-key shortcuts only apply
  while the canvas has focus, so they never take keystrokes meant for a text field.
- **Shortcuts:** Command is the primary modifier (`-Dprimary-modifier=auto`).
- **Printing:** the map is rendered to a PDF and printed through the native macOS print panel
  (`src/macos-print.m`), because Homebrew's GTK has no CUPS print backend.
- **Files:** `.minder` is a registered document type with its own icon; Finder, Open With and
  Dock drops open files.
- **Undo:** while a just-created node is still being edited, Undo falls back to the map history.

## Known limitations

- LaTeX formulas need Lasem, which is not in Homebrew, and TeX's math fonts. Run
  `macos/build-lasem.sh` once (it builds a pinned commit into `build-deps/`, which is git-ignored),
  then `macos/build-tex-fonts.sh`, then `source macos/env.sh` and `macos/make-app.sh`. The bundle
  then includes the library and the fonts, and `-Dlatex=true` is used automatically.
- Lasem draws square roots, big operators and stretched brackets with TeX's `cmex10`, `cmsy10`,
  `cmmi10` and `cmr10`. `build-tex-fonts.sh` converts MacTeX's Type 1 copies to TrueType (macOS
  cannot load Type 1) using `fonttools` in a virtual environment under `build-deps/`; the app
  registers them from `Resources/fonts` at startup. They are under the SIL OFL with Reserved Font
  Names, so an app bundled with the converted fonts is for local use only. To distribute it, rename
  the fonts and the names in Lasem's font table first.
- Lasem's upstream has had no commits since 2020; its Makefile installs only the DOM headers, so
  the build script installs the MathML/SVG headers itself, and stubs the gtk-doc and
  introspection autoconf macros.
- GTK4 draws its own window chrome and dialogs. The menu bar, file chooser and print panel are native.
- The bundle is signed ad hoc only; Developer ID signing and notarization need an Apple
  Developer account (issue #20).

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
