#!/usr/bin/env python3
"""
Project-local compositor for LandLedger App Store screenshots.

Identical to the shared compose.py EXCEPT:
  - Does NOT paint a synthetic Dynamic Island pill.
    The simulator screenshot already contains the real pill; adding
    another one on top produced a doubled cutout in the prior output.

Do not modify the shared skill compose.py. Edit this file instead.
"""

import argparse
import sys
import os
from PIL import Image, ImageDraw, ImageFont

# ── Reference canvas (all constants tuned for this size) ────────────
REF_W = 1290
REF_H = 2796

# ── Device template constants (tuned for REF_W/REF_H) ──────────────
REF_DEVICE_W      = 1030
REF_BEZEL         = 30
REF_SCREEN_CORNER_R = 62
REF_DEVICE_Y      = 540
REF_MIN_TEXT_DEVICE_GAP = 40
REF_VERB_SIZE_MAX = 220
REF_VERB_SIZE_MIN = 130
REF_DESC_SIZE     = 105
REF_VERB_DESC_GAP = 18
REF_DESC_LINE_GAP = 20
REF_TEXT_TOP      = 150

FONT_PATH = "/Library/Fonts/SF-Pro-Display-Black.otf"


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def word_wrap(draw, text, font, max_w):
    words = text.split()
    lines, cur = [], ""
    for w in words:
        test = f"{cur} {w}".strip()
        if draw.textlength(test, font=font) <= max_w:
            cur = test
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def fit_font(text, max_w, size_max, size_min, font_path=None):
    fp = font_path or FONT_PATH
    dummy = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    for size in range(size_max, size_min - 1, -4):
        font = ImageFont.truetype(fp, size)
        bbox = dummy.textbbox((0, 0), text, font=font)
        if (bbox[2] - bbox[0]) <= max_w:
            return font
    return ImageFont.truetype(fp, size_min)


def draw_centered(draw, y, text, font, canvas_w, max_w=None, line_gap=None):
    _line_gap = line_gap if line_gap is not None else REF_DESC_LINE_GAP
    lines = word_wrap(draw, text, font, max_w) if max_w else [text]
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        h = bbox[3] - bbox[1]
        draw.text((canvas_w // 2, y - bbox[1]), line, fill="white",
                  font=font, anchor="mt")
        y += h + _line_gap
    return y


def compose(bg_hex, verb, desc, screenshot_path, output_path,
            font_path=None, canvas_w=None, canvas_h=None):
    cw = canvas_w or REF_W
    ch = canvas_h or REF_H

    sx = cw / REF_W
    sy = ch / REF_H
    s  = min(sx, sy)

    device_w  = int(REF_DEVICE_W * sx)
    bezel     = int(REF_BEZEL * sx)
    screen_w  = device_w - 2 * bezel
    corner_r  = int(REF_SCREEN_CORNER_R * sx)
    device_y  = int(REF_DEVICE_Y * sy)
    min_gap   = int(REF_MIN_TEXT_DEVICE_GAP * sy)
    verb_max  = int(REF_VERB_SIZE_MAX * s)
    verb_min  = int(REF_VERB_SIZE_MIN * s)
    desc_size = int(REF_DESC_SIZE * s)
    vd_gap    = int(REF_VERB_DESC_GAP * sy)
    line_gap  = int(REF_DESC_LINE_GAP * sy)
    text_top  = int(REF_TEXT_TOP * sy)
    max_text_w = int(cw * 0.92)

    bg = hex_to_rgb(bg_hex)
    fp = font_path or FONT_PATH

    # 1. Canvas
    canvas = Image.new("RGBA", (cw, ch), (*bg, 255))
    draw   = ImageDraw.Draw(canvas)

    # 2. Measure text height
    verb_font = fit_font(verb.upper(), max_text_w, verb_max, verb_min, fp)
    desc_font = ImageFont.truetype(fp, desc_size)

    dummy = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    m_y = 0
    m_y = draw_centered(dummy, m_y, verb.upper(), verb_font, cw, line_gap=line_gap)
    m_y += vd_gap
    text_height = draw_centered(dummy, m_y, desc.upper(), desc_font, cw,
                                max_w=max_text_w, line_gap=line_gap)

    device_y = max(device_y, text_top + text_height + min_gap)

    # 3. Draw text
    y = text_top
    y = draw_centered(draw, y, verb.upper(), verb_font, cw, line_gap=line_gap)
    y += vd_gap
    draw_centered(draw, y, desc.upper(), desc_font, cw,
                  max_w=max_text_w, line_gap=line_gap)

    device_x = (cw - device_w) // 2
    screen_x = device_x + bezel

    # 4. Load screenshot
    shot = Image.open(screenshot_path).convert("RGBA")

    bottom_pad   = int(100 * sy)
    shot_scale   = screen_w / shot.width
    shot_scaled_h = int(shot.height * shot_scale)
    shot_resized = shot.resize((screen_w, shot_scaled_h), Image.LANCZOS)

    device_h_full = bezel + shot_scaled_h + bezel
    device_h      = min(device_h_full, ch - bottom_pad - device_y)

    frame_device_y = ch - bottom_pad - device_h
    device_y = max(device_y, frame_device_y)

    screen_y = device_y + bezel
    screen_h = device_h - 2 * bezel
    shot_cropped = shot_resized.crop((0, 0, screen_w, screen_h))

    # 5. Draw device shell (black rounded rect)
    device_r   = int(corner_r * 1.6)
    dev_layer  = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    dev_mask   = Image.new("L",    canvas.size, 0)
    ImageDraw.Draw(dev_mask).rounded_rectangle(
        [device_x, device_y, device_x + device_w, device_y + device_h],
        radius=device_r, fill=255,
    )
    black_canvas = Image.new("RGBA", canvas.size, (0, 0, 0, 255))
    dev_layer = Image.composite(black_canvas, dev_layer, dev_mask)

    # 6. Paste screenshot into screen viewport
    screen_mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(screen_mask).rounded_rectangle(
        [screen_x, screen_y, screen_x + screen_w, screen_y + screen_h],
        radius=corner_r, fill=255,
    )
    dev_layer.paste(shot_cropped, (screen_x, screen_y),
                    mask=screen_mask.crop(
                        (screen_x, screen_y,
                         screen_x + screen_w, screen_y + screen_h)))
    dev_layer.putalpha(dev_mask)
    canvas = Image.alpha_composite(canvas, dev_layer)

    # ── NO synthetic Dynamic Island pill ────────────────────────────
    # The simulator screenshot already contains the real pill.
    # Painting another one here produced a doubled cutout. Omitted.

    canvas.convert("RGB").save(output_path, "PNG")
    print(f"✓ {output_path} ({cw}×{ch})")


def main():
    p = argparse.ArgumentParser(description="LandLedger local screenshot compositor")
    p.add_argument("--bg",         required=True)
    p.add_argument("--verb",       required=True)
    p.add_argument("--desc",       required=True)
    p.add_argument("--screenshot", required=True)
    p.add_argument("--output",     required=True)
    p.add_argument("--font",       default=None)
    p.add_argument("--size",       default=None)
    args = p.parse_args()

    cw, ch = None, None
    if args.size:
        cw, ch = (int(x) for x in args.size.lower().split("x"))

    compose(args.bg, args.verb, args.desc, args.screenshot, args.output,
            font_path=args.font, canvas_w=cw, canvas_h=ch)


if __name__ == "__main__":
    main()
