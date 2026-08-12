#!/usr/bin/env python3
"""Report the on-page size of the smallest type in every figure.

The page gives a 7.00in wide by ~8.40in tall box for a figure (Letter, 0.75in
side margins, 1in top/bottom, minus room for the caption). Word scales an
image uniformly to fit inside that box, so:

    displayed_width = min(7.00, 8.40 * w / h)
    effective_pt    = source_pt * displayed_width / (w / 150)

Substituting gives two independent caps, which is the useful part:

    width-limited  (h/w <= 1.20):  effective_pt = 11 * 1050 / w  -> w <= 1155px
    height-limited (h/w >  1.20):  effective_pt = 11 * 1260 / h  -> h <= 1386px

So a figure is legible if BOTH w <= 1155 and h <= 1386, and it fills the full
column width only when h/w <= 1.20. A figure that is too tall wastes width;
widening it (side-by-side instead of stacked) costs nothing until 1155px.

Usage:  python3 education/tools/figcheck.py <track>
"""

import pathlib
import re
import struct
import sys

DPI = 150
COL_IN, BOX_H_IN = 7.0, 8.4
TARGET = 10.0
MAX_W = int(11 * COL_IN * DPI / TARGET)      # 1155
MAX_H = int(11 * BOX_H_IN * DPI / TARGET)    # 1386

EDUCATION = pathlib.Path(__file__).resolve().parent.parent


def png_size(p):
    return struct.unpack(">II", p.read_bytes()[16:24])


def smallest_font(dot):
    s = dot.read_text()
    sizes = [int(x) for x in re.findall(r'POINT-SIZE="(\d+)"', s)]
    for attr in (r"node\s*\[[^\]]*fontsize=(\d+)", r"edge\s*\[[^\]]*fontsize=(\d+)"):
        sizes += [int(x) for x in re.findall(attr, s)]
    return min(sizes) if sizes else 14


def main():
    if len(sys.argv) < 2:
        sys.exit(f"usage: python3 education/tools/figcheck.py <track>\n"
                 f"tracks: " + ", ".join(
                     d.name for d in sorted(EDUCATION.iterdir())
                     if d.is_dir() and (d / "images").is_dir()))
    track = EDUCATION / sys.argv[1]
    images, diagrams = track / "images", track / "diagrams"
    if not images.is_dir():
        sys.exit(f"{sys.argv[1]}: no images/ directory")

    print(f"track {track.name}   figure box {COL_IN}in x {BOX_H_IN}in   "
          f"caps: w<={MAX_W}px  h<={MAX_H}px   target >= {TARGET}pt\n")
    print(f"{'figure':<34}{'px':>12}{'aspect':>8}{'shown':>10}{'pt':>7}  fix")
    print("-" * 88)
    bad = []
    for img in sorted(images.glob("*.png")):
        dot = diagrams / (img.stem + ".dot")
        if not dot.exists():
            continue
        w, h = png_size(img)
        base = smallest_font(dot)
        disp_w = min(COL_IN, BOX_H_IN * w / h)
        eff = base * disp_w / (w / DPI)
        need = []
        if w > MAX_W:
            need.append(f"narrower by {w - MAX_W}px")
        if h > MAX_H:
            need.append(f"shorter by {h - MAX_H}px")
        if eff < TARGET:
            bad.append(img.stem)
        print(f"{img.stem:<34}{w}x{h:<7}{h/w:>7.2f}{disp_w:>9.2f}in{eff:>7.1f}  "
              f"{', '.join(need)}")
    print("-" * 88)
    if bad:
        print(f"{len(bad)} below {TARGET}pt: " + ", ".join(bad))
    else:
        print(f"all {len(list(images.glob('*.png')))} figures >= {TARGET}pt on page")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
