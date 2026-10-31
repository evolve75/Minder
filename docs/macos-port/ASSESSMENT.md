# Minder macOS Port — Feasibility Assessment

Date: 2026-10-31. Based on a read of the upstream repo (version 3.0.0,
GPL-3.0); no build was attempted. Homebrew availability claims are from
memory and unverified.

## Summary

Feasible and moderate in size: roughly 2-4 weeks for a working, unpackaged
GTK4 build on macOS; 1-3 months for a polished, signed, notarized `.app`.

Minder is ~68k lines of Vala (compiled to C), a GTK4 app built with Meson and
targeted at elementary OS (also shipped as a Flatpak). No portal, D-Bus or
Posix code paths were found. The work is in the dependencies and packaging.

## Dependencies

| Dependency | Where used | macOS situation |
|---|---|---|
| gtk4, glib, gobject, cairo, gee-0.8, json-glib, libxml-2.0, libarchive, gtksourceview-5, librsvg, libwebp | Core | Available via Homebrew; low risk. |
| libmarkdown | Markdown | Homebrew `discount`; verify, since the repo carries `vapi/libmarkdown.vapi`. |
| granite-7 | 25 files | Main work item. elementary-only, not packaged for macOS. Usage is shallow; replace with a compat shim over GTK4/libadwaita. |
| webkitgtk-6.0 | `ReleaseNotes.vala` only | No WebKitGTK on macOS. Drop/stub, or open notes in the system browser. |
| lasem-0.6 | `LatexRenderer.vala`, `UnicodeInsert.vala` | Obscure, not in Homebrew; hardest dependency. Fallback: make LaTeX rendering optional and compile it out. |

## Granite usage

Mostly helpers: `Granite.contrasting` (17 uses), `MessageDialog` (8), the
`SUGGESTED` CSS class (8), `STYLE`, `Box.Spacing.LINKED`. `Granite.Settings`
(dark mode) appears in 2-3 places. Plan: a small in-repo `compat` shim that
reimplements these on plain GTK4/libadwaita, keeping Linux builds working.
Dark mode via `Gtk.Settings` or libadwaita.

## Other work

1. Build system: fix `gnome.post_install` steps, gresource compile,
   `LOCALEDIR`; ignore `elementary/` and `flathub/`.
2. Packaging: `.app` bundle (gtk-mac-bundler or custom script) with dylibs,
   GSettings schemas, icon theme, gdk-pixbuf loaders; sign and notarize.
   Usually the most time-consuming part.
3. UI/behavior: Cmd-vs-Ctrl in `KeyCommands.vala` (117 KB) and
   `Shortcuts.vala`; no native macOS menubar in GTK4; HiDPI and font fallback
   in `CanvasText.vala`; clipboard, drag-and-drop, file dialogs need testing.
4. Printing/PDF export (`ExportPrint`, `ExportPDF`): GTK macOS print backend
   is the least mature area.
5. Graceful already: `get_flatpak_runtime`, `XDG_CURRENT_DESKTOP`. Data dirs
   resolve via GLib's XDG paths on macOS too (`~/.local/share`, `~/.config`;
   verified), so no migration is needed. Revisit for the `.app` bundle, which
   must put its `share/` directory on `XDG_DATA_DIRS`.
6. Tests: run `minder-regress` first to validate the toolchain.

## Suggested order

1. Install deps via Homebrew (vala, meson, gtk4, libgee, json-glib,
   libarchive, gtksourceview5, librsvg, webp, discount, libadwaita); run
   `meson setup` and record failures.
2. Stub lasem and WebKit behind build options; shim Granite.
3. Get `minder-regress`, then the app, running from the terminal.
4. Fix shortcuts, dark mode, HiDPI.
5. Package, sign, notarize.

## Risks

- Lasem is the main unknown; without it LaTeX-in-nodes does not work.
- GTK4 on macOS is functional but not native-feeling. A native AppKit rewrite
  is a much larger, different project.
- License: GPL-3.0; the fork must remain GPL-3.0 with source available.
- To track upstream, keep the compat shim and build options upstreamable to
  limit drift.

## Decisions (2026-10-31)

| Topic | Decision |
|---|---|
| Granite | In-repo compat shim over GTK4/libadwaita; real Granite stays available on Linux via a build option. |
| Lasem/LaTeX | Compile out first (`-Dlatex=false`); revisit once the app runs. |
| WebKit release notes | Open in the system browser on macOS; WebKit view stays on Linux (`-Dwebkit=false`). |
| Upstream | Upstreamable fork: small changes gated behind options, merge `upstream` regularly. |
| Packaging | Local unsigned build first; bundling, signing and notarization deferred. |
| First milestone | `minder-regress` passing, then the app launching from the terminal. |
