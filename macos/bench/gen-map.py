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
# Generate a large synthetic mind map for benchmarking (see src/Benchmark.vala).
# The map reuses the header and node styling of an existing map (the template),
# replacing its nodes with a tree of the requested size.
#
# Usage: gen-map.py TEMPLATE.minder NODE_COUNT OUTPUT.minder [WITH_NOTES]

import copy
import io
import sys
import tarfile
import xml.etree.ElementTree as ET

FANOUT = 5
X_STEP = 330
Y_STEP = 60


def load_map(path):
    with tarfile.open(path, "r:gz") as tar:
        return ET.fromstring(tar.extractfile("map.xml").read())


def make_tree(template_node, count, with_notes):
    next_id = [1]
    made = [0]

    def build(depth, y_slot, prefix):
        node = copy.deepcopy(template_node)
        node.attrib["id"] = str(next_id[0])
        next_id[0] += 1
        made[0] += 1
        node.attrib["posx"] = str(100 + depth * X_STEP)
        node.attrib["posy"] = str(y_slot[0] * Y_STEP)
        node.attrib["fold"] = "false"
        name = node.find("nodename")
        for t in list(name):
            name.remove(t)
        ET.SubElement(name, "text", {"data": "%s item %d" % (prefix, made[0])})
        note = node.find("nodenote")
        if note is not None:
            note.text = "Note %d with **bold** and a list\n\n* one\n* two" % made[0] if with_notes else ""
        children = node.find("nodes")
        if children is not None:
            node.remove(children)
        kids = ET.SubElement(node, "nodes")
        y_slot[0] += 1
        if made[0] < count and depth < 6:
            for _ in range(FANOUT):
                if made[0] >= count:
                    break
                kids.append(build(depth + 1, y_slot, prefix))
        if len(kids) == 0:
            node.remove(kids)
        return node

    y = [0]
    root = build(0, y, "Root")
    # keep adding top-level branches until the count is reached
    while made[0] < count:
        root.find("nodes").append(build(1, y, "Branch"))
    return root


def main():
    template, count, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    with_notes = len(sys.argv) > 4
    root = load_map(template)
    nodes = root.find("nodes")
    first = nodes[0]
    for n in list(nodes):
        nodes.remove(n)
    nodes.append(make_tree(first, count, with_notes))
    data = ET.tostring(root, encoding="unicode").encode()
    info = tarfile.TarInfo("map.xml")
    info.size = len(data)
    with tarfile.open(out, "w:gz") as tar:
        tar.addfile(info, io.BytesIO(data))
    print("wrote %s (%d nodes)" % (out, count))


if __name__ == "__main__":
    main()
