#!/usr/bin/env python3
"""Cut the app's brand assets out of the official logo.

Everything under `assets/brand/` is derived from `logo/file-001.png` by this
script. It is committed so the assets are reproducible rather than a one-off
someone did by hand and cannot repeat — re-run it after any change to the
artwork, then regenerate the launcher icon and splash:

    python3 mobile/korkem_flow/tool/extract_brand_assets.py
    cd mobile/korkem_flow
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create
    flutter test test/goldens --update-goldens

Requires Pillow. The repository does not otherwise use Python, so this runs in
a throwaway venv rather than adding a project dependency:

    python3 -m venv /tmp/brandvenv && /tmp/brandvenv/bin/pip install Pillow
    /tmp/brandvenv/bin/python mobile/korkem_flow/tool/extract_brand_assets.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "logo" / "file-001.png"
OUT = ROOT / "mobile" / "korkem_flow" / "assets" / "brand"

# Sampled from the artwork, not chosen. The field is 97% of the image.
FIELD = (43, 56, 42)
INK = (222, 218, 208)

# Bounding boxes within the 4997x4997 source, found by scanning for ink.
# The wordmark is six glyphs; the O is the second.
RING = (1434, 2356, 1886, 2809)  # the O and its woven lattice
MARK = (1434, 2218, 1886, 2809)  # the same O, with its ornament above
LOCKUP = (876, 2074, 4121, 3039)  # rules, wordmark, SINCE 2021


def alpha_mask(image, box):
    """Recover the mark's alpha by projecting onto the field->ink axis.

    Thresholding would give a jagged edge; the source is anti-aliased against a
    known background, so how far each pixel has travelled from the field toward
    the ink *is* its coverage. That keeps the original curves intact.
    """
    axis = [INK[i] - FIELD[i] for i in range(3)]
    length_squared = sum(v * v for v in axis)

    crop = image.crop(box)
    out = Image.new("LA", crop.size)
    src, dst = crop.load(), out.load()

    for y in range(crop.size[1]):
        for x in range(crop.size[0]):
            pixel = src[x, y]
            t = sum((pixel[i] - FIELD[i]) * axis[i] for i in range(3))
            t /= length_squared
            dst[x, y] = (255, round(max(0.0, min(1.0, t)) * 255))

    return out


def centred(mask, canvas, fraction):
    """Place `mask` on a square canvas at `fraction` of its size."""
    out = Image.new("LA", (canvas, canvas), (255, 0))
    scale = (canvas * fraction) / max(mask.size)
    resized = mask.resize(
        (max(1, int(mask.width * scale)), max(1, int(mask.height * scale))),
        Image.LANCZOS,
    )
    out.paste(
        resized,
        ((canvas - resized.width) // 2, (canvas - resized.height) // 2),
        resized,
    )
    return out


def tinted(mask, rgb):
    out = Image.new("RGBA", mask.size)
    src, dst = mask.load(), out.load()
    for y in range(mask.size[1]):
        for x in range(mask.size[0]):
            dst[x, y] = rgb + (src[x, y][1],)
    return out


def main():
    logo = Image.open(SOURCE).convert("RGB")
    OUT.mkdir(parents=True, exist_ok=True)

    ring = alpha_mask(logo, RING)
    mark = alpha_mask(logo, MARK)
    lockup = alpha_mask(logo, LOCKUP)

    # In-app. Shipped as cream and re-tinted at runtime by AppLogo, so one file
    # is correct on a cream page and on a forest field.
    tinted(centred(mark, 1024, 0.88), INK).save(OUT / "korkem_mark.png")
    tinted(lockup, INK).save(OUT / "korkem_lockup.png")
    tinted(ring.resize((512, 512), Image.LANCZOS), INK).save(
        OUT / "korkem_ring.png"
    )

    # Launcher. The ring *without* the umlaut ornaments: at 48dp those become
    # specks while the ring still reads. Verified by rendering both at 192, 96
    # and 48px before choosing. 0.56 keeps it inside the 66% safe zone of the
    # adaptive icon's 108dp canvas.
    tinted(centred(ring, 1024, 0.56), INK).save(OUT / "icon_foreground.png")
    # A separate white master: the launcher recolours the monochrome layer, and
    # a cream one would be tinted twice.
    tinted(centred(ring, 1024, 0.56), (255, 255, 255)).save(
        OUT / "icon_monochrome.png"
    )

    square = Image.new("RGBA", (1024, 1024), FIELD + (255,))
    square.alpha_composite(tinted(centred(ring, 1024, 0.66), INK))
    square.convert("RGB").save(OUT / "icon_play.png")

    print(f"wrote 6 assets to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
