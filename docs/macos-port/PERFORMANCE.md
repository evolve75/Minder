# Performance and memory

Measured on one Apple Silicon Mac (M-series, macOS 27), release build, software Cairo surface. The
numbers are for the canvas draw callback only (not GTK compositing). The tools live in the repo, so
every figure below can be reproduced.

## How to measure

```sh
tools/bench/gen-map.py ~/Desktop/some.minder 5000 /tmp/map-5000.minder           # synthetic map
tools/bench/gen-map.py ~/Desktop/some.minder 700 /tmp/formulas-700.minder formulas
Minder.app/Contents/MacOS/Minder --benchmark /tmp/map-5000.minder
MINDER_BENCH_CHURN=1 Minder.app/Contents/MacOS/Minder --benchmark /tmp/map-1000.minder   # open/close memory
```

`--benchmark` (hidden option, `src/Benchmark.vala`) draws the map into an offscreen 1600x1000
surface 20 times and prints the mean and best time per frame for three views (`viewport`, `hidpi` =
device scale 2, `zoom-out` = scale 0.1, whole map visible), plus checks and micro-benchmarks:

| Line | What it checks |
|---|---|
| `culling-identical` | a frame drawn with and without off-screen culling is byte-identical |
| `latex-clip-identical` | same for the clipped formula mask |
| `image-draw` | cost of painting a 300x200 image with and without the cached surface |
| `text-helpers` | cost of Markdown and word-boundary helpers per call |
| `save` | time of a full save (what the 30-second recovery copy also costs); overwrites the file, so use a copy |
| `animation` | frames drawn and duration of a zoom-to-fit |
| `tab-churn` (with `MINDER_BENCH_CHURN=1`) | memory growth over repeated open/close of a map |

`MINDER_BENCH_FRAMES=N` lengthens a run so a profiler (`sample <pid>`) can look at it;
`MINDER_BENCH_ROUNDS` and `MINDER_BENCH_HOLD` control the churn scenario.

## Results

Draw time per frame in milliseconds (mean). Before = start of the performance work.

| Map | View | Before | After |
|---|---|---|---|
| 200 nodes | viewport | 1.80 | 0.96 |
| 1000 nodes | viewport | 3.45 | 0.94 |
| 5000 nodes | viewport | 12.93 | 1.77 |
| 5000 nodes | hidpi | 15.34 | 4.44 |
| 5000 nodes | zoom-out | 13.43 | 2.92 |
| 700 LaTeX formulas | viewport | 20.78 | 1.45 |
| 700 LaTeX formulas | zoom-out | 115.67 | 5.39 |

* **Off-screen culling (#48):** nodes and links are only drawn when their bounds (plus a margin for
  resizers, callouts and stickers) overlap the visible clip. Cost no longer grows with map size.
* **LaTeX mask clip (#61):** each formula was composited as an unbounded mask over the whole clip;
  it is now confined to the formula's box.
* **Cached image surface (#49):** a raster image or sticker costs 0.026 ms per draw instead of
  0.094 ms (the Cairo surface is built once per pixbuf).
* **Closed tabs (#57):** a 1000-node map left 10-12 MB behind per close; now 2.2 MB (the canvas
  widget). See the issue for the causes.
* **Tried and not shipped:** driving animations from the frame clock (#50) showed no gain here;
  compiling the regular expressions once (#51, #52) saves microseconds because the helpers cost
  2-17 us per call.

## Save and recovery cost

A full save (XML, archive, images) takes about 17 ms for a 1000-node map and 75 ms for 5000 nodes, so
the crash-recovery copy written every 30 seconds while a document has unsaved changes (#55) is not
noticeable.

## Known limits

* Animation frames cost O(nodes) (every node is adjusted each frame); a zoom-to-fit on 5000 nodes
  takes about 9 frames over 230 ms.
* The canvas widget of a closed tab is not finalized (about 2 MB per closed 1000-node tab).
* Raster images are scaled at logical size, so they may look soft on Retina displays.
