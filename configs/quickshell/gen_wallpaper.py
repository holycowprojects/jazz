#!/usr/bin/env python3
"""Generates JAZZ theme wallpapers: a calm neutral base (the theme's own
chrome surface color), a subtle accent-colored glow, and a restrained
abstract waveform motif nodding to "Jazz" as music - not a loud rainbow
gradient across all six workspace colors, which would read as generic/
AI-templated and contradict the project's own "calm by default" design
philosophy (Design-Vision.md sec 1).

Task 27b extension: theme-parameterized (base/accent/mode) instead of the
original Task 23 dark/light-hardcoded version. Reads design/tokens/themes.json
directly so every theme's wallpaper stays derived from its own real chrome/
accent tokens, not a copy-pasted hex.

This generator produces a placeholder wallpaper per theme - a genuinely
different composition per call (via --variant), but still procedural/
abstract. Per the wallpaper-sourcing research recorded in tasks/todo.md
(Task 27b, 8 Sept 2026), the real per-theme wallpaper SET should be
primarily curated/AI-generated art color-graded to the theme's palette
(Recraft, etc.) - this script's output is a functional fallback so the
theme system has *something* wired end-to-end, not the final asset.

Usage: python3 gen_wallpaper.py <theme-id> [--variant N] [--out PATH]
       python3 gen_wallpaper.py --all   (regenerates variant 1 for every
       theme in themes.json that has no real file yet - used to bootstrap)
"""
import argparse
import json
import math
import pathlib
import random

from PIL import Image, ImageDraw, ImageFilter

W, H = 1920, 1080
ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
THEMES_PATH = ROOT / "design/tokens/themes.json"


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def make_wallpaper(base_hex: str, accent_hex: str, mode: str, out_path: str, variant: int = 1):
    dark = (mode == "dark")
    base = hex_to_rgb(base_hex)
    accent = hex_to_rgb(accent_hex)
    glow_alpha = 70 if dark else 40

    img = Image.new("RGB", (W, H), base)

    # Variant 1: radial glow upper-left + waveform bars lower-third (Task 23's
    # original composition). Variant 2: glow lower-right + a denser, taller
    # waveform band through the vertical center - genuinely different
    # placement/density, not just a re-run of variant 1, per Task 27b's
    # "at least 2 real, genuinely different wallpaper variants" requirement.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    if variant == 1:
        cx, cy = int(W * 0.22), int(H * 0.18)
    else:
        cx, cy = int(W * 0.80), int(H * 0.82)
    max_r = int(W * 0.55)
    for r in range(max_r, 0, -6):
        a = int(glow_alpha * (1 - r / max_r) ** 2)
        if a <= 0:
            continue
        gdraw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*accent, a))
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")

    draw = ImageDraw.Draw(img, "RGBA")
    line_color = (255, 255, 255, 14) if dark else (20, 18, 22, 16)
    random.seed(42 + variant)
    bar_w = 6
    gap = 5
    if variant == 1:
        baseline = int(H * 0.78)
        x = int(W * 0.06)
        n_bars = int((W * 0.42) / (bar_w + gap))
        amp = 46
    else:
        baseline = int(H * 0.50)
        x = int(W * 0.30)
        n_bars = int((W * 0.55) / (bar_w + gap))
        amp = 90
    for i in range(n_bars):
        t = i / n_bars
        h = amp * (0.35 + 0.65 * abs(math.sin(t * math.pi * 3.1 + math.sin(t * 11) * 0.6)))
        draw.rounded_rectangle(
            [x, baseline - h, x + bar_w, baseline + h],
            radius=bar_w // 2, fill=line_color,
        )
        x += bar_w + gap

    grain = Image.effect_noise((W, H), 14).convert("L")
    grain = grain.point(lambda p: 128 + (p - 128) // 6)
    grain_rgba = Image.merge("RGBA", (grain, grain, grain, Image.new("L", (W, H), 10)))
    img = Image.alpha_composite(img.convert("RGBA"), grain_rgba).convert("RGB")

    img.save(out_path, "PNG")
    print(f"wrote {out_path} ({W}x{H})")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("theme", nargs="?", help="theme id from themes.json (e.g. midnight)")
    ap.add_argument("--variant", type=int, default=1)
    ap.add_argument("--out", default=None)
    ap.add_argument("--all", action="store_true", help="generate variant 1 for every theme's first listed wallpaper file that doesn't exist yet")
    args = ap.parse_args()

    themes = json.loads(THEMES_PATH.read_text())["themes"]

    if args.all:
        for theme_id, t in themes.items():
            for wp in t["wallpapers"]:
                out = pathlib.Path(wp["path"])
                if out.exists():
                    continue
                if "midnight" in wp["path"] or "warm" in wp["path"] or theme_id in ("midnight", "warm"):
                    make_wallpaper(t["chrome"]["surface"], t["accent"], t["mode"], str(out), variant=1)
        return

    if not args.theme:
        ap.error("theme id required unless --all is given")
    t = themes[args.theme]
    out = args.out or f"jazz-wallpaper-{args.theme}-{args.variant:02d}.png"
    make_wallpaper(t["chrome"]["surface"], t["accent"], t["mode"], out, variant=args.variant)


if __name__ == "__main__":
    main()
