#!/usr/bin/env python3
"""Costruisce le missioni di Silver Star (19–24) e data/paragrafi_ss.json.

Fonti:
- data/carte/missioneN.json  carte Condizione trascritte (tools/carte_ss_trascritte.py)
- tools/paragrafi_ss<n>.py   testo italiano e ops dei paragrafi di ciascuna missione
- le carte tedesche GE10–GE71 della Missione 19, rilette a mano dal foglio del mod TTS (tools/carte_ss_grezze.json)
- data/missione1.json        squadra pre-generata (riarmata secondo il briefing)
"""
import importlib, json, pathlib, sys

R = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(R / "tools"))
M1 = json.loads((R / "data/missione1.json").read_text())
COL = "ABCDEFGHIJKLMNOPQRSTUVWXY"


def carta(lettera, ruolo, pv, armi, granate, IN, PC, WS, DS, MPA, gruppi, colonne, righe, **extra):
    """righe: una lista di valori per gruppo, nell’ordine delle colonne."""
    d = {"lettera": lettera, "ruolo": ruolo, "pv": pv, "armi": armi, "granate": granate, "IN": IN, "PC": PC, "WS": WS, "DS": DS,
         "MPA": MPA, "gruppi": gruppi, "colonne": {c: [r[i] for r in righe] for i, c in enumerate(colonne)}}
    d.update(extra)
    return d


C6 = ["1-2", "S", "A", "B", "D", "T"]
C5 = ["1-2", "S", "A", "B", "D"]
TEDESCHI_19 = {
    "10": carta("M", "Autista del camion", 2, ["bolt", "pistol"], 1, 4, 6, 1, 8, 4, [[0, 1], [2, 5], [6, 8], [9, 9]], C6,
                [[803, 812, 859, 347, 869, 565], [807, 833, 860, 344, 825, 565], [819, 817, 857, 343, 824, 565],
                 [809, 816, 858, 345, 808, 565]], ignora_s_veicolo=True),
    "11": carta("R", "Assistente autista", 0, ["bolt", "pistol"], 2, 2, 4, 0, 6, 4, [[0, 1], [2, 2], [3, 5], [6, 9]], C6,
                [[862, 817, 857, 343, 842, 566], [863, 816, 858, 344, 856, 566], [864, 833, 856, 345, 858, 566],
                 [865, 839, 802, 347, 857, 566]], ignora_s_veicolo=True),
    "12": carta("X", "Soldato", 0, ["mp"], 2, 3, 6, -1, 8, 4, [[0, 1], [2, 2], [3, 5], [6, 9]], C6,
                [[866, 859, 860, 344, 869, 567], [868, 800, 869, 345, 808, 567], [867, 817, 770, 347, 824, 567],
                 [819, 839, 801, 343, 825, 567]], ignora_s_veicolo=True),
    "13": carta("W", "Soldato", 0, ["mp"], 1, 2, 5, -1, 6, 4, [[0, 2], [3, 4], [5, 5], [6, 9]], C6,
                [[868, 816, 857, 344, 842, 566], [863, 839, 856, 347, 858, 566], [866, 868, 801, 343, 860, 566],
                 [864, 817, 856, 345, 861, 566]], ignora_s_veicolo=True),
    "14": carta("V", "Soldato", 0, ["mp"], 2, 0, 2, -1, 0, 3, [[0, 1], [2, 2], [3, 6], [7, 9]], C6,
                [[803, 839, 859, 347, 856, 567], [800, 821, 857, 345, 857, 567], [807, 817, 860, 344, 801, 567],
                 [808, 833, 858, 343, 802, 567]], ignora_s_veicolo=True),
    "15": carta("N", "Capitano", 2, ["mp", "pistol"], 1, 5, 7, 0, 8, 5, [[0, 1], [2, 4], [5, 6], [7, 9]], C6,
                [[823, 817, 856, 344, 832, 568], [863, 823, 860, 343, 861, 568], [822, 859, 861, 347, 835, 568],
                 [866, 825, 857, 345, 860, 568]], ignora_s_veicolo=True, comandante=True, pv_cattura=2),
    "51": carta("P", "Guarnigione", 0, ["mp"], 2, 1, 3, 0, 4, 3, [[0, 2], [3, 4], [5, 5], [6, 9]], C5,
                [[866, 812, 782, 345, 801], [863, 817, 782, 344, 869], [840, 839, 800, 347, 817], [868, 821, 782, 343, 802]]),
    "52": carta("Z", "Guarnigione", 0, ["bolt"], 2, 5, 9, 0, 4, 5, [[0, 1], [2, 3], [4, 5], [6, 9]], C5,
                [[862, 833, 784, 343, 869], [866, 812, 784, 347, 801], [863, 817, 784, 345, 802], [803, 840, 784, 344, 842]]),
    "53": carta("Q", "Guarnigione", 0, ["mp"], 2, 0, 0, -2, 0, 3, [[0, 4], [5, 5], [6, 7], [8, 9]], C5,
                [[803, 817, 785, 345, 801], [809, 833, 844, 343, 808], [807, 839, 785, 344, 802], [868, 821, 785, 347, 817]]),
    "54": carta("S", "Guarnigione", 0, ["bolt"], 2, 2, 3, -2, 2, 4, [[0, 2], [3, 4], [5, 5], [6, 9]], C5,
                [[803, 859, 786, 347, 802], [867, 825, 786, 345, 869], [868, 817, 786, 343, 860], [865, 833, 786, 344, 801]]),
    "60": carta("U", "Barca di guardia", 1, ["bolt"], 99, 2, 5, 0, 4, 4, [[0, 9]], ["1-2"], [[911]], pv_eliminata=2,
                equipaggio={"3": {"IN": 2, "PC": 5, "WS": 0, "par": [911, 912, 913, 914]},
                            "2": {"IN": 2, "PC": 3, "WS": 0, "par": [914, 911, 912, 913]},
                            "1": {"IN": 1, "PC": 3, "WS": -1, "par": [912, 913, 911, 914]}}),
    "61": carta("L", "Barca di guardia", 1, ["bolt"], 99, 3, 6, 1, 4, 4, [[0, 9]], ["1-2"], [[915]], pv_eliminata=2,
                equipaggio={"3": {"IN": 3, "PC": 6, "WS": 1, "par": [918, 916, 915, 917]},
                            "2": {"IN": 3, "PC": 4, "WS": 1, "par": [916, 917, 918, 915]},
                            "1": {"IN": 1, "PC": 2, "WS": -1, "par": [915, 918, 917, 916]}}),
    "70": carta("Y", "Sommozzatore", 1, ["pistol"], 1, 4, 6, 0, 8, 4, [[0, 9]], ["1", "2", "S"], [[233, 672, 348]],
                pv_cattura=2, sub=True),
    "71": carta("T", "Sommozzatore", 0, ["pistol"], 1, 3, 5, 1, 2, 4, [[0, 9]], ["1", "2", "S"], [[564, 672, 348]], sub=True),
}

# Squadra pre-generata riarmata: solo carabine, mitra, pistole, bazooka e granate; E–H sono i sommozzatori.
ARMI_19 = {"A": (["smg"], {"smg": 5, "granata": 2}), "B": (["carbine"], {"carbine": 5, "granata": 2}),
           "C": (["carbine", "bazooka"], {"carbine": 3, "bazooka": 3, "granata": 1}), "D": (["smg"], {"smg": 4, "granata": 2}),
           "E": (["pistol"], {"pistol": 3, "granata": 2}), "F": (["smg"], {"smg": 3, "granata": 2}),
           "G": (["pistol"], {"pistol": 3, "granata": 2}), "H": (["carbine"], {"carbine": 3, "granata": 2})}


def condizioni(n):
    d = json.loads((R / f"data/carte/missione{n}.json").read_text())
    return {c: {"esagoni": v["esagoni"], "evento": v["evento"], "movimenti": v["movimenti"]} for c, v in d.items()}


MISSIONI = {
    19: {
        "titolo": "Fradici", "titolo_originale": "All Wet",
        "data": "Sicilia, presso Messina, agosto 1943", "mappa": "FH", "nord": "a destra (in alto è ovest)", "libro": "ss",
        "briefing": "Agosto 1943. Secondo l’intelligence i tedeschi ammassano rifornimenti per una controffensiva in una piccola "
                    "cala vicino a Messina. La squadra deve verificare la notizia e, se è vera, distruggere quante più scorte "
                    "possibile. Si viaggia leggeri e veloci: due canoe, quattro sommozzatori con autorespiratori, coltelli ed "
                    "esplosivi a tempo.",
        "ingresso": "Mezza mappa H sopra la mappa F; in alto è ovest. La squadra entra in A1 di notte: due uomini per canoa e due "
                    "sommozzatori aggrappati ai fianchi di ogni canoa (in superficie) finché un paragrafo non dice altrimenti. "
                    "Ponte di pietra intatto in T7 (da T6 a T8), guado in K12 (da K11 a K13). Livelli di attivazione: "
                    "Condizione 1 da 0 a 5, Condizione 2 da 0 a 8.",
        "regole_testo": "[b]Notte.[/b] Si vede fino a 3 esagoni. [b]Dirupi.[/b] Gli esagoni XXX delle carte sono invalicabili. "
                        "[b]Coltelli.[/b] A, B, C e D hanno un coltello: +1 all’abilità nell’assalto (massimo +2). "
                        "[b]Esplosivi a tempo.[/b] Li portano solo i sommozzatori (E, F, G, H): un’azione nell’esagono di una "
                        "chiatta per applicarlo; salta alla fine del Round successivo (ratés 05). [b]Nuoto.[/b] In acqua si "
                        "spendono 2 PM per esagono; il cambio di postura è gratuito: in piedi si è in superficie, proni sott’acqua "
                        "(solo i sommozzatori). Sott’acqua si vede e si è visti solo nello stesso esagono o in uno adiacente e non "
                        "si spara; in superficie si spara solo di rapido e mai col bazooka. Chi spara a un nuotatore ha −4. "
                        "[b]Canoe.[/b] Si muovono con due uomini a bordo; i sommozzatori aggrappati le seguono.",
        "ingresso_breve": "A1, in canoa", "uscita_breve": "A1 (dopo il 789)",
        "ingresso_esagoni": ["A1"], "uscita_esagoni": ["A1"],
        "vittoria_pv": 20, "attivazione": {"1": 5, "2": 8}, "obiettivi": [],
        "regole": {"vista": 3, "xxx": True, "canoe": 2, "dirupi": "impassabili", "sommozzatori": ["E", "F", "G", "H"],
                   "coltelli": ["A", "B", "C", "D"], "missione_19": True},
        "modifiche_iniziali": {},
        "vittoria_testo": "[b]Servono 20 PV.[/b] Ogni chiatta distrutta vale 3 PV; la fine della missione si scopre durante il gioco.",
        "testo_fine": "",
    },
}


def main():
    tutti = {}
    for n in MISSIONI:
        for k, v in importlib.import_module(f"paragrafi_ss{n}").P.items():
            tutti.setdefault(k, v)
    base = json.loads((R / "data/paragrafi.json").read_text())
    for n, meta in MISSIONI.items():
        d = {"id": n}
        d.update(meta)
        sq = json.loads(json.dumps(M1["squadra"]))
        for a in sq:
            armi, mun = ARMI_19[a["id"]]
            a["porte"] = armi
            a["munizioni"] = mun
        d["squadra"] = sq
        d["tedeschi"] = TEDESCHI_19
        d["condizioni"] = condizioni(n)
        (R / f"data/missione{n}.json").write_text(json.dumps(d, ensure_ascii=False, indent=1))
        mancanti = set()
        for c in d["condizioni"].values():
            for v in list(c["esagoni"].values()) + list(c["evento"].values()) + list(c["movimenti"].values()):
                p = v.split(":")[-1]
                if p.isdigit() and p not in tutti and p not in base:
                    mancanti.add(p)
        for g in d["tedeschi"].values():
            for v in g["colonne"].values():
                for x in v:
                    if str(x) not in tutti and str(x) not in base:
                        mancanti.add(str(x))
        print(n, len(d["condizioni"]), "carte,", len(d["tedeschi"]), "tedeschi; mancanti:", sorted(mancanti))
    (R / "data/paragrafi_ss.json").write_text(json.dumps(tutti, ensure_ascii=False, indent=1))
    print(len(tutti), "paragrafi Silver Star")


if __name__ == "__main__":
    main()
