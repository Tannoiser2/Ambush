#!/usr/bin/env python3
"""Ritaglia le pedine della versione ridisegnata dai fogli «Ambush Counters» (0,63" e 0,50").

Uso: python3 tools/estrai_pedine_nuove.py <fronte 0.63> <retro 0.63> <fronte 0.50> <retro 0.50>
Scrive in assets/pedine_nuove/ con gli stessi nomi di assets/pedine/, così l’interfaccia
può scegliere una serie o l’altra. Fronte 0,63": soldati in piedi; retro: accovacciati.
"""
import pathlib, sys
from PIL import Image

RADICE = pathlib.Path(__file__).resolve().parent.parent
USCITA = RADICE / "assets" / "pedine_nuove"


def cella63(im, riga, col):
    x = 178 + 221.9 * col
    y = 229 + 223.75 * riga
    return im.crop((round(x + 5), round(y + 5), round(x + 185), round(y + 185)))


def cella50(im, riga, col):
    x = 185 + 184.45 * col
    y = 174.5 + 174.9 * riga
    return im.crop((round(x + 3), round(y + 3), round(x + 148), round(y + 148)))


def salva(img, nome):
    img.convert("RGBA").resize((128, 128), Image.LANCZOS).save(USCITA / (nome + ".png"))


def main():
    f63, r63, f50, r50 = [Image.open(p).convert("RGB") for p in sys.argv[1:5]]
    USCITA.mkdir(parents=True, exist_ok=True)
    # soldati in piedi (fronte)
    for i, l in enumerate("ABCDEFGHJ"):
        salva(cella63(f63, 8, 1 + i), "us_" + l)
    salva(cella63(f63, 9, 0), "us_K")
    for i, l in enumerate("LMNPQRS"):
        salva(cella63(f63, 9, 3 + i), "ge_" + l)
    for i, l in enumerate("TUVWX"):
        salva(cella63(f63, 10, i), "ge_" + l)
    # soldati accovacciati (retro, speculare)
    for i, l in enumerate("JHGFEDCBA"):
        salva(cella63(r63, 8, i), "us_" + l + "_acc")
    salva(cella63(r63, 9, 9), "us_K_acc")
    for i, l in enumerate("SRQPNML"):
        salva(cella63(r63, 9, i), "ge_" + l + "_acc")
    for i, l in enumerate("XWVUT"):
        salva(cella63(r63, 10, 5 + i), "ge_" + l + "_acc")
    # segnalini
    salva(cella63(f63, 0, 0), "evento")
    salva(cella63(f63, 3, 0), "campo_minato")
    salva(cella63(f63, 5, 5), "cratere")
    salva(cella63(f63, 5, 0), "typhoon")
    salva(cella63(r63, 5, 0), "macerie")
    salva(cella50(f50, 4, 0), "prono_us")
    salva(cella50(r50, 4, 0), "prono_de")
    salva(cella50(f50, 4, 0), "prono")
    salva(cella50(f50, 7, 0), "ferito")
    salva(cella50(r50, 7, 0), "incapacitato")
    salva(cella50(f50, 8, 1), "ucciso")
    salva(cella50(r50, 8, 2), "prigioniero")
    print("pedine scritte:", len(list(USCITA.glob("*.png"))))


if __name__ == "__main__":
    main()
