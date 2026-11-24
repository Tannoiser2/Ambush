#!/usr/bin/env python3
"""Mappe di Silver Star (F intera, mezze mappe G e H) nel reticolo del gioco (4200x3840).

Nomi come nel libretto (nel salvataggio di Tabletop Simulator G e H sono scambiati):
  H = mezza mappa del lago (righe 1–9, più la riga 10 delle colonne A, C, E, …), si posa su F in alto;
  G = mezza mappa del fiume e della scarpata (il resto), si posa su F in basso.
Combinazioni usate dalle missioni: F (20, 23), F+H «fh» (19, 22), F+G «fg» (21), G+H «gh» (24).
Il terreno viene dalla classificazione per colore corretta a vista (tools/mappe_ss, tools/terreno_ss.json).
Uso: python3 tools/costruisci_mappe_ss.py [<map_F.jpg> <map_F_con_H.jpg(TTS «F w/G»)> <map_F_con_G.jpg(TTS «F w/H»)>]"""
import json, pathlib, sys
import numpy as np
from PIL import Image
R = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(R / "tools"))
from costruisci_mappe_ph import converti, finestre  # noqa: E402
COL = "ABCDEFGHIJKLMNOPQRSTUVWXY"
SCALA = 0.6
ORIG = (307.0 * SCALA, 272.0 * SCALA)
PASSO = (270.8 * SCALA, 314.0 * SCALA)
DIM = (4200, 3840)
# Reticolo misurato sulle scansioni (puntini centrali, minimi quadrati).
GRIGLIE = {
    "f": {"x0": 120.41164206776735, "dx": 110.91641365952225, "y0": 112.46404451481503, "dy": 128.7975379472664},
    "fh": {"x0": 118.7761748966599, "dx": 111.07591354681587, "y0": 110.38971154441865, "dy": 128.92873395564413},
    "fg": {"x0": 118.13558378991509, "dx": 111.07897402243356, "y0": 113.23899007446867, "dy": 128.62094925931086},
}


def in_h(h):
    c = COL.index(h[0]); r = int(h[1:])
    return r <= 9 or (r == 10 and c % 2 == 0)


def porta(src, g):
    kx, ky = g["dx"] / PASSO[0], g["dy"] / PASSO[1]
    a = (kx, 0.0, g["x0"] - ORIG[0] * kx, 0.0, ky, g["y0"] - ORIG[1] * ky)
    return src.transform(DIM, Image.AFFINE, a, resample=Image.BICUBIC, fillcolor=(150, 152, 140))


def maschera_h():
    """Pixel che appartengono a un esagono della mezza mappa H."""
    ys, xs = np.mgrid[0:DIM[1], 0:DIM[0]].astype(np.float32)
    q0 = np.round((xs - ORIG[0]) / PASSO[0]).astype(int)
    best = np.full(xs.shape, 1e12, np.float32); dentro = np.zeros(xs.shape, bool)
    for dq in (-1, 0, 1):
        q = q0 + dq
        off = np.where(q & 1, PASSO[1] / 2, 0)
        r0 = np.round((ys - ORIG[1] - off) / PASSO[1]).astype(int)
        for dr in (-1, 0, 1):
            r = r0 + dr
            d = (xs - (ORIG[0] + q * PASSO[0])) ** 2 + (ys - (ORIG[1] + r * PASSO[1] + off)) ** 2
            m = d < best
            best[m] = d[m]
            dentro[m] = ((r + 1) <= 9)[m] | (((r + 1) == 10) & (q % 2 == 0))[m]
    return dentro


def immagini(f, fh, fg):
    out = {"f": porta(Image.open(f).convert("RGB"), GRIGLIE["f"]),
           "fh": porta(Image.open(fh).convert("RGB"), GRIGLIE["fh"]),
           "fg": porta(Image.open(fg).convert("RGB"), GRIGLIE["fg"])}
    m = maschera_h()
    gh = np.asarray(out["fg"]).copy()
    gh[m] = np.asarray(out["fh"])[m]
    out["gh"] = Image.fromarray(gh)
    for k, im in out.items():
        im.save(R / "assets/maps" / f"mappa_{k}.jpg", quality=88)
        print("scritta", f"mappa_{k}.jpg")


NOTE = {"f": "Mappa F (Silver Star)", "fh": "Mappa F con mezza mappa H (Silver Star)",
        "fg": "Mappa F con mezza mappa G (Silver Star)", "gh": "Mezze mappe G e H (Silver Star)"}


def dati():
    T = json.loads((R / "tools/terreno_ss.json").read_text())
    pezzi = {k: {h: {"t": v[0], "q": v[1]} for h, v in T[k].items()} for k in ("F", "H", "G")}
    combinazioni = {
        "f": pezzi["F"],
        "fh": {**{h: v for h, v in pezzi["F"].items() if not in_h(h)}, **pezzi["H"]},
        "fg": {**{h: v for h, v in pezzi["F"].items() if in_h(h)}, **pezzi["G"]},
        "gh": {**pezzi["H"], **pezzi["G"]},
    }
    for k, es in combinazioni.items():
        es = converti(es)
        lati = {}
        finestre(es, lati, range(1, 20))
        d = {"mappa": k.upper(), "esagoni": es, "lati": lati, "alture_obiettivo": [], "note": NOTE[k]}
        (R / "data" / f"mappa_{k}.json").write_text(json.dumps(d, ensure_ascii=False, indent=0))
        print("scritta", k, len(es), len(lati))


def centro_px(h):
    c = COL.index(h[0]); r = int(h[1:])
    return ORIG[0] + c * PASSO[0], ORIG[1] + (r - 1) * PASSO[1] + (PASSO[1] / 2 if c & 1 else 0)


def vegetazione():
    """Gli alberi disegnati su queste mappe non si riconoscono per colore: bosco e macchia si riempiono
    come nell'editor delle mappe; nei massi si mettono rocce."""
    import random
    RAG = 180.5 * 0.6
    for k in ("f", "fh", "fg", "gh"):
        es = json.loads((R / "data" / f"mappa_{k}.json").read_text())["esagoni"]
        p3 = R / "data" / f"mappa_{k}_3d.json"
        d = json.loads(p3.read_text())
        alberi, cespugli, massi = [], [], []
        for h, v in sorted(es.items()):
            rng = random.Random(h + k)
            cx, cy = centro_px(h)
            t = v["t"]
            passo = {"woods": 58.0, "brush": 34.0, "boulder": 46.0}.get(t)
            if passo is None:
                continue
            y = -RAG
            while y <= RAG:
                x = -RAG
                while x <= RAG:
                    px = x + rng.uniform(-passo * 0.3, passo * 0.3); py = y + rng.uniform(-passo * 0.3, passo * 0.3)
                    if (px * px + py * py) ** 0.5 < RAG * 0.86:
                        if t == "woods":
                            alberi.append([round(cx + px, 1), round(cy + py, 1), round(rng.uniform(40, 60), 1)])
                        elif t == "brush":
                            if rng.random() < 0.75:
                                cespugli.append([round(cx + px, 1), round(cy + py, 1), round(rng.uniform(16, 28), 1)])
                        elif rng.random() < 0.6:
                            massi.append([round(cx + px, 1), round(cy + py, 1), round(rng.uniform(14, 30), 1)])
                    x += passo
                y += passo * 0.87
        d["alberi"], d["cespugli"], d["massi"] = alberi, cespugli, massi
        p3.write_text(json.dumps(d, separators=(",", ":")))
        print(k, "alberi", len(alberi), "cespugli", len(cespugli), "massi", len(massi))


if __name__ == "__main__":
    if len(sys.argv) == 4:
        immagini(*sys.argv[1:4])
    dati()
    if (R / "data/mappa_f_3d.json").exists():
        vegetazione()

