#!/usr/bin/env python3
"""Vygeneruje 1024x1024 app icon (žaluzie před oknem) do Assets.xcassets.

watchOS appky se rendrují jako kruh, takže nekreslíme čtvercový rám.
Kresba musí dobře vypadat i po circular cropu.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def make_image() -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # --- Sky gradient behind everything ---
    sky_top = (108, 180, 248)
    sky_bottom = (22, 70, 138)
    for y in range(SIZE):
        c = lerp(sky_top, sky_bottom, y / (SIZE - 1))
        draw.line([(0, y), (SIZE, y)], fill=c + (255,))

    # Soft sun glow (top-left, partially clipped — looks natural in circle)
    sun_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sun_draw = ImageDraw.Draw(sun_layer)
    sun_draw.ellipse(
        [SIZE * 0.10, SIZE * 0.06, SIZE * 0.46, SIZE * 0.42],
        fill=(255, 240, 195, 90),
    )
    sun_layer = sun_layer.filter(ImageFilter.GaussianBlur(radius=55))
    img.alpha_composite(sun_layer)

    # --- Slats ---
    slat_count = 8
    slot = SIZE / slat_count
    # Slat front face thickness (gap between slats = slot - thickness)
    thickness = slot * 0.74
    # Top "lip" — bit of the top of each slat visible (3D depth cue)
    top_lip = slot * 0.10

    # Antracit
    slat_top = (96, 100, 108)
    slat_bottom = (32, 36, 42)
    top_lip_color = (132, 138, 146)
    gap_shadow = (0, 0, 0, 200)

    slat_canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(slat_canvas)

    for i in range(slat_count):
        y_top = int(i * slot)
        y_front_top = int(y_top + top_lip)
        y_bottom = int(y_top + thickness + top_lip)

        # Top lip (slat seen from slightly above — narrow horizontal strip)
        sd.rectangle(
            [(0, y_top), (SIZE, y_front_top)],
            fill=top_lip_color + (255,),
        )
        # Front face with vertical gradient
        h = max(y_bottom - y_front_top, 1)
        strip = Image.new("RGBA", (SIZE, h), (0, 0, 0, 0))
        ssd = ImageDraw.Draw(strip)
        for yy in range(h):
            c = lerp(slat_top, slat_bottom, yy / max(h - 1, 1))
            ssd.line([(0, yy), (SIZE, yy)], fill=c + (255,))
        slat_canvas.alpha_composite(strip, dest=(0, y_front_top))
        # Subtle highlight just under the top lip
        sd.rectangle(
            [(0, y_front_top), (SIZE, y_front_top + max(int(slot * 0.03), 2))],
            fill=(255, 255, 255, 70),
        )
        # Shadow under each slat (the gap between slats)
        gap_h = max(int(slot * 0.06), 3)
        sd.rectangle(
            [(0, y_bottom), (SIZE, y_bottom + gap_h)],
            fill=gap_shadow,
        )

    # Subtle vertical lighting falloff (slightly darker on sides for 3D feel)
    vignette = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vignette)
    for x in range(SIZE):
        # Darker at edges, light in the middle — narrow falloff
        center_d = abs(x - SIZE / 2) / (SIZE / 2)
        alpha = int(40 * center_d ** 2)
        if alpha > 0:
            vd.line([(x, 0), (x, SIZE)], fill=(0, 0, 0, alpha))
    slat_canvas.alpha_composite(vignette)

    img.alpha_composite(slat_canvas)

    return img.convert("RGB")


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img = make_image()
    img.save(OUT, "PNG", optimize=True)
    print(f"Wrote {OUT} ({OUT.stat().st_size // 1024} KiB)")


if __name__ == "__main__":
    main()
