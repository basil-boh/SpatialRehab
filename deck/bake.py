#!/usr/bin/env python3
"""Re-bake the slide backgrounds from their original photographs.

Only needed when changing a photo or its grading — the baked results in
backgrounds/ are committed, so building the deck does not require this script.

For each entry in photos.json: download the original if it is not already in
.sources/ (untracked), crop it to the slide aspect, blur it, and grade it.
One image may back more than one slide, hence "slides" is a list.
Blurring here rather than in CSS keeps the published page cheap to render and
makes a screenshot look exactly like the live deck.

Requires Pillow:  python3 -m pip install Pillow
Then:             python3 deck/bake.py && python3 deck/build.py
"""
import json
import os
import urllib.parse
import urllib.request

from PIL import Image, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCES = os.path.join(HERE, ".sources")
BACKGROUNDS = os.path.join(HERE, "backgrounds")
UA = {"User-Agent": "Mozilla/5.0"}
WIDTH, HEIGHT = 2400, 1504   # roughly 2x, so photographs stay crisp on retina displays

os.makedirs(SOURCES, exist_ok=True)
os.makedirs(BACKGROUNDS, exist_ok=True)

photos = json.load(open(os.path.join(HERE, "photos.json")))
total = 0

for tag, spec in photos.items():
    original = os.path.join(SOURCES, tag + ".jpg")
    if not os.path.exists(original):
        url = spec["source"]
        if "images.unsplash.com" in url:
            url += "?w=1900&q=80&fm=jpg"      # ask Unsplash for a sensible size
        url = urllib.parse.quote(url, safe=":/?&=%")   # gov filenames contain spaces
        urllib.request.urlretrieve(urllib.request.Request(url, headers=UA).full_url, original)

    im = Image.open(original).convert("RGB")

    # cover-crop to the slide aspect, centred
    scale = max(WIDTH / im.width, HEIGHT / im.height)
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    left, top = (im.width - WIDTH) // 2, (im.height - HEIGHT) // 2
    im = im.crop((left, top, left + WIDTH, top + HEIGHT))

    im = im.filter(ImageFilter.GaussianBlur(spec["blur"]))
    im = ImageEnhance.Brightness(im).enhance(spec["brightness"])
    im = ImageEnhance.Color(im).enhance(spec["saturation"])

    # warmth: lift red, drop blue, so the whole deck sits in one register
    warmth = spec["warmth"]
    if warmth != 1.0:
        r, g, b = im.split()
        r = r.point(lambda v: min(255, int(v * warmth)))
        b = b.point(lambda v: int(v / warmth))
        im = Image.merge("RGB", (r, g, b))

    dest = os.path.join(BACKGROUNDS, tag + ".jpg")
    im.save(dest, quality=80, optimize=True, progressive=True)
    size = os.path.getsize(dest)
    total += size
    slides = ", ".join(str(n) for n in spec["slides"])
    print("%-9s slide %-6s %6.1f KB   %s" % (tag, slides, size / 1024, spec["credit"]))

print("total              %6.1f KB across %d frames" % (total / 1024, len(photos)))
