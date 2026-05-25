"""Generate app logo untuk Mewarnai. Output PNG 1024 & 512."""
import math
from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
OUT_DIR = r"c:\data_dave\work\alone\david\game\mewarnai\godot\images"


def rounded_bg(size, radius, color):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=color)
    return img


def star(d, cx, cy, r, color, rot=-math.pi / 2):
    pts = []
    for i in range(10):
        ang = rot + math.pi * i / 5
        rad = r if i % 2 == 0 else r * 0.45
        pts.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
    d.polygon(pts, fill=color)


def make_crayon(body_color, tip_color, band_color):
    w, h, tip = 230, 660, 150
    layer = Image.new("RGBA", (w, h + 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # badan
    d.rounded_rectangle([0, tip, w, h], radius=28, fill=body_color)
    # ujung
    d.polygon([(w / 2, 0), (0, tip), (w, tip)], fill=tip_color)
    # ujung kecil (lilin)
    d.polygon([(w / 2, 30), (w * 0.36, tip), (w * 0.64, tip)], fill=(255, 255, 255, 120))
    # garis pembungkus
    d.rectangle([0, tip + 60, w, tip + 70], fill=band_color)
    d.rectangle([0, tip + 110, w, tip + 120], fill=band_color)
    return layer


def main():
    bg = rounded_bg(SIZE, 200, (255, 227, 163, 255))
    d = ImageDraw.Draw(bg)

    # lingkaran aksen lembut
    d.ellipse([130, 130, SIZE - 130, SIZE - 130], fill=(255, 240, 205, 255))

    # percikan bintang & titik warna
    star(d, 250, 250, 70, (255, 209, 102, 255))
    star(d, 800, 320, 50, (118, 200, 147, 255))
    d.ellipse([760, 720, 850, 810], fill=(108, 180, 255, 255))
    d.ellipse([210, 740, 280, 810], fill=(236, 100, 150, 255))
    star(d, 840, 640, 38, (171, 130, 220, 255))

    # krayon utama (merah) miring
    cr1 = make_crayon((232, 76, 76, 255), (200, 55, 55, 255), (150, 40, 40, 255))
    cr1 = cr1.rotate(35, expand=True, resample=Image.BICUBIC)
    bg.alpha_composite(cr1, (SIZE // 2 - cr1.width // 2 - 60, SIZE // 2 - cr1.height // 2))

    # krayon kedua (biru) miring berlawanan, di belakang sedikit
    cr2 = make_crayon((77, 150, 255, 255), (55, 120, 220, 255), (40, 90, 170, 255))
    cr2 = cr2.rotate(-30, expand=True, resample=Image.BICUBIC)
    bg.alpha_composite(cr2, (SIZE // 2 - cr2.width // 2 + 120, SIZE // 2 - cr2.height // 2 + 40))

    bg.save(f"{OUT_DIR}\\logo_1024.png")
    bg.resize((512, 512), Image.LANCZOS).save(f"{OUT_DIR}\\logo_512.png")
    # icon Godot
    bg.resize((256, 256), Image.LANCZOS).save(f"{OUT_DIR}\\icon.png")

    make_feature(bg)
    print("Logo dibuat: logo_1024.png, logo_512.png, icon.png, feature_1024x500.png")


def _font(size):
    for name in ["arialbd.ttf", "segoeuib.ttf", "ariblk.ttf", "arial.ttf"]:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def make_feature(logo):
    W, H = 1024, 500
    img = Image.new("RGBA", (W, H), (255, 227, 163, 255))
    d = ImageDraw.Draw(img)

    # aksen
    d.ellipse([-120, -120, 260, 260], fill=(255, 240, 205, 255))
    d.ellipse([W - 200, H - 200, W + 120, H + 120], fill=(255, 240, 205, 255))
    star(d, 560, 90, 34, (255, 209, 102, 255))
    star(d, 980, 120, 26, (118, 200, 147, 255))
    d.ellipse([600, 400, 650, 450], fill=(236, 100, 150, 255))

    # logo di kiri
    badge = logo.resize((360, 360), Image.LANCZOS)
    img.alpha_composite(badge, (40, 70))

    # judul + tagline
    title_font = _font(120)
    sub_font = _font(46)
    tx = 440
    d.text((tx, 150), "Mewarnai", font=title_font, fill=(232, 90, 90, 255))
    d.text((tx, 290), "Ubah foto jadi", font=sub_font, fill=(90, 80, 90, 255))
    d.text((tx, 345), "gambar mewarnai!", font=sub_font, fill=(90, 80, 90, 255))

    img.convert("RGB").save(f"{OUT_DIR}\\feature_1024x500.png")


if __name__ == "__main__":
    main()
