"""Procedural looping backgrounds for the Now Playing screen.

Renders five calm scenes (flame, rain, wind, forest, sea) frame by frame with
numpy + Pillow and pipes them into ffmpeg. Every moving thing is a function of
the loop phase t/T only (integer-harmonic sines, FFT noise that is periodic in
time, particles whose position is (phase0 + k*t/T) mod 1), so frame N would
equal frame 0 and the clip loops without a seam.

    python tools/generate_backgrounds/generate.py            # all scenes
    python tools/generate_backgrounds/generate.py sea rain   # some scenes

Writes assets/videos/backgrounds/<scene>.mp4 and <scene>.jpg (poster used by
the picker and as the reduced-motion still). Needs numpy and Pillow, and
ffmpeg on PATH or the imageio-ffmpeg wheel (pip install imageio-ffmpeg).
"""

from __future__ import annotations

import math
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 720, 1280
FPS = 24
SECONDS = 8
N = FPS * SECONDS  # frames per loop
TAU = 2 * math.pi

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "videos" / "backgrounds"

# The app's palette: green-black surfaces, gold as the only warm light.
GOLD = np.array([230, 199, 126], np.float32) / 255
YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)

# A fixed ±1 LSB dither: breaks banding in the dark gradients and, being
# static, costs almost nothing after the first keyframe.
DITHER = (np.random.default_rng(7).random((H, W, 1), np.float32) - 0.5) * (2 / 255)


def ffmpeg_exe() -> str:
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        sys.exit("ffmpeg not found: install it or `pip install imageio-ffmpeg`")


# ── helpers ──────────────────────────────────────────────────────────────────


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def vgrad(stops):
    """Vertical gradient from [(y_fraction, (r, g, b)), ...] → HxWx3 float."""
    ys = np.linspace(0, 1, H)
    pos = [s[0] for s in stops]
    cols = np.array([s[1] for s in stops], np.float32) / 255
    col = np.stack([np.interp(ys, pos, cols[:, c]) for c in range(3)], -1)
    return np.repeat(col[:, None, :], W, axis=1).astype(np.float32)


def rgb(*c):
    return np.array(c, np.float32) / 255


def periodic_noise(shape, cycles, seed):
    """Gaussian-filtered white noise via FFT: periodic along every axis.

    cycles[i] is roughly how many undulations fit along axis i, so the time
    axis (length N) loops seamlessly by construction.
    """
    rng = np.random.default_rng(seed)
    spec = np.fft.fftn(rng.standard_normal(shape))
    filt = np.ones(shape)
    for axis, (n, c) in enumerate(zip(shape, cycles)):
        f = np.fft.fftfreq(n) * n  # integer cycles along this axis
        sh = [1] * len(shape)
        sh[axis] = n
        filt = filt * np.exp(-((f / c) ** 2)).reshape(sh)
    out = np.real(np.fft.ifftn(spec * filt))
    return ((out - out.mean()) / out.std()).astype(np.float32)


def up(a, w=W, h=H):
    """Bilinear upscale of a small float field."""
    return np.asarray(Image.fromarray(a.astype(np.float32), "F").resize((w, h), Image.BILINEAR))


def wrap_sample(field, ys, xs):
    """Bilinear sample with wrap-around (for tileable fields)."""
    fh, fw = field.shape
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy, fx = ys - y0, xs - x0
    y0 %= fh
    x0 %= fw
    y1, x1 = (y0 + 1) % fh, (x0 + 1) % fw
    top = field[y0, x0] * (1 - fx) + field[y0, x1] * fx
    bot = field[y1, x0] * (1 - fx) + field[y1, x1] * fx
    return top * (1 - fy) + bot * fy


def screen(base, col, a):
    """Emissive light: screen blend of col at alpha a over base."""
    return 1 - (1 - base) * (1 - col * a[..., None])


def over(base, col, a):
    return base * (1 - a[..., None]) + col * a[..., None]


def gauss_blob(base, cx, cy, sigma, col, strength):
    """Additive soft dot, computed only in its own neighbourhood."""
    r = int(sigma * 3.5) + 1
    x0, x1 = max(int(cx) - r, 0), min(int(cx) + r + 1, W)
    y0, y1 = max(int(cy) - r, 0), min(int(cy) + r + 1, H)
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    g = np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * sigma * sigma)) * strength
    base[y0:y1, x0:x1] += col * g[..., None]


class Supersampled:
    """A 2x grayscale canvas for antialiased strokes."""

    S = 2

    def __init__(self):
        self.img = Image.new("L", (W * self.S, H * self.S), 0)
        self.draw = ImageDraw.Draw(self.img)

    def line(self, pts, value, width):
        s = self.S
        self.draw.line([(x * s, y * s) for x, y in pts], fill=int(255 * min(value, 1)), width=max(1, round(width * s)))

    def ellipse(self, cx, cy, rx, ry, value, width):
        s = self.S
        self.draw.ellipse(
            [(cx - rx) * s, (cy - ry) * s, (cx + rx) * s, (cy + ry) * s],
            outline=int(255 * min(value, 1)),
            width=max(1, round(width * s)),
        )

    def alpha(self, blur=0.0):
        img = self.img.resize((W, H), Image.BOX)
        if blur:
            img = img.filter(ImageFilter.GaussianBlur(blur))
        return np.asarray(img, np.float32) / 255


# ── scenes ───────────────────────────────────────────────────────────────────
# Each scene is a class with frame(i) -> HxWx3 float in 0..1. Focal points
# sit between y≈0.40H and 0.62H: above that the player shows the artwork,
# below it the controls.


class Flame:
    """A candle in the dark: slim flame, warm halo, flicker from looping noise."""

    def __init__(self):
        self.bg = vgrad([(0, (7, 24, 20)), (0.5, (5, 18, 15)), (1, (3, 10, 9))])
        self.cx, self.base = W / 2, 0.555 * H  # bottom of the flame
        self.fh, self.fw = 112.0, 34.0
        self.sway = periodic_noise((N, 64), (5, 3), seed=11)  # (t, height)
        self.flick = periodic_noise((N,), (7,), seed=12)
        self.flick2 = periodic_noise((N,), (3,), seed=13)
        # Flame box.
        self.x0, self.x1 = int(self.cx - 80), int(self.cx + 80)
        self.y0, self.y1 = int(self.base - self.fh * 1.6), int(self.base + 30)
        self.bx, self.by = np.meshgrid(np.arange(self.x0, self.x1, dtype=np.float32), np.arange(self.y0, self.y1, dtype=np.float32))
        self.candle = self._candle()

    def _candle(self):
        top, half = self.base + 12, 25.0
        dx = np.abs(XX - self.cx)
        side = np.clip(half + 0.5 - dx, 0, 1)
        below = YY - top
        body = side * (below >= 0)
        # Rounded top rim (a flattened ellipse) blends into the body.
        rim = np.clip(1 - ((XX - self.cx) / half) ** 2 - ((YY - top) / 5) ** 2, 0, 1) ** 0.3
        mask = np.maximum(body, rim)
        cyl = 0.4 + 0.6 * np.clip(np.cos(np.clip(dx / half, 0, 1) * math.pi / 2), 0, 1) ** 0.8
        lit = np.exp(-np.clip(below, 0, None) / 75)
        fade = 1 - smoothstep(0.08 * H, 0.2 * H, below)
        col = rgb(176, 146, 104)[None, None] * (cyl * (0.08 + 0.92 * lit) * fade)[..., None]
        # Translucent wax near the flame glows from inside.
        col += rgb(255, 150, 60)[None, None] * (0.45 * np.exp(-np.clip(below, 0, None) / 18) * cyl)[..., None]
        return col, mask * np.maximum(fade, 0.0)

    def frame(self, i):
        t = i / N
        f = 1 + 0.07 * self.flick[i] + 0.04 * math.sin(TAU * 3 * t + 0.6)
        img = self.bg.copy()

        # Halo on the room (slightly taller than wide), breathing with the flame.
        cy = self.base - 0.45 * self.fh
        r2 = ((XX - self.cx) / 1.0) ** 2 + ((YY - cy) / 1.25) ** 2
        warm = rgb(255, 138, 52)
        img += warm * ((0.20 * np.exp(-r2 / (2 * 120**2)) + 0.05 * np.exp(-r2 / (2 * 380**2))) * f)[..., None]

        # Candle body, lit by the flicker.
        ccol, cmask = self.candle
        img = over(img, ccol * (0.85 + 0.15 * f), cmask)

        # Wick.
        wick = (np.abs(XX - self.cx) < 1.4) & (YY > self.base - 8) & (YY < self.base + 14)
        img[wick] = img[wick] * 0.3 + rgb(30, 20, 12) * 0.7

        # Flame, in its own box.
        fh = self.fh * (1 + 0.05 * self.flick2[i] + 0.03 * self.flick[i])
        u = (self.base - self.by) / fh  # 0 at base, 1 at tip
        ui = np.clip(u, 0, 1) * 63
        lo = np.floor(ui).astype(int)
        hi = np.minimum(lo + 1, 63)
        n = self.sway[i, lo] * (1 - (ui - lo)) + self.sway[i, hi] * (ui - lo)
        sway = 5.5 * n * np.clip(u, 0, 1) ** 1.6 + 2.5 * math.sin(TAU * t + 0.3) * np.clip(u, 0, 1) ** 2
        uc = np.clip(u, -0.12, 1)
        half = self.fw * ((uc + 0.12) / 1.12) ** 0.55 * (1 - uc) ** 0.85 + 0.01
        d = np.abs(self.bx - self.cx - sway) / half
        alpha = (1 - smoothstep(0.7, 1.02, d)) * smoothstep(-0.14, 0.03, u) * (1 - smoothstep(0.82, 1.0, u))
        core, mid, edge = rgb(255, 248, 222), rgb(255, 186, 88), rgb(232, 98, 28)
        k1 = smoothstep(0.0, 0.62, d + 0.55 * np.clip(u - 0.45, 0, None))[..., None]
        k2 = smoothstep(0.5, 1.0, d + 0.35 * u)[..., None]
        col = core * (1 - k1) + mid * k1
        col = col * (1 - k2) + edge * k2
        # A faint blue foot, as real candle flames have.
        blue = (smoothstep(0.12, -0.05, u) * (1 - smoothstep(0.3, 0.9, d)))[..., None]
        col = col * (1 - 0.5 * blue) + rgb(90, 120, 255) * 0.5 * blue

        layer = col * alpha[..., None]
        halo = np.asarray(Image.fromarray((np.clip(layer, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10)), np.float32) / 255
        box = img[self.y0 : self.y1, self.x0 : self.x1]
        box = 1 - (1 - box) * (1 - halo * 0.55 * f)
        box = 1 - (1 - box) * (1 - layer)
        img[self.y0 : self.y1, self.x0 : self.x1] = box
        return img


class Rain:
    """Slow diagonal streaks over a blue-green dusk, faint ripples low down."""

    SLOPE = 0.16  # x drift per pixel of fall

    def __init__(self):
        rng = np.random.default_rng(21)
        self.bg = vgrad([(0, (8, 32, 38)), (0.45, (8, 30, 32)), (1, (3, 14, 14))])
        self.haze = periodic_noise((N, 24, 14), (2, 3, 2), seed=22)
        # (count, cycles per loop, length, width, alpha)
        layers = [(140, 2, 46, 1.0, 0.16), (70, 2, 70, 1.3, 0.24), (26, 3, 120, 1.8, 0.30)]
        self.drops = []
        for count, k, length, width, a in layers:
            for _ in range(count):
                self.drops.append(
                    (rng.random() * (W + 300) - 150, rng.random(), k, length * rng.uniform(0.75, 1.25), width, a * rng.uniform(0.6, 1.1))
                )
        self.ripples = [(rng.uniform(40, W - 40), rng.uniform(0.80 * H, 0.97 * H), rng.random(), int(rng.integers(1, 3))) for _ in range(14)]

    def frame(self, i):
        t = i / N
        img = self.bg.copy()
        haze = up(self.haze[i])
        img += rgb(30, 70, 72) * (0.05 * (haze + 1.5) * smoothstep(0.0, 0.5, YY / H) * (1 - smoothstep(0.5, 1.0, YY / H)))[..., None]

        canvas = Supersampled()
        travel = H + 200
        for x0, p0, k, length, width, a in self.drops:
            ph = (p0 + k * t) % 1.0
            y = ph * travel - 100
            x = x0 + self.SLOPE * y
            canvas.line([(x - self.SLOPE * length, y - length), (x, y)], a, width)
        for x, y, p0, m in self.ripples:
            ph = (p0 + m * t) % 1.0
            r = 4 + 42 * ph
            canvas.ellipse(x, y, r, r * 0.28, 0.22 * (1 - ph) ** 2, 1.0)
        a = canvas.alpha(blur=0.6)
        return screen(img, rgb(178, 214, 208), a)


class Wind:
    """Horizontal mist streams and thin wind lines drifting right to left."""

    def __init__(self):
        rng = np.random.default_rng(31)
        self.bg = vgrad([(0, (6, 28, 24)), (0.55, (6, 24, 20)), (1, (3, 12, 10))])
        # Tileable mist fields, stretched horizontally (few cycles in x).
        self.mist = [periodic_noise((160, 90), (20, 1.4), seed=32), periodic_noise((160, 90), (32, 2.2), seed=33)]
        self.wob = periodic_noise((N, 160), (2, 4), seed=34)
        self.lines = []
        for _ in range(64):
            self.lines.append(
                dict(
                    y0=rng.uniform(0.04, 0.98) * H,
                    p0=rng.random(),
                    k=int(rng.choice([1, 1, 2])),
                    length=rng.uniform(80, 240),
                    width=rng.uniform(0.8, 2.0),
                    a=rng.uniform(0.16, 0.42),
                    amp=rng.uniform(6, 26),
                    lam=rng.uniform(260, 560),
                    n=int(rng.integers(1, 3)),
                    phi=rng.uniform(0, TAU),
                )
            )
        self.motes = [(rng.uniform(0.1, 0.95) * H, rng.random(), rng.uniform(8, 30), rng.uniform(0, TAU)) for _ in range(12)]
        ys = np.linspace(0, 160, H // 4, endpoint=False, dtype=np.float32)
        xs = np.linspace(0, 90, W // 4, endpoint=False, dtype=np.float32)
        self.my, self.mx = np.meshgrid(ys, xs, indexing="ij")

    def _y(self, ln, x, t):
        return ln["y0"] + ln["amp"] * np.sin(TAU * x / ln["lam"] + TAU * ln["n"] * t + ln["phi"])

    def frame(self, i):
        t = i / N
        img = self.bg.copy()
        # Mist: scroll each tileable field by exactly k widths per loop.
        mist = np.zeros_like(self.my)
        for k, (field, strength) in enumerate(zip(self.mist, (0.07, 0.045)), start=1):
            wob = np.interp(self.my[:, 0] / 160 * 160, np.arange(160), self.wob[i])[:, None] * (2.0 if k == 1 else 1.2)
            m = wrap_sample(field, self.my + wob, self.mx + 90 * k * t)
            mist += strength * smoothstep(-1.0, 2.2, m)
        img = screen(img, rgb(120, 172, 152), up(mist))

        canvas = Supersampled()
        travel = W + 500
        for ln in self.lines:
            head = W + 250 - ((ln["p0"] + ln["k"] * t) % 1.0) * travel  # right → left
            segs = 14
            xs = head + np.linspace(ln["length"], 0, segs + 1)
            ys = self._y(ln, xs, t)
            for s in range(segs):
                fade = ((s + 1) / segs) ** 1.6  # tail thin and faint, head brighter
                canvas.line([(xs[s], ys[s]), (xs[s + 1], ys[s + 1])], ln["a"] * fade, ln["width"] * (0.5 + 0.5 * fade))
        img = screen(img, rgb(196, 226, 210), canvas.alpha(blur=0.5))

        for y0, p0, amp, phi in self.motes:
            x = W + 40 - ((p0 + t) % 1.0) * (W + 80)
            y = y0 + amp * math.sin(TAU * x / 400 + TAU * t + phi)
            gauss_blob(img, x, y, 2.2, GOLD, 0.55)
            gauss_blob(img, x, y, 7, GOLD, 0.08)
        return img


class Forest:
    """Layered pines swaying out of phase, fog between them, fireflies."""

    def __init__(self):
        rng = np.random.default_rng(41)
        self.sky = vgrad([(0, (6, 24, 22)), (0.42, (14, 48, 42)), (0.6, (10, 36, 31)), (1, (4, 14, 12))])
        glow = np.exp(-(((XX - W / 2) / 1.3) ** 2 + (YY - 0.44 * H) ** 2) / (2 * 260**2))
        self.sky += rgb(40, 92, 76) * (0.18 * glow)[..., None]
        # (base y, min h, max h, colour, sway px, count, x placement)
        specs = [
            (0.56, 0.08, 0.15, (18, 54, 46), 2.0, 22, "all"),
            (0.66, 0.13, 0.24, (12, 39, 33), 4.0, 15, "all"),
            (0.79, 0.20, 0.34, (8, 29, 25), 7.0, 10, "all"),
            (0.97, 0.36, 0.56, (3, 13, 11), 11.0, 5, "edges"),
        ]
        self.layers = []
        for li, (base, hmin, hmax, col, sway, count, place) in enumerate(specs):
            mask = self._layer(rng, base * H, hmin * H, hmax * H, count, place)
            self.layers.append((mask, rgb(*col), sway, base * H, hmax * H, li * 1.3))
        self.fog = periodic_noise((80, 45), (3, 2.5), seed=42)
        self.flies = [
            dict(
                x=rng.uniform(0.05, 0.95) * W,
                y=rng.uniform(0.44, 0.95) * H,
                ax=rng.uniform(10, 40),
                ay=rng.uniform(6, 24),
                n1=int(rng.integers(1, 3)),
                n2=int(rng.integers(1, 3)),
                m=int(rng.integers(1, 4)),
                p=rng.uniform(0, TAU, 3),
                s=rng.uniform(0.5, 1.0),
            )
            for _ in range(24)
        ]
        ys = np.arange(H // 4, dtype=np.float32)
        xs = np.arange(W // 4, dtype=np.float32)
        self.fy, self.fx = np.meshgrid(ys * 80 / (H // 4), xs * 45 / (W // 4), indexing="ij")

    def _layer(self, rng, base, hmin, hmax, count, place):
        pad = 40
        s = 2
        img = Image.new("L", ((W + 2 * pad) * s, H * s), 0)
        d = ImageDraw.Draw(img)
        ph = rng.uniform(0, TAU, 2)
        ground = [(x * s, (base + 7 * math.sin(x / 90 + ph[0]) + 4 * math.sin(x / 37 + ph[1])) * s) for x in range(0, W + 2 * pad + 8, 8)]
        d.polygon(ground + [((W + 2 * pad) * s, H * s), (0, H * s)], fill=255)
        for j in range(count):
            if place == "edges":
                x = rng.uniform(-30, 0.2 * W) if j % 2 == 0 else rng.uniform(0.8 * W, W + 30)
            else:
                x = (j + rng.uniform(0.1, 0.9)) / count * (W + 2 * pad) - pad
            h = rng.uniform(hmin, hmax)
            self._pine(d, (x + pad) * s, (base + rng.uniform(0, 12)) * s, h * s, rng)
        img = img.resize((W + 2 * pad, H), Image.BOX)
        return np.asarray(img, np.float32) / 255

    @staticmethod
    def _pine(d, x, base, h, rng):
        top = base - h
        tiers = int(rng.integers(7, 11))
        half_w = h * rng.uniform(0.17, 0.23)
        pts_l, pts_r = [(x, top)], []
        for k in range(1, tiers + 1):
            f = k / tiers
            y = top + h * 0.92 * f
            w = half_w * f ** 0.9 * rng.uniform(0.85, 1.1)
            pts_l.append((x - w, y))
            pts_l.append((x - w * 0.55, y - h * 0.012))
            pts_r.append((x + w * 0.55, y - h * 0.012))
            pts_r.append((x + w, y))
        d.polygon(pts_l + list(reversed(pts_r)), fill=255)
        d.rectangle([x - h * 0.012, base - h * 0.1, x + h * 0.012, base + 4], fill=255)

    def _draw_layer(self, img, layer, t):
        mask, col, sway, base, hmax, phase = layer
        pad = 40
        bend = np.clip((base - YY) / hmax, 0, 1) ** 2  # tops move, roots stay
        shift = sway * bend * np.sin(TAU * t + phase + TAU * 0.6 * XX / W) + sway * 0.25 * bend * np.sin(TAU * 2 * t + phase * 2)
        src = XX + pad - shift
        x0 = np.clip(np.floor(src).astype(int), 0, W + 2 * pad - 2)
        fx = np.clip(src - x0, 0, 1)
        yi = YY.astype(int)
        m = mask[yi, x0] * (1 - fx) + mask[yi, x0 + 1] * fx
        return over(img, col, m)

    def _fog(self, img, t, y_center, spread, strength, k):
        f = wrap_sample(self.fog, self.fy, self.fx + 45 * k * t)
        band = np.exp(-(((self.fy * (H / 80)) - y_center) / spread) ** 2) * smoothstep(-0.6, 1.4, f)
        return screen(img, rgb(84, 134, 116), up(band * strength))

    def _flies(self, img, t, front):
        for j, fl in enumerate(self.flies):
            if (j % 4 == 0) != front:
                continue
            x = fl["x"] + fl["ax"] * math.sin(TAU * fl["n1"] * t + fl["p"][0])
            y = fl["y"] + fl["ay"] * math.sin(TAU * fl["n2"] * t + fl["p"][1])
            b = (0.5 + 0.5 * math.sin(TAU * fl["m"] * t + fl["p"][2])) ** 2 * fl["s"]
            size = 1.4 if not front else 2.0
            gauss_blob(img, x, y, size, rgb(255, 222, 140), 0.9 * b)
            gauss_blob(img, x, y, size * 5, GOLD, 0.10 * b)

    def frame(self, i):
        t = i / N
        img = self.sky.copy()
        img = self._draw_layer(img, self.layers[0], t)
        img = self._fog(img, t, 0.565 * H, 46, 0.22, 1)
        img = self._draw_layer(img, self.layers[1], t)
        img = self._fog(img, t, 0.67 * H, 44, 0.16, 2)
        img = self._draw_layer(img, self.layers[2], t)
        img = self._fog(img, t, 0.80 * H, 40, 0.09, 1)
        self._flies(img, t, front=False)
        img = self._draw_layer(img, self.layers[3], t)
        self._flies(img, t, front=True)
        return img


class Sea:
    """Night sea: a slow swell under a low moon, glitter on the moon path."""

    HORIZON = 0.47 * H

    def __init__(self):
        rng = np.random.default_rng(51)
        self.sky = vgrad([(0, (4, 18, 20)), (0.47, (16, 54, 56)), (1, (16, 54, 56))])
        self.mx, self.my = W / 2, 0.415 * H
        r2 = (XX - self.mx) ** 2 + (YY - self.my) ** 2
        moon = rgb(244, 234, 204)
        self.sky += moon * (0.30 * np.exp(-r2 / (2 * 55**2)) + 0.10 * np.exp(-r2 / (2 * 210**2)))[..., None]
        disc = np.clip(27 - np.sqrt(r2), 0, 1)
        self.sky = over(self.sky, moon, disc * 0.95)
        self.stars = [(rng.uniform(0, W), rng.uniform(0.02, 0.36) * H, rng.uniform(0.15, 0.5), int(rng.integers(0, 4)), rng.uniform(0, TAU)) for _ in range(70)]

        # Water geometry: a pinhole camera above a flat sea.
        hy = self.HORIZON
        rows = np.arange(int(hy) + 1, H, dtype=np.float32)
        self.y0 = int(hy) + 1
        dy = rows - hy + 5.0
        f, cam = 690.0, 7.6
        self.Z = (cam * f / dy)[:, None]  # distance
        self.dZdy = (cam * f / dy**2)[:, None]
        self.X = (XX[0][None, :] - W / 2) * self.Z / f
        self.dXdx = self.Z / f
        self.dy = dy[:, None]
        # (amplitude, wavelength, angle from view axis, cycles per loop, phase)
        self.waves = [
            (0.55, 3.2, 0.10, 1, 0.0),
            (0.22, 1.5, -0.45, 2, 1.7),
            (0.14, 0.9, 0.55, 2, 4.1),
            (0.08, 0.55, -0.2, 3, 2.3),
            (0.05, 0.34, 0.8, 4, 5.0),
            (0.035, 0.22, -0.7, 5, 0.9),
        ]
        v = (rows - hy) / (H - hy)
        self.water = np.stack([np.interp(v, [0, 0.12, 1], [a, b, c]) for a, b, c in zip((22, 66, 66), (12, 44, 46), (2, 14, 14))], -1)[:, None, :] / 255
        self.path_w = 16 + 0.20 * self.dy

    def frame(self, i):
        t = i / N
        img = self.sky.copy()
        for x, y, a, m, p in self.stars:
            tw = a * (0.65 + 0.35 * math.sin(TAU * m * t + p)) if m else a
            gauss_blob(img, x, y, 0.8, rgb(220, 232, 225), tw)

        slope_z = np.zeros_like(self.Z * self.X)
        slope_x = np.zeros_like(slope_z)
        for amp, lam, ang, n, ph in self.waves:
            k = TAU / lam
            kz, kx = k * math.cos(ang), k * math.sin(ang)
            # Fade each wave out where it would alias (> ~0.25 cycles/pixel).
            freq = np.sqrt((kz * self.dZdy) ** 2 + (kx * self.dXdx) ** 2) / TAU
            aa = np.exp(-((freq / 0.22) ** 2))
            s = -amp * aa * np.sin(kx * self.X + kz * self.Z - TAU * n * t + ph)
            slope_z += s * kz
            slope_x += s * kx
        water = self.water * (1 + 0.10 * np.clip(slope_z, -2, 2))[..., None]
        # Moon path: a soft column plus glitter on facets tilted toward the moon.
        x = XX[0][None, :]
        column = np.exp(-(((x - self.mx) / self.path_w) ** 2))
        glint = smoothstep(0.55, 1.6, slope_z * 0.9 - np.abs(slope_x) * 0.35)
        near_fade = 1 - 0.55 * smoothstep(0.62 * H, 0.98 * H, self.dy + self.HORIZON)
        light = (0.10 * column * (0.6 + 0.4 * np.clip(slope_z, -1, 1)) + 0.60 * column * glint) * near_fade
        water = screen(water, rgb(232, 222, 186), light)
        img[self.y0 :] = water
        # Mist on the horizon line.
        img += rgb(34, 82, 78) * (0.35 * np.exp(-(((YY - self.HORIZON) / 9) ** 2)))[..., None]
        return img


SCENES = {"flame": Flame, "rain": Rain, "wind": Wind, "forest": Forest, "sea": Sea}
POSTER_FRAME = {"flame": 30, "rain": 40, "wind": 50, "forest": 48, "sea": 36}


def encode(name, scene):
    OUT.mkdir(parents=True, exist_ok=True)
    mp4 = OUT / f"{name}.mp4"
    cmd = [
        ffmpeg_exe(), "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "26",
        # A keyframe every 2 s: the loop point (frame N → 0) is then an
        # ordinary keyframe boundary instead of a quality jump after 8 s of
        # P-frame drift.
        "-g", str(FPS * 2), "-keyint_min", str(FPS * 2), "-sc_threshold", "0",
        "-profile:v", "high", "-level", "3.1", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", str(mp4),
    ]  # fmt: skip
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    poster = None
    for i in range(N):
        frame = np.clip(scene.frame(i) + DITHER, 0, 1)
        data = (frame * 255 + 0.5).astype(np.uint8)
        if i == POSTER_FRAME[name]:
            poster = data
        proc.stdin.write(data.tobytes())
        if i % 48 == 0:
            print(f"  {name}: frame {i}/{N}", flush=True)
    proc.stdin.close()
    if proc.wait():
        sys.exit(f"ffmpeg failed for {name}")
    Image.fromarray(poster).resize((360, 640), Image.LANCZOS).save(OUT / f"{name}.jpg", quality=80, optimize=True, progressive=True)
    print(f"{name}: {mp4.stat().st_size / 1024:.0f} KB")


def main(names):
    for name in names or SCENES:
        print(f"rendering {name}…", flush=True)
        encode(name, SCENES[name]())


if __name__ == "__main__":
    main(sys.argv[1:])
