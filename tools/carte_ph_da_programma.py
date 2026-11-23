#!/usr/bin/env python3
"""Ricava tools/carte_ph.json (carte dei tedeschi e dei mezzi di Purple Heart) dal database del programma d’aiuto
«ePurpleHeart» (AmbSoldierCards.USR e AmbSoldierCardRecords.USR, FileMaker 5). PM e guida (DS), che il database non ha,
sono letti a vista dal foglio stampato delle carte (bgg9583.pdf).
Uso: python3 tools/carte_ph_da_programma.py <cartella del programma>"""
import json, pathlib, re, sys
QUI = pathlib.Path(__file__).parent
sys.path.insert(0, str(QUI))
from fm5 import records

MPA = {4: 4, 6: 4, 8: 4, 9: 4, 10: 4, 11: 4, 12: 5, 14: 4, 15: 4, 16: 4, 17: 4, 19: 4, 20: 5, 21: 5, 22: 4, 23: 3,
       24: 4, 25: 4, 26: 4, 27: 4, 28: 4, 29: 4, 33: 4, 34: 4, 35: 4, 36: 5, 37: 4, 38: 4, 39: 4, 40: 5, 41: 4, 42: 4,
       44: 4, 45: 4, 48: 3, 49: 4, 50: 4, 52: 4, 53: 4, 55: 4, 56: 3, 61: 4, 62: 5, 63: 4, 64: 4, 65: 4, 66: 4}
DS = {4: 8, 6: 8, 8: 8, 16: 8, 48: 8, 52: 8, 53: 6}
# Equipaggi dei mezzi: guida (DS) per livello di equipaggio, dal foglio stampato.
DS_EQ = {43: [2, 4, 6, 8, 8], 57: [2, 4, 6, 6, 8], 58: [2, 4, 6, 8, 8], 59: [2, 4, 6, 8, 8], 60: [2, 4, 6, 6, 6],
         69: [2, 4, 6, 8, 8], 67: [2, 4, 6, 8, 8], 68: [2, 4, 6, 8, 8]}
DS_EQ_US = {1: [4, 6, 6, 8, 8], 2: [4, 4, 6, 8, 8], 3: [6, 8, 8, 8, 8]}
MPA_US = {4: 3, 5: 3}
DS_US = {5: 6}


def armi(t):
    a = []
    if "Machine Pistol" in t: a.append("mp")
    if re.search(r"(?<!Machine )Pistol", t): a.append("pistol")
    if "Scope" in t: a.append("scoped")
    elif "Bolt Rifle" in t: a.append("bolt")
    if "Light Machinegun" in t: a.append("lmg")
    elif "Heavy Machinegun" in t: a.append("hmg")
    elif "Machinegun" in t: a.append("mmg")
    if "Panzerfaust" in t: a.append("pzf")
    if "Semi" in t: a.append("sar")
    return a


# Carte con dati incompleti nel database: lette a vista dal foglio stampato (gruppi di dadi, colonne).
FISSE = {
    "GE45": {"IN": 3, "PC": 5, "WS": 0, "gruppi": [[0, 3], [4, 5], [6, 6], [7, 9]],
             "colonne": {"1-3": [866, 865, 750, 821], "S": [833, 839, 812, 859], "L": [802, 801, 800, 869]}},
    "GE48": {"IN": 1, "PC": 1, "WS": -2, "gruppi": [[0, 2], [3, 4], [5, 7], [8, 9]],
             "colonne": {"1-4": [826, 826, 826, 826], "S": [859, 833, 839, 971], "A": [624, 624, 627, 627],
                         "B": [661, 661, 661, 661], "C": [659, 659, 659, 659]}},
    "GE49": {"IN": 2, "PC": 5, "WS": 0, "gruppi": [[0, 0], [1, 3], [4, 6], [7, 9]],
             "colonne": {"1-3": [801, 802, 829, 808], "4": [855, 855, 855, 855], "S": [971, 839, 833, 859],
                         "A": [627, 627, 624, 624], "B": [661, 661, 661, 661], "C": [659, 659, 659, 659]}},
    "GE52": {"IN": 3, "PC": 7, "WS": 1, "gruppi": [[0, 0], [1, 2], [3, 5], [6, 9]],
             "colonne": {"1-3": [872, 872, 876, 876], "4": [881, 881, 886, 886], "S": [833, 971, 839, 859], "L": [889, 893, 898, 889]}},
    "GE55": {"IN": 4, "PC": 7, "WS": 1, "gruppi": [[0, 2], [3, 5], [6, 7], [8, 9]],
             "colonne": {"1-2": [959, 815, 848, 815], "3": [771, 769, 761, 848], "4": [804, 785, 783, 780], "S": [833, 971, 859, 839]}},
    "GE61": {"IN": 2, "PC": 5, "WS": 1, "gruppi": [[0, 2], [3, 3], [4, 6], [7, 9]],
             "colonne": {"1": [403, 403, 411, 428], "2-4": [825, 800, 573, 858], "S": [839, 800, 971, 971], "A": [825, 800, 808, 829]}},
    "GE65": {"armi": ["mp", "pistol"], "granate": 2, "armi_testo": "Machine Pistol; Pistol (Luger); 2 Grenades"},
    "GE66": {"IN": 2, "PC": 4, "WS": 1, "gruppi": [[0, 0], [1, 4], [5, 5], [6, 9]],
             "colonne": {"1-2": [801, 825, 800, 842], "3-4": [802, 825, 711, 801], "S": [840, 800, 833, 971]}},
}
EQ_FISSI = {
    "GE68": {"5": [5, 8, 2, [758, 747, 736, 733]], "4": [4, 7, 1, [733, 736, 747, 758]], "3": [3, 6, 0, [776, 776, 763, 763]],
             "2": [3, 4, -2, [849, 849, 847, 847]], "1": [1, 2, -2, [873, 873, 873, 873]], "_gruppi": [[0, 2], [3, 5], [6, 7], [8, 9]]},
    "US3": {"5": [5, 6, 1, [946, 939, 939, 946]], "4": [3, 3, 0, [939, 946, 946, 939]], "3": [2, 2, 0, [956, 956, 956, 956]],
            "2": [1, 1, 0, [956, 956, 956, 956]], "1": [1, 0, 0, [969, 969, 969, 969]], "_gruppi": [[0, 3], [4, 6], [7, 8], [9, 9]]},
}


def gruppi(colonne):
    """Raggruppa i dadi 0–9 con le stesse azioni in tutte le colonne."""
    g = []
    for d in range(10):
        riga = tuple(c[d] for c in colonne.values())
        if g and g[-1][2] == riga:
            g[-1][1] = d
        else:
            g.append([d, d, riga])
    return [[a, b] for a, b, _ in g], {k: [c[a] for a, b, _ in g] for k, c in colonne.items()}


def main(cartella):
    cart = pathlib.Path(cartella)
    meta = {}
    for f in records(cart / "AmbSoldierCards.USR"):
        m = re.match(r"Purple Heart!_(GE|US)_(\d+)$", f.get("M", ""))
        if m and str(f.get("F", "")).isdigit():
            meta[f"{m.group(1)}{int(m.group(2))}"] = f
    righe = {}
    for f in records(cart / "AmbSoldierCardRecords.USR"):
        m = re.match(r"Purple Heart!_(GE|US)_(\d+)", f.get("M", ""))
        if m:
            righe.setdefault(f"{m.group(1)}{int(m.group(2))}", []).append(f)
    out = {}
    for k, f in sorted(meta.items(), key=lambda x: (x[0][:2], int(x[0][2:]))):
        lato, num = k[:2], int(k[2:])
        rr = righe.get(k, [])
        def valori(r):
            v = [r.get("T", "")] + [r.get("T*", {}).get(str(i), r.get("T*", {}).get(i, "")) for i in range(2, 11)]
            return [int(x) if str(x).isdigit() else None for x in v]
        vp = f.get("J", "")
        pv = int(re.search(r"\+\s*(\d+)", vp).group(1)) if re.search(r"\+\s*(\d+)", vp) else 0
        cat = re.search(r"\+\s*(\d+)\s*VP\s*if\s*captured", vp, re.I)
        ko = re.search(r"\+\s*(\d+)\s*VP\s*if\s*(knocked out|sunk)", vp, re.I)
        c = {"lato": lato, "num": num, "lettera": f.get("G", ""), "ruolo": f.get("I", ""), "pv": pv, "pv_testo": vp,
             "armi_testo": f.get("K", ""), "note": f.get("L", "")}
        if "when inactive" in vp.lower():
            c["pv_inattivo"] = True
        if cat:
            c["pv_cattura"] = int(cat.group(1))
        if ko:
            c["pv_distrutto"] = int(ko.group(1))
        mezzo = rr and all(str(r.get("S", "")).isdigit() and len(rr) >= 4 for r in rr) and lato == "GE" and num in DS_EQ or lato == "US" and num in DS_EQ_US
        if mezzo:
            eq = {}
            ds = DS_EQ.get(num) if lato == "GE" else DS_EQ_US[num]
            for r in rr:
                n = int(r["S"])
                v = valori(r)
                eq[str(n)] = {"IN": int(r.get("X", 0)), "PC": int(r.get("Y", 0)), "WS": int(str(r.get("Z", "0")).replace("+", "")),
                              "DS": ds[n - 1], "valori": v}
            c["veicolo"] = True
            c["equipaggio"] = eq
            c["primo_turno"] = int(f["X"]) if str(f.get("X", "")).isdigit() else 0
        else:
            colonne = {}
            for r in rr:
                colonne[str(r.get("S", "?"))] = valori(r)
            if rr:
                prima = rr[0]
                c.update({"IN": int(prima.get("X", 0)), "PC": int(prima.get("Y", 0)), "WS": int(str(prima.get("Z", "0")).replace("+", ""))})
            c["MPA"] = MPA.get(num, 4) if lato == "GE" else MPA_US.get(num, 4)
            if (DS if lato == "GE" else DS_US).get(num):
                c["DS"] = (DS if lato == "GE" else DS_US)[num]
            c["armi"] = armi(c["armi_testo"])
            g = re.search(r"(\d)\s*Grenades?", c["armi_testo"])
            c["granate"] = int(g.group(1)) if g else (1 if "Grenade" in c["armi_testo"] else 0)
            e = re.search(r"(\d)\s*Explosive", c["armi_testo"])
            if e:
                c["esplosivi"] = int(e.group(1))
            if colonne:
                c["gruppi"], c["colonne"] = gruppi(colonne)
        out[k.replace("GE", "GE").replace("US", "US")] = c
    for k, f in FISSE.items():
        out[k].update(f)
    if "US3" not in out:
        out["US3"] = {"lato": "US", "num": 3, "lettera": "CC", "ruolo": "Sherman Tank", "pv": 0, "pv_testo": "", "armi_testo": "",
                      "note": "Enters open; cannon prepared. When open, 3 crew exposed. On first turn, conduct 944.",
                      "veicolo": True, "primo_turno": 944, "equipaggio": {}}
    for k, e in EQ_FISSI.items():
        gr = e["_gruppi"]
        ds = DS_EQ.get(int(k[2:])) if k.startswith("GE") else DS_EQ_US[int(k[2:])]
        for n, (i, pc, ws, vv) in ((n, v) for n, v in e.items() if n != "_gruppi"):
            val = [None] * 10
            for (a, b), x in zip(gr, vv):
                for d in range(a, b + 1):
                    val[d] = x
            out[k]["equipaggio"][n] = {"IN": i, "PC": pc, "WS": ws, "DS": ds[int(n) - 1], "valori": val}
    # Le carte del foglio del mod TTS (OCR verificato) restano quelle buone; il database corregge solo GE23.
    foglio = json.loads((QUI / "carte_ph_foglio.json").read_text())
    for k, c in foglio.items():
        c = dict(c)
        c.pop("lato", None)
        out.setdefault(k, {}).update(c)
        out[k]["lato"] = "GE"
    out["GE23"]["colonne"]["S"] = [859, 839, 833, 971]
    out["GE23"]["colonne"]["X"] = [846, 848, 852, 846]
    (QUI / "carte_ph.json").write_text(json.dumps(out, ensure_ascii=False, indent=1))
    print(len(out), "carte:", " ".join(sorted(out, key=lambda x: (x[:2], int(x[2:])))))


if __name__ == "__main__":
    main(sys.argv[1])
