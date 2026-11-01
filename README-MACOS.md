# Minder on macOS

[![macOS build](https://github.com/evolve75/Minder/actions/workflows/macos.yml/badge.svg?branch=features/macos-port)](https://github.com/evolve75/Minder/actions/workflows/macos.yml)

This fork builds and runs Minder natively on macOS (Apple silicon and Intel, macOS 13 or later). The macOS
changes are compiled in only on macOS, so Linux and elementary OS builds keep their current behaviour.
The work is split into a first group of changes that are not macOS specific (bug fixes, performance,
build options) and a second group for the macOS port itself, so either can be proposed upstream
separately. See [`docs/macos-port/UPSTREAM.md`](docs/macos-port/UPSTREAM.md).

## What is different on macOS

**Native look and behaviour**

- A full native menu bar (File, Edit, Format, View, Node, Insert, Arrange, Go, Table, Window, Help) with native
  key equivalents, validated live against the current selection.
- Command is the primary shortcut modifier; Control-Command chords no longer trigger Command shortcuts.
- Native traffic-light window buttons, centred on the toolbar; the tab close button is on the left.
- The app keeps running after its window is closed. Clicking the Dock icon brings the window back.
- The Dock menu lists the open tabs (unsaved ones included) and the Window menu lists them too.
- Printing goes through the native macOS print panel.
- `.minder` is a registered document type with its own icon. Finder, Open With and drops on the Dock icon open files.
- File > Open Recent lists the last 10 documents.
- The selected tab stands out, and tabs with unsaved changes show an asterisk and the window shows the
  native edited dot.
- Preferences has an "Enable sidebar animations" switch for the sidebar slide.
- LaTeX formulas render through Lasem and TeX fonts (optional, see below).

**Fixes and performance that apply everywhere**

- Off-screen nodes and links are not drawn (5000 nodes: 12.9 ms to 1.8 ms per frame), raster images and
  LaTeX formulas are cached, and each formula's mask is confined to its own box.
- Unsaved documents are written to a recovery copy every 30 seconds and come back after a crash.
- Saving over a file that was changed by someone else asks first; closing never overwrites it.
- Saving to a folder that no longer exists reports an error instead of aborting the app.
- Closed tabs release their memory, and the tab close button works after other tabs were closed.
- Notes render Markdown with libmarkdown 3.x, and malformed note HTML no longer breaks exports.
- `Minder --benchmark file.minder` times drawing, saving and tab churn; see
  [`docs/macos-port/PERFORMANCE.md`](docs/macos-port/PERFORMANCE.md).

## Building

You need Homebrew and the Xcode command-line tools.

```sh
brew bundle --file=Brewfile        # toolchain and libraries
source macos/env.sh                # pkg-config paths for the keg-only formulae
meson setup build-mac -Dgranite=false -Dlatex=false
meson compile -C build-mac
meson test -C build-mac            # runs minder-regress
```

To build an unsigned, self-contained `Minder.app`:

```sh
macos/make-app.sh                  # -> build-app/Minder.app
open build-app/Minder.app
```

The bundle holds the binary, its Homebrew libraries, the GDK-Pixbuf loaders, GtkSourceView data, the
Adwaita icons and the compiled settings schemas. It is only ad-hoc signed, so it runs on the Mac that
built it. Signing for distribution is covered in [`docs/macos-port/BUILDING.md`](docs/macos-port/BUILDING.md).

### Build options

| Option | Default | When false |
|---|---|---|
| `granite` | true | Uses the in-tree compatibility layer over GTK4 and libadwaita (`src/compat/Granite.vala`). |
| `latex` | true | Formulas are shown as plain text (no Lasem). |
| `webkit` | auto | `auto` is on everywhere except macOS. When false, release notes open in the system browser. |
| `primary-modifier` | auto | `auto` is Command on macOS and Control elsewhere. |

### LaTeX formulas (optional)

Lasem is not in Homebrew, and Lasem draws math with TeX fonts that macOS cannot load as shipped.

```sh
macos/build-lasem.sh               # builds a pinned Lasem into build-deps/ (git-ignored)
macos/build-tex-fonts.sh           # converts MacTeX's Type 1 fonts to TrueType (needs MacTeX)
source macos/env.sh
macos/make-app.sh                  # enables -Dlatex=true when Lasem is found
```

The converted fonts are modified versions of fonts whose names are reserved under the SIL Open Font
License, so an app bundled with them is for local use only. Do not distribute it.

## Known limitations

- GTK draws its own controls and dialogs, so only the menu bar, window buttons, file chooser and print
  panel are native.
- The `.app` is not notarized. Distribution needs an Apple Developer ID (see `docs/macos-port/BUILDING.md`).
- WebKit is not available on macOS, so release notes open in the browser.

## More

- [`docs/macos-port/ASSESSMENT.md`](docs/macos-port/ASSESSMENT.md): the plan and the decisions behind the port.
- [`docs/macos-port/BUILDING.md`](docs/macos-port/BUILDING.md): details of the bundle, signing and notarization.
- [`docs/macos-port/PERFORMANCE.md`](docs/macos-port/PERFORMANCE.md): measurements and how to repeat them.
- [`docs/macos-port/UPSTREAM.md`](docs/macos-port/UPSTREAM.md): branch layout and how to sync with upstream.
