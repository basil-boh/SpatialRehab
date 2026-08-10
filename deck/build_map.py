#!/usr/bin/env python3
"""Generate the Remember the Way map as an isometric 3D SVG.

Reads the app's own OpenStreetMap extract of Tiong Bahru
(SpatialRehab/TiongBahruMap.json, the same file NeighborhoodWorld.swift meshes
at runtime) and renders real building footprints, extruded by their real storey
count, over the real street network, with a route that follows actual streets.

Writes deck/map.svg. Run it via deck/build.py, or directly to regenerate.
"""
import heapq
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, os.pardir, "SpatialRehab", "TiongBahruMap.json")
OUT = os.path.join(HERE, "map.svg")

VIEW_W, VIEW_H = 1000.0, 330.0
ROTATE = math.radians(-28)      # turn the estate to a pleasing angle
ISO_Y = 0.34                    # shallower than true isometric: reads as a map tilt
STOREY_M = 3.1                  # metres per building level
Z_SCALE = 0.85                  # flatten heights a little so towers don't dominate

WALKABLE = {"residential", "pedestrian", "footway", "living_street", "service", "path"}
ROAD_W = {"motorway": 3.2, "motorway_link": 2.2, "primary": 3.0, "secondary": 2.6,
          "secondary_link": 1.8, "residential": 1.9, "service": 1.1,
          "pedestrian": 1.3, "living_street": 1.5, "footway": 0.8,
          "cycleway": 0.8, "path": 0.8, "steps": 0.8}


def load():
    with open(SRC) as fh:
        return json.load(fh)["elements"]


def make_projector(elements):
    lats = [g["lat"] for e in elements for g in e.get("geometry", []) or []]
    lons = [g["lon"] for e in elements for g in e.get("geometry", []) or []]
    lat0 = (min(lats) + max(lats)) / 2.0
    lon0 = (min(lons) + max(lons)) / 2.0
    mx = 111320.0 * math.cos(math.radians(lat0))

    def to_metres(lat, lon):
        x = (lon - lon0) * mx
        y = (lat - lat0) * 110570.0
        # rotate in plan
        c, s = math.cos(ROTATE), math.sin(ROTATE)
        return x * c - y * s, x * s + y * c

    return to_metres


def iso(x, y, z=0.0):
    """Shallow isometric projection, y increasing downward on screen."""
    return (x - y) * math.cos(math.radians(30)), (x + y) * ISO_Y - z * Z_SCALE


def fit(points):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    scale = min(VIEW_W / (max(xs) - min(xs)), VIEW_H / (max(ys) - min(ys))) * 0.93
    ox = (VIEW_W - (max(xs) - min(xs)) * scale) / 2 - min(xs) * scale
    oy = (VIEW_H - (max(ys) - min(ys)) * scale) / 2 - min(ys) * scale
    return scale, ox, oy


def route_through_streets(elements, to_m, bbox):
    """Dijkstra over the walkable street graph, corner to corner."""
    graph, coords = {}, {}

    def key(g):
        return (round(g["lat"], 6), round(g["lon"], 6))

    for e in elements:
        tags = e.get("tags", {})
        if tags.get("highway") not in WALKABLE:
            continue
        geom = e.get("geometry") or []
        for a, b in zip(geom, geom[1:]):
            ka, kb = key(a), key(b)
            coords.setdefault(ka, to_m(a["lat"], a["lon"]))
            coords.setdefault(kb, to_m(b["lat"], b["lon"]))
            ax, ay = coords[ka]
            bx, by = coords[kb]
            w = math.hypot(bx - ax, by - ay)
            graph.setdefault(ka, []).append((kb, w))
            graph.setdefault(kb, []).append((ka, w))

    # keep both ends inside the built-up area, then take the longest diagonal
    inside = [k for k in coords if bbox[0] <= coords[k][0] <= bbox[2]
              and bbox[1] <= coords[k][1] <= bbox[3]] or list(coords)
    start = min(inside, key=lambda k: coords[k][0] + coords[k][1] * 0.4)
    goal = max(inside, key=lambda k: coords[k][0] + coords[k][1] * 0.4)

    dist = {start: 0.0}
    prev = {}
    seen = set()
    pq = [(0.0, start)]
    while pq:
        d, node = heapq.heappop(pq)
        if node in seen:
            continue
        seen.add(node)
        if node == goal:
            break
        for nb, w in graph.get(node, []):
            nd = d + w
            if nd < dist.get(nb, float("inf")):
                dist[nb] = nd
                prev[nb] = node
                heapq.heappush(pq, (nd, nb))

    if goal not in dist:
        return []
    path, cur = [], goal
    while cur != start:
        path.append(coords[cur])
        cur = prev[cur]
    path.append(coords[start])
    path.reverse()
    return path


def main():
    elements = load()
    to_m = make_projector(elements)

    buildings, roads = [], []
    for e in elements:
        tags = e.get("tags", {})
        geom = e.get("geometry") or []
        if len(geom) < 2:
            continue
        pts = [to_m(g["lat"], g["lon"]) for g in geom]
        if "building" in tags:
            try:
                levels = float(tags.get("building:levels", 3))
            except ValueError:
                levels = 3.0
            buildings.append((pts, max(1.0, min(levels, 18.0)) * STOREY_M))
        elif tags.get("highway") in ROAD_W:
            roads.append((pts, ROAD_W[tags["highway"]]))

    bxs = [x for pts, _ in buildings for x, _ in pts]
    bys = [y for pts, _ in buildings for _, y in pts]
    bbox = (min(bxs), min(bys), max(bxs), max(bys))
    route = route_through_streets(elements, to_m, bbox)

    # fit everything, including roof heights, into the viewBox
    probe = [iso(x, y, h) for pts, h in buildings for x, y in pts]
    probe += [iso(x, y) for pts, _ in buildings for x, y in pts]
    probe += [iso(x, y) for x, y in route]      # keep both route markers in frame
    scale, ox, oy = fit(probe)

    def P(x, y, z=0.0):
        sx, sy = iso(x, y, z)
        return sx * scale + ox, sy * scale + oy

    def poly(pts):
        return " ".join("%.1f,%.1f" % p for p in pts)

    out = ['<svg viewBox="0 0 %d %d" class="rw-map" role="img" '
           'aria-label="Isometric map of Tiong Bahru with a route drawn from a start point to home">'
           % (VIEW_W, VIEW_H)]

    # ---- roads on the ground plane
    out.append('<g class="rw-roads" fill="none" stroke-linecap="round" stroke-linejoin="round">')
    for pts, w in sorted(roads, key=lambda r: -r[1]):
        d = " ".join(("M" if i == 0 else "L") + "%.1f %.1f" % P(x, y) for i, (x, y) in enumerate(pts))
        out.append('<path d="%s" stroke-width="%.1f"></path>' % (d, max(0.9, w * scale * 0.55)))
    out.append("</g>")

    # ---- buildings, painter's algorithm: farthest (smallest x+y) first
    out.append('<g class="rw-blocks">')
    for pts, h in sorted(buildings, key=lambda b: sum(x + y for x, y in b[0]) / len(b[0])):
        walls = []
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            quad = [P(ax, ay), P(bx, by), P(bx, by, h), P(ax, ay, h)]
            # shade by edge orientation so the extrusion reads as 3D
            lit = (bx - ax) > 0
            walls.append('<polygon class="%s" points="%s"></polygon>'
                         % ("w-a" if lit else "w-b", poly(quad)))
        roof = poly([P(x, y, h) for x, y in pts])
        out.append('<g class="bldg">%s<polygon class="roof" points="%s"></polygon></g>'
                   % ("".join(walls), roof))
    out.append("</g>")

    # ---- the route, lifted just off the ground so it reads above the roads
    rd = ""
    if route:
        rd = " ".join(("M" if i == 0 else "L") + "%.1f %.1f" % P(x, y, 2.0)
                      for i, (x, y) in enumerate(route))
        out.append('<defs><mask id="rw-reveal" maskUnits="userSpaceOnUse" x="0" y="0" '
                   'width="%d" height="%d">' % (VIEW_W, VIEW_H))
        out.append('<path class="rw-wipe" d="%s" pathLength="100" fill="none" stroke="#fff" '
                   'stroke-width="14" stroke-linecap="round" stroke-linejoin="round"></path>'
                   % rd)
        out.append("</mask></defs>")
        out.append('<g mask="url(#rw-reveal)">')
        out.append('<path class="rw-route-glow" d="%s" fill="none" stroke-linecap="round" '
                   'stroke-linejoin="round"></path>' % rd)
        out.append('<path class="rw-route" d="%s" fill="none" stroke-linecap="round" '
                   'stroke-linejoin="round"></path>' % rd)
        out.append("</g>")

        sx, sy = P(*route[0], 2.0)
        ex, ey = P(*route[-1], 2.0)
        out.append('<circle class="rw-pulse" cx="%.1f" cy="%.1f" r="7"></circle>' % (sx, sy))
        out.append('<circle class="rw-start" cx="%.1f" cy="%.1f" r="5"></circle>' % (sx, sy))
        out.append('<circle class="rw-walker" cx="0" cy="0" r="4"></circle>')
        # the translate has to sit on an outer group: the CSS pop-in animates
        # transform on .rw-home, which would otherwise override a transform attribute
        out.append('<g transform="translate(%.1f %.1f)"><g class="rw-home">' % (ex, ey))
        out.append('<circle r="11"></circle>'
                   '<path class="pin" d="M-4.6 0.4 0 -3.8l4.6 4.2M-3 0v3.8h6V0" fill="none" '
                   'stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"></path>'
                   '</g></g>')
        out.append('<text class="rw-label rw-label-start" x="%.1f" y="%.1f">Start</text>'
                   % (sx + 12, sy + 4))
        out.append('<text class="rw-label rw-label-home" x="%.1f" y="%.1f" text-anchor="end">Home</text>'
                   % (ex - 15, ey + 4))

        # the walker follows the real route, so its path has to be baked in here
        out.append('<style>.rw-map .rw-walker { offset-path: path("%s"); }</style>' % rd)

    out.append("</svg>")

    svg = "\n".join(out)
    with open(OUT, "w") as fh:
        fh.write(svg)
    print("map.svg  %6.1f KB   %d buildings, %d road segments, route of %d points"
          % (len(svg) / 1024, len(buildings), len(roads), len(route)))


if __name__ == "__main__":
    sys.exit(main())
