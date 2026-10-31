# Homebrew dependencies for building Minder on macOS.
# Usage: brew bundle --file=Brewfile   (then: source macos/env.sh)
# See docs/macos-port/ASSESSMENT.md.

# Toolchain
brew "vala"
brew "meson"
brew "ninja"
brew "pkgconf"
brew "gettext"

# Libraries (core)
brew "glib"
brew "cairo"
brew "gtk4"
brew "libadwaita"       # backs the Granite compat shim (#6)
brew "libgee"
brew "json-glib"
brew "gtksourceview5"
brew "librsvg"
brew "webp"
brew "adwaita-icon-theme"

# Keg-only: not on the default pkg-config path; see macos/env.sh
brew "libarchive"
brew "libxml2"

# Provides libmarkdown (bundled vapi compatibility tracked in #4)
brew "discount"

# Deliberately absent: granite-7 (shimmed), webkitgtk-6.0 (no macOS build),
# lasem-0.6 (LaTeX compiled out first). See ASSESSMENT.md decisions.
