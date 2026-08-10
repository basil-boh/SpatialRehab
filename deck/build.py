#!/usr/bin/env python3
"""Build the presentation deck.

Reads template.html, replaces the /*__PHOTO_CSS__*/ marker with one CSS rule per
background carrying a base64 data URI, embeds team portraits from
assets/avatars/ at /*__AVATAR_CSS__*/, embeds the mahjong hand photo at
/*__HAND_CSS__*/, embeds family face CSS at /*__FAMILY_CSS__*/ and SVG
__FAMILY_<name>__ markers, embeds the kopi table still at /*__KOPI_CSS__*/, embeds the Ah Pek
greeting video at __VIDEO_ah_pek_greeting__, inlines map.svg at the
<!--__MAP_SVG__--> marker, and writes spatialrehab-deck.html.

The backgrounds (and portraits) have to be embedded rather than linked: the
deck is published as a Claude Artifact, which runs under a policy that blocks
every external host, so a normal <img src="..."> or url(backgrounds/x.jpg)
would silently fail to load.

Standard library only. Run it after any edit to template.html:

    python3 deck/build.py
"""
import base64
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
MARKER = "/*__PHOTO_CSS__*/"
AVATAR_MARKER = "/*__AVATAR_CSS__*/"
HAND_MARKER = "/*__HAND_CSS__*/"
FAMILY_CSS_MARKER = "/*__FAMILY_CSS__*/"
KOPI_MARKER = "/*__KOPI_CSS__*/"
MAP_MARKER = "<!--__MAP_SVG__-->"

TEAM_AVATARS = (
    "aditya",
    "brian",
    "jingtong",
    "nicole",
    "basil",
)

FAMILY_FACES = (
    "ah-pek",
    "chio-bu",
    "wei-ming",
    "mei-ling",
    "jun-hao",
    "sze-hao",
)

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

avatar_rules = []
avatar_total = 0
for tag in TEAM_AVATARS:
    path = os.path.join(HERE, "assets", "avatars", tag + ".jpg")
    if not os.path.exists(path):
        raise SystemExit(
            "missing %s — drop a face crop at that path (256px JPEG)" % path
        )
    raw = open(path, "rb").read()
    avatar_total += len(raw)
    encoded = base64.b64encode(raw).decode("ascii")
    avatar_rules.append(
        ".av-%s { background-image: url(data:image/jpeg;base64,%s); }"
        % (tag, encoded)
    )

hand_png = os.path.join(HERE, "assets", "mahjong-win.png")
hand_jpg = os.path.join(HERE, "assets", "mahjong-win.jpg")
if os.path.exists(hand_png):
    hand_path = hand_png
    hand_mime = "image/png"
elif os.path.exists(hand_jpg):
    hand_path = hand_jpg
    hand_mime = "image/jpeg"
else:
    raise SystemExit("missing deck/assets/mahjong-win.png (or .jpg)")
hand_raw = open(hand_path, "rb").read()
hand_rule = (
    ".img-mahjong-win { background-image: url(data:%s;base64,%s); }"
    % (hand_mime, base64.b64encode(hand_raw).decode("ascii"))
)

family_total = 0
family_uris = {}
family_css = []
for tag in FAMILY_FACES:
    path = os.path.join(HERE, "assets", "family", tag + ".jpg")
    if not os.path.exists(path):
        raise SystemExit("missing %s" % path)
    raw = open(path, "rb").read()
    family_total += len(raw)
    uri = "data:image/jpeg;base64," + base64.b64encode(raw).decode("ascii")
    family_uris[tag] = uri
    # Higher specificity than `.namecard .avatar` so the portrait beats the
    # gradient fallback on the identity card.
    family_css.append(
        ".face-%s, .namecard .avatar.face-%s {"
        " background-image: url(%s);"
        " background-size: cover;"
        " background-position: center top;"
        " background-repeat: no-repeat; }"
        % (tag, tag, uri)
    )

kopi_path = os.path.join(HERE, "assets", "coffee_table.jpg")
if not os.path.exists(kopi_path):
    raise SystemExit("missing %s" % kopi_path)
kopi_raw = open(kopi_path, "rb").read()
kopi_rule = (
    ".img-coffee-table { background-image: url(data:image/jpeg;base64,%s); }"
    % base64.b64encode(kopi_raw).decode("ascii")
)

# Greeting video (slide 11) — portrait MP4 from assets/
GREETING_VIDEO = "assets/grok-video-49be710f-e5b2-412e-ac27-954c5e323d73.mp4"
GREETING_TOKEN = "__VIDEO_ah_pek_greeting__"
greeting_path = os.path.join(HERE, GREETING_VIDEO)
if not os.path.exists(greeting_path):
    raise SystemExit("missing %s" % greeting_path)
greeting_raw = open(greeting_path, "rb").read()
greeting_uri = "data:video/mp4;base64," + base64.b64encode(greeting_raw).decode("ascii")

template = open(os.path.join(HERE, "template.html")).read()
for needed in (MARKER, AVATAR_MARKER, HAND_MARKER, FAMILY_CSS_MARKER, KOPI_MARKER):
    if needed not in template:
        raise SystemExit("template.html is missing the %s marker" % needed)
if GREETING_TOKEN not in template:
    raise SystemExit("template.html is missing the %s token" % GREETING_TOKEN)

referenced = set(re.findall(r"ph-([a-z0-9]+)", template))
missing = referenced - set(photos)
if missing:
    raise SystemExit("template references backgrounds with no photos.json entry: %s"
                     % ", ".join(sorted(missing)))

page = template.replace(MARKER, "\n  ".join(rules))
page = page.replace(AVATAR_MARKER, "\n  ".join(avatar_rules))
page = page.replace(HAND_MARKER, hand_rule)
page = page.replace(FAMILY_CSS_MARKER, "\n  ".join(family_css))
page = page.replace(KOPI_MARKER, kopi_rule)
page = page.replace(GREETING_TOKEN, greeting_uri)

for tag, uri in family_uris.items():
    token = "__FAMILY_%s__" % tag
    if token not in page:
        raise SystemExit("template is missing family face token %s" % token)
    page = page.replace(token, uri)

map_path = os.path.join(HERE, "map.svg")
if MAP_MARKER in page:
    if not os.path.exists(map_path):
        raise SystemExit("missing map.svg — run: python3 deck/build_map.py")
    page = page.replace(MAP_MARKER, open(map_path).read())
dest = os.path.join(HERE, "spatialrehab-deck.html")
open(dest, "w").write(page)

print("backgrounds  %6.1f KB across %d files" % (total / 1024, len(photos)))
print("avatars      %6.1f KB across %d files" % (avatar_total / 1024, len(TEAM_AVATARS)))
print("family       %6.1f KB across %d files" % (family_total / 1024, len(FAMILY_FACES)))
print("hand photo   %6.1f KB (%s)" % (len(hand_raw) / 1024, os.path.basename(hand_path)))
print("kopi table   %6.1f KB" % (len(kopi_raw) / 1024))
print("greeting vid %6.1f KB" % (len(greeting_raw) / 1024))
print("built        %6.1f KB -> %s" % (len(page.encode()) / 1024, os.path.relpath(dest)))
