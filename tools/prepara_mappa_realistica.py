#!/usr/bin/env python3
"""Porta la «mappa realistica» A nello stesso reticolo della mappa originale.

Uso: python3 tools/prepara_mappa_realistica.py <pagina della mappa A, PNG a 144 dpi>
La pagina si ottiene con: pdftoppm -r 144 -png Realistic_Maps_Ambush-compressed.pdf mappa
(la mappa A è la seconda pagina). Il risultato, assets/maps/mappa_a_realistica.jpg, ha le
stesse dimensioni e gli stessi centri degli esagoni di mappa_a.jpg: il gioco può scambiarle.
"""
import pathlib, sys
from PIL import Image

RADICE = pathlib.Path(__file__).resolve().parent.parent
# Reticolo della mappa originale nella trama del gioco (vedi scripts/ui/mappa.gd).
SCALA = 0.6
ORIG = (307.0 * SCALA, 272.0 * SCALA)
PASSO = (270.8 * SCALA, 314.0 * SCALA)
DIM = (4200, 3840)
# Reticolo misurato sulla mappa realistica a 144 dpi: centri di A1 e di Y19.
R_ORIG = (141.7, 146.3)
R_PASSO = ((2526.3 - 141.7) / 24.0, (2217.7 - 146.3) / 18.0)


def main():
    src = Image.open(sys.argv[1]).convert("RGB")
    kx = R_PASSO[0] / PASSO[0]
    ky = R_PASSO[1] / PASSO[1]
    # trasformazione affine: coordinate di uscita -> coordinate della sorgente
    a = (kx, 0.0, R_ORIG[0] - ORIG[0] * kx, 0.0, ky, R_ORIG[1] - ORIG[1] * ky)
    out = src.transform(DIM, Image.AFFINE, a, resample=Image.BICUBIC, fillcolor=(58, 66, 44))
    # I margini bianchi della pagina (con i segni di taglio) diventano un bordo verde scuro.
    grigi = src.convert("L")
    w, h = src.size
    def chiara(box):
        c = grigi.crop(box)
        return sum(c.getdata()) / (c.size[0] * c.size[1]) > 235
    sx = next(x for x in range(w) if not chiara((x, h // 3, x + 1, 2 * h // 3)))
    dx = next(x for x in range(w - 1, 0, -1) if not chiara((x, h // 3, x + 1, 2 * h // 3)))
    su = next(y for y in range(h) if not chiara((w // 3, y, 2 * w // 3, y + 1)))
    giu = next(y for y in range(h - 1, 0, -1) if not chiara((w // 3, y, 2 * w // 3, y + 1)))
    from PIL import ImageDraw
    d = ImageDraw.Draw(out)
    bordi = [(sx + 2 - a[2]) / kx, (su + 2 - a[5]) / ky, (dx - 2 - a[2]) / kx, (giu - 2 - a[5]) / ky]
    colore = (58, 66, 44)
    d.rectangle((0, 0, DIM[0], max(0, bordi[1])), fill=colore)
    d.rectangle((0, min(DIM[1], bordi[3]), DIM[0], DIM[1]), fill=colore)
    d.rectangle((0, 0, max(0, bordi[0]), DIM[1]), fill=colore)
    d.rectangle((min(DIM[0], bordi[2]), 0, DIM[0], DIM[1]), fill=colore)
    out.save(RADICE / "assets" / "maps" / "mappa_a_realistica.jpg", quality=86)
    print("scritta", out.size, "fattori", round(1 / kx, 4), round(1 / ky, 4))


if __name__ == "__main__":
    main()
