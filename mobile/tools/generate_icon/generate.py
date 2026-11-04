"""The Ihsan (إحسان) app icon and logo.

A wordmark: إحسان in Aref Ruqaa Bold (SIL OFL, see OFL.txt) with "Ihsan"
under it, in gold on the app's deep green. The name is from
«وَبِالْوَالِدَيْنِ إِحْسَانًا» (al-Isra 17:23).

    flutter test tools/generate_icon/wordmark_test.dart   # only if the text changes
    python tools/generate_icon/generate.py

Run from mobile/. The Dart step shapes the Arabic and writes wordmark_ar.png
and wordmark_en.png (white on transparent). This script colours them, lays
them out and writes assets/images/logo.png (splash), the Android legacy,
adaptive (foreground + monochrome) and iOS AppIcon PNGs. Needs Pillow only.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RES = ROOT / "android/app/src/main/res"
APPICON = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"

SS = 4
GREEN_TOP = (0x15, 0x6B, 0x5B)
GREEN_BOTTOM = (0x0B, 0x47, 0x3B)
GOLD = (0xDD, 0xB8, 0x6A)

# Layout as fractions of the icon tile's side.
ARABIC_WIDTH = 0.64
LATIN_WIDTH = 0.30
GAP = 0.035
# iOS-style continuous corner, close enough for the splash logo.
TILE_RADIUS = 0.2237

# Android adaptive icons: a 108 dp layer seen through a 72 dp mask.
ADAPTIVE_VIEW = 72 / 108
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def _ink(name: str) -> Image.Image:
    alpha = Image.open(HERE / name).convert("RGBA").getchannel("A")
    return alpha.crop(alpha.getbbox())


ARABIC = _ink("wordmark_ar.png")
LATIN = _ink("wordmark_en.png")


def gradient(size: int) -> Image.Image:
    im = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(im)
    for y in range(size):
        t = y / max(size - 1, 1)
        c = tuple(round(a + (b - a) * t) for a, b in zip(GREEN_TOP, GREEN_BOTTOM))
        d.line([(0, y), (size, y)], fill=c + (255,))
    return im


def _scaled(mask: Image.Image, width: float) -> Image.Image:
    return mask.resize((round(width), round(mask.height * width / mask.width)), Image.LANCZOS)


def draw_mark(im: Image.Image, tile: float, color) -> None:
    """Centres the two-line wordmark on [im], sized for a [tile] px icon."""
    ar = _scaled(ARABIC, tile * ARABIC_WIDTH)
    en = _scaled(LATIN, tile * LATIN_WIDTH)
    gap = round(tile * GAP)
    top = (im.height - (ar.height + gap + en.height)) // 2
    for mask, y in ((ar, top), (en, top + ar.height + gap)):
        ink = Image.new("RGBA", mask.size, color + (255,))
        ink.putalpha(mask)
        im.alpha_composite(ink, ((im.width - mask.width) // 2, y))


def full_tile(size: int) -> Image.Image:
    """Square, opaque: gradient plus wordmark (iOS masks it itself)."""
    big = gradient(size * SS)
    draw_mark(big, size * SS, GOLD)
    return big.resize((size, size), Image.LANCZOS).convert("RGB")


def rounded_tile(size: int) -> Image.Image:
    im = full_tile(size).convert("RGBA")
    mask = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size * SS - 1, size * SS - 1], radius=size * SS * TILE_RADIUS, fill=255)
    im.putalpha(mask.resize((size, size), Image.LANCZOS))
    return im


def adaptive_layer(size: int, color) -> Image.Image:
    """Wordmark alone on a transparent 108 dp layer, scaled to the 72 dp view."""
    big = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    draw_mark(big, size * SS * ADAPTIVE_VIEW, color)
    return big.resize((size, size), Image.LANCZOS)


def main() -> None:
    rounded_tile(1024).save(ROOT / "assets/images/logo.png", optimize=True)

    for name, scale in DENSITIES.items():
        folder = RES / f"mipmap-{name}"
        rounded_tile(round(48 * scale)).save(folder / "ic_launcher.png", optimize=True)
        layer = round(108 * scale)
        adaptive_layer(layer, GOLD).save(folder / "ic_launcher_foreground.png", optimize=True)
        adaptive_layer(layer, (255, 255, 255)).save(
            folder / "ic_launcher_monochrome.png", optimize=True)

    for image in json.loads((APPICON / "Contents.json").read_text())["images"]:
        side = float(image["size"].split("x")[0]) * int(image["scale"][0])
        full_tile(round(side)).save(APPICON / image["filename"], optimize=True)


if __name__ == "__main__":
    main()
