# Staying in sync with upstream

Remotes: `upstream` = https://github.com/phase1geo/Minder (read-only, never pushed to),
`origin` = the GitHub fork https://github.com/evolve75/Minder, `acv` = the internal Gitea
repository, which stays the issue tracker. Branches are pushed to `origin` and `acv`.

## Branches

The fork is kept for ongoing development on macOS and Linux, and for pulling upstream changes.

- `master` is the fork's default branch: upstream plus the macOS port. Development lands here
  through short-lived topic branches (`features/<topic>`, fast-forwarded into `master` and then
  deleted). It is never rewritten.
- `features/macos-port` is the same work as a clean, ordered series of one-concern commits on top
  of `upstream/master`. It is the source of the pull requests to upstream, and is rebased onto
  `upstream/master` when upstream moves (see "Producing patches").
- `features/macos-integration` keeps the chronological history of the port.

Issue numbers stay in the commit subjects, so `git log --grep '#67'` finds the commit for an issue.

## Pulling upstream changes

```sh
git fetch upstream
git rev-list --count master..upstream/master        # how far behind (0 when up to date)
git merge-tree --write-tree master upstream/master  # trial merge; prints a tree id if clean
git switch master && git merge upstream/master
git push origin master && git push acv master
```

Merge rather than rebase, so `master` is never rewritten. Then rebuild with
`macos/make-app.sh`. Conflicts are most likely in `src/MainWindow.vala` and
`src/Application.vala`, where the macOS menu bar and open handling live behind
`#if PRIMARY_COMMAND`. Keep that guard so Linux builds stay byte-for-byte upstream behaviour.

## What can go upstream

Changes are written so they can be proposed as separate pull requests. In order of
how self-contained they are:

| Change | Why it is upstreamable | Files |
|---|---|---|
| Ignore indentation whitespace when loading node text (#24) | A general bug: indented map XML puts a blank text node before `<text>`; not macOS specific | `Utils.vala`, `Node.vala`, `Connection.vala`, `NodeGroup.vala` |
| `granite`, `latex`, `webkit` Meson options | Default keeps the current behaviour (`webkit` is `auto`: on except macOS) | `meson.build`, `meson_options.txt`, `LatexRenderer.vala`, `ReleaseNotes.vala` |
| In-tree Granite compat shim | Only built with `-Dgranite=false` | `src/compat/Granite.vala` |
| `post_install` tolerates missing tools; librsvg fallback vapi | Helps any non-GNOME platform | `meson.build`, `vapi/fallback/` |
| GNOME schema guard in `Application.vala` | Avoids an abort when the schema is absent | `Application.vala` |

macOS-only behaviour (menu bar, Command shortcuts, print via PDF, open events, undo
fallback, `live-action.c`) is behind `#if PRIMARY_COMMAND` and tracked separately; propose
it only if upstream wants macOS support.

## Producing patches

`features/macos-port` is a clean, ordered series of one-concern commits on top of `upstream/master`.
The first group is not macOS specific and is meant to be proposed upstream on its own: the build
options and shims (`granite`, `latex`, `webkit`, all defaulting to the current behaviour), then bug
fixes, stability work (crash recovery, safe saving, freed tabs) and drawing performance. The second
group is the macOS port: docs, the menu bar and shortcuts, window and Dock behaviour, packaging,
LaTeX support and the macOS polish. Docs and CI come last. Every commit from the WebKit option onward
builds with `-Dgranite=false -Dlatex=false` (the three before it need Lasem and WebKit installed, as
on Linux).

```sh
git rebase upstream/master features/macos-port          # after fetching, when upstream moved
git diff master features/macos-port                     # empty while master has no extra commits
git format-patch -o patches/ upstream/master..features/macos-port
```

While upstream pull requests are pending, new work is added to `master` and also applied to the
series as its own commit (or folded into its parent topic). Nothing is sent upstream from here; this
repo only keeps the patches ready. Do not push to `upstream`.
