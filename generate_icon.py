#!/usr/bin/env python3
"""
Generate macOS app icon PNGs for ClaudeDashboard at all required sizes.
Uses Pillow to draw the icon programmatically.
"""

import math
import os
from PIL import Image, ImageDraw, ImageFilter

# Output directory
APPICONSET_DIR = (
    "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard/"
    "ClaudeDashboard/Resources/Assets.xcassets/AppIcon.appiconset"
)
os.makedirs(APPICONSET_DIR, exist_ok=True)

# Required icon sizes
SIZES = [16, 32, 64, 128, 256, 512, 1024]


def lerp_color(c1, c2, t):
    """Linearly interpolate between two RGB tuples."""
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def draw_rounded_rect(draw, x0, y0, x1, y1, radius, fill):
    """Draw a filled rounded rectangle."""
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill)


def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def generate_icon(size):
    """Generate the icon at the given pixel size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    s = size  # shorthand

    # --- Background ---
    corner_radius = int(s * 0.215)  # macOS icon corner radius ~22%
    # Draw gradient background manually (top-left dark navy → bottom-right near-black)
    bg = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)

    color_tl = hex_to_rgb("#1A1F2E")
    color_br = hex_to_rgb("#0D1117")

    # Fill gradient row by row (good enough approximation)
    for y in range(s):
        t = y / s
        c = lerp_color(color_tl, color_br, t)
        bg_draw.line([(0, y), (s, y)], fill=c + (255,))

    # Clip to rounded rect
    mask = Image.new("L", (s, s), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, s - 1, s - 1], radius=corner_radius, fill=255)
    img.paste(bg, (0, 0), mask)

    # --- Bar chart setup ---
    # Bars: 5 bars, centered horizontally
    # Baseline at 70% of height
    baseline_y = int(s * 0.703)
    bar_width = int(s * 0.078)
    bar_gap = int(s * 0.039)
    total_bars_width = 5 * bar_width + 4 * bar_gap
    start_x = (s - total_bars_width) // 2

    # Heights as fraction of icon height (from baseline upward)
    bar_heights_frac = [0.215, 0.322, 0.420, 0.273, 0.176]

    # Amber gradient colors
    bar_colors_top = [
        hex_to_rgb("#FCD34D"),  # bar 1
        hex_to_rgb("#F59E0B"),  # bar 2
        hex_to_rgb("#FBBF24"),  # bar 3 (tallest)
        hex_to_rgb("#D97706"),  # bar 4
        hex_to_rgb("#F59E0B"),  # bar 5
    ]
    bar_colors_bot = [
        hex_to_rgb("#B45309"),
        hex_to_rgb("#92400E"),
        hex_to_rgb("#B45309"),
        hex_to_rgb("#78350F"),
        hex_to_rgb("#B45309"),
    ]

    # Draw ambient glow behind bars (soft blurred rectangle)
    glow_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    gx0 = int(s * 0.27)
    gx1 = int(s * 0.73)
    gy0 = int(s * 0.29)
    gy1 = int(s * 0.72)
    glow_draw.rounded_rectangle(
        [gx0, gy0, gx1, gy1],
        radius=int(s * 0.06),
        fill=hex_to_rgb("#D97706") + (80,)
    )
    blur_radius = max(1, int(s * 0.055))
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    # Clip glow to rounded mask
    glow_clipped = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    glow_clipped.paste(glow_layer, (0, 0), mask)
    img = Image.alpha_composite(img, glow_clipped)
    draw = ImageDraw.Draw(img)

    # Draw each bar with vertical gradient
    bar_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    for i in range(5):
        bar_h = int(s * bar_heights_frac[i])
        bx0 = start_x + i * (bar_width + bar_gap)
        bx1 = bx0 + bar_width
        by0 = baseline_y - bar_h
        by1 = baseline_y

        bar_r = max(2, int(bar_width * 0.15))  # corner radius for bar

        # Draw gradient bar pixel-by-pixel (vertical)
        bar_img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        bar_draw = ImageDraw.Draw(bar_img)

        # Fill bar with gradient using horizontal slices
        for row in range(by0, by1 + 1):
            t = 1.0 - (row - by0) / max(bar_h, 1)  # 1.0 at top, 0.0 at bottom
            c = lerp_color(bar_colors_bot[i], bar_colors_top[i], t)
            bar_draw.line([(bx0, row), (bx1, row)], fill=c + (255,))

        # Create mask for rounded bar shape
        bar_mask = Image.new("L", (s, s), 0)
        bar_mask_draw = ImageDraw.Draw(bar_mask)
        bar_mask_draw.rounded_rectangle([bx0, by0, bx1, by1], radius=bar_r, fill=255)

        # Apply bar mask
        bar_final = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        bar_final.paste(bar_img, (0, 0), bar_mask)
        bar_layer = Image.alpha_composite(bar_layer, bar_final)

    # Add bar glow: blur the bar layer and composite under+over
    bar_glow = bar_layer.copy().filter(ImageFilter.GaussianBlur(radius=max(1, int(s * 0.018))))
    # Clip to rounded icon
    bar_glow_clipped = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bar_glow_clipped.paste(bar_glow, (0, 0), mask)
    img = Image.alpha_composite(img, bar_glow_clipped)

    # Clip bar_layer to icon shape
    bar_clipped = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bar_clipped.paste(bar_layer, (0, 0), mask)
    img = Image.alpha_composite(img, bar_clipped)

    draw = ImageDraw.Draw(img)

    # --- Baseline rule ---
    lw = max(1, int(s * 0.004))
    bline_x0 = int(s * 0.207)
    bline_x1 = int(s * 0.793)
    draw.line(
        [(bline_x0, baseline_y), (bline_x1, baseline_y)],
        fill=hex_to_rgb("#D97706") + (110,),
        width=lw
    )

    # --- Sparkle / asterisk (Claude-inspired) above tallest bar (bar index 2) ---
    # Tallest bar center x
    tallest_bar_cx = start_x + 2 * (bar_width + bar_gap) + bar_width // 2
    tallest_bar_top = baseline_y - int(s * bar_heights_frac[2])
    sparkle_y = tallest_bar_top - int(s * 0.075)
    sparkle_cx = tallest_bar_cx

    # Draw sparkle glow (soft blurred circle)
    sparkle_glow_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sparkle_glow_draw = ImageDraw.Draw(sparkle_glow_layer)
    gr = int(s * 0.07)
    sparkle_glow_draw.ellipse(
        [sparkle_cx - gr, sparkle_y - gr, sparkle_cx + gr, sparkle_y + gr],
        fill=hex_to_rgb("#F59E0B") + (90,)
    )
    sparkle_glow_layer = sparkle_glow_layer.filter(
        ImageFilter.GaussianBlur(radius=max(1, int(s * 0.035)))
    )
    sparkle_glow_clipped = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sparkle_glow_clipped.paste(sparkle_glow_layer, (0, 0), mask)
    img = Image.alpha_composite(img, sparkle_glow_clipped)

    draw = ImageDraw.Draw(img)

    # Draw 6-ray asterisk using lines
    ray_len = max(2, int(s * 0.048))
    ray_width = max(1, int(s * 0.010))
    angles_deg = [0, 60, 120]  # three lines through center = 6 rays
    sparkle_color = hex_to_rgb("#FCD34D") + (240,)

    for ang_d in angles_deg:
        ang_r = math.radians(ang_d)
        dx = ray_len * math.cos(ang_r)
        dy = ray_len * math.sin(ang_r)
        draw.line(
            [
                (int(sparkle_cx - dx), int(sparkle_y - dy)),
                (int(sparkle_cx + dx), int(sparkle_y + dy)),
            ],
            fill=sparkle_color,
            width=ray_width,
        )

    # Center dot of sparkle
    dot_r = max(1, int(s * 0.008))
    draw.ellipse(
        [
            sparkle_cx - dot_r,
            sparkle_y - dot_r,
            sparkle_cx + dot_r,
            sparkle_y + dot_r,
        ],
        fill=sparkle_color,
    )

    # Clip final image to rounded rect again to be safe
    final = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    final.paste(img, (0, 0), mask)

    return final


def main():
    print("Generating icons...")
    for size in SIZES:
        icon = generate_icon(size)
        # Save with proper naming
        if size == 1024:
            filename = "AppIcon-1024.png"
        else:
            filename = f"AppIcon-{size}.png"
        path = os.path.join(APPICONSET_DIR, filename)
        icon.save(path, "PNG")
        print(f"  Saved {size}x{size} → {filename}")

    print(f"\nAll icons saved to:\n  {APPICONSET_DIR}")


if __name__ == "__main__":
    main()
