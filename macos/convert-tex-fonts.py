#!/usr/bin/env python3
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
# Convert TeX's Computer Modern Type 1 fonts (cmr10, cmmi10, cmex10, cmsy10)
# to TrueType so macOS can load them.  Lasem draws square roots, big operators
# and stretched brackets with these fonts, addressing glyphs by their TeX
# character code (as the Latin-1 code point of the same value).
#
# The fonts are licensed under the SIL OFL 1.1 and their names are Reserved Font
# Names, so the converted fonts must only be used locally and not redistributed
# under the same names (see docs/macos-port/BUILDING.md).
#
# Usage: convert-tex-fonts.py OUTPUT_DIR PFB [PFB ...]

import os
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.t1Lib import T1Font


def convert(pfb, out_dir):
    name = os.path.splitext(os.path.basename(pfb))[0]
    t1 = T1Font(pfb)
    t1.parse()
    glyphs = t1.getGlyphSet()
    encoding = t1.font["Encoding"]
    order = [".notdef"] + sorted(n for n in glyphs.keys() if n != ".notdef")

    ttglyphs = {}
    metrics = {}
    for gname in order:
        if gname in glyphs.keys():
            glyph = glyphs[gname]
            pen = TTGlyphPen(glyphs)
            glyph.draw(Cu2QuPen(pen, max_err=1.0, reverse_direction=True))
            ttglyphs[gname] = pen.glyph()
            metrics[gname] = (int(round(glyph.width)), 0)
        else:
            ttglyphs[gname] = TTGlyphPen(None).glyph()
            metrics[gname] = (500, 0)

    cmap = {}
    for code, gname in enumerate(encoding):
        if gname != ".notdef" and gname in ttglyphs:
            cmap[code] = gname

    bbox = t1.font.get("FontBBox", [0, -250, 1000, 750])
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(ttglyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=int(bbox[3]), descent=int(bbox[1]))
    fb.setupNameTable({
        "familyName": name,
        "styleName": "Regular",
        "uniqueFontIdentifier": name + "-Regular",
        "fullName": name,
        "psName": name,
        "version": "Version 1.0",
    })
    fb.setupOS2(sTypoAscender=int(bbox[3]), sTypoDescender=int(bbox[1]),
                usWinAscent=int(bbox[3]), usWinDescent=-int(bbox[1]))
    fb.setupPost()
    path = os.path.join(out_dir, name + ".ttf")
    fb.save(path)
    print("wrote", path)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for pfb in sys.argv[2:]:
        convert(pfb, out)
