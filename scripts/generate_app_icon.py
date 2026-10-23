#!/usr/bin/env python3
"""
Generates the native macOS squircle AppIcon.icns for Vettam.
Complies with Apple macOS Human Interface Guidelines (transparent padding
outside an ~824x824 squircle centered in 1024x1024 canvas), preventing macOS
from rendering a fallback white backing tile/border around the app icon.
"""
import os
import shutil
import subprocess
from PIL import Image

def generate_icons():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    resources_dir = os.path.join(root, "resources")
    mask_path = os.path.join(resources_dir, "squircle_mask.png")
    template_path = os.path.join(resources_dir, "vettam_template@2x.png")
    output_icns = os.path.join(resources_dir, "AppIcon.icns")
    iconset_dir = os.path.join(root, "AppIcon.iconset")

    if not os.path.exists(mask_path):
        raise FileNotFoundError(f"Missing mask: {mask_path}")
    if not os.path.exists(template_path):
        raise FileNotFoundError(f"Missing template: {template_path}")

    # 1. Base 1024x1024 canvas with transparent background
    mask = Image.open(mask_path).convert("L")
    base = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    black_fill = Image.new("RGB", (1024, 1024), (0, 0, 0))
    base.paste(black_fill, (0, 0), mask)

    # 2. Scale and position white radiant logo
    template = Image.open(template_path).convert("RGBA")
    logo_h = 480
    ratio = template.width / template.height
    logo_w = int(logo_h * ratio)
    logo_resized = template.resize((logo_w, logo_h), Image.Resampling.LANCZOS)

    # Recolor alpha template to solid white
    white_logo = Image.new("RGBA", (logo_w, logo_h), (0, 0, 0, 0))
    t_pix = logo_resized.load()
    w_pix = white_logo.load()
    for y in range(logo_h):
        for x in range(logo_w):
            r, g, b, a = t_pix[x, y]
            if a > 0:
                w_pix[x, y] = (255, 255, 255, a)

    pos_x = (1024 - logo_w) // 2
    pos_y = (1024 - logo_h) // 2 - 6 # optically centered vertically in squircle
    base.paste(white_logo, (pos_x, pos_y), white_logo)

    # 3. Create iconset directory and sizes
    os.makedirs(iconset_dir, exist_ok=True)
    icon_sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png")
    ]

    for size, filename in icon_sizes:
        resized = base.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, filename))

    # 4. Compile to .icns using macOS iconutil
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", output_icns], check=True)
    shutil.rmtree(iconset_dir)
    print(f"Successfully generated {output_icns}")

if __name__ == "__main__":
    generate_icons()
