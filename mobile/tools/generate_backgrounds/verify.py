"""Checks the generated backgrounds: format, size and the loop seam.

    python tools/generate_backgrounds/verify.py [out_dir_for_contact_sheets]

For each clip prints duration, resolution, codec, pixel format, fps, audio
streams and size, then decodes it and compares the seam (last frame → first)
with an ordinary step between neighbouring frames. A seamless loop has a seam
difference in the same range as the ordinary steps. Uses ffprobe when it is
on PATH, otherwise parses `ffmpeg -i`.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

from generate import OUT, SCENES, ffmpeg_exe

MAX_SECONDS = 10
MAX_BYTES = 1.5 * 1024 * 1024


def probe(path: Path) -> dict:
    ffprobe = shutil.which("ffprobe")
    if ffprobe:
        out = subprocess.run(
            [ffprobe, "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)],
            capture_output=True, text=True, check=True,
        ).stdout  # fmt: skip
        info = json.loads(out)
        v = next(s for s in info["streams"] if s["codec_type"] == "video")
        num, den = map(int, v["r_frame_rate"].split("/"))
        return dict(
            duration=float(info["format"]["duration"]),
            width=v["width"], height=v["height"], codec=v["codec_name"],
            pix_fmt=v["pix_fmt"], fps=num / den,
            audio=sum(s["codec_type"] == "audio" for s in info["streams"]),
        )  # fmt: skip
    err = subprocess.run([ffmpeg_exe(), "-hide_banner", "-i", str(path)], capture_output=True, text=True).stderr
    d = re.search(r"Duration: (\d+):(\d+):([\d.]+)", err)
    v = re.search(r"Video: (\w+).*?, (\w+)\(.*?\), (\d+)x(\d+).*?, ([\d.]+) fps", err)
    return dict(
        duration=int(d[1]) * 3600 + int(d[2]) * 60 + float(d[3]),
        codec=v[1], pix_fmt=v[2], width=int(v[3]), height=int(v[4]), fps=float(v[5]),
        audio=len(re.findall(r"Stream #.*Audio:", err)),
    )  # fmt: skip


def decode(path: Path, w: int, h: int) -> np.ndarray:
    raw = subprocess.run(
        [ffmpeg_exe(), "-v", "error", "-i", str(path), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True, check=True,
    ).stdout  # fmt: skip
    return np.frombuffer(raw, np.uint8).reshape(-1, h, w, 3)


def main(sheet_dir: Path | None):
    ok = True
    for name in SCENES:
        mp4 = OUT / f"{name}.mp4"
        info = probe(mp4)
        size = mp4.stat().st_size
        frames = decode(mp4, info["width"], info["height"]).astype(np.float32)
        steps = np.abs(np.diff(frames, axis=0)).mean(axis=(1, 2, 3))
        seam = np.abs(frames[0] - frames[-1]).mean()
        checks = {
            "duration<=10s": info["duration"] <= MAX_SECONDS,
            "720x1280": (info["width"], info["height"]) == (720, 1280),
            "h264": info["codec"] == "h264",
            "yuv420p": info["pix_fmt"] == "yuv420p",
            "no audio": info["audio"] == 0,
            "<=1.5MB": size <= MAX_BYTES,
            "seamless": seam <= steps.max() * 1.25 + 0.05,
            "poster": (OUT / f"{name}.jpg").exists(),
        }
        ok &= all(checks.values())
        print(
            f"{name:7s} {info['duration']:.2f}s {info['width']}x{info['height']} {info['codec']} {info['pix_fmt']} "
            f"{info['fps']:.0f}fps audio={info['audio']} {size / 1024:.0f}KB | seam {seam:.3f} vs steps "
            f"{steps.mean():.3f} (max {steps.max():.3f}) | "
            + ", ".join(k for k, v in checks.items() if not v or k == "seamless")
            + (" FAIL" if not all(checks.values()) else " ok")
        )
        if sheet_dir:
            # Last two frames, then the first two: the seam sits in the middle.
            picks = [len(frames) - 2, len(frames) - 1, 0, 1, len(frames) // 3, 2 * len(frames) // 3]
            tiles = [Image.fromarray(frames[i].astype(np.uint8)).resize((240, 427)) for i in picks]
            sheet = Image.new("RGB", (240 * len(tiles) + 8 * (len(tiles) - 1), 427), (255, 255, 255))
            for k, tile in enumerate(tiles):
                sheet.paste(tile, (k * 248, 0))
            sheet_dir.mkdir(parents=True, exist_ok=True)
            sheet.save(sheet_dir / f"{name}_loop.png")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else None)
