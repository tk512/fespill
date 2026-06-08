#!/usr/bin/env python3
"""
Turn a real face photo (transparent background) into a retro, dithered
harbor-master portrait for the docking screen.

  in : /Users/tk/tmp/papsen.png   (or pass a path as argv[1])
  out: assets/ports/portraits/default.png   (used for every harbour that has no
       port-specific portrait — see Port screen fallback)

It crops to the face, shrinks it small (so it reads as chunky pixels in the
game's nearest-filter portrait well), and quantizes to a small palette with
dithering for that 90s look — while staying clearly recognizable.
"""
import os, sys
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else "/Users/tk/tmp/papsen.png"
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ports", "portraits", "default.png")
WIDTH = 130       # small -> chunky pixels when scaled up in the well
COLORS = 24       # palette size (lower = more retro banding)

im = Image.open(SRC).convert("RGBA")
bbox = im.getbbox()
if bbox:
    im = im.crop(bbox)

h = max(1, round(im.height * WIDTH / im.width))
im = im.resize((WIDTH, h), Image.LANCZOS)

r, g, b, a = im.split()
rgb = Image.merge("RGB", (r, g, b))
# reduced-palette dither (Floyd–Steinberg) for the retro look
dithered = rgb.quantize(colors=COLORS, method=Image.MEDIANCUT,
                        dither=Image.FLOYDSTEINBERG).convert("RGB")
# keep a clean cutout: hard-threshold the original alpha
amask = a.point(lambda v: 255 if v > 128 else 0)
out = Image.merge("RGBA", (*dithered.split(), amask))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
out.save(OUT)
print("wrote", OUT, out.size)

# preview on the dark portrait-well colour, scaled up, so we can eyeball it
scale = 3
well = Image.new("RGB", (out.width * scale, out.height * scale), (38, 26, 18))
big = out.resize((out.width * scale, out.height * scale), Image.NEAREST)
well.paste(big, (0, 0), big)
well.save("/tmp/portrait_prev.png")
