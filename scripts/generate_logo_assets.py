"""Generate derived display and Android icon assets from Tritium's logo."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/images/logo/icon.png"
README_OUTPUT = ROOT / "assets/images/logo/readme-icon.png"
LEGACY_OUTPUT = ROOT / "assets/images/logo/launcher-icon.png"
ICON_SIZE = 512
ANDROID_SOURCE_SIZE = 1024


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1),
        radius=radius,
        fill=255,
    )
    return mask


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    android_source = source.resize(
        (ANDROID_SOURCE_SIZE, ANDROID_SOURCE_SIZE),
        Image.Resampling.LANCZOS,
    )
    android_radius = round(ANDROID_SOURCE_SIZE * 0.225)
    android_mask = rounded_mask(ANDROID_SOURCE_SIZE, android_radius)
    legacy = Image.new("RGBA", android_source.size, (0, 0, 0, 0))
    legacy.paste(android_source, (0, 0), android_mask)
    legacy.save(LEGACY_OUTPUT)

    source = source.resize((ICON_SIZE, ICON_SIZE), Image.Resampling.LANCZOS)

    radius = round(ICON_SIZE * 0.225)
    mask = rounded_mask(ICON_SIZE, radius)
    icon = Image.new("RGBA", source.size, (0, 0, 0, 0))
    icon.paste(source, (0, 0), mask)

    shine_alpha = Image.new("L", source.size, 0)
    shine_draw = ImageDraw.Draw(shine_alpha)
    shine_height = ICON_SIZE // 3
    for y in range(shine_height):
        progress = y / shine_height
        alpha = round(58 * (1 - progress) ** 0.55)
        shine_draw.line((0, y, ICON_SIZE, y), fill=alpha)
    shine_alpha = Image.composite(shine_alpha, Image.new("L", source.size), mask)
    shine = Image.new("RGBA", source.size, (255, 255, 255, 0))
    shine.putalpha(shine_alpha)
    icon = Image.alpha_composite(icon, shine)

    padding = 30
    shadow_offset = 8
    shadow_blur = 10
    canvas_size = ICON_SIZE + padding * 2 + shadow_offset * 2
    shadow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (
            padding,
            padding + shadow_offset,
            padding + ICON_SIZE - 1,
            padding + shadow_offset + ICON_SIZE - 1,
        ),
        radius=radius + 2,
        fill=(0, 0, 0, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(shadow_blur))

    composed = Image.new("RGBA", shadow.size, (0, 0, 0, 0))
    composed.alpha_composite(shadow)
    composed.alpha_composite(icon, (padding, padding))

    bounds = composed.getbbox()
    if bounds is None:
        raise RuntimeError("Generated icon is empty")
    composed = composed.crop(bounds)

    margin = 24
    final = Image.new(
        "RGBA",
        (composed.width + margin * 2, composed.height + margin * 2),
        (0, 0, 0, 0),
    )
    final.alpha_composite(composed, (margin, margin))
    final.save(README_OUTPUT)
    print(f"Saved {README_OUTPUT} ({final.width}x{final.height})")
    print(f"Saved {LEGACY_OUTPUT} ({legacy.width}x{legacy.height})")


if __name__ == "__main__":
    main()
