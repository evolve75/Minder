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
GSettings schemas. The launcher points `XDG_DATA_DIRS`, `GSETTINGS_SCHEMA_DIR`
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
