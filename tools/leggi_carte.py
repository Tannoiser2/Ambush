#!/usr/bin/env python3
"""Legge le carte Condizione di Ambush! dalle scansioni (OCR con tesseract).

Uso: python3 tools/leggi_carte.py <scansione.png> [<uscita.json>]

La carta ha due blocchi di 10 righe separati dalla riga delle lettere (A..Y, RE).
Ordine delle righe stampate (finestrella della busta):
  blocco alto:  0 3 6 9 12 15 18 1 4 7
  blocco basso: 10 13 16 19 2 5 8 11 14 17
Ogni cella ha un riferimento nero (NONE, EVENT, paragrafo, sN paragrafo) e a volte,
sotto, un riferimento di movimento rosso (esagono, paragrafo o Exit).
L’uscita contiene per ogni cella il testo letto e un indice di affidabilità; le celle dubbie
si correggono a mano in un file di revisione.
"""
import os, json, re, subprocess, sys, tempfile, pathlib
import numpy as np
from PIL import Image, ImageOps

Image.MAX_IMAGE_PIXELS = None
ORDINE = [0, 3, 6, 9, 12, 15, 18, 1, 4, 7, 10, 13, 16, 19, 2, 5, 8, 11, 14, 17]
COLONNE = [chr(65 + i) for i in range(25)] + ["RE"]
LARGHEZZA = int(os.environ.get("LARGHEZZA", 3300))


def gruppi(v, soglia, distacco=3):
    idx = np.where(v > soglia)[0]
    out = []
    if len(idx) == 0:
        return out
    s = p = idx[0]
    for i in idx[1:]:
        if i - p > distacco:
            out.append([int(s), int(p)])
            s = i
        p = i
    out.append([int(s), int(p)])
    return out


def carica(percorso):
    im = Image.open(percorso)
    if im.mode == "RGB":
        a = np.asarray(im).astype(int)
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        rosso = (r - (g + b) / 2 > 60) & (r > 120)
        grigio = np.asarray(im.convert("L")).astype(int)
        nero = (grigio < 110) & ~rosso
    else:
        grigio = np.asarray(im.convert("L")).astype(int)
        nero = grigio < 95
        rosso = (grigio >= 95) & (grigio < 185)
    k = LARGHEZZA / im.size[0]
    return grigio, nero, rosso, k


def tesseract(img, whitelist, psm=6):
    with tempfile.TemporaryDirectory() as d:
        p = pathlib.Path(d) / "m.png"
        img.save(p)
        cmd = ["tesseract", str(p), "stdout", "--psm", str(psm), "-c", "tessedit_char_whitelist=" + whitelist,
               "-c", "preserve_interword_spaces=1", "tsv"]
        out = subprocess.run(cmd, capture_output=True, text=True).stdout
    righe = {}
    for r in out.splitlines()[1:]:
        c = r.split("\t")
        if len(c) < 12 or c[11].strip() == "":
            continue
        chiave = (int(c[2]), int(c[3]), int(c[4]))
        righe.setdefault(chiave, []).append((int(c[6]), c[11], float(c[10])))
    return righe


def mosaico(ritagli, altezza):
    """Mette i ritagli uno sotto l’altro, ognuno in una riga alta `altezza`."""
    w = max(r.size[0] for r in ritagli) + 40
    m = Image.new("L", (w, altezza * len(ritagli) + 20), 255)
    for i, r in enumerate(ritagli):
        m.paste(r, (20, 10 + i * altezza + (altezza - r.size[1]) // 2))
    return m


def leggi_mosaico(ritagli, whitelist, altezza, blocco=150):
    """Legge i ritagli a gruppi (tesseract non accetta immagini più alte di 32767 pixel)."""
    testi = []
    for i0 in range(0, len(ritagli), blocco):
        parte = ritagli[i0:i0 + blocco]
        m = mosaico(parte, altezza)
        with tempfile.TemporaryDirectory() as d:
            p = pathlib.Path(d) / "m.png"
            m.save(p)
            out = subprocess.run(["tesseract", str(p), "stdout", "--psm", "6", "-c", "tessedit_char_whitelist=" + whitelist, "tsv"],
                                 capture_output=True, text=True).stdout
        celle = [[] for _ in parte]
        for r in out.splitlines()[1:]:
            c = r.split("\t")
            if len(c) < 12 or c[11].strip() == "":
                continue
            top, h = int(c[7]), int(c[9])
            i = int((top + h / 2 - 10) // altezza)
            if 0 <= i < len(celle):
                celle[i].append((int(c[6]), c[11], float(c[10])))
        for parole in celle:
            parole.sort()
            testi.append((" ".join(p[1] for p in parole), min([p[2] for p in parole], default=-1)))
    return testi


def leggi(percorso):
    grigio, nero, rosso, k = carica(percorso)
    H, W = nero.shape
    # righe di testo nero
    prof = nero.sum(axis=1)
    linee = [g for g in gruppi(prof, W * 0.004, 4) if g[1] - g[0] > H * 0.006]
    # riga delle lettere: quella con meno inchiostro nel mezzo del foglio; il titolo è subito sotto
    altezze = [g[1] - g[0] for g in linee]
    h_tip = sorted(altezze)[len(altezze) // 2]
    linee = [g for g in linee if g[1] - g[0] > h_tip * 0.6]
    # Le righe di dati occupano tutta la larghezza; le righe dei riferimenti rossi (scure in
    # alcune scansioni) solo qualche colonna: le scarto contando i gruppi d’inchiostro.
    def gruppi_x(g):
        return len(gruppi(nero[g[0]:g[1] + 1].sum(axis=0), 0.5, int(W * 0.006)))
    linee = [g for g in linee if gruppi_x(g) >= 18]
    # Le 20 righe di dati sono le linee più regolari: escludo intestazione e titolo cercando
    # le due linee tra i blocchi (le uniche con distanza diversa dal passo).
    centri = [(g[0] + g[1]) / 2 for g in linee]
    passi = np.diff(centri)
    passo = float(np.median(passi))
    # blocco alto: 10 linee consecutive a passo regolare
    def blocchi():
        out, cor = [], [0]
        for i in range(1, len(linee)):
            if abs(passi[i - 1] - passo) < passo * 0.25:
                cor.append(i)
            else:
                out.append(cor)
                cor = [i]
        out.append(cor)
        return out
    bl = [b for b in blocchi() if len(b) >= 8]
    if len(bl) < 2:
        raise SystemExit("blocchi non trovati: %s" % [len(b) for b in blocchi()])
    alto = bl[0][-10:]
    h_int = alto[-1] + 1
    # il blocco basso: le ultime 10 linee della serie a passo regolare dopo l’intestazione
    # (il titolo «Ambush! Mission…» può cadere allo stesso passo e va scartato)
    serie = [h_int + 1]
    for i in range(h_int + 2, len(linee)):
        if abs(centri[i] - centri[serie[-1]] - passo) < passo * 0.25:
            serie.append(i)
        elif len(serie) >= 10:
            break
        else:
            serie = [i]
    if len(serie) < 10:
        raise SystemExit("blocco basso non trovato")
    basso = serie[-10:]
    dati = [linee[i] for i in alto] + [linee[i] for i in basso]
    # titolo della carta (missione e condizione), per controllo
    ta, tb = linee[h_int + 1]
    crop = 255 - (nero[ta - 4:tb + 5, :] * 255).astype(np.uint8)
    img = Image.fromarray(crop)
    f_t = 50.0 / max(1, img.size[1])
    img = img.resize((int(img.size[0] * f_t), int(img.size[1] * f_t)), Image.LANCZOS)
    with tempfile.TemporaryDirectory() as d:
        p = pathlib.Path(d) / "t.png"
        img.save(p)
        titolo = subprocess.run(["tesseract", str(p), "stdout", "--psm", "7"], capture_output=True, text=True).stdout.strip()
    # colonne: dalle lettere dell’intestazione (la linea subito sotto il blocco alto)
    intest = linee[bl[0][-1] + 1]
    a0, b0 = intest
    pad = int((b0 - a0) * 0.6)
    crop = 255 - (nero[a0 - pad:b0 + pad, :] * 255).astype(np.uint8)
    img = Image.fromarray(crop)
    f = 60.0 / max(1, img.size[1])
    img = img.resize((int(img.size[0] * f), int(img.size[1] * f)), Image.LANCZOS)
    with tempfile.TemporaryDirectory() as d:
        p = pathlib.Path(d) / "h.png"
        img.save(p)
        out = subprocess.run(["tesseract", str(p), "stdout", "--psm", "7", "-c", "tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYRE", "tsv"],
                             capture_output=True, text=True).stdout
    lettere = []
    for r in out.splitlines()[1:]:
        c = r.split("\t")
        if len(c) < 12 or c[11].strip() == "":
            continue
        x, w, txt = int(c[6]) / f, int(c[8]) / f, c[11].strip()
        # parole incollate («AB») divise in parti uguali
        n = len(txt) if txt != "RE" else 1
        if txt.endswith("RE") and len(txt) > 2:
            n = len(txt) - 1
        for j in range(n):
            lettere.append(x + w * (j + 0.5) / n)
    # profilo dell’intestazione come riserva
    if len(lettere) != 26:
        prof_h = nero[a0:b0 + 1].sum(axis=0)
        bl_h = gruppi(prof_h, 0.5, int(W * 0.003))
        if len(bl_h) == 27:  # «R» ed «E» separati
            bl_h = bl_h[:25] + [[bl_h[25][0], bl_h[26][1]]]
        lettere = [(g[0] + g[1]) / 2 for g in bl_h]
    if len(lettere) != 26:
        raise SystemExit("lettere dell’intestazione: %d" % len(lettere))
    lettere.sort()
    confini = [0] + [int((lettere[i] + lettere[i + 1]) / 2) for i in range(25)] + [W]
    ritagli_neri, ritagli_rossi, posti, scatole = [], [], [], []
    code = {}
    stat = {"righe_segmentate": 0}
    # 1) Celle di ogni riga: gruppi di inchiostro separati da uno spazio più largo di quello
    #    tra «s2» e «106». 2) Le righe che non danno 26 gruppi usano i centri delle colonne
    #    stimati (retta in y) dalle righe riuscite, così l’inclinazione della scansione non conta.
    tutti = []
    for (a, b) in dati:
        h = b - a
        prof_r = nero[a:b + 1].sum(axis=0)
        pezzi = []
        for fr in (0.75, 0.65, 0.85, 0.55, 0.95, 0.5, 1.05, 0.45):
            pezzi = gruppi(prof_r, 0.5, max(2, int(h * fr)))
            if len(pezzi) == 26:
                break
        tutti.append(pezzi if len(pezzi) == 26 else None)
    # scarta le righe «riuscite» i cui gruppi si scostano dalla mediana delle colonne
    # (una macchia a sinistra e due celle fuse danno comunque 26 gruppi, ma spostati)
    passo = (lettere[-1] - lettere[0]) / 25
    for _giro in range(2):
        ok = [i for i in range(len(dati)) if tutti[i]]
        if len(ok) < 3:
            break
        ys = np.array([(dati[i][0] + dati[i][1]) / 2 for i in ok])
        cattive = set()
        for j in range(26):
            xs = np.array([(tutti[i][j][0] + tutti[i][j][1]) / 2 for i in ok])
            p = np.polyfit(ys, xs, 1)
            for i, y, x in zip(ok, ys, xs):
                if abs(np.polyval(p, y) - x) > passo * 0.35:
                    cattive.add(i)
        for i in cattive:
            tutti[i] = None
    buone = [(dati[i][0] + dati[i][1]) / 2 for i in range(len(dati)) if tutti[i]]
    stat["righe_segmentate"] = len(buone)
    stat["interpolate"] = [ORDINE[i] for i in range(len(dati)) if not tutti[i]]
    rette = []
    for j in range(26):
        if len(buone) >= 2:
            ys = np.array(buone)
            xs = np.array([(p[j][0] + p[j][1]) / 2 for p in tutti if p])
            rette.append(np.polyfit(ys, xs, 1))
        else:
            rette.append(np.array([0.0, float(lettere[j])]))
    for ri, (a, b) in enumerate(dati):
        h = b - a
        if tutti[ri]:
            limiti = [(max(0, p[0] - 3), min(W, p[1] + 4)) for p in tutti[ri]]
        else:
            y = (a + b) / 2
            c = [float(np.polyval(rette[j], y)) for j in range(26)]
            m = [0] + [int((c[j] + c[j + 1]) / 2) for j in range(25)] + [W]
            limiti = [(m[j], m[j + 1]) for j in range(26)]
        for ci in range(26):
            x0, x1 = limiti[ci]
            cella = 255 - (nero[a - 2:b + 3, x0:x1] * 255).astype(np.uint8)
            img = Image.fromarray(cella)
            img = img.resize((max(1, int(img.size[0] * k)), max(1, int(img.size[1] * k))), Image.LANCZOS)
            ritagli_neri.append(ImageOps.expand(img, 6, 255))
            # zona rossa: sotto la riga, nella stessa colonna
            # zona rossa delimitata dai punti medi tra le celle di questa stessa riga
            xr0 = 0 if ci == 0 else (limiti[ci - 1][1] + limiti[ci][0]) // 2
            xr1 = W if ci == 25 else (limiti[ci][1] + limiti[ci + 1][0]) // 2
            scatole.append([int(xr0), int(a), int(xr1), int(b + h * 1.25)])
            sotto = rosso[b + 1:b + 1 + int(h * 1.25), xr0:xr1]
            if sotto.sum() > h * 2:
                ys = np.where(sotto.any(axis=1))[0]
                xs = np.where(sotto.any(axis=0))[0]
                z = sotto[ys[0]:ys[-1] + 1, xs[0]:xs[-1] + 1]
                img = Image.fromarray(255 - (z * 255).astype(np.uint8))
                fatt = (h * k * 0.9) / max(1, img.size[1])
                img = img.resize((max(1, int(img.size[0] * fatt)), max(1, int(img.size[1] * fatt))), Image.LANCZOS)
                ritagli_rossi.append(ImageOps.expand(img, 6, 255))
                posti.append((ri, ci))
                # coda della prima lettera (Q) rispetto alle altre cifre (O): differenza dei fondi
                cp = z.any(axis=0)
                fine = 0
                while fine < len(cp) and cp[fine]:
                    fine += 1
                primo = z[:, :fine]
                resto = z[:, fine:]
                if primo.any() and resto.any():
                    f1 = np.where(primo.any(axis=1))[0][-1]
                    f2 = np.where(resto.any(axis=1))[0][-1]
                    code[(ri, ci)] = round(float(f1 - f2) / max(1, z.shape[0]), 3)
    alt = int(max(r.size[1] for r in ritagli_neri) * 1.6)
    neri = leggi_mosaico(ritagli_neri, "NOEVTLADXs0123456789 ", alt)
    rossi = leggi_mosaico(ritagli_rossi, "ABCDEFGHIJKLMNOPQRSTUVWXYZExit0123456789-", alt) if ritagli_rossi else []
    # seconda lettura con sole lettere: distingue O/Q/0 e I/J/1 nella lettera dell’esagono
    rossi_l = leggi_mosaico(ritagli_rossi, "ABCDEFGHIJKLMNOPQRSTUVWXYZ-", alt) if ritagli_rossi else []
    risultato = {"_titolo": titolo, "_stat": stat}
    for ri in range(20):
        riga = ORDINE[ri]
        for ci in range(26):
            t, conf = neri[ri * 26 + ci]
            risultato[f"{riga}|{COLONNE[ci]}"] = {"nero": t, "conf": conf, "box": scatole[ri * 26 + ci]}
    for (ri, ci), (t, conf), (tl, _c) in zip(posti, rossi, rossi_l):
        risultato[f"{ORDINE[ri]}|{COLONNE[ci]}"]["rosso_l"] = tl
        risultato[f"{ORDINE[ri]}|{COLONNE[ci]}"]["coda"] = code.get((ri, ci))
        risultato[f"{ORDINE[ri]}|{COLONNE[ci]}"]["rosso"] = t
        risultato[f"{ORDINE[ri]}|{COLONNE[ci]}"]["conf_rosso"] = conf
    return risultato


VALIDO = re.compile(r"^(NONE|EVENT|\d{3}|s\d \d{3})$")


def normalizza(t):
    t = re.sub(r"\s+", " ", t.strip())
    if t in ("NONE", "EVENT", "LAND", "XXX"):
        return t
    if re.fullmatch(r"N[0O]N[EF]?|N0NE|NONF|NQNE", t):
        return "NONE"
    if re.fullmatch(r"E[VY]EN[T7]|EVENI|EVEN", t):
        return "EVENT"
    s = t.replace("O", "0")
    if re.fullmatch(r"\d{3}", s):
        return s
    # «s2 106» letto in vari modi: «s2 106», «2 106», «82 106», «s2106», «82106»
    m = re.fullmatch(r"s?\S?(\d) ?(\d{3})", s)
    if m and (s.startswith("s") or " " in s or len(s) == 5):
        return f"s{m.group(1)}:{m.group(2)}"
    return t


if __name__ == "__main__":
    r = leggi(sys.argv[1])
    print(r["_titolo"])
    for k, v in r.items():
        if not k.startswith("_"):
            v["norm"] = normalizza(v["nero"])
    if len(sys.argv) > 2:
        pathlib.Path(sys.argv[2]).write_text(json.dumps(r, ensure_ascii=False, indent=0))
    dubbi = [k for k, v in r.items() if not k.startswith("_") and not re.fullmatch(r"NONE|EVENT|LAND|XXX|\d{3}|s\d:\d{3}", v["norm"])]
    print(r["_stat"])
    print("celle:", len(r), "dubbie:", len(dubbi), dubbi[:30])
