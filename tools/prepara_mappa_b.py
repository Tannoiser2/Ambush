#!/usr/bin/env python3
"""Porta la scansione della mappa B nello stesso reticolo della trama del gioco (come mappa_a.jpg).
Uso: python3 tools/prepara_mappa_b.py <map_b.jpg> [realistica.png A1x A1y Y19x Y19y]"""
import pathlib, sys
from PIL import Image
RADICE = pathlib.Path(__file__).resolve().parent.parent
SCALA = 0.6
ORIG = (307.0 * SCALA, 272.0 * SCALA)
PASSO = (270.8 * SCALA, 314.0 * SCALA)
DIM = (4200, 3840)

def porta(src, a1, y19, uscita):
    passo = ((y19[0] - a1[0]) / 24.0, (y19[1] - a1[1]) / 18.0)
    kx, ky = passo[0] / PASSO[0], passo[1] / PASSO[1]
    a = (kx, 0.0, a1[0] - ORIG[0] * kx, 0.0, ky, a1[1] - ORIG[1] * ky)
    out = src.transform(DIM, Image.AFFINE, a, resample=Image.BICUBIC, fillcolor=(150, 152, 140))
    out.save(uscita, quality=88)

if __name__ == "__main__":
    # Reticolo misurato sulla scansione (puntini centrali, minimi quadrati): A1 e Y19.
    x0, dx, y0, dy = 302.98, 267.716, 275.227, 314.073
    porta(Image.open(sys.argv[1]).convert("RGB"), (x0, y0), (x0 + 24 * dx, y0 + 18 * dy), RADICE / "assets/maps/mappa_b.jpg")
    if len(sys.argv) > 2:
        porta(Image.open(sys.argv[2]).convert("RGB"), (float(sys.argv[3]), float(sys.argv[4])),
              (float(sys.argv[5]), float(sys.argv[6])), RADICE / "assets/maps/mappa_b_realistica.jpg")
