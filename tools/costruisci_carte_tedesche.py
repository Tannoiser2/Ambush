#!/usr/bin/env python3
"""Carte dei tedeschi per tutte le missioni.

- assets/carte/base/geNN.jpg: carte con la nuova grafica (foto) di Ambush! base, prese dal mod TTS; quelle che il mod non
  ha (GE 3, 86–93) dal PDF «Cards_ready_to_print_v1.5».
- assets/carte/orig/<modulo>/geNN.jpg: carte originali di Move Out! (mo), Purple Heart (ph) e Silver Star (ss) dal mod TTS.
- assets/carte/nuove/mN/geNN.jpg: carte ricostruite con la nuova grafica per le carte che non ce l'hanno (tutte quelle
  delle missioni 9–24 e le poche della base che mancano): stesso stile delle carte base, dati della missione
  (data/missioneN.json), foto prese dalle carte base per ruolo (cecchino, ufficiale, mitragliere, mitra, carro, soldato).

Uso: python3 tools/costruisci_carte_tedesche.py <cartella Mods del mod TTS> <Cards_ready_to_print_v1.5.pdf>
"""
import hashlib, json, os, pathlib, re, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

R = pathlib.Path(__file__).resolve().parent.parent
OUT = R / "assets/carte"
FONT = str(R / "assets/fonts/Oswald.ttf")
W, H = 460, 664                 # carta finita (proporzioni delle carte base ritagliate)
BOX_BASE = (80, 88, 845, 1192)  # area della carta nel ritaglio TTS 931x1273
FOTO_BASE = (362, 198, 845, 772)
MODULI = {"base": range(1, 9), "mo": range(9, 13), "ph": range(13, 19), "ss": range(19, 25)}
PERCORSO_TTS = {"//": "base", "//Move Out!/": "mo", "//Purple Heart/": "ph", "//Silver Star/": "ss"}
ARMI = {"knife": "Coltello", "pistol": "Pistola", "bolt": "Fucile a otturatore", "scoped": "Fucile con ottica",
        "sar": "Fucile semiautomatico", "carbine": "Carabina", "mp": "Pistola mitragliatrice", "smg": "Mitra",
        "ar": "Fucile automatico", "pzf": "Panzerfaust", "pzb": "Panzerbüchse", "lmg": "Mitragliatrice leggera",
        "mmg": "Mitragliatrice media", "hmg": "Mitragliatrice pesante", "cannone": "Cannone", "mortar": "Mortaio",
        "mortaio": "Mortaio", "flamethrower": "Lanciafiamme", "satchel": "Carica da demolizione"}


def modulo_di(n):
    for m, r in MODULI.items():
        if n in r:
            return m


def missione(n):
    return json.load(open(R / f"data/missione{n}.json"))


# ------------------------------------------------------------------ carte dal mod TTS
def carte_tts(mods):
    d = json.load(open(pathlib.Path(mods) / "Workshop/3099626094.json"))
    imgs = os.listdir(pathlib.Path(mods) / "Images")
    out = []

    def walk(o, path):
        if isinstance(o, dict):
            if o.get("Name") in ("Card", "CardCustom") and o.get("CardID") is not None:
                cid = o["CardID"]
                cd = o.get("CustomDeck", {}).get(str(cid // 100), {})
                out.append(dict(nick=o.get("Nickname", "").strip(), pos=cid % 100, url=cd.get("FaceURL", ""),
                                w=cd.get("NumWidth"), h=cd.get("NumHeight"), path=path))
            for v in o.values():
                if isinstance(v, (dict, list)):
                    walk(v, path + "/" + str(o.get("Nickname", ""))[:20])
        elif isinstance(o, list):
            for x in o:
                walk(x, path)
    walk(d, "")
    cache = {}
    res = {}
    for c in out:
        m = re.match(r"GE\s*(\d+)(?:-(\d+))?$", c["nick"])
        mod = PERCORSO_TTS.get(c["path"])
        if not m or not mod or not c["w"]:
            continue
        h = c["url"].rstrip("/").split("/")[-1]
        f = next((x for x in imgs if h in x), None)
        if not f:
            continue
        if f not in cache:
            cache[f] = Image.open(pathlib.Path(mods) / "Images" / f).convert("RGB")
        im = cache[f]
        cw, ch = im.width / c["w"], im.height / c["h"]
        x, y = c["pos"] % c["w"], c["pos"] // c["w"]
        cr = im.crop((int(x * cw), int(y * ch), int((x + 1) * cw), int((y + 1) * ch)))
        a, b = int(m.group(1)), int(m.group(2) or m.group(1))
        for n in range(a, b + 1):
            res[(mod, n)] = cr
    return res


def carte_pdf(pdf, voluti):
    """Carte base che il mod non ha, dal PDF stampabile (3 x 3 carte per pagina)."""
    res = {}
    with tempfile.TemporaryDirectory() as t:
        subprocess.run(["pdftotext", "-bbox", pdf, f"{t}/b.html"], check=True)
        s = open(f"{t}/b.html").read()
        subprocess.run(["pdftoppm", "-r", "200", "-png", pdf, f"{t}/p"], check=True)
        for pi, p in enumerate(s.split("<page ")[1:]):
            ws = re.findall(r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="[\d.]+" yMax="[\d.]+">([^<]*)</word>', p)
            for i, w in enumerate(ws[:-1]):
                if w[2] != "GE":
                    continue
                m = re.match(r"(\d+)/", ws[i + 1][2])
                if not m or int(m.group(1)) not in voluti or int(m.group(1)) in res:
                    continue
                pag = sorted(pathlib.Path(t).glob("p-*.png"))[pi]
                im = Image.open(pag).convert("RGB")
                k = 200 / 72.0
                x0, y0 = float(w[0]) - 9.5, float(w[1]) - 8.5
                res[int(m.group(1))] = im.crop((int(x0 * k), int(y0 * k), int((x0 + 182) * k), int((y0 + 263) * k)))
    return res


# ------------------------------------------------------------------ carte ricostruite
def categoria(t):
    ruolo = t.get("ruolo", "").lower()
    armi = t.get("armi", [])
    if "jagdpanther" in ruolo:
        return "jagdpanther"
    if t.get("carro") or "panzer" in ruolo or "carro" in ruolo:
        return "carro"
    if t.get("veicolo") or any(x in ruolo for x in ("auto", "autista", "camion", "motocicl", "semicingolato", "kübel")):
        return "mezzo"
    if "scoped" in armi:
        return "cecchino"
    if any(x in ruolo for x in ("ufficiale", "tenente", "capitano", "generale", "maggiore", "aiutante", "comandante")):
        return "ufficiale"
    if any(x in ruolo for x in ("sottufficiale", "sergente", "caporale")):
        return "sottufficiale"
    if any(a in armi for a in ("lmg", "mmg", "hmg")) or "mitragli" in ruolo or "servente" in ruolo:
        return "mitragliere"
    if "mp" in armi:
        return "mitra"
    return "soldato"


def pulisci_foto(foto):
    """Tiene solo la foto: le scritte della carta base (piccole macchie scure staccate) diventano bianco."""
    import numpy as np
    from scipy import ndimage
    a = np.asarray(foto).astype(np.int16)
    pieno = (a.min(axis=2) < 232)
    unito = ndimage.binary_closing(pieno, iterations=3)
    lab, n = ndimage.label(unito)
    if n == 0:
        return foto
    aree = ndimage.sum(np.ones_like(lab), lab, index=range(1, n + 1))
    grande = max(aree)
    tieni = np.zeros(n + 1, bool)
    for i, ar in enumerate(aree, start=1):
        tieni[i] = ar >= grande * 0.08
    maschera = ndimage.binary_dilation(tieni[lab], iterations=2)
    b = np.asarray(foto).copy()
    b[~maschera] = 255
    ys, xs = np.nonzero(maschera)
    out = Image.fromarray(b)
    if len(xs):
        out = out.crop((max(0, xs.min() - 4), max(0, ys.min() - 4), min(b.shape[1], xs.max() + 5), b.shape[0]))
    return out


# Foto delle carte base che non sono soldati (razzi V1, solo un fucile, civili): non si riusano.
FOTO_ESCLUSE = {15, 24, 25, 42, 60}
# Foto con una striscia di valori stampata sotto: si taglia la parte bassa.
FOTO_TAGLIA_SOTTO = {19: 0.13}


def foto_base(base_cards):
    """Ritratti delle carte base raggruppati per categoria."""
    info = {}
    for n in range(2, 9):
        for k, t in missione(n)["tedeschi"].items():
            info.setdefault(int(k), t)
    pool = {}
    for n, im in base_cards.items():
        if n not in info or n in FOTO_ESCLUSE:
            continue
        ritaglio = im.crop(FOTO_BASE)
        if n in FOTO_TAGLIA_SOTTO:
            ritaglio = ritaglio.crop((0, 0, ritaglio.width, int(ritaglio.height * (1 - FOTO_TAGLIA_SOTTO[n]))))
        foto = pulisci_foto(ritaglio)
        pool.setdefault(categoria(info[n]), []).append((n, foto))
    pool.setdefault("sottufficiale", []).extend(pool.get("ufficiale", []))
    pool.setdefault("jagdpanther", []).extend(pool.get("carro", []))
    for k in pool:
        pool[k].sort(key=lambda x: x[0])
    return pool


def scegli_foto(pool, cat, chiave, usate):
    lista = pool.get(cat) or pool["soldato"]
    h = int(hashlib.md5(chiave.encode()).hexdigest(), 16)
    for i in range(len(lista)):
        n, f = lista[(h + i) % len(lista)]
        if n not in usate:
            usate.add(n)
            return f
    return lista[h % len(lista)][1]


def f(dim, peso="Regular"):
    ft = ImageFont.truetype(FONT, dim)
    try:
        ft.set_variation_by_name(peso)
    except Exception:
        pass
    return ft


def testo_largo(d, xy, s, ft, larg, fill, interl=1.12):
    """Testo a capo entro una larghezza; restituisce la y finale."""
    x, y = xy
    righe = []
    for par in s.split("\n"):
        r = ""
        for w in par.split():
            prova = (r + " " + w).strip()
            if d.textlength(prova, font=ft) <= larg:
                r = prova
            else:
                righe.append(r)
                r = w
        righe.append(r)
    for r in righe:
        d.text((x, y), r, font=ft, fill=fill)
        y += int(ft.size * interl)
    return y


def numero(n):
    return f"{n:+d}" if n else "0"


def disegna_carta(num, t, foto):
    S = 2  # disegno a doppia risoluzione e poi riduco
    im = Image.new("RGB", (W * S, H * S), (255, 255, 255))
    d = ImageDraw.Draw(im)
    m = 14 * S
    # intestazione
    d.rounded_rectangle((m, m, W * S - m, 64 * S), radius=22 * S, fill=(84, 98, 99))
    d.rectangle((m, 40 * S, W * S - m, 64 * S), fill=(84, 98, 99))
    lett = t.get("lettera", "")
    d.text((m + 14 * S, m + 7 * S), f"GE {num % 1000} {lett}".strip(), font=f(32 * S, "Bold"), fill="white")
    ruolo = t.get("ruolo", "Soldato")
    fr = f(28 * S, "Bold")
    while d.textlength(ruolo, font=fr) > (W - 210) * S and fr.size > 14 * S:
        fr = f(fr.size - 2 * S, "Bold")
    d.text((W * S - m - 12 * S - d.textlength(ruolo, font=fr), m + 9 * S + (28 * S - fr.size) // 2), ruolo, font=fr, fill="white")
    # foto a destra
    fy0, fy1 = 66 * S, 400 * S
    if foto is not None:
        fh = fy1 - fy0
        fw = int(foto.width * fh / foto.height)
        maxw = int(236 * S)
        if fw > maxw:
            fh = int(fh * maxw / fw)
            fw = maxw
        ph = foto.resize((fw, fh), Image.LANCZOS)
        im.paste(ph, (W * S - m - fw - 4 * S, fy1 - fh))
    # colonna sinistra: PV, armi, note
    x = m + 16 * S
    y = 78 * S
    pv = int(t.get("pv", 0))
    d.text((x, y), f"+{pv} PV" if pv > 0 else "0 PV", font=f(34 * S, "Bold"), fill=(204, 30, 36))
    y += 52 * S
    armi = [ARMI.get(a, a) for a in t.get("armi", [])]
    if t.get("carro") and not armi:
        armi = ["Cannone", "mitragliatrici"]
    g = int(t.get("granate", 0))
    if g:
        armi.append(f"{g} granate" if g > 1 else "Granata")
    larg = 176 * S
    y = testo_largo(d, (x, y), ", ".join(armi) if armi else "Disarmato", f(21 * S, "Bold"), larg, (25, 25, 25)) + 10 * S
    note = []
    if t.get("pv_cattura"):
        note.append((f"+{t['pv_cattura']} PV SE CATTURATO", (204, 30, 36)))
    if t.get("comandante"):
        note.append(("COMANDANTE", (60, 60, 60)))
    if t.get("primo_turno"):
        note.append((f"AL PRIMO TURNO USA IL {t['primo_turno']}.", (70, 70, 70)))
    if t.get("esplosivi"):
        note.append(("PORTA ESPLOSIVI.", (70, 70, 70)))
    if t.get("mortaio"):
        note.append(("SQUADRA DEL MORTAIO.", (70, 70, 70)))
    for s_, c in note:
        y = testo_largo(d, (x, y), s_, f(17 * S), larg, c) + 6 * S
    # barra delle caratteristiche
    by = 404 * S
    d.rectangle((m, by, W * S - m, by + 40 * S), fill=(103, 116, 117))
    voci = [f"IN: {t.get('IN', 0)}", f"PC: {t.get('PC', 0)}", f"WS: {numero(int(t.get('WS', 0)))}"]
    voci.append(f"MPA: {t.get('MPA', 0)}")
    if "DS" in t:
        voci.append(f"DS: {t['DS']}")
    fs = f(25 * S, "Bold")
    tot = sum(d.textlength(v, font=fs) for v in voci)
    spazio = ((W - 28) * S - tot) / (len(voci) + 1)
    xx = m + spazio
    for v in voci:
        d.text((xx, by + 5 * S), v, font=fs, fill="white")
        xx += d.textlength(v, font=fs) + spazio
    # tabella delle azioni
    ty = by + 44 * S
    d.rounded_rectangle((m, ty, W * S - m, H * S - m), radius=22 * S, fill=(0, 0, 0))
    d.rectangle((m, ty, W * S - m, ty + 22 * S), fill=(0, 0, 0))
    col = t.get("colonne", {})
    cond = [k for k in col if re.match(r"^[\d,\-]+$", k)]
    spec = [k for k in col if k not in cond]
    chiavi = cond + spec
    gruppi = t.get("gruppi", [])
    nc = len(chiavi) + 1
    x0 = m + 10 * S
    larg_t = W * S - 2 * m - 20 * S
    cw = larg_t / nc
    fh_ = f(20 * S)
    if cond:
        cx = x0 + cw + cw * len(cond) / 2
        d.text((cx - d.textlength("Condizione", font=fh_) / 2, ty + 8 * S), "Condizione", font=fh_, fill="white")
    if spec:
        cx = x0 + cw * (1 + len(cond)) + cw * len(spec) / 2
        d.text((cx - d.textlength("Speciale", font=fh_) / 2, ty + 8 * S), "Speciale", font=fh_, fill="white")
    fc = f(22 * S)
    hy = ty + 36 * S
    for i, k in enumerate(["DADO"] + chiavi):
        lab = k.replace(",", "")
        ff = f(18 * S) if i == 0 else fc
        d.text((x0 + cw * i + cw / 2 - d.textlength(lab, font=ff) / 2, hy), lab, font=ff, fill="white")
    righe = max(1, len(gruppi))
    rh = min(34 * S, (H * S - m - 12 * S - (hy + 34 * S)) / righe)
    fv = f(int(min(24 * S, rh * 0.72)))
    for r, gr in enumerate(gruppi):
        ry = hy + 32 * S + r * rh
        if r % 2 == 0:
            d.rectangle((x0, ry + 2 * S, x0 + larg_t, ry + rh - 2 * S), fill=(232, 232, 232))
        colore = (0, 0, 0) if r % 2 == 0 else (255, 255, 255)
        dado = f"{gr[0]}" if gr[0] == gr[1] else f"{gr[0]}-{gr[1]}"
        valori = [dado] + [str(col[k][r]) if r < len(col[k]) else "" for k in chiavi]
        for i, v in enumerate(valori):
            d.text((x0 + cw * i + cw / 2 - d.textlength(v, font=fv) / 2, ry + (rh - fv.size) / 2 - 3 * S), v, font=fv, fill=colore)
        if cond and spec:
            xs = x0 + cw * (1 + len(cond))
            d.line((xs, ry + 4 * S, xs, ry + rh - 4 * S), fill=(120, 120, 120), width=2 * S)
    return im.resize((W, H), Image.LANCZOS)


def main():
    mods, pdf = sys.argv[1], sys.argv[2]
    tts = carte_tts(mods)
    base = {n: im for (mod, n), im in tts.items() if mod == "base"}
    usate_base = set()
    for n in range(1, 9):
        usate_base |= {int(k) for k in missione(n)["tedeschi"]}
    mancanti = sorted(usate_base - set(base))
    dal_pdf = carte_pdf(pdf, set(mancanti))
    for d_ in ("base", "orig/mo", "orig/ph", "orig/ss", "nuove"):
        (OUT / d_).mkdir(parents=True, exist_ok=True)
    for n, im in base.items():
        im.crop(BOX_BASE).resize((W, H), Image.LANCZOS).save(OUT / f"base/ge{n:02d}.jpg", quality=86)
    for n, im in dal_pdf.items():
        im.resize((W, H), Image.LANCZOS).save(OUT / f"base/ge{n:02d}.jpg", quality=86)
    print("base:", len(base), "dal mod,", len(dal_pdf), "dal PDF")
    for (mod, n), im in tts.items():
        if mod != "base":
            # le carte originali sono stampate senza bordo arrotondato: si toglie solo il margine bianco del foglio
            im.resize((W, int(im.height * W / im.width)), Image.LANCZOS).save(OUT / f"orig/{mod}/ge{n:02d}.jpg", quality=86)
    pool = foto_base(base)
    fatte = 0
    for n in range(1, 25):
        mod = modulo_di(n)
        usate = set()
        for k, t in missione(n)["tedeschi"].items():
            num = int(k)
            if mod == "base" and (num in base or num in dal_pdf):
                continue
            cart = OUT / f"nuove/m{n}"
            cart.mkdir(parents=True, exist_ok=True)
            foto = scegli_foto(pool, categoria(t), f"{n}-{num}", usate)
            disegna_carta(num, t, foto).save(cart / f"ge{num:02d}.jpg", quality=86)
            fatte += 1
    print("ricostruite:", fatte)


if __name__ == "__main__":
    main()
