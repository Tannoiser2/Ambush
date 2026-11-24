#!/usr/bin/env python3
"""Rifinisce le stanze degli edifici (data/mappa_X_3d.json, voce «case») sul disegno della mappa.

Ogni stanza è un rettangolo. Per ogni orientamento vicino a quello attuale si cerca, lato per lato,
la posizione in cui il lato coincide con il bordo ESTERNO del muro stampato (dentro: muro o tratto
scuro; fuori: carta). Vince l'orientamento con il punteggio migliore. Poi si rileggono lungo ogni
lato muri, finestre e porte.

Uso: python3 tools/rifinisci_case.py [lettere...]   (predefinite: a ad b be c)
     --anteprima  scrive /tmp/case_X.jpg con le stanze sopra la mappa
"""
import json, os, sys
import numpy as np, cv2

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def maschere(img):
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.float32)
    H, S, V = hsv[..., 0] * 2, hsv[..., 1] / 255, hsv[..., 2] / 255
    azzurro = (H >= 170) & (H <= 215) & (S > 0.15) & (V > 0.45)
    legno = (H >= 12) & (H <= 42) & (S > 0.3) & (V > 0.35)
    scuro = V < 0.42
    muro = (azzurro | legno | scuro).astype(np.float32)
    return muro, scuro.astype(np.uint8), (azzurro | legno).astype(np.uint8)


def campiona(m, pts):
    x = np.clip(np.round(pts[:, 0]).astype(int), 0, m.shape[1] - 1)
    y = np.clip(np.round(pts[:, 1]).astype(int), 0, m.shape[0] - 1)
    return m[y, x]


def rifinisci(muro, rett):
    (cx, cy), (w, h), ang = rett
    c = np.array([cx, cy], np.float64)
    migliore = None
    for dang in np.arange(-6.0, 6.01, 0.5):
        t = np.radians(ang + dang)
        u = np.array([np.cos(t), np.sin(t)])
        v = np.array([-np.sin(t), np.cos(t)])
        mezzi = [w / 2, h / 2, w / 2, h / 2]
        assi = [u, v, -u, -v]
        lati = []
        tot = 0.0
        for k in range(4):
            n = assi[k]
            lungo = assi[(k + 1) % 4]
            meta_l = mezzi[(k + 1) % 4]
            s = np.linspace(-meta_l * 0.8, meta_l * 0.8, 36)
            best = None
            for off in np.arange(mezzi[k] - 26, mezzi[k] + 26.1, 1.0):
                base = c[None, :] + n[None, :] * off + lungo[None, :] * s[:, None]
                dentro = campiona(muro, base - n[None, :] * 7)
                fuori = campiona(muro, base + n[None, :] * 7)
                bordo = campiona(muro, base - n[None, :] * 2)
                p = float(np.mean(dentro * 0.6 + bordo * 0.4 - fuori))
                if best is None or p > best[0]:
                    best = (p, off)
            lati.append(best[1])
            tot += best[0]
        if migliore is None or tot > migliore[0]:
            migliore = (tot, dang, lati, u, v)
    tot, dang, (a1, b1, a2, b2), u, v = migliore
    # nuovo centro e misure dai quattro lati
    cn = c + u * (a1 - a2) / 2 + v * (b1 - b2) / 2
    W, Hh = a1 + a2, b1 + b2
    if not (100 < W < 420 and 100 < Hh < 420):
        return rett, 0.0
    return ((float(cn[0]), float(cn[1])), (float(W), float(Hh)), float(ang + dang)), tot / 4


def leggi_lati(W, scuro, rett):
    box = cv2.boxPoints(rett)
    cen = np.array(rett[0])
    lati = []
    for i in range(4):
        p, q = box[i], box[(i + 1) % 4]
        lung = np.linalg.norm(q - p)
        dirv = (q - p) / max(lung, 1)
        dentro = cen - (p + q) / 2
        dentro = dentro / max(np.linalg.norm(dentro), 1)
        cls = []
        for s_ in np.arange(0, lung, 4):
            pt = p + dirv * s_ + dentro * 12
            x, y = int(pt[0]), int(pt[1])
            x0, x1, y0, y1 = max(0, x - 7), x + 8, max(0, y - 7), y + 8
            if W[y0:y1, x0:x1].mean() > 0.35:
                cls.append("m")
            elif scuro[y0:y1, x0:x1].any():
                cls.append("f")
            else:
                cls.append("v")
        tratti = []
        for j, cl in enumerate(cls):
            if tratti and tratti[-1][2] == cl:
                tratti[-1][1] = j + 1
            else:
                tratti.append([j, j + 1, cl])
        buoni = []
        for tr in tratti:
            if (tr[1] - tr[0]) * 4 < 14 and buoni:
                buoni[-1][1] = tr[1]
            else:
                buoni.append(tr)
        uniti = []
        for tr in buoni:
            if uniti and uniti[-1][2] == tr[2]:
                uniti[-1][1] = tr[1]
            else:
                uniti.append(tr)
        n_ = max(1, len(cls))
        lato = []
        for tr in uniti:
            tipo = {"m": "muro", "f": "finestra", "v": "porta"}[tr[2]]
            if tipo == "porta" and (tr[1] - tr[0]) * 4 > 140:
                tipo = "finestra"
            lato.append([round(tr[0] / n_, 3), round(min(1.0, tr[1] / n_), 3), tipo])
        lati.append(lato)
    return lati


ORIG = np.array([307.0, 272.0]) * 0.6
PASSO = np.array([270.8, 314.0]) * 0.6


def centro_hex(h):
    col, rig = ord(h[0]) - 65, int(h[1:])
    return ORIG + np.array([col * PASSO[0], (rig - 1) * PASSO[1] + (col & 1) * PASSO[1] / 2])


def area(p):
    p = np.asarray(p, np.float32)
    return abs(cv2.contourArea(p))


def sovrapposta(a, b):
    r, inter = cv2.intersectConvexConvex(np.asarray(a, np.float32), np.asarray(b, np.float32))
    return r / max(1.0, min(area(a), area(b)))


def completa(d, lettera, muro_s, scuro, fascia):
    """Esagoni di edificio che nessuna stanza copre: si prova a trovare la stanza stampata attorno al centro."""
    ter = json.load(open(os.path.join(RADICE, "data/mappa_%s.json" % lettera)))
    aggiunte = []
    for h, v in sorted(ter["esagoni"].items()):
        t = v.get("t", "")
        if t not in ("stone_building", "wood_building"):
            continue
        c = centro_hex(h)
        if any(cv2.pointPolygonTest(np.asarray(st["angoli"], np.float32), (float(c[0]), float(c[1])), False) >= 0 for st in d["case"]):
            continue
        angoli_base = {0.0, 30.0, -30.0, 60.0}
        for st in d["case"]:
            if np.hypot(st["rett"][0] - c[0], st["rett"][1] - c[1]) < 500:
                angoli_base.add(round(st["rett"][4], 1))
        migliore = None
        for a0 in angoli_base:
            nuovo, punti = rifinisci(muro_s, ((float(c[0]), float(c[1])), (180.0, 180.0), a0))
            if migliore is None or punti > migliore[1]:
                migliore = (nuovo, punti)
        nuovo, punti = migliore
        box = cv2.boxPoints(nuovo)
        if punti < 0.45 or cv2.pointPolygonTest(box, (float(c[0]), float(c[1])), False) < 0:
            continue
        if any(sovrapposta(box, st["angoli"]) > 0.08 for st in d["case"]):
            continue
        d["case"].append({"tipo": "pietra" if t == "stone_building" else "legno", "hex": [h],
                          "rett": [nuovo[0][0], nuovo[0][1], nuovo[1][0], nuovo[1][1], nuovo[2]],
                          "angoli": [[round(float(x), 1), round(float(y), 1)] for x, y in box],
                          "lati": leggi_lati(fascia, scuro, nuovo)})
        aggiunte.append(h)
    return aggiunte


def elabora(lettera, anteprima=False):
    img = cv2.imread(os.path.join(RADICE, "assets/maps/mappa_%s.jpg" % lettera))
    percorso = os.path.join(RADICE, "data/mappa_%s_3d.json" % lettera)
    d = json.load(open(percorso))
    muro, scuro, fascia = maschere(img)
    muro_s = cv2.GaussianBlur(muro, (0, 0), 1.2)
    cambi = []
    for st in d.get("case", []):
        r = st.get("rett")
        if r is None:
            r = cv2.minAreaRect(np.array(st["angoli"], np.float32))
            r = [r[0][0], r[0][1], r[1][0], r[1][1], r[2]]
        rett = ((r[0], r[1]), (r[2], r[3]), r[4])
        nuovo, punti = rifinisci(muro_s, rett)
        box = cv2.boxPoints(nuovo)
        spost = float(np.hypot(nuovo[0][0] - rett[0][0], nuovo[0][1] - rett[0][1]))
        cambi.append((spost, nuovo[2] - rett[2], punti))
        st["rett"] = [nuovo[0][0], nuovo[0][1], nuovo[1][0], nuovo[1][1], nuovo[2]]
        st["angoli"] = [[round(float(x), 1), round(float(y), 1)] for x, y in box]
        st["lati"] = leggi_lati(fascia, scuro, nuovo)
    aggiunte = completa(d, lettera, muro_s, scuro, fascia)
    if aggiunte:
        print(lettera, "stanze aggiunte negli esagoni di edificio scoperti:", ", ".join(aggiunte))
    d["edifici"] = [{"tipo": c["tipo"], "poly": c["angoli"]} for c in d.get("case", [])]
    json.dump(d, open(percorso, "w"), separators=(",", ":"))
    if cambi:
        a = np.array(cambi)
        print(lettera, "stanze", len(cambi), "spostamento medio %.1f px" % a[:, 0].mean(), "rotazione media %.2f°" % np.abs(a[:, 1]).mean(),
              "punteggio medio %.2f" % a[:, 2].mean())
    if anteprima:
        vis = img.copy()
        for st in d["case"]:
            box = np.array(st["angoli"])
            for i, lato in enumerate(st["lati"]):
                p, q = box[i], box[(i + 1) % 4]
                for t0, t1, tipo in lato:
                    a_, b_ = p + (q - p) * t0, p + (q - p) * t1
                    col = {"muro": (0, 0, 220), "finestra": (220, 0, 220), "porta": (0, 200, 0)}[tipo]
                    cv2.line(vis, (int(a_[0]), int(a_[1])), (int(b_[0]), int(b_[1])), col, 3)
        cv2.imwrite("/tmp/case_%s.jpg" % lettera, vis)


if __name__ == "__main__":
    arg = [a for a in sys.argv[1:] if not a.startswith("--")]
    for l in (arg or ["a", "ad", "b", "be", "c"]):
        elabora(l, "--anteprima" in sys.argv)
