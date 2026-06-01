"""Render a .drawio file to one SVG per page — no drawio engine required.

drawio files are mxGraph XML; the official renderers are all GUI/web. This is a
small, dependency-free converter that understands the subset of mxGraph this
repo's diagrams use (rounded rects, notes, ellipses, text, orthogonal edges
with arrowheads + labels) and emits plain SVG. SVG renders anywhere: a browser,
`inkscape`/`magick`, or inline in a terminal that supports images
(e.g. ghostty + image.nvim).

    python scripts/drawio_to_svg.py docs/pipeline.drawio        # -> docs/pipeline-<page>.svg
    python scripts/drawio_to_svg.py docs/pipeline.drawio --png  # also rasterize via magick/inkscape

Then view a page, e.g.:
    magick display docs/pipeline-2-current-pipeline.png
    # or in nvim with image.nvim: :lua require('image').from_file('...'):render()
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import escape


def parse_style(style: str) -> dict:
    out = {}
    for part in (style or "").split(";"):
        if not part:
            continue
        if "=" in part:
            k, v = part.split("=", 1)
            out[k] = v
        else:
            out[part] = True  # bare token, e.g. "text" or "rounded"
    return out


def slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def svg_text_block(cx, cy, lines, font_size, color, bold) -> str:
    """Vertically centred multi-line text."""
    weight = ' font-weight="bold"' if bold else ""
    lh = font_size * 1.25
    start = cy - (len(lines) - 1) * lh / 2
    spans = []
    for i, ln in enumerate(lines):
        y = start + i * lh
        spans.append(
            f'<text x="{cx:.0f}" y="{y:.0f}" font-size="{font_size}" '
            f'fill="{color}" text-anchor="middle" dominant-baseline="middle" '
            f'font-family="Helvetica,Arial,sans-serif"{weight}>{escape(ln)}</text>'
        )
    return "\n".join(spans)


def render_vertex(cell, geo) -> str:
    x, y = float(geo.get("x", 0)), float(geo.get("y", 0))
    w, h = float(geo.get("width", 120)), float(geo.get("height", 40))
    st = parse_style(cell.get("style", ""))
    value = (cell.get("value") or "").replace("<br>", "\n")
    lines = value.split("\n")
    fill = st.get("fillColor", "#ffffff")
    stroke = st.get("strokeColor", "#000000")
    fs = int(st.get("fontSize", 12))
    bold = st.get("fontStyle") in ("1", "3")
    fontcolor = st.get("fontColor", "#000000")
    dash = ' stroke-dasharray="6 4"' if st.get("dashed") == "1" else ""
    cx, cy = x + w / 2, y + h / 2
    shapes = []

    is_text = "text" in st or fill == "none"
    if st.get("shape") == "note":
        fold = 14
        pts = (f"{x},{y} {x+w-fold},{y} {x+w},{y+fold} {x+w},{y+h} {x},{y+h}")
        shapes.append(f'<polygon points="{pts}" fill="{fill}" stroke="{stroke}"{dash}/>')
        shapes.append(f'<polyline points="{x+w-fold},{y} {x+w-fold},{y+fold} {x+w},{y+fold}" '
                      f'fill="none" stroke="{stroke}"/>')
    elif st.get("ellipse") is True or "ellipse" in st:
        shapes.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{w/2}" ry="{h/2}" '
                      f'fill="{fill}" stroke="{stroke}"{dash}/>')
    elif not is_text:
        rx = 8 if st.get("rounded") == "1" else 0
        shapes.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" '
                      f'fill="{fill}" stroke="{stroke}"{dash}/>')

    shapes.append(svg_text_block(cx, cy, lines, fs, fontcolor if is_text else "#222222", bold))
    return "\n".join(shapes)


def conn_point(geo, frac_x, frac_y):
    x, y = float(geo.get("x", 0)), float(geo.get("y", 0))
    w, h = float(geo.get("width", 120)), float(geo.get("height", 40))
    return x + w * frac_x, y + h * frac_y


def edge_endpoints(sgeo, tgeo, st):
    """Pick exit/entry points: explicit if given, else by dominant direction."""
    sx0, sy0 = float(sgeo.get("x", 0)), float(sgeo.get("y", 0))
    sw, sh = float(sgeo.get("width", 120)), float(sgeo.get("height", 40))
    tx0, ty0 = float(tgeo.get("x", 0)), float(tgeo.get("y", 0))
    tw, th = float(tgeo.get("width", 120)), float(tgeo.get("height", 40))
    scx, scy = sx0 + sw / 2, sy0 + sh / 2
    tcx, tcy = tx0 + tw / 2, ty0 + th / 2

    if "exitX" in st:
        sp = conn_point(sgeo, float(st["exitX"]), float(st["exitY"]))
    elif abs(tcx - scx) >= abs(tcy - scy):
        sp = (sx0 + sw, scy) if tcx >= scx else (sx0, scy)
    else:
        sp = (scx, sy0 + sh) if tcy >= scy else (scx, sy0)

    if "entryX" in st:
        tp = conn_point(tgeo, float(st["entryX"]), float(st["entryY"]))
    elif abs(tcx - scx) >= abs(tcy - scy):
        tp = (tx0, tcy) if tcx >= scx else (tx0 + tw, tcy)
    else:
        tp = (tcx, ty0) if tcy >= scy else (tcx, ty0 + th)
    return sp, tp, (scx, scy), (tcx, tcy)


def render_edge(cell, geos) -> str:
    s, t = cell.get("source"), cell.get("target")
    if s not in geos or t not in geos:
        return ""
    st = parse_style(cell.get("style", ""))
    sp, tp, sc, tc = edge_endpoints(geos[s], geos[t], st)
    # Orthogonal elbow between the two connection points.
    (sx, sy), (tx, ty) = sp, tp
    if abs(tc[0] - sc[0]) >= abs(tc[1] - sc[1]):
        mx = (sx + tx) / 2
        pts = [(sx, sy), (mx, sy), (mx, ty), (tx, ty)]
    else:
        my = (sy + ty) / 2
        pts = [(sx, sy), (sx, my), (tx, my), (tx, ty)]
    stroke = st.get("strokeColor", "#333333")
    dash = ' stroke-dasharray="6 4"' if st.get("dashed") == "1" else ""
    path = " ".join(f"{x:.0f},{y:.0f}" for x, y in pts)
    out = [f'<polyline points="{path}" fill="none" stroke="{stroke}" '
           f'stroke-width="1.5"{dash} marker-end="url(#arrow)"/>']
    label = cell.get("value")
    if label:
        lx, ly = pts[len(pts) // 2]
        if len(pts) % 2 == 0:  # midpoint between the two centre nodes
            a, b = pts[len(pts) // 2 - 1], pts[len(pts) // 2]
            lx, ly = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        w = max(40, len(label) * 6.5)
        out.append(f'<rect x="{lx - w/2:.0f}" y="{ly - 9:.0f}" width="{w:.0f}" height="16" '
                   f'fill="#ffffff" opacity="0.85"/>')
        out.append(f'<text x="{lx:.0f}" y="{ly:.0f}" font-size="10" fill="{stroke}" '
                   f'text-anchor="middle" dominant-baseline="middle" '
                   f'font-family="Helvetica,Arial,sans-serif">{escape(label)}</text>')
    return "\n".join(out)


def render_page(diagram) -> tuple[str, str]:
    name = diagram.get("name", "page")
    cells = diagram.find("mxGraphModel/root").findall("mxCell")
    geos = {}
    maxx = maxy = 0
    for c in cells:
        g = c.find("mxGeometry")
        if c.get("vertex") == "1" and g is not None and g.get("x") is not None:
            geos[c.get("id")] = g
            maxx = max(maxx, float(g.get("x", 0)) + float(g.get("width", 0)))
            maxy = max(maxy, float(g.get("y", 0)) + float(g.get("height", 0)))
    pad = 30
    W, H = int(maxx + pad), int(maxy + pad)
    body = [render_edge(c, geos) for c in cells if c.get("edge") == "1"]
    body += [render_vertex(c, geos[c.get("id")]) for c in cells
             if c.get("vertex") == "1" and c.get("id") in geos]
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
        f'viewBox="0 0 {W} {H}">\n'
        f'<defs><marker id="arrow" markerWidth="10" markerHeight="10" refX="8" refY="3" '
        f'orient="auto" markerUnits="strokeWidth">'
        f'<path d="M0,0 L8,3 L0,6 z" fill="#333333"/></marker></defs>\n'
        f'<rect width="{W}" height="{H}" fill="#ffffff"/>\n'
        + "\n".join(b for b in body if b) + "\n</svg>\n"
    )
    return name, svg


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("drawio", type=Path)
    ap.add_argument("--png", action="store_true", help="also rasterize via magick or inkscape")
    ap.add_argument("--outdir", type=Path, default=None,
                    help="write outputs here instead of next to the .drawio")
    args = ap.parse_args()

    outdir = args.outdir or args.drawio.parent
    outdir.mkdir(parents=True, exist_ok=True)
    tree = ET.parse(args.drawio)
    written = []
    for i, diagram in enumerate(tree.getroot().findall("diagram"), 1):
        name, svg = render_page(diagram)
        out = outdir / f"{args.drawio.stem}-{i}-{slug(name)}.svg"
        out.write_text(svg)
        written.append(out)
        print(f"  wrote {out}")
        if args.png:
            png = out.with_suffix(".png")
            if shutil.which("magick"):
                subprocess.run(["magick", "-density", "150", str(out), str(png)], check=True)
            elif shutil.which("inkscape"):
                subprocess.run(["inkscape", str(out), "--export-type=png",
                                f"--export-filename={png}"], check=True)
            else:
                print("    (no magick/inkscape for PNG)", file=sys.stderr)
                continue
            print(f"  wrote {png}")
    return 0 if written else 1


if __name__ == "__main__":
    raise SystemExit(main())
