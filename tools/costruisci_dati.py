#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genera i dati di gioco della Missione 1 a partire dalle trascrizioni verificate.

Uscite:
  data/paragrafi.json   paragrafi di missione e azioni tedesche (testo italiano + script)
  data/missione1.json   carte Condizione 1–4 (riferimenti neri, Evento casuale, movimenti rossi),
                        squadra, tedeschi, livelli di attivazione
  data/mappa_a.json     terreno, quote e lati della mappa A

Uso:  python3 tools/costruisci_dati.py
"""
import json
import re
import sys
from pathlib import Path

RADICE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from paragrafi_m1 import P  # noqa: E402
from condizione4 import C4_NERI, C4_ROSSI  # noqa: E402

COLONNE = [chr(65 + i) for i in range(25)]  # A..Y


def sorgente_condizioni():
    """Condizioni 1–3: trascrizione già confrontata riga per riga con le scansioni m1_c1..c3."""
    vecchio = json.loads((RADICE / "tools/condizioni_1_3.json").read_text(encoding="utf-8"))
    out = {}
    for c in ("1", "2", "3"):
        cd = vecchio[c]
        ev = {str(n): cd["events"].get(str(n), "NONE") for n in range(19)}
        out[c] = {"esagoni": cd["hexes"], "evento": ev, "movimenti": {}}
    esagoni, evento = {}, {}
    for n, riga in C4_NERI.items():
        valori, re_ = riga.split("|")
        valori = valori.split()
        assert len(valori) == 25, n
        if n <= 18:
            evento[str(n)] = re_.strip()
        if n == 0:
            continue
        for i, v in enumerate(valori):
            esagoni[f"{COLONNE[i]}{n}"] = v
    out["4"] = {"esagoni": esagoni, "evento": evento, "movimenti": C4_ROSSI}
    return out


SQUADRA = [
    # id, nome, IN, PC, WS, DS, MPA, comandante, porte, munizioni
    ("A", "Alex", 4, 6, 2, 2, 4, True, ["ar"], {"ar": 5, "granata": 1}),
    ("B", "Bradley", 3, 5, 0, 4, 4, False, ["carbine"], {"carbine": 5, "granata": 1}),
    ("C", "Charles", 3, 4, 0, 4, 4, False, ["carbine", "bazooka"], {"carbine": 3, "bazooka": 2, "granata": 1}),
    ("D", "David", 2, 4, 0, 6, 4, False, ["carbine"], {"carbine": 5, "granata": 1}),
    ("E", "Encio", 2, 3, -1, 4, 4, False, ["sar"], {"sar": 5, "granata": 1}),
    ("F", "Frankie", 2, 5, 0, 6, 4, False, ["sar", "satchel"], {"sar": 3, "granata": 3}),
    ("G", "Gerald", 2, 3, 1, 4, 4, False, ["ar"], {"ar": 5, "granata": 1}),
    ("H", "Harold", 2, 3, 1, 6, 4, False, ["sar", "satchel"], {"sar": 4, "granata": 2}),
]

# Carte dei tedeschi della missione 1, verificate sulle immagini del modulo TTS.
TEDESCHI = {
    1: dict(lettera="Q", ruolo="Soldato", pv=1, armi=["mp"], granate=0, IN=1, PC=2, WS=-1, MPA=3,
            gruppi=[[0, 2], [3, 3], [4, 7], [8, 9]],
            colonne={"2-3": [808, 824, 802, 800], "4": [920, 803, 809, 813], "A": [808, 824, 802, 800], "S": [813, 816, 802, 839]}),
    9: dict(lettera="R", ruolo="Soldato", pv=1, armi=["scoped"], granate=0, IN=2, PC=3, WS=0, MPA=4,
            gruppi=[[0, 3], [4, 6], [7, 8], [9, 9]],
            colonne={"3": [801, 915, 800, 825], "4": [916, 800, 809, 916], "S": [839, 971, 816, 813]}),
    15: dict(lettera="L", ruolo="Cecchino", pv=1, armi=["scoped"], granate=1, IN=3, PC=5, WS=0, MPA=4,
             gruppi=[[0, 3], [4, 6], [7, 8], [9, 9]],
             colonne={"3": [802, 808, 915, 800], "4": [915, 917, 800, 809], "S": [833, 833, 971, 816]}),
    25: dict(lettera="N", ruolo="Cecchino", pv=2, armi=["scoped", "pistol"], granate=0, IN=4, PC=7, WS=1, MPA=4,
             gruppi=[[0, 0], [1, 2], [3, 5], [6, 9]],
             colonne={"2-3": [802, 829, 808, 801], "4": [800, 919, 919, 918], "B": [829, 808, 801, 801], "S": [816, 971, 802, 839]}),
    34: dict(lettera="X", ruolo="Ufficiale", pv=1, armi=["mp", "pistol"], granate=0, IN=4, PC=6, WS=1, MPA=4,
             pv_cattura=2, condizione_se_perso=4, comandante=True,
             gruppi=[[0, 1], [2, 2], [3, 6], [7, 9]],
             colonne={"2": [965, 835, 802, 829], "3": [808, 914, 913, 835], "4": [804, 805, 836, 837], "B": [831, 829, 808, 832], "S": [971, 816, 839, 813]}),
    53: dict(lettera="S", ruolo="Soldato", pv=1, armi=["bolt"], granate=1, IN=2, PC=4, WS=0, MPA=4,
             gruppi=[[0, 2], [3, 6], [7, 7], [8, 9]],
             colonne={"2-3": [808, 802, 800, 829], "4": [838, 919, 838, 800], "B": [802, 801, 829, 808], "S": [839, 833, 971, 816]}),
    81: dict(lettera="P", ruolo="Soldato", pv=1, armi=["bolt"], granate=0, IN=1, PC=1, WS=-2, MPA=3,
             gruppi=[[0, 2], [3, 3], [4, 7], [8, 9]],
             colonne={"2-3": [800, 801, 808, 801], "4": [813, 920, 809, 825], "A": [800, 801, 808, 802], "S": [816, 839, 813, 800]}),
}


def costruisci_mappa():
    vecchia = json.loads((RADICE / "tools/mappa_a_revisionata.json").read_text(encoding="utf-8"))
    campioni = json.loads((RADICE / "tools/quote_campioni.json").read_text(encoding="utf-8"))
    esagoni = {}
    for h, r in vecchia["hexes"].items():
        esagoni[h] = {"t": r["terrain"], "q": int(r["elevation"]), "presunta": bool(r.get("elevation_assumed"))}

    def vicini(h):
        q = ord(h[0]) - 65
        row = int(h[1:])
        dirs_even = [(0, -1), (1, -1), (1, 0), (0, 1), (-1, 0), (-1, -1)]
        dirs_odd = [(0, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0)]
        for dq, dr in (dirs_odd if q & 1 else dirs_even):
            nq, nr = q + dq, row + dr
            if 0 <= nq < 25 and 1 <= nr <= 19:
                yield f"{chr(65 + nq)}{nr}"

    # Quote presunte: maggioranza dei vicini con quota verificata (le zone di quota sono contigue).
    for h, r in esagoni.items():
        if not r["presunta"]:
            continue
        b = campioni.get(h, [None])[0]
        if r["t"] == "clear" and b is not None:
            r["q"] = 1 if b >= 242 else 2
            continue
        voti = [esagoni[v]["q"] for v in vicini(h) if not esagoni[v]["presunta"]]
        if voti:
            r["q"] = max(set(voti), key=voti.count)
    # Alture di sud-est (livello 3, colore giallo più carico): il briefing le delimita con il cambio
    # di quota che va da Q19 a Y13. Si misura il giallo del fondo (G−B) nel quadrante sud-est
    # e si uniforma con la maggioranza dei vicini (gli esagoni di bosco non hanno fondo visibile).
    giallo = json.loads((RADICE / "tools/giallo_campioni.json").read_text(encoding="utf-8"))
    def nel_quadrante(h):
        return ord(h[0]) - 65 >= 15 and int(h[1:]) >= 12
    alto = {h: (giallo[h] >= 33 if giallo[h] >= 0 else None) for h in esagoni if nel_quadrante(h)}
    for _ in range(3):
        nuovo = {}
        for h, v in alto.items():
            voti = [alto[n] for n in vicini(h) if n in alto and alto[n] is not None]
            si = sum(1 for x in voti if x)
            if v is None:
                nuovo[h] = si * 2 >= len(voti) if voti else False
            else:
                nuovo[h] = v if abs(si * 2 - len(voti)) <= 2 else si * 2 > len(voti)
        alto = nuovo
    for h, v in alto.items():
        if v and esagoni[h]["q"] == 2:
            esagoni[h]["q"] = 3
    # Ponte di pietra sulla strada in M12.
    esagoni["M12"]["ponte"] = True
    for r in esagoni.values():
        r.pop("presunta")
    lati = {k: v for k, v in vecchia["hexsides"].items()}
    # S13 e T12 sono entrambi sull’altura: tra loro non c’è scarpata (la linea tratteggiata passa a nord-ovest).
    lati.pop("S13|T12", None)
    return {"mappa": "A", "esagoni": esagoni, "lati": lati,
            "note": "Terreno e lati dall'ultima revisione manuale; quote presunte ricavate dai vicini; livello 3 a sud-est della linea Q19–Y13; ponte in M12."}


def main():
    cond = sorgente_condizioni()
    # Controllo: ogni riferimento delle carte deve esistere tra i paragrafi.
    mancanti = set()
    for c in cond.values():
        for v in list(c["esagoni"].values()) + list(c["evento"].values()) + list(c["movimenti"].values()):
            for num in re.findall(r"\d{3}", v):
                if num not in P:
                    mancanti.add(num)
    for g in TEDESCHI.values():
        for col in g["colonne"].values():
            for num in col:
                if str(num) not in P:
                    mancanti.add(str(num))

    def visita(ops):
        for o in ops:
            if o.get("op") == "goto" and o["p"] not in P:
                mancanti.add(o["p"])
            for k in ("ok", "ko", "then", "else", "any", "all_fail"):
                if k in o:
                    visita(o[k])
            if o.get("op") == "die":
                for _, _, b in o["b"]:
                    visita(b)
    for p in P.values():
        visita(p["ops"])
    if mancanti:
        sys.exit("Paragrafi mancanti: " + ", ".join(sorted(mancanti)))

    missione = {
        "id": "missione_1",
        "titolo": "Sangue a Saint-Michaux",
        "titolo_originale": "Bloody St. Mick",
        "data": "Normandia, fine giugno 1944",
        "briefing": "Fine giugno 1944. La divisione da cui dipende la tua squadra avanza con cautela nel bocage normanno. Stamattina un’altra squadra è stata mandata avanti per prendere un tratto trasversale della strada di Saint-Michaux che, in mano alleata, collegherebbe le forze britanniche a est con quelle americane a ovest. Sotto il fuoco intenso di cecchini nascosti, la squadra ha dovuto ripiegare. Questo pomeriggio tocca ai tuoi uomini, più esperti: assicurare il controllo della strada di Saint-Michaux.",
        "ingresso": "I soldati entrano in qualsiasi esagono del margine nord tra A1 e J1 compresi. All’inizio non ci sono segnalini sulla mappa. Il corso d’acqua è un ruscello.",
        "vittoria_pv": 13,
        "attivazione": {"1": 1, "2": 3, "3": 5, "4": 8},
        "squadra": [
            {"id": i, "nome": n, "IN": a, "PC": p, "WS": w, "DS": d, "MPA": m, "comandante": c, "porte": porte, "munizioni": mun}
            for i, n, a, p, w, d, m, c, porte, mun in SQUADRA
        ],
        "tedeschi": {str(k): v for k, v in TEDESCHI.items()},
        "condizioni": cond,
    }
    (RADICE / "data").mkdir(exist_ok=True)
    (RADICE / "data/missione1.json").write_text(json.dumps(missione, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (RADICE / "data/paragrafi.json").write_text(json.dumps(P, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (RADICE / "data/mappa_a.json").write_text(json.dumps(costruisci_mappa(), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Paragrafi: {len(P)}  Condizioni: {len(cond)}  Tedeschi: {len(TEDESCHI)}")


if __name__ == "__main__":
    main()
