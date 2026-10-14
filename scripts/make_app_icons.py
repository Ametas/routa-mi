#!/usr/bin/env python3
"""Generates the RoutaMi launcher icons from docs/brand/app-icon.jpg.

The source is a round avatar with a neon ring. The ring is cut off, the art
fills the whole adaptive-icon layer, and the corners left outside the art
circle take the background colour. Needs Pillow: python3 scripts/make_app_icons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'docs/brand/app-icon.jpg'
RES = ROOT / 'android/app/src/main/res'

BACKGROUND = (13, 14, 32, 255)  # #0D0E20, the corners of the source
ART_CENTER = (320, 320)  # centre of the art circle in the 640 px source
ART_RADIUS = 304  # inside the neon ring
VIEW_CENTER = (322, 308)  # what the launcher mask is centred on
VIEW_RADIUS = 245  # source pixels shown in the 72 dp viewport


def art() -> Image.Image:
    src = Image.open(SOURCE).convert('RGBA')
    scale = src.width / 640
    canvas = Image.new('RGBA', src.size, BACKGROUND)
    mask = Image.new('L', src.size, 0)
    cx, cy, r = (v * scale for v in (*ART_CENTER, ART_RADIUS))
    ImageDraw.Draw(mask).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    canvas.paste(src, (0, 0), mask.filter(ImageFilter.GaussianBlur(3 * scale)))
    return canvas, scale


def crop(radius: float, size: int) -> Image.Image:
    """Square of [radius] source pixels around VIEW_CENTER, padded with BACKGROUND."""
    source, scale = art()
    r = radius * scale
    cx, cy = (v * scale for v in VIEW_CENTER)
    side = round(2 * r)
    out = Image.new('RGBA', (side, side), BACKGROUND)
    out.paste(source, (round(r - cx), round(r - cy)))
    return out.resize((size, size), Image.LANCZOS)


def masked(image: Image.Image, shape: str, inset: float = 0) -> Image.Image:
    size = image.width
    big = size * 4
    mask = Image.new('L', (big, big), 0)
    box = (big * inset, big * inset, big * (1 - inset) - 1, big * (1 - inset) - 1)
    draw = ImageDraw.Draw(mask)
    if shape == 'circle':
        draw.ellipse(box, fill=255)
    else:
        draw.rounded_rectangle(box, radius=big * (1 - 2 * inset) * 0.22, fill=255)
    out = Image.new('RGBA', image.size, (0, 0, 0, 0))
    out.paste(image, (0, 0), mask.resize(image.size, Image.LANCZOS))
    return out


def main() -> None:
    # Adaptive icon: 108 dp layer, the inner 72 dp is what launchers show.
    crop(VIEW_RADIUS * 1.5, 432).save(RES / 'drawable/ic_launcher_foreground.png', optimize=True)

    # Legacy icons for launchers without adaptive icons.
    for bucket, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        face = crop(VIEW_RADIUS, px)
        folder = RES / f'mipmap-{bucket}'
        masked(face, 'square', 0.04).save(folder / 'ic_launcher.webp', lossless=True)
        masked(face, 'circle', 0.02).save(folder / 'ic_launcher_round.webp', lossless=True)

    # In-app icon (About) and the desktop icon.
    icon = masked(crop(VIEW_RADIUS, 550), 'square')
    icon.save(ROOT / 'assets/images/icon.png', optimize=True)
    icon.resize((256, 256), Image.LANCZOS).save(ROOT / 'assets/images/icon.ico')

    # Android TV banner.
    banner = Image.new('RGBA', (320, 180), BACKGROUND)
    banner.alpha_composite(masked(crop(VIEW_RADIUS, 112), 'square'), (24, 34))
    font = ImageFont.truetype(str(ROOT / 'assets/fonts/JetBrainsMono-Regular.ttf'), 30)
    draw = ImageDraw.Draw(banner)
    draw.text((150, 90), 'RoutaMi', font=font, fill=(240, 236, 255, 255), anchor='lm')
    banner.save(RES / 'mipmap-xhdpi/ic_banner.png', optimize=True)


if __name__ == '__main__':
    main()
