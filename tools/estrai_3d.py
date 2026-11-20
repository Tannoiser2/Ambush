#!/usr/bin/env python3
"""Estrae dalla mappa disegnata gli elementi per la vista 3D.

Per ogni mappa (A, B) legge assets/maps/mappa_X.jpg e scrive:
  data/mappa_X_3d.json   alberi, cespugli, ciuffi d'erba, muri degli edifici (poligoni)
  assets/maps/mappa_X_maschere.png   R = acqua del fiume, G = macchie di copertura
Tutte le coordinate sono in pixel dell'immagine (lo spazio «tex» della mappa 2D).
Uso: python3 tools/estrai_3d.py
"""
import json, os
import numpy as np, cv2
from scipy.spatial import cKDTree
from skimage.feature import peak_local_max

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCALA = 1.0  # le coordinate escono in pixel dell'immagine
ORIG = np.array([307.0, 272.0]) * 0.6
PASSO = np.array([270.8, 314.0]) * 0.6
RAGGIO = 180.5 * 0.6
COLONNE, RIGHE = 25, 19
rng = np.random.default_rng(1983)


def centro(col, rig):
    return ORIG + np.array([col * PASSO[0], (rig - 1) * PASSO[1] + (col & 1) * PASSO[1] / 2])


def disco(r):
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))


def mappa_esagoni(shape, fattore):
    """Per ogni pixel (a risoluzione ridotta) l'indice dell'esagono, -1 fuori mappa."""
    ids, centri = [], []
    for c in range(COLONNE):
        for r in range(1, RIGHE + 1):
            ids.append("%s%d" % (chr(65 + c), r))
            centri.append(centro(c, r))
    albero = cKDTree(np.array(centri))
    h, w = shape
    ys, xs = np.mgrid[0:h, 0:w]
    pts = np.stack([xs.ravel(), ys.ravel()], 1) * fattore
    d, i = albero.query(pts)
    i[d > RAGGIO * 1.02] = -1
    return ids, i.reshape(h, w)


def estrai(lettera):
    img = cv2.imread(os.path.join(RADICE, "assets/maps/mappa_%s.jpg" % lettera))
    dati = json.load(open(os.path.join(RADICE, "data/mappa_%s.json" % lettera)))
    tipi = {h: v.get("t", "clear") for h, v in dati["esagoni"].items()}
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.float32)
    H, S, V = hsv[..., 0] * 2, hsv[..., 1] / 255, hsv[..., 2] / 255
    fiume = ((H >= 185) & (H <= 205) & (S > 0.45) & (V > 0.75)).astype(np.uint8)
    azzurro = ((H >= 175) & (H <= 200) & (S > 0.18) & (S <= 0.45) & (V > 0.6)).astype(np.uint8)
    legno = ((H >= 20) & (H <= 40) & (S > 0.33) & (V > 0.6) & (V < 0.9)).astype(np.uint8)
    verde = ((H >= 120) & (H <= 175) & (S > 0.3) & (V > 0.35)).astype(np.uint8)
    oliva = ((H >= 55) & (H <= 100) & (S > 0.3) & (V > 0.4)).astype(np.uint8)
    copertura = ((H >= 40) & (H <= 80) & (S > 0.18) & (S <= 0.42) & (V > 0.45) & (V < 0.9)).astype(np.uint8)

    # --- esagoni a risoluzione piena per i muri, ridotta per il resto
    ids, idx = mappa_esagoni(img.shape[:2], 1.0)
    edifici = np.zeros(img.shape[:2], np.uint8)
    for k, h in enumerate(ids):
        if tipi.get(h, "") in ("stone_building", "wood_building"):
            edifici[idx == k] = 1
    edifici = cv2.dilate(edifici, disco(30))

    muri = []
    for nome, m in (("pietra", azzurro), ("legno", legno)):
        m = m & edifici
        m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, disco(2))
        largo = cv2.morphologyEx(m, cv2.MORPH_OPEN, disco(17))  # strade e sterrati: più larghi dei muri
        m = m & (1 - cv2.dilate(largo, disco(4)))
        m = cv2.morphologyEx(m, cv2.MORPH_OPEN, disco(3))
        cont, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for c in cont:
            if cv2.contourArea(c) < 300:
                continue
            ap = cv2.approxPolyDP(c, 3.0, True).reshape(-1, 2)
            if len(ap) < 3:
                continue
            muri.append({"tipo": nome, "poly": [[round(float(x) * SCALA, 1), round(float(y) * SCALA, 1)] for x, y in ap]})

    meta = lambda m: cv2.resize(m, (img.shape[1] // 2, img.shape[0] // 2), interpolation=cv2.INTER_AREA)

    def semina(densita, soglia, passo, raggio_fn, massimo=4000):
        """Punti dove la densità del disegno supera la soglia, tenuti a distanza «passo» (metà risoluzione)."""
        ys, xs = np.nonzero(densita > soglia)
        if len(xs) == 0:
            return []
        ordine = rng.permutation(len(xs))
        griglia = {}
        presi = []
        for j in ordine:
            x, y = int(xs[j]), int(ys[j])
            gx, gy = x // passo, y // passo
            vicino = False
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for (px, py) in griglia.get((gx + dx, gy + dy), ()):
                        if (px - x) ** 2 + (py - y) ** 2 < passo * passo:
                            vicino = True
                            break
            if vicino:
                continue
            griglia.setdefault((gx, gy), []).append((x, y))
            presi.append((x, y))
            if len(presi) >= massimo:
                break
        return [[float(x) * 2, float(y) * 2, raggio_fn(densita[y, x])] for x, y in presi]

    # --- alberi: dove il disegno ha chiome verdi fitte
    dverde = cv2.GaussianBlur(meta(verde).astype(np.float32), (0, 0), 9)
    alberi = semina(dverde, 0.16, 26, lambda d: round(38 + 30 * min(1.0, float(d) * 1.6), 1))
    # --- copertura: macchie piene grigio-oliva (riempimento uniforme, non puntinato)
    piena = cv2.GaussianBlur(meta(copertura).astype(np.float32), (0, 0), 10)
    c2 = ((piena > 0.62) & (meta(copertura) > 0)).astype(np.uint8)
    c2 = cv2.morphologyEx(c2, cv2.MORPH_CLOSE, disco(5))
    # --- cespugli: macchie verde oliva sparse (non le macchie piene di copertura)
    doliva = cv2.GaussianBlur((meta(oliva) & (1 - cv2.dilate(c2, disco(6)))).astype(np.float32), (0, 0), 6)
    doliva[dverde > 0.16] = 0
    cespugli = semina(doliva, 0.12, 14, lambda d: round(16 + 14 * min(1.0, float(d) * 2.0), 1))
    ys, xs = np.nonzero(c2)
    ciuffi = []
    if len(xs):
        scelti = rng.choice(len(xs), size=min(len(xs), len(xs) // 180 + 1), replace=False)
        ciuffi = [[float(xs[j]) * 2, float(ys[j]) * 2] for j in scelti]

    # --- maschere per il rilievo: R acqua, G copertura (1/6 della risoluzione, sfumate)
    dim = (img.shape[1] // 6, img.shape[0] // 6)
    acqua = cv2.resize(cv2.morphologyEx(fiume, cv2.MORPH_CLOSE, disco(4)) * 255, dim, interpolation=cv2.INTER_AREA)
    cop = cv2.resize(c2 * 255, dim, interpolation=cv2.INTER_AREA)
    acqua = cv2.GaussianBlur(acqua, (5, 5), 0)
    cop = cv2.GaussianBlur(cop, (5, 5), 0)
    out = np.dstack([np.zeros_like(acqua), cop, acqua])  # BGR
    cv2.imwrite(os.path.join(RADICE, "assets/maps/mappa_%s_maschere.png" % lettera), out)

    ris = {"mappa": lettera.upper(), "nota": "Generato da tools/estrai_3d.py: coordinate in pixel della mappa.",
           "alberi": alberi, "cespugli": cespugli, "ciuffi": ciuffi, "muri": muri}
    json.dump(ris, open(os.path.join(RADICE, "data/mappa_%s_3d.json" % lettera), "w"), separators=(",", ":"))
    print(lettera, "alberi", len(alberi), "cespugli", len(cespugli), "ciuffi", len(ciuffi), "muri", len(muri))
    return img, alberi, cespugli, muri


if __name__ == "__main__":
    for l in ("a", "b"):
        img, alberi, cespugli, muri = estrai(l)
        # anteprima di controllo
        vis = (img * 0.45 + 140).astype(np.uint8)
        for x, y, r in alberi:
            cv2.circle(vis, (int(x / SCALA), int(y / SCALA)), int(r / SCALA), (0, 140, 0), 3)
        for x, y, r in cespugli:
            cv2.circle(vis, (int(x / SCALA), int(y / SCALA)), max(2, int(r / SCALA)), (0, 200, 200), 2)
        for m in muri:
            p = (np.array(m["poly"]) / SCALA).astype(np.int32)
            cv2.polylines(vis, [p], True, (200, 0, 0) if m["tipo"] == "pietra" else (0, 60, 160), 4)
        cv2.imwrite("/tmp/anteprima3d_%s.jpg" % l, cv2.resize(vis, (1400, 1280)))
