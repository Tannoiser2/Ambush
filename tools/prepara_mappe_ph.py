#!/usr/bin/env python3
"""Mappe di Purple Heart nel reticolo del gioco (4200x3840, come mappa_a.jpg).
- mappa_c.jpg: mappa C intera (scansione del mod TTS).
- mappa_ad.jpg / mappa_be.jpg: mappa A (o B) del gioco con sopra, dalla riga 10 in giù,
  la mezza mappa D (o E), presa dalla scansione «Map A w/Map D» («Map B w/Map E»).
Uso: python3 tools/prepara_mappe_ph.py <mapC.jpg> <mapAD.jpg> <mapBE.jpg> <griglie.json>"""
import json, pathlib, sys
import numpy as np
from PIL import Image
R = pathlib.Path(__file__).resolve().parent.parent
SCALA = 0.6
ORIG = (307.0 * SCALA, 272.0 * SCALA)
PASSO = (270.8 * SCALA, 314.0 * SCALA)
DIM = (4200, 3840)


def porta(src, g):
    kx, ky = g["dx"] / PASSO[0], g["dy"] / PASSO[1]
    a = (kx, 0.0, g["x0"] - ORIG[0] * kx, 0.0, ky, g["y0"] - ORIG[1] * ky)
    return src.transform(DIM, Image.AFFINE, a, resample=Image.BICUBIC, fillcolor=(150, 152, 140))


def riga_per_pixel():
    """Riga (1..19) dell’esagono più vicino a ogni pixel dell’uscita."""
    ys, xs = np.mgrid[0:DIM[1], 0:DIM[0]].astype(np.float32)
    q0 = np.round((xs - ORIG[0]) / PASSO[0]).astype(int)
    best = np.full(xs.shape, 1e12, np.float32); riga = np.zeros(xs.shape, np.int16)
    for dq in (-1, 0, 1):
        q = q0 + dq
        cx = ORIG[0] + q * PASSO[0]
        off = np.where(q & 1, PASSO[1] / 2, 0)
        r0 = np.round((ys - ORIG[1] - off) / PASSO[1]).astype(int)
        for dr in (-1, 0, 1):
            r = r0 + dr
            cy = ORIG[1] + r * PASSO[1] + off
            d = (xs - cx) ** 2 + (ys - cy) ** 2
            m = d < best
            best[m] = d[m]; riga[m] = r[m] + 1
    return riga


def main():
    G = json.load(open(sys.argv[4]))
    porta(Image.open(sys.argv[1]).convert("RGB"), G["c"]).save(R / "assets/maps/mappa_c.jpg", quality=88)
    sotto = riga_per_pixel() >= 10
    for base, scan, chiave, nome in (("mappa_a.jpg", sys.argv[2], "d", "mappa_ad.jpg"), ("mappa_b.jpg", sys.argv[3], "e", "mappa_be.jpg")):
        b = np.asarray(Image.open(R / "assets/maps" / base).convert("RGB")).copy()
        m = np.asarray(porta(Image.open(scan).convert("RGB"), G[chiave]))
        b[sotto] = m[sotto]
        Image.fromarray(b).save(R / "assets/maps" / nome, quality=88)
        print("scritta", nome)


if __name__ == "__main__":
    main()
