# Staying in sync with upstream

Remotes: `upstream` = https://github.com/phase1geo/Minder (read-only), `acv` = the internal
Gitea fork. Base branch is `master`, which currently equals upstream `master`.

## Pulling upstream changes

```sh
git fetch upstream
git rev-list --count master..upstream/master        # how far behind
git merge-tree --write-tree master upstream/master  # trial merge; prints a tree id if clean
git switch master && git merge --ff-only upstream/master   # when master has no local commits
git push acv master
```

Then merge `master` into the active `features/*` branch (or rebase it) and rebuild with
`macos/make-app.sh`. Conflicts are most likely in `src/MainWindow.vala` and
`src/Application.vala`, where the macOS menu bar and open handling live behind
`#if PRIMARY_COMMAND`. Keep that guard so Linux builds stay byte-for-byte upstream behaviour.

## What can go upstream

Changes are written so they can be proposed as separate pull requests. In order of
how self-contained they are:

| Change | Why it is upstreamable | Files |
|---|---|---|
| Ignore indentation whitespace when loading node text (#24) | A general bug: indented map XML puts a blank text node before `<text>`; not macOS specific | `Utils.vala`, `Node.vala`, `Connection.vala`, `NodeGroup.vala` |
| `granite`, `latex`, `webkit` Meson options | Default `true`, no behaviour change | `meson.build`, `meson_options.txt`, `LatexRenderer.vala`, `ReleaseNotes.vala` |
| In-tree Granite compat shim | Only built with `-Dgranite=false` | `src/compat/Granite.vala` |
| `post_install` tolerates missing tools; librsvg fallback vapi | Helps any non-GNOME platform | `meson.build`, `vapi/fallback/` |
| GNOME schema guard in `Application.vala` | Avoids an abort when the schema is absent | `Application.vala` |

macOS-only behaviour (menu bar, Command shortcuts, print via PDF, open events, undo
fallback, `live-action.c`) is behind `#if PRIMARY_COMMAND` and tracked separately; propose
it only if upstream wants macOS support.

## Producing patches

`features/macos-integration` keeps the chronological history. `features/macos-series` holds the
same final tree as a clean, ordered series of one-concern commits on top of `master`:
general fixes first (indentation whitespace, scale-0 canvas, GNOME schema guard), then the
build options and shims, then the macOS behaviour grouped by topic, docs last. Every commit
from the WebKit option onward builds with `-Dgranite=false -Dlatex=false -Dwebkit=false`
(the three before it need Lasem and WebKit installed, as on Linux).

```sh
git diff features/macos-integration features/macos-series   # must be empty
git format-patch -o patches/ master..features/macos-series
```

When a macOS change lands on `features/macos-integration`, re-apply it to the series as its own
commit (or fold it into its parent topic). Nothing is sent upstream from here; this repo only
keeps the patches ready. Do not push to `upstream`.
