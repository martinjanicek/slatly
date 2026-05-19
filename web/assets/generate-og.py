#!/usr/bin/env python3
"""
Generate the 1200x630 Open Graph image for Slatly.

Layout:
  - Navy → indigo gradient background with a soft warm glow top-right.
  - Slatly app icon on the right (rounded, drop shadow).
  - Big wordmark + tagline on the left.
  - Footer chip "Apple Watch · Somfy" in muted ink.
"""

import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1200, 630
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'og-image.png')
ICON = os.path.join(HERE, 'app-icon-512.png')

# --- Background -----------------------------------------------------------
img = Image.new('RGB', (W, H), (14, 21, 48))
px = img.load()
for y in range(H):
    blend_y = y / (H - 1)
    for x in range(W):
        blend_x = x / (W - 1)
        # Diagonal gradient: navy bottom-left to indigo top-right.
        r = int(10 + (1 - blend_y) * 18 + blend_x * 10)
        g = int(16 + (1 - blend_y) * 14 + blend_x * 8)
        b = int(48 + (1 - blend_y) * 30 + blend_x * 22)
        px[x, y] = (min(r, 255), min(g, 255), min(b, 255))

# Warm sun-glow top-right
glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
gdraw = ImageDraw.Draw(glow)
for radius, alpha in [(420, 24), (330, 38), (240, 56), (160, 78), (90, 110)]:
    cx, cy = 980, 120
    gdraw.ellipse(
        [cx - radius, cy - radius, cx + radius, cy + radius],
        fill=(255, 196, 132, alpha),
    )
glow = glow.filter(ImageFilter.GaussianBlur(40))
img.paste(glow, (0, 0), glow)

# --- Slatly icon, rounded + shadow ---------------------------------------
if os.path.exists(ICON):
    icon = Image.open(ICON).convert('RGBA').resize((380, 380), Image.LANCZOS)
    # Drop shadow
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle(
        [780, 145, 780 + 380, 145 + 380], radius=86,
        fill=(0, 0, 0, 160),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    img.paste(shadow, (0, 12), shadow)
    img.paste(icon, (770, 125), icon)

# --- Typography -----------------------------------------------------------
def load_font(size):
    candidates = [
        '/System/Library/Fonts/Helvetica.ttc',
        '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
        '/Library/Fonts/Arial.ttf',
    ]
    for c in candidates:
        if os.path.exists(c):
            try:
                return ImageFont.truetype(c, size)
            except OSError:
                continue
    return ImageFont.load_default()

font_title = load_font(132)
font_sub = load_font(48)
font_meta = load_font(28)

draw = ImageDraw.Draw(img)

# Wordmark with subtle shadow
shadow_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow_layer)
sd.text((78, 178), 'Slatly', font=font_title, fill=(0, 0, 0, 160))
shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(6))
img.paste(shadow_layer, (0, 0), shadow_layer)
draw.text((76, 174), 'Slatly', font=font_title, fill=(255, 255, 255))

# Tagline
draw.text((78, 326), 'Your blinds, on your wrist.', font=font_sub, fill=(202, 214, 240))

# Eyebrow chip "Apple Watch · Somfy"
chip_text = 'APPLE WATCH  ·  SOMFY'
chip_bbox = draw.textbbox((0, 0), chip_text, font=font_meta)
cw = chip_bbox[2] - chip_bbox[0]
ch = chip_bbox[3] - chip_bbox[1]
chip_pad_x, chip_pad_y = 22, 12
chip_x, chip_y = 78, 470
draw.rounded_rectangle(
    [chip_x, chip_y, chip_x + cw + chip_pad_x * 2, chip_y + ch + chip_pad_y * 2],
    radius=20,
    fill=(255, 255, 255, 22),
    outline=(255, 255, 255, 60),
    width=1,
)
draw.text(
    (chip_x + chip_pad_x, chip_y + chip_pad_y - 2),
    chip_text,
    font=font_meta,
    fill=(200, 215, 240),
)

# Footer URL hint
draw.text((78, 558), 'slatly.punkhive.com', font=font_meta, fill=(140, 158, 200))

# --- Save -----------------------------------------------------------------
img.save(OUT, 'PNG', optimize=True)
print(f'Wrote {OUT} ({os.path.getsize(OUT)} bytes)')
