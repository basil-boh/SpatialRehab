#!/usr/bin/env python3
"""Build the presentation deck.

Reads template.html, replaces the /*__PHOTO_CSS__*/ marker with one CSS rule per
background carrying a base64 data URI, inlines map.svg at the <!--__MAP_SVG__-->
marker, and writes spatialrehab-deck.html.

The backgrounds have to be embedded rather than linked: the deck is published as
a Claude Artifact, which runs under a policy that blocks every external host, so
a normal <img src="..."> or url(backgrounds/x.jpg) would silently fail to load.

Standard library only. Run it after any edit to template.html:

    python3 deck/build.py
"""
import base64
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
MARKER = "/*__PHOTO_CSS__*/"
MAP_MARKER = "<!--__MAP_SVG__-->"

photos = json.load(open(os.path.join(HERE, "photos.json")))

rules = []
total = 0
for tag in photos:
    path = os.path.join(HERE, "backgrounds", tag + ".jpg")
    if not os.path.exists(path):
        raise SystemExit("missing %s — run: python3 deck/bake.py" % path)
    raw = open(path, "rb").read()
    total += len(raw)
    encoded = base64.b64encode(raw).decode("ascii")
    rules.append(".ph-%s { background-image: url(data:image/jpeg;base64,%s); }" % (tag, encoded))

template = open(os.path.join(HERE, "template.html")).read()
if MARKER not in template:
    raise SystemExit("template.html is missing the %s marker" % MARKER)

referenced = set(re.findall(r"ph-([a-z0-9]+)", template))
missing = referenced - set(photos)
if missing:
    raise SystemExit("template references backgrounds with no photos.json entry: %s"
                     % ", ".join(sorted(missing)))

page = template.replace(MARKER, "\n  ".join(rules))

map_path = os.path.join(HERE, "map.svg")
if MAP_MARKER in page:
    if not os.path.exists(map_path):
        raise SystemExit("missing map.svg — run: python3 deck/build_map.py")
    page = page.replace(MAP_MARKER, open(map_path).read())
dest = os.path.join(HERE, "spatialrehab-deck.html")
open(dest, "w").write(page)

print("backgrounds  %6.1f KB across %d files" % (total / 1024, len(photos)))
print("built        %6.1f KB -> %s" % (len(page.encode()) / 1024, os.path.relpath(dest)))
