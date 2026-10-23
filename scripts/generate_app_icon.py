#!/usr/bin/env python3
"""
Generates the native macOS squircle AppIcon.icns for Vettam.
Preserves 100% interior opacity on the squircle mask (via alpha_composite +
mask alpha merge) so macOS IconServices never places the icon inside a white
fallback border, and sharpens the 50x36 template into a crisp high-res emblem.
"""
import os
import shutil
import subprocess
from PIL import Image, ImageFilter

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

    mask = Image.open(mask_path).convert("L")
    template = Image.open(template_path).convert("RGBA")
    _, _, _, ta = template.split()

    # 1. Upscale and contour-sharpen the white Vettam emblem
    logo_h = 420
    logo_w = int(round(logo_h * (template.width / template.height)))
    up_smooth = ta.resize((logo_w, logo_h), Image.Resampling.LANCZOS).filter(
        ImageFilter.GaussianBlur(radius=2.5)
    )

    sharp_a = Image.new("L", (logo_w, logo_h))
    s_pix = up_smooth.load()
    out_pix = sharp_a.load()
    for y in range(logo_h):
        for x in range(logo_w):
            a = s_pix[x, y] / 255.0
            tail_w = 0.0
            if y > logo_h * 0.70 and x < logo_w * 0.48:
                ty = min(1.0, (y - logo_h * 0.70) / (logo_h * 0.12))
                tx = min(1.0, (logo_w * 0.48 - x) / (logo_w * 0.18))
                tail_w = ty * tx
            t_crisp = max(0.0, min(1.0, (a - 0.38) / 0.14))
            crisp = t_crisp * t_crisp * (3.0 - 2.0 * t_crisp)
            t_tail = max(0.0, min(1.0, (a - 0.06) / 0.50))
            soft = (t_tail * t_tail * (3.0 - 2.0 * t_tail)) * min(1.0, a * 1.4)
            val = crisp * (1.0 - tail_w) + soft * tail_w
            out_pix[x, y] = int(round(max(0.0, min(1.0, val)) * 255))

    # 2. Composite glowing white emblem over full-black canvas
    base = Image.new("RGBA", (1024, 1024), (0, 0, 0, 255))
    glow_a = sharp_a.filter(ImageFilter.GaussianBlur(radius=18.0)).point(
        lambda p: int(p * 0.16)
    )
    glow_layer = Image.new("RGBA", (logo_w, logo_h), (255, 255, 255, 0))
    glow_layer.putalpha(glow_a)

    white_logo = Image.new("RGBA", (logo_w, logo_h), (255, 255, 255, 0))
    white_logo.putalpha(sharp_a)

    pos_x = (1024 - logo_w) // 2 + 6
    pos_y = (1024 - logo_h) // 2 - 4

    overlay = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    overlay.alpha_composite(glow_layer, (pos_x, pos_y))
    overlay.alpha_composite(white_logo, (pos_x, pos_y))
    base = Image.alpha_composite(base, overlay)

    # Apply exact squircle alpha mask without interior holes
    r, g, b, _ = base.split()
    final_img = Image.merge("RGBA", (r, g, b, mask))

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
        resized = final_img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, filename))

    # 4. Compile to .icns using macOS iconutil
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", output_icns], check=True)
    shutil.rmtree(iconset_dir)
    print(f"Successfully generated {output_icns}")

if __name__ == "__main__":
    generate_icons()
