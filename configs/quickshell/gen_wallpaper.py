#!/usr/bin/env python3
"""Generates JAZZ's dark and light wallpapers: a calm neutral base, a subtle
Forge-blue glow (Forge is the default/highest-traffic workspace per
Design-Vision.md), and a restrained abstract waveform motif nodding to
"Jazz" as music - not a loud rainbow gradient across all six workspace
colors, which would read as generic/AI-templated and contradict the
project's own "calm by default" design philosophy.
"""
import math
import random
from PIL import Image, ImageDraw, ImageFilter

W, H = 1920, 1080
FORGE = (76, 111, 160)      # #4c6fa0

def make_wallpaper(dark: bool, out_path: str):
    base = (20, 19, 24) if dark else (233, 234, 236)   # near panel_dark / panel_light
    glow_alpha = 70 if dark else 40

    img = Image.new("RGB", (W, H), base)

    # Subtle radial glow, upper-left, Forge blue - the "default workspace" cue
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    cx, cy = int(W * 0.22), int(H * 0.18)
    max_r = int(W * 0.55)
    for r in range(max_r, 0, -6):
        a = int(glow_alpha * (1 - r / max_r) ** 2)
        if a <= 0:
            continue
        gdraw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*FORGE, a))
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")

    # Restrained waveform motif, lower third - horizontal bars of varying
    # height like an audio waveform, faint, evoking "Jazz" without shouting it
    draw = ImageDraw.Draw(img, "RGBA")
    line_color = (255, 255, 255, 14) if dark else (20, 18, 22, 16)
    random.seed(42)
    bar_w = 6
    gap = 5
    baseline = int(H * 0.78)
    x = int(W * 0.06)
    n_bars = int((W * 0.42) / (bar_w + gap))
    amp = 46
    for i in range(n_bars):
        # smooth pseudo-random envelope so it reads as a waveform, not noise
        t = i / n_bars
        h = amp * (0.35 + 0.65 * abs(math.sin(t * math.pi * 3.1 + math.sin(t * 11) * 0.6)))
        draw.rounded_rectangle(
            [x, baseline - h, x + bar_w, baseline + h],
            radius=bar_w // 2, fill=line_color,
        )
        x += bar_w + gap

    # Fine film-grain for depth (avoids a flat, "vector gradient" AI look)
    grain = Image.effect_noise((W, H), 14).convert("L")
    grain = grain.point(lambda p: 128 + (p - 128) // 6)
    grain_rgba = Image.merge("RGBA", (grain, grain, grain, Image.new("L", (W, H), 10)))
    img = Image.alpha_composite(img.convert("RGBA"), grain_rgba).convert("RGB")

    img.save(out_path, "PNG")
    print(f"wrote {out_path} ({W}x{H})")

if __name__ == "__main__":
    make_wallpaper(dark=True, out_path="jazz-wallpaper-dark.png")
    make_wallpaper(dark=False, out_path="jazz-wallpaper-light.png")
