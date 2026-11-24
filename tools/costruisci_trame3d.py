#!/usr/bin/env python3
"""Trame procedurali per la vista 3D (edifici, tetti, alberi), tutte ripetibili senza cuciture.

Scrive in assets/trame3d/:
  pietra_*.png      muratura in pietra squadrata (colore, normali)
  intonaco_*.png    intonaco a calce consumato
  legno_*.png       assi di legno orizzontali
  tegole_*.png      coppi in laterizio (colore, normali); la V va lungo la falda
  scandole_*.png    scandole di legno scure
  corteccia_*.png   corteccia
  foglie.png        ciuffo di foglie con trasparenza (atlante 2x2 di varianti)
  erba.png          ciuffo d'erba con trasparenza
Uso: python3 tools/costruisci_trame3d.py
"""
import os
import numpy as np, cv2

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(RADICE, "assets/trame3d")
N = 512
rng = np.random.default_rng(1944)


def rumore(n, scale, ott=5, pers=0.55, seme=0):
    """Rumore frattale ripetibile (somma di ottave di rumore a valori interpolato con avvolgimento)."""
    r = np.random.default_rng(seme)
    tot = np.zeros((n, n), np.float32)
    amp, somma = 1.0, 0.0
    for o in range(ott):
        k = max(1, int(scale * 2 ** o))
        g = r.random((k, k)).astype(np.float32)
        g = np.tile(g, (3, 3))
        big = cv2.resize(g, (n * 3, n * 3), interpolation=cv2.INTER_CUBIC)[n:2 * n, n:2 * n]
        tot += big * amp
        somma += amp
        amp *= pers
    tot /= somma
    return (tot - tot.min()) / max(1e-6, tot.max() - tot.min())


def normali(alt, forza=4.0):
    a = alt.astype(np.float32)
    dx = (np.roll(a, -1, 1) - np.roll(a, 1, 1)) * forza
    dy = (np.roll(a, -1, 0) - np.roll(a, 1, 0)) * forza
    n = np.dstack([-dx, -dy, np.ones_like(a)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    # convenzione OpenGL (Godot): verde verso l'alto
    rgb = np.dstack([n[..., 0] * 0.5 + 0.5, -n[..., 1] * 0.5 + 0.5, n[..., 2] * 0.5 + 0.5])
    return (np.clip(rgb, 0, 1) * 255).astype(np.uint8)


def salva(nome, rgb, alpha=None):
    os.makedirs(OUT, exist_ok=True)
    img = np.clip(rgb, 0, 255).astype(np.uint8)
    if alpha is not None:
        img = np.dstack([img, np.clip(alpha, 0, 255).astype(np.uint8)])
        cv2.imwrite(os.path.join(OUT, nome), cv2.cvtColor(img, cv2.COLOR_RGBA2BGRA))
    else:
        cv2.imwrite(os.path.join(OUT, nome), cv2.cvtColor(img, cv2.COLOR_RGB2BGR))


def colora(base, var, n):
    return np.array(base, np.float32)[None, None, :] * (1.0 + (n[..., None] - 0.5) * var)


def pietra():
    """Conci di pietra in corsi di altezza variabile, giunti di malta incassati."""
    alt = np.zeros((N, N), np.float32)
    col = np.zeros((N, N, 3), np.float32)
    malta = np.ones((N, N), np.float32)
    y = 0
    righe = []
    while y < N:
        h = int(rng.integers(44, 76))
        if N - y - h < 40:
            h = N - y
        righe.append((y, h))
        y += h
    gr = rumore(N, 3, 6, 0.6, 11)
    fine = rumore(N, 24, 4, 0.5, 12)
    for (y0, h) in righe:
        x = int(rng.integers(0, 60))
        while x < N + 60:
            w = int(rng.integers(70, 150))
            tono = rng.uniform(-0.12, 0.12)
            tinta = np.array([0.7, 0.65, 0.56]) * (1 + tono) + rng.uniform(-0.015, 0.015)
            m = np.zeros((N, N), np.uint8)
            pts = np.array([[x + 3, y0 + 3], [x + w - 3, y0 + 3], [x + w - 3, y0 + h - 3], [x + 3, y0 + h - 3]], np.int32)
            for dx in (-N, 0, N):
                cv2.fillPoly(m, [pts + np.array([dx, 0])], 1)
            # bordi smussati e irregolari
            dist = cv2.distanceTransform(m, cv2.DIST_L2, 5)
            bombato = np.clip(dist / 9.0, 0, 1) ** 0.6
            sel = m > 0
            alt[sel] = (0.55 + 0.45 * bombato[sel]) * (0.85 + 0.3 * gr[sel])
            for c in range(3):
                col[..., c][sel] = tinta[c]
            malta[sel] = 0
            x += w
    alt += fine * 0.18
    rgb = col * (0.78 + 0.35 * gr[..., None]) * (0.9 + 0.2 * fine[..., None])
    rgb[malta > 0] = np.array([0.72, 0.69, 0.62]) * (0.85 + 0.2 * fine[malta > 0][:, None])
    alt[malta > 0] = 0.15 + fine[malta > 0] * 0.1
    # sporco alla base dei corsi e macchie
    macchie = rumore(N, 2, 5, 0.6, 13)
    rgb *= (0.82 + 0.25 * macchie[..., None])
    salva("pietra_c.png", rgb * 255)
    salva("pietra_n.png", normali(cv2.GaussianBlur(alt, (0, 0), 1.0), 6.0))


def intonaco():
    n1 = rumore(N, 4, 6, 0.6, 21)
    n2 = rumore(N, 32, 4, 0.5, 22)
    macchie = rumore(N, 2, 4, 0.6, 23)
    base = np.array([0.86, 0.80, 0.68])
    rgb = base[None, None, :] * (0.88 + 0.16 * n1[..., None]) * (0.95 + 0.08 * n2[..., None])
    rgb *= (0.8 + 0.25 * macchie[..., None])
    # pietra a vista dove l'intonaco è caduto
    caduto = (macchie < 0.08).astype(np.float32)
    caduto = cv2.GaussianBlur(caduto, (0, 0), 2)
    rgb = rgb * (1 - caduto[..., None]) + np.array([0.6, 0.55, 0.48]) * caduto[..., None] * (0.8 + 0.3 * n2[..., None])
    alt = n2 * 0.4 + n1 * 0.2 - caduto * 0.4
    salva("intonaco_c.png", rgb * 255)
    salva("intonaco_n.png", normali(alt, 3.0))


def legno():
    """Assi orizzontali sovrapposte, venatura, chiodi."""
    alt = np.zeros((N, N), np.float32)
    rgb = np.zeros((N, N, 3), np.float32)
    h = N // 8
    ven = rumore(N, 2, 3, 0.5, 31)
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    for i in range(8):
        y0 = i * h
        tono = rng.uniform(-0.1, 0.1)
        base = np.array([0.45, 0.33, 0.22]) * (1 + tono)
        sel = (yy >= y0) & (yy < y0 + h)
        fase = rng.uniform(0, 100)
        venatura = 0.5 + 0.5 * np.sin((yy - y0) * 0.9 + ven * 18 + fase + np.sin(xx * 0.02 + fase) * 2)
        loc = (yy - y0) / h
        rgb[sel] = (base[None, :] * (0.8 + 0.3 * venatura[sel][:, None]))
        alt[sel] = 0.4 + loc[sel] * 0.5 + venatura[sel] * 0.05
        alt[(yy == y0) | (yy == y0 + 1)] = 0
        rgb[(yy >= y0) & (yy < y0 + 3)] *= 0.45
    grigio = rumore(N, 3, 4, 0.6, 32)
    rgb = rgb * (0.75 + 0.35 * grigio[..., None])
    rgb = rgb * 0.8 + np.array([0.42, 0.4, 0.37]) * 0.2   # legno invecchiato
    salva("legno_c.png", rgb * 255)
    salva("legno_n.png", normali(alt, 4.0))


def tegole():
    """Coppi: file di canali curvi; la V scende lungo la falda (in basso la gronda)."""
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    k = 8           # coppi per riga
    w = N / k
    righe = 6
    hr = N / righe
    fila = np.floor(yy / hr)
    off = (fila % 2) * w / 2
    u = ((xx + off) % w) / w
    v = (yy % hr) / hr
    curva = np.sin(u * np.pi) ** 0.7
    alt = curva * 0.7 + v * 0.35
    alt[v > 0.92] *= 0.4
    tinte = rng.uniform(-0.12, 0.12, (righe, k + 1))
    idx_c = np.floor((xx + off) / w).astype(int) % (k + 1)
    t = tinte[fila.astype(int) % righe, idx_c]
    base = np.array([0.56, 0.32, 0.23])
    n1 = rumore(N, 4, 5, 0.6, 41)
    rgb = base[None, None, :] * (1 + t[..., None]) * (0.65 + 0.45 * curva[..., None]) * (0.85 + 0.25 * n1[..., None])
    rgb[v > 0.92] *= 0.55
    licheni = (rumore(N, 10, 4, 0.6, 42) > 0.9).astype(np.float32)
    licheni = cv2.GaussianBlur(licheni, (0, 0), 1.5)
    rgb = rgb * (1 - 0.3 * licheni[..., None]) + np.array([0.45, 0.42, 0.32]) * 0.3 * licheni[..., None]
    salva("tegole_c.png", rgb * 255)
    salva("tegole_n.png", normali(cv2.GaussianBlur(alt, (0, 0), 1.0), 5.0))


def scandole():
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    righe = 10
    hr = N / righe
    fila = np.floor(yy / hr).astype(int)
    rgb = np.zeros((N, N, 3), np.float32)
    alt = np.zeros((N, N), np.float32)
    n1 = rumore(N, 5, 5, 0.6, 51)
    for r in range(righe):
        x = rng.uniform(0, 30)
        sel_r = fila == r
        while x < N + 40:
            w = rng.uniform(26, 52)
            tono = rng.uniform(-0.15, 0.15)
            sel = sel_r & (((xx - x) % N) < w)
            v = (yy % hr) / hr
            rgb[sel] = np.array([0.34, 0.3, 0.26]) * (1 + tono)
            alt[sel] = v[sel] * 0.8 + 0.2
            bordo = sel & ((((xx - x) % N) < 2))
            rgb[bordo] *= 0.5
            alt[bordo] = 0.05
            x += w
    rgb *= (0.8 + 0.35 * n1[..., None])
    salva("scandole_c.png", rgb * 255)
    salva("scandole_n.png", normali(alt, 4.0))


def corteccia():
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    n1 = rumore(N, 3, 5, 0.6, 61)
    fessure = np.abs(np.sin(xx / N * np.pi * 14 + n1 * 9))
    alt = fessure ** 0.4
    rgb = np.array([0.36, 0.3, 0.24])[None, None, :] * (0.55 + 0.6 * alt[..., None]) * (0.85 + 0.3 * rumore(N, 16, 3, 0.5, 62)[..., None])
    salva("corteccia_c.png", rgb * 255)
    salva("corteccia_n.png", normali(alt, 5.0))


def foglia(img, cx, cy, ang, lung, larg, col):
    """Una foglia a mandorla con nervatura centrale."""
    t = np.linspace(0, 1, 18)
    lato = np.sin(t * np.pi) ** 0.8 * larg
    pts_a = np.stack([t * lung, lato], 1)
    pts_b = np.stack([t[::-1] * lung, -lato[::-1]], 1)
    pts = np.concatenate([pts_a, pts_b])
    c, s = np.cos(ang), np.sin(ang)
    pts = pts @ np.array([[c, s], [-s, c]]) + np.array([cx, cy])
    cv2.fillPoly(img, [pts.astype(np.int32)], col, lineType=cv2.LINE_AA)
    scuro = tuple(int(v * 0.75) for v in col[:3]) + ((col[3],) if len(col) > 3 else ())
    p0 = (int(cx), int(cy))
    p1 = (int(cx + c * lung * 0.9), int(cy - s * lung * 0.9))
    cv2.line(img, p0, p1, scuro, 1, cv2.LINE_AA)


def foglie():
    """Atlante 2x2: quattro ciuffi di foglie diversi. RGB = colore (poi tinto per albero), A = forma."""
    M = 1024
    h = M // 2
    tot = np.zeros((M, M, 4), np.uint8)
    for q in range(4):
        img = np.zeros((h, h, 4), np.uint8)
        c0 = np.array([h / 2, h / 2])
        n_f = 700
        for i in range(n_f):
            # più foglie verso il centro; ombra verso il basso e il centro
            r = h * 0.43 * np.sqrt(rng.random())
            a = rng.uniform(0, 2 * np.pi)
            p = c0 + np.array([np.cos(a), np.sin(a)]) * r
            luce = 0.55 + 0.45 * (1 - (p[1] / h)) * 0.7 + 0.3 * (r / (h * 0.43))
            luce *= rng.uniform(0.75, 1.1)
            g = np.clip(np.array([0.27, 0.43, 0.16]) * luce * rng.uniform(0.85, 1.15, 3), 0, 1)
            col = (int(g[0] * 255), int(g[1] * 255), int(g[2] * 255), 255)
            foglia(img, p[0], p[1], rng.uniform(0, 2 * np.pi), rng.uniform(20, 34), rng.uniform(7, 12), col)
        # rametti
        for i in range(5):
            a = rng.uniform(0, 2 * np.pi)
            p1 = c0 + np.array([np.cos(a), np.sin(a)]) * h * 0.4
            cv2.line(img, tuple(c0.astype(int)), tuple(p1.astype(int)), (70, 55, 40, 255), 3, cv2.LINE_AA)
        x0, y0 = (q % 2) * h, (q // 2) * h
        tot[y0:y0 + h, x0:x0 + h] = img
    # riempie il colore sotto la trasparenza (niente aloni scuri con il filtro)
    a = tot[..., 3]
    rgb = tot[..., :3].astype(np.float32)
    media = rgb[a > 0].mean(0)
    rgb[a == 0] = media
    cv2.imwrite(os.path.join(OUT, "foglie.png"), cv2.cvtColor(np.dstack([rgb.astype(np.uint8), a]), cv2.COLOR_RGBA2BGRA))


def erba():
    M = 256
    img = np.zeros((M, M, 4), np.uint8)
    for i in range(70):
        x = rng.uniform(20, M - 20)
        alto = rng.uniform(0.45, 0.95) * M
        curva = rng.uniform(-30, 30)
        g = np.clip(np.array([0.5, 0.58, 0.28]) * rng.uniform(0.75, 1.2, 3), 0, 1)
        col = (int(g[0] * 255), int(g[1] * 255), int(g[2] * 255), 255)
        pts = []
        for t in np.linspace(0, 1, 10):
            pts.append([x + curva * t * t - 3 * (1 - t), M - t * alto])
        for t in np.linspace(1, 0, 10):
            pts.append([x + curva * t * t + 3 * (1 - t), M - t * alto])
        cv2.fillPoly(img, [np.array(pts, np.int32)], col, cv2.LINE_AA)
    a = img[..., 3]
    rgb = img[..., :3].astype(np.float32)
    rgb[a == 0] = rgb[a > 0].mean(0)
    cv2.imwrite(os.path.join(OUT, "erba.png"), cv2.cvtColor(np.dstack([rgb.astype(np.uint8), a]), cv2.COLOR_RGBA2BGRA))


if __name__ == "__main__":
    for f in (pietra, intonaco, legno, tegole, scandole, corteccia, foglie, erba):
        f()
        print("fatto", f.__name__)
