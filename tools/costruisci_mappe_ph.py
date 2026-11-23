#!/usr/bin/env python3
"""Dati del terreno delle mappe di Purple Heart.
- data/mappa_ad.json: mappa A (righe 1–9) + mezza mappa D (righe 10–19, tools/terreno_d.json)
- data/mappa_be.json: mappa B (righe 1–9) + mezza mappa E (righe 10–19, tools/terreno_e.json)
- data/mappa_c.json: mappa C intera (tools/terreno_c.json)
I file tools/terreno_*.json sono la classificazione per colore corretta a vista
(tipo t, quota q; "bridge" diventa ruscello con ponte). Tutti i lati esterni degli
edifici sono finestre (approssimazione); muretti, scarpate e creste in tools/lati_*.json."""
import json, pathlib
R = pathlib.Path(__file__).resolve().parent.parent
COL = "ABCDEFGHIJKLMNOPQRSTUVWXY"
EDIFICI = ("stone_building", "wood_building")


def vicini(h):
    q = COL.index(h[0]); r = int(h[1:])
    pari = [(0, -1), (1, -1), (1, 0), (0, 1), (-1, 0), (-1, -1)]; dis = [(0, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0)]
    for dq, dr in (dis if q & 1 else pari):
        if 0 <= q + dq < 25 and 1 <= r + dr <= 19:
            yield f"{COL[q+dq]}{r+dr}"


def lato(a, b):
    ka = (COL.index(a[0]), int(a[1:])); kb = (COL.index(b[0]), int(b[1:]))
    return f"{a}|{b}" if ka < kb else f"{b}|{a}"


def converti(T):
    out = {}
    for h, v in T.items():
        e = {"t": v["t"], "q": int(v.get("q", 1) or 1)}
        if v["t"] == "bridge":
            e = {"t": "stream", "q": e["q"], "ponte": True}
        if v.get("ponte"):
            e["ponte"] = True
        out[h] = e
    return out


def finestre(es, lati, righe):
    for h, v in es.items():
        if int(h[1:]) not in righe or v["t"] not in EDIFICI:
            continue
        for n in vicini(h):
            if es.get(n, {}).get("t") not in EDIFICI:
                lati.setdefault(lato(h, n), "window")


def lati_extra(nome):
    p = R / "tools" / f"lati_{nome}.json"
    return json.loads(p.read_text()) if p.exists() else {}


def unisci(base, mezza, lettera, nota):
    b = json.loads((R / "data" / f"mappa_{base}.json").read_text())
    T = converti(json.loads((R / "tools" / f"terreno_{mezza}.json").read_text()))
    es = {h: v for h, v in b["esagoni"].items() if int(h[1:]) <= 9}
    es.update({h: v for h, v in T.items() if int(h[1:]) >= 10})
    lati = {k: v for k, v in b["lati"].items() if all(int(x[1:]) <= 9 for x in k.split("|"))}
    finestre(es, lati, range(10, 20))
    lati.update(lati_extra(mezza))
    dati = {"mappa": lettera, "esagoni": es, "lati": lati, "alture_obiettivo": [], "note": nota}
    if b.get("campanile") and int(b["campanile"][1:]) <= 9:
        dati["campanile"] = b["campanile"]
    (R / "data" / f"mappa_{lettera.lower()}.json").write_text(json.dumps(dati, ensure_ascii=False, indent=0))
    print("scritta", lettera, len(es), len(lati))


def intera(nome, lettera, nota):
    p = R / "tools" / f"terreno_{nome}.json"
    if not p.exists():
        return
    es = converti(json.loads(p.read_text()))
    lati = {}
    finestre(es, lati, range(1, 20))
    lati.update(lati_extra(nome))
    (R / "data" / f"mappa_{lettera.lower()}.json").write_text(json.dumps(
        {"mappa": lettera, "esagoni": es, "lati": lati, "alture_obiettivo": [], "note": nota}, ensure_ascii=False, indent=0))
    print("scritta", lettera, len(es), len(lati))


if __name__ == "__main__":
    unisci("a", "d", "AD", "Mappa A con la mezza mappa D (base navale) sulle righe 10–19: terreno di D letto per colore e corretto a vista.")
    if (R / "tools/terreno_e.json").exists():
        unisci("b", "e", "BE", "Mappa B con la mezza mappa E (città) sulle righe 10–19: terreno di E letto per colore e corretto a vista.")
    intera("c", "C", "Mappa C: terreno letto per colore e corretto a vista.")
