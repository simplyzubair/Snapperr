"""Draws the Snapperr icon: four arrows pointing out from the center.

Run:  python assets/make_icon.py
Makes: assets/snapperr.ico (16-256 px) and assets/snapperr.png (512 px).
Needs: pip install pillow
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

S = 1024                      # draw big, then shrink for sharp edges
C = S / 2
TOP = (52, 211, 153)          # light emerald
BOTTOM = (4, 120, 87)         # deep green
WHITE = (255, 255, 255, 255)
OUT = Path(__file__).parent


def background():
    grad = Image.new("RGBA", (S, S))
    px = grad.load()
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * S - 2)          # diagonal blend
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)) + (255,)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle((32, 32, S - 32, S - 32), radius=230, fill=255)
    bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bg.paste(grad, (0, 0), mask)

    # soft shine on the top half
    shine = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shine).ellipse((-200, -620, S + 200, 470), fill=(255, 255, 255, 34))
    shine_mask = Image.new("L", (S, S), 0)
    shine_mask.paste(mask)
    bg.alpha_composite(Image.composite(shine, Image.new("RGBA", (S, S)), shine_mask))
    return bg


def arrows(draw):
    reach = 0.37 * S      # center to arrow tip
    head_len = 0.17 * S
    head_half = 0.13 * S
    shaft_half = 0.045 * S
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        px, py = -dy, dx                       # perpendicular
        tip = (C + dx * reach, C + dy * reach)
        base = (C + dx * (reach - head_len), C + dy * (reach - head_len))
        draw.polygon([tip,
                      (base[0] + px * head_half, base[1] + py * head_half),
                      (base[0] - px * head_half, base[1] - py * head_half)], fill=WHITE)
        end = (C + dx * (reach - head_len + 2), C + dy * (reach - head_len + 2))
        draw.polygon([(C + px * shaft_half, C + py * shaft_half),
                      (end[0] + px * shaft_half, end[1] + py * shaft_half),
                      (end[0] - px * shaft_half, end[1] - py * shaft_half),
                      (C - px * shaft_half, C - py * shaft_half)], fill=WHITE)
    r = 0.105 * S                                # center hub
    draw.ellipse((C - r, C - r, C + r, C + r), fill=WHITE)
    r2 = 0.05 * S
    draw.ellipse((C - r2, C - r2, C + r2, C + r2), fill=BOTTOM + (255,))


def main():
    icon = background()
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    arrows(ImageDraw.Draw(fg))
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow.putalpha(fg.getchannel("A").point(lambda a: a * 0.35))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    icon.alpha_composite(shadow, (0, 10))
    icon.alpha_composite(fg)

    icon.resize((512, 512), Image.LANCZOS).save(OUT / "snapperr.png")
    sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
    icon.save(OUT / "snapperr.ico", sizes=[(s, s) for s in sizes])

    # Mac icons leave empty space around the shape (about 824 of 1024 px).
    mac = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    body = round(S * 0.86)
    mac.alpha_composite(icon.resize((body, body), Image.LANCZOS), ((S - body) // 2, (S - body) // 2))
    mac.save(OUT / "snapperr.icns")
    print("Wrote snapperr.ico, snapperr.icns and snapperr.png in", OUT)


if __name__ == "__main__":
    main()
