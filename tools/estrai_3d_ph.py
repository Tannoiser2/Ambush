#!/usr/bin/env python3
"""Elementi 3D delle mappe di Purple Heart (C, A+D, B+E).

Usa tools/estrai_3d.py (stesso disegno, stessa griglia delle mappe A e B) e poi corregge con il tipo di terreno degli esagoni,
perché su queste mappe i colori pastello delle colline e delle vigne vengono scambiati per cespugli:
  - alberi: solo fuori da acqua ed edifici;
  - cespugli e ciuffi: solo negli esagoni di macchia (brush) o bosco;
  - vigne: filari ricavati dall'orientamento del disegno in ogni esagono di vigna;
  - maschera dell'acqua: colore azzurro solo dentro gli esagoni di acqua e ruscello;
  - case: scartate quelle che si sovrappongono troppo a un'altra (resta la più grande).
Uso: python3 tools/estrai_3d_ph.py
"""
import json, os, sys
import numpy as np, cv2

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import estrai_3d as e  # noqa: E402

R = e.RADICE


def esagono_di(x, y, albero, ids):
    d, i = albero.query([x, y])
    return ids[i] if d <= e.RAGGIO * 1.02 else ""


def poligono_area(p):
    p = np.array(p, np.float32)
    return abs(cv2.contourArea(p))


def sovrapposizione(a, b):
    pa, pb = np.array(a, np.float32), np.array(b, np.float32)
    ok, inter = cv2.intersectConvexConvex(pa, pb)
    return ok / max(1.0, min(poligono_area(a), poligono_area(b)))


def filari(img_gray, cx, cy, rng):
    """Filari di vite in un esagono: direzione dal tensore di struttura del disegno."""
    r = int(e.RAGGIO * 0.9)
    x0, y0 = int(cx - r), int(cy - r)
    pezzo = img_gray[max(0, y0):y0 + 2 * r, max(0, x0):x0 + 2 * r].astype(np.float32)
    if pezzo.size == 0:
        return []
    gx = cv2.Sobel(pezzo, cv2.CV_32F, 1, 0, ksize=5)
    gy = cv2.Sobel(pezzo, cv2.CV_32F, 0, 1, ksize=5)
    jxx, jyy, jxy = (gx * gx).sum(), (gy * gy).sum(), (gx * gy).sum()
    ang_grad = 0.5 * np.arctan2(2 * jxy, jxx - jyy)  # direzione dominante del gradiente
    ang = ang_grad + np.pi / 2  # i filari corrono perpendicolari al gradiente
    d = np.array([np.cos(ang), np.sin(ang)])
    n = np.array([-d[1], d[0]])
    out = []
    passo = 26.0
    for k in np.arange(-3.5, 3.6, 1.0):
        off = n * k * passo
        # semicorda dell'esagono (approssimato con un cerchio di raggio 0.78 R)
        rr = e.RAGGIO * 0.78
        dist = abs(k * passo)
        if dist >= rr:
            continue
        semi = np.sqrt(rr * rr - dist * dist) * rng.uniform(0.85, 0.98)
        p = np.array([cx, cy]) + off - d * semi
        q = np.array([cx, cy]) + off + d * semi
        out.append([round(float(p[0]), 1), round(float(p[1]), 1), round(float(q[0]), 1), round(float(q[1]), 1)])
    return out


def elabora(lettera):
    img, alberi, cespugli, muri = e.estrai(lettera)
    dati = json.load(open(os.path.join(R, "data/mappa_%s.json" % lettera)))
    tipi = {h: v.get("t", "clear") for h, v in dati["esagoni"].items()}
    from scipy.spatial import cKDTree
    ids, centri = [], []
    for c in range(e.COLONNE):
        for r in range(1, e.RIGHE + 1):
            ids.append("%s%d" % (chr(65 + c), r))
            centri.append(e.centro(c, r))
    albero = cKDTree(np.array(centri))
    p3 = os.path.join(R, "data/mappa_%s_3d.json" % lettera)
    d = json.load(open(p3))
    vietati = ("water", "stone_building", "wood_building", "fuel_tank", "monument", "wharf", "subpen")
    d["alberi"] = [a for a in d["alberi"] if tipi.get(esagono_di(a[0], a[1], albero, ids), "clear") not in vietati]
    d["cespugli"] = [a for a in d["cespugli"] if tipi.get(esagono_di(a[0], a[1], albero, ids), "") in ("brush", "woods")]
    d["ciuffi"] = [a for a in d["ciuffi"] if tipi.get(esagono_di(a[0], a[1], albero, ids), "") in ("brush", "woods")]
    # case: punteggio = quanto i lati del rettangolo coincidono con i muri disegnati; tra case sovrapposte resta la migliore
    hsv0 = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.float32)
    H0, S0, V0 = hsv0[..., 0] * 2, hsv0[..., 1] / 255, hsv0[..., 2] / 255
    muro = (((H0 >= 175) & (H0 <= 200) & (S0 > 0.18) & (V0 > 0.6)) | ((H0 >= 20) & (H0 <= 40) & (S0 > 0.33) & (V0 > 0.6) & (V0 < 0.9)) | (V0 < 0.5)).astype(np.uint8)
    muro = cv2.dilate(muro, e.disco(5))

    def punteggio(c):
        box = np.array(c["angoli"], np.float32)
        cen = box.mean(0)
        colpi = tot = 0
        for i in range(4):
            p_, q_ = box[i], box[(i + 1) % 4]
            dentro = cen - (p_ + q_) / 2
            dentro /= max(np.linalg.norm(dentro), 1)
            for t_ in np.linspace(0.05, 0.95, 30):
                pt = p_ + (q_ - p_) * t_ + dentro * 10
                x, y = int(pt[0]), int(pt[1])
                if 0 <= y < muro.shape[0] and 0 <= x < muro.shape[1]:
                    tot += 1
                    colpi += int(muro[y, x])
        return colpi / max(tot, 1)

    for c in d["case"]:
        c["_p"] = punteggio(c)
    case = sorted(d["case"], key=lambda c: -c["_p"])
    tenute = []
    for c in case:
        if c["_p"] < 0.45:
            continue
        if all(sovrapposizione(c["angoli"], t["angoli"]) < 0.12 for t in tenute):
            tenute.append(c)
        else:
            for t in tenute:
                if sovrapposizione(c["angoli"], t["angoli"]) >= 0.12:
                    t["hex"] = sorted(set(t["hex"]) | set(c["hex"]))
    for c in tenute:
        c.pop("_p", None)
    d["case"] = tenute
    d["edifici"] = [{"tipo": c["tipo"], "poly": c["angoli"]} for c in tenute]
    # vigne
    grigio = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    rng = np.random.default_rng(7)
    vigne = []
    for h, t in sorted(tipi.items()):
        if t == "vineyard":
            c = e.centro(ord(h[0]) - 65, int(h[1:]))
            vigne.extend(filari(grigio, c[0], c[1], rng))
    d["vigne"] = vigne
    # oggetti fissi della mappa (serbatoi, monumenti): il centro dell'esagono
    d["serbatoi"] = [[float(x) for x in e.centro(ord(h[0]) - 65, int(h[1:]))] for h, t in sorted(tipi.items()) if t == "fuel_tank"]
    d["monumenti"] = [[float(x) for x in e.centro(ord(h[0]) - 65, int(h[1:]))] for h, t in sorted(tipi.items()) if t == "monument"]
    d["nota"] = "Generato da tools/estrai_3d_ph.py (estrai_3d.py + correzioni per tipo di terreno)."
    json.dump(d, open(p3, "w"), separators=(",", ":"))
    # maschera dell'acqua: solo negli esagoni d'acqua (dopo che estrai ha scritto la sua)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.float32)
    H, S, V = hsv[..., 0] * 2, hsv[..., 1] / 255, hsv[..., 2] / 255
    blu = ((H >= 170) & (H <= 215) & (S > 0.16) & (V > 0.55)).astype(np.uint8)
    _, idx = e.mappa_esagoni(img.shape[:2], 1.0)
    acqua_hex = np.zeros(img.shape[:2], np.uint8)
    for k, h in enumerate(ids):
        if tipi.get(h, "") in ("water", "stream"):
            acqua_hex[idx == k] = 1
    acqua_hex = cv2.dilate(acqua_hex, e.disco(12))
    m = cv2.morphologyEx(blu & acqua_hex, cv2.MORPH_OPEN, e.disco(3))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, e.disco(6))
    pm = os.path.join(R, "assets/maps/mappa_%s_maschere.png" % lettera)
    mas = cv2.imread(pm)
    dim = (mas.shape[1], mas.shape[0])
    a = cv2.GaussianBlur(cv2.resize(m * 255, dim, interpolation=cv2.INTER_AREA), (5, 5), 0)
    mas[..., 2] = a
    # copertura (G) solo in macchia e bosco
    cop_hex = np.zeros(img.shape[:2], np.uint8)
    for k, h in enumerate(ids):
        if tipi.get(h, "") in ("brush", "woods"):
            cop_hex[idx == k] = 255
    mas[..., 1] = np.minimum(mas[..., 1], cv2.resize(cop_hex, dim, interpolation=cv2.INTER_AREA))
    cv2.imwrite(pm, mas)
    print(lettera, "→ alberi", len(d["alberi"]), "cespugli", len(d["cespugli"]), "case", len(tenute), "filari", len(vigne),
          "serbatoi", len(d["serbatoi"]), "monumenti", len(d["monumenti"]))
    # anteprima
    vis = (img * 0.45 + 140).astype(np.uint8)
    for x, y, r in d["alberi"]:
        cv2.circle(vis, (int(x), int(y)), int(r), (0, 140, 0), 3)
    for x, y, r in d["cespugli"]:
        cv2.circle(vis, (int(x), int(y)), max(2, int(r)), (0, 200, 200), 2)
    for c in tenute:
        cv2.polylines(vis, [np.array(c["angoli"]).astype(np.int32)], True, (0, 0, 220), 8)
    for x0, y0, x1, y1 in vigne:
        cv2.line(vis, (int(x0), int(y0)), (int(x1), int(y1)), (40, 90, 140), 4)
    vis[m > 0] = (vis[m > 0] * 0.4 + np.array([255, 80, 0]) * 0.6).astype(np.uint8)
    cv2.imwrite("/tmp/anteprima3d_%s.jpg" % lettera, cv2.resize(vis, (1400, 1280)))


if __name__ == "__main__":
    for l in sys.argv[1:] or ("c", "ad", "be"):
        elabora(l)
