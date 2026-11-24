#!/usr/bin/env python3
"""Costruisce le missioni di Silver Star (19–24) e data/paragrafi_ss.json.

Fonti:
- data/carte/missioneN.json  carte Condizione trascritte (tools/carte_ss_trascritte.py)
- tools/paragrafi_ss<n>.py   testo italiano e ops dei paragrafi di ciascuna missione
- le carte tedesche GE10–GE71 della Missione 19, rilette a mano dal foglio del mod TTS (tools/carte_ss_grezze.json)
- data/missione1.json        squadra pre-generata (riarmata secondo il briefing)
"""
import importlib, json, pathlib, re, sys

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

C4 = ["1-2", "3", "S", "D"]
C4b = ["1", "2-3", "S", "D"]
TEDESCHI_20 = {
    "16": carta("Y", "Mitragliere", 0, ["lmg", "pistol"], 1, 4, 7, 0, 4, 4, [[0, 3], [4, 4], [5, 6], [7, 9]], C4,
                [[466, 139, 817, 815], [466, 139, 833, 800], [466, 139, 839, 770], [466, 139, 812, 841]], primo_turno=815,
                mg_squadra=17),
    "17": carta("S", "Mitragliere", 0, ["bolt"], 1, 3, 5, 0, 4, 4, [[0, 1], [2, 2], [3, 6], [7, 9]], C4,
                [[467, 139, 803, 843], [467, 139, 803, 841], [467, 139, 817, 815], [467, 139, 833, 770]], primo_turno=815,
                assiste=16, granate_porta=1),
    "18": carta("U", "Soldato", 0, ["mp"], 2, 3, 5, 1, 4, 4, [[0, 0], [1, 2], [3, 5], [6, 9]], C4 + ["M"],
                [[241, 115, 817, 802, 862], [241, 115, 833, 801, 864], [241, 115, 829, 808, 863], [241, 115, 839, 817, 866]],
                s_solo_stesso_piano=True),
    "19": carta("W", "Mitragliere", 0, ["lmg", "pistol"], 2, 1, 4, -1, 6, 3, [[0, 3], [4, 5], [6, 8], [9, 9]], C4b,
                [[815, 132, 859, 815], [843, 132, 817, 841], [802, 132, 812, 843], [840, 132, 833, 802]], primo_turno=869,
                mg_squadra=20),
    "20": carta("R", "Mitragliere", 0, ["bolt"], 0, 2, 4, -2, 2, 4, [[0, 2], [3, 6], [7, 7], [8, 9]], C4b,
                [[815, 132, 812, 815], [860, 132, 839, 841], [842, 132, 859, 840], [841, 132, 971, 860]], primo_turno=815,
                assiste=19),
    "48": carta("M", "Soldato", 0, ["mp"], 3, 3, 5, 0, 2, 4, [[0, 0], [1, 3], [4, 5], [6, 9]], C4,
                [[800, 800, 825, 770], [352, 106, 812, 825], [352, 106, 817, 824], [352, 106, 824, 801]]),
    "49": carta("X", "Soldato", 0, ["mp"], 2, 3, 4, -1, 6, 4, [[0, 1], [2, 2], [3, 6], [7, 9]], C4,
                [[352, 106, 812, 770], [840, 844, 817, 802], [352, 106, 833, 825], [352, 106, 859, 824]]),
    "50": carta("N", "Tiratore scelto", 0, ["scoped"], 1, 5, 8, 0, 6, 5, [[0, 2], [3, 6], [7, 7], [8, 9]], C4b,
                [[462, 114, 817, 824], [462, 114, 859, 825], [804, 844, 869, 802], [462, 114, 971, 801]]),
    "471": carta("L", "Squadra del mortaio", 0, ["mp"], 3, 3, 7, -1, 0, 4, [[0, 9]], ["1-3", "S", "D"], [[549, 549, 549]],
                 mortaio=47),
    "472": carta("Q", "Squadra del mortaio", 0, ["bolt"], 2, 1, 4, 0, 0, 3, [[0, 9]], ["1-3", "S", "D"], [[549, 549, 549]],
                 mortaio=47),
    "473": carta("T", "Squadra del mortaio", 0, ["bolt"], 2, 2, 4, 0, 0, 4, [[0, 9]], ["1-3", "S", "D"], [[549, 549, 549]],
                 mortaio=47),
}
CONVOGLIO = [{"id": "J", "nome": "Jimmy", "IN": 3, "PC": 7, "WS": -1, "DS": 8, "MPA": 4, "comandante": False, "porte": ["smg"],
              "munizioni": {"smg": 2}},
             {"id": "K", "nome": "Kenny", "IN": 1, "PC": 5, "WS": -2, "DS": 8, "MPA": 3, "comandante": False,
              "porte": ["carbine", "pistol"], "munizioni": {"carbine": 2, "pistol": 1, "granata": 1}}]

# Squadra pre-generata riarmata: solo carabine, mitra, pistole, bazooka e granate; E–H sono i sommozzatori.
ARMI_19 = {"A": (["smg"], {"smg": 5, "granata": 2}), "B": (["carbine"], {"carbine": 5, "granata": 2}),
           "C": (["carbine", "bazooka"], {"carbine": 3, "bazooka": 3, "granata": 1}), "D": (["smg"], {"smg": 4, "granata": 2}),
           "E": (["pistol"], {"pistol": 3, "granata": 2}), "F": (["smg"], {"smg": 3, "granata": 2}),
           "G": (["pistol"], {"pistol": 3, "granata": 2}), "H": (["carbine"], {"carbine": 3, "granata": 2})}

C3T = ["1-3", "S", "D", "T"]
C3H = ["1-3", "S", "D", "H"]
C3 = ["1-3", "S", "D"]
G4 = [[0, 4], [5, 5], [6, 8], [9, 9]]
TEDESCHI_21 = {
    "22": carta("M", "Granatiere", 1, ["mp", "pistol"], 1, 3, 7, -1, 2, 4, G4, C3T,
                [[868, 770, 801, 426], [864, 817, 802, 426], [866, 839, 808, 426], [867, 829, 817, 426]]),
    "23": carta("S", "Granatiere", 1, ["mp"], 2, 3, 5, 1, 4, 4, [[0, 0], [1, 2], [3, 5], [6, 9]], C3T,
                [[865, 816, 840, 425], [863, 817, 825, 425], [868, 812, 824, 425], [807, 833, 802, 425]]),
    "24": carta("N", "Soldato", 1, ["bolt"], 2, 5, 6, 0, 4, 5, G4, C3,
                [[862, 839, 825], [863, 812, 802], [868, 859, 801], [865, 971, 800]]),
    "25": carta("T", "Soldato", 1, ["bolt"], 2, 2, 4, 0, 2, 4, [[0, 3], [4, 5], [6, 7], [8, 9]], C3,
                [[866, 817, 770], [867, 812, 825], [865, 833, 802], [864, 859, 824]]),
    "31": carta("V", "Granatiere", 1, ["mp"], 2, 1, 3, -1, 6, 3, [[0, 3], [4, 6], [7, 8], [9, 9]], C3T,
                [[862, 833, 801, 584], [863, 817, 860, 584], [864, 825, 869, 584], [807, 859, 802, 584]]),
    "32": carta("Z", "Granatiere", 1, ["mp"], 2, 4, 7, -1, 4, 4, [[0, 0], [1, 2], [3, 4], [5, 9]], C3T,
                [[830, 839, 802, 585], [866, 817, 808, 585], [867, 833, 801, 585], [865, 821, 817, 585]]),
    "33": carta("X", "Soldato nascosto", 1, ["bolt"], 3, 3, 7, 0, 6, 4, [[0, 5], [6, 7], [8, 8], [9, 9]], C3H,
                [[868, 812, 842, 586], [867, 817, 869, 586], [807, 824, 801, 586], [865, 816, 802, 586]]),
    "34": carta("Y", "Soldato nascosto", 1, ["mp", "pistol"], 1, 5, 7, 1, 4, 5, [[0, 3], [4, 4], [5, 8], [9, 9]], C3H,
                [[866, 770, 869, 583], [868, 711, 817, 583], [862, 839, 824, 583], [803, 816, 801, 583]]),
    "35": carta("U", "Mitragliere", 1, ["lmg", "pistol"], 1, 3, 5, 1, 2, 4, [[0, 3], [4, 6], [7, 8], [9, 9]], C3,
                [[865, 817, 869], [862, 812, 824], [815, 821, 815], [868, 839, 825]], primo_turno=815, mg_squadra=36),
    "36": carta("L", "Mitragliere", 1, ["mp"], 0, 3, 6, 0, 4, 4, [[0, 1], [2, 2], [3, 6], [7, 9]], C3,
                [[862, 817, 770], [865, 833, 840], [865, 839, 841], [815, 812, 815]], primo_turno=841, assiste=35),
    "30": carta("LL", "Panzer IV", 3, [], 0, 5, 8, 2, 8, 6, [[0, 9]], ["1-3"], [[800]],
                carro={"modello": "panzer4", "gruppi": [[0, 3], [4, 5], [6, 8], [9, 9]],
                       "righe": {"5": {"IN": 5, "PC": 8, "WS": 2, "DS": 8, "par": [902, 905, 925, 814]},
                                 "4": {"IN": 3, "PC": 6, "WS": 1, "DS": 8, "par": [925, 902, 905, 827]},
                                 "3": {"IN": 3, "PC": 5, "WS": 0, "DS": 6, "par": [906, 907, 707, 826]},
                                 "2": {"IN": 2, "PC": 3, "WS": -1, "DS": 4, "par": [908, 910, 921, 814]},
                                 "1": {"IN": 1, "PC": 1, "WS": -2, "DS": 2, "par": [937, 921, 874, 923]}},
                       "immobile": False, "pv_distrutto": 0, "primo_turno": 0,
                       "testo": "Enters open; cannon prepared. Drives slow until fired upon."}),
    "21": carta("MM", "Jagdpanther", 3, [], 0, 4, 7, 1, 8, 6, [[0, 9]], ["1-3"], [[800]],
                carro={"modello": "jagdpanther", "gruppi": [[0, 1], [2, 6], [7, 7], [8, 9]],
                       "righe": {"5": {"IN": 4, "PC": 7, "WS": 1, "DS": 8, "par": [928, 936, 928, 936]},
                                 "4": {"IN": 4, "PC": 7, "WS": 1, "DS": 8, "par": [928, 936, 928, 936]},
                                 "3": {"IN": 4, "PC": 5, "WS": 0, "DS": 6, "par": [928, 933, 936, 933]},
                                 "2": {"IN": 3, "PC": 4, "WS": -1, "DS": 4, "par": [933, 924, 840, 924]},
                                 "1": {"IN": 2, "PC": 3, "WS": -2, "DS": 2, "par": [840, 874, 908, 874]}},
                       "immobile": False, "pv_distrutto": 0, "primo_turno": 0,
                       "testo": "Enters open; cannon prepared. Drives slow until fired upon."}),
}
CARRI_US_21 = {
    "4": carta("AA", "Sherman", 0, [], 0, 4, 8, 1, 8, 6, [[0, 9]], ["1-6"], [[800]],
               carro={"modello": "sherman", "gruppi": [[0, 1], [2, 7], [8, 9]],
                      "righe": {"5": {"IN": 4, "PC": 8, "WS": 1, "DS": 8, "par": [939, 946, 939]},
                                "4": {"IN": 4, "PC": 7, "WS": 1, "DS": 8, "par": [946, 939, 946]},
                                "3": {"IN": 4, "PC": 6, "WS": 0, "DS": 6, "par": [956, 956, 956]},
                                "2": {"IN": 3, "PC": 5, "WS": 0, "DS": 6, "par": [956, 956, 956]},
                                "1": {"IN": 2, "PC": 4, "WS": -1, "DS": 4, "par": [706, 706, 706]}},
                      "immobile": False, "pv_distrutto": 0, "primo_turno": 0, "testo": "Enters open; cannon prepared."}),
}
C12 = ["1", "2", "3-4", "S"]
TEDESCHI_22 = {
    "26": carta("S", "Cecchino", 1, ["scoped"], 2, 3, 6, 1, 2, 4, [[0, 1], [2, 4], [5, 5], [6, 9]], C12 + ["B"],
                [[807, 801, 807, 839, 599], [836, 802, 803, 859, 599], [804, 824, 809, 833, 599], [803, 825, 866, 971, 599]],
                no_auto_reazioni=["B"]),
    "27": carta("N", "Cecchino", 1, ["mp", "pzf"], 1, 5, 8, 2, 6, 5, [[0, 0], [1, 2], [3, 4], [5, 9]], ["1-2", "3-4", "S", "P", "Q"],
                [[800, 860, 868, 208, 209], [801, 866, 215, 208, 209], [817, 807, 812, 208, 209], [824, 809, 817, 208, 209]]),
    "28": carta("M", "Mitragliere", 1, ["lmg", "pistol"], 2, 4, 6, 1, 4, 4, [[0, 2], [3, 4], [5, 6], [7, 9]], ["1-2", "3-4", "S"],
                [[848, 864, 817], [815, 863, 816], [959, 867, 819], [815, 868, 823]], primo_turno=815, mg_squadra=46),
    "29": carta("L", "Cecchino", 1, ["scoped"], 2, 3, 5, 1, 4, 4, [[0, 1], [2, 5], [6, 6], [7, 9]], C12,
                [[807, 825, 862, 825], [804, 802, 863, 812], [806, 801, 864, 802], [836, 824, 867, 817]]),
    "38": carta("T", "Cecchino", 1, ["bolt", "pzf"], 1, 3, 7, 0, 2, 4, [[0, 0], [1, 2], [3, 5], [6, 9]], ["1-2", "3-4", "S", "P", "Q"],
                [[840, 865, 711, 208, 209], [802, 819, 971, 208, 209], [825, 863, 813, 208, 209], [824, 868, 816, 208, 209]]),
    "40": carta("Y", "Ufficiale", 2, ["mp", "pistol"], 1, 5, 8, 2, 8, 5, [[0, 3], [4, 6], [7, 8], [9, 9]],
                ["1-2", "3-4", "S", "E", "G", "H", "T"],
                [[809, 832, 859, 261, 158, 153, 217], [803, 823, 833, 261, 158, 153, 217], [807, 822, 812, 261, 158, 153, 217],
                 [856, 969, 868, 261, 158, 153, 217]], pv_cattura=2),
    "41": carta("Z", "Autista del semicingolato", 2, ["mp"], 2, 4, 7, -1, 6, 4, [[0, 4], [5, 6], [7, 8], [9, 9]],
                ["1-4", "S", "E", "G", "H", "T"],
                [[862, 817, 261, 481, 153, 216], [863, 833, 261, 481, 153, 216], [864, 812, 261, 481, 153, 216],
                 [868, 816, 261, 481, 153, 216]]),
    "42": carta("Q", "Geniere", 1, ["mp"], 1, 1, 4, -1, 4, 3, [[0, 1], [2, 5], [6, 6], [7, 9]], ["1-4", "S", "E", "T"],
                [[864, 833, 261, 218], [867, 816, 261, 218], [869, 971, 261, 218], [868, 711, 261, 218]]),
    "43": carta("U", "Geniere", 1, ["mp"], 1, 3, 5, 0, 2, 4, [[0, 3], [4, 5], [6, 6], [7, 9]], ["1-4", "S", "E", "T"],
                [[862, 817, 261, 218], [863, 839, 261, 218], [865, 816, 261, 218], [866, 859, 261, 218]]),
    "44": carta("W", "Geniere", 1, ["mp"], 1, 1, 2, 0, 4, 3, [[0, 1], [2, 4], [5, 5], [6, 9]], ["1-4", "S", "E", "T"],
                [[863, 812, 261, 218], [864, 971, 261, 218], [865, 811, 261, 218], [866, 813, 261, 218]]),
    "45": carta("X", "Geniere", 1, ["bolt"], 2, 4, 5, -1, 2, 4, [[0, 1], [2, 5], [6, 7], [8, 9]], ["1-4", "S", "E", "T"],
                [[803, 817, 261, 218], [806, 833, 261, 218], [865, 859, 261, 218], [864, 812, 261, 218]]),
    "46": carta("V", "Mitragliere", 1, ["bolt"], 0, 1, 2, -1, 4, 3, [[0, 0], [1, 2], [3, 4], [5, 9]], ["1-2", "3-4", "S"],
                [[815, 815, 859], [869, 803, 823], [815, 809, 839], [770, 807, 812]], primo_turno=869, assiste=28),
    "371": carta("P", "Servente del cannone anticarro", 1, ["mp"], 2, 1, 2, -2, 0, 3, [[0, 9]], ["1-4", "S"], [[265, 265]]),
    "372": carta("Q", "Servente del cannone anticarro", 1, ["mp"], 2, 1, 4, -2, 0, 3, [[0, 9]], ["1-4", "S"], [[265, 265]]),
    "471": TEDESCHI_20["471"], "472": TEDESCHI_20["472"], "473": TEDESCHI_20["473"],
    "67": carta("LL", "Panzer IV", 2, [], 0, 5, 8, 1, 8, 6, [[0, 9]], ["1-4"], [[800]],
                carro={"modello": "panzer4", "gruppi": [[0, 2], [3, 3], [4, 7], [8, 9]],
                       "righe": {"5": {"IN": 5, "PC": 8, "WS": 1, "DS": 8, "par": [907, 905, 925, 925]},
                                 "4": {"IN": 3, "PC": 7, "WS": 1, "DS": 8, "par": [925, 905, 925, 925]},
                                 "3": {"IN": 3, "PC": 6, "WS": 1, "DS": 6, "par": [923, 923, 709, 708]},
                                 "2": {"IN": 2, "PC": 3, "WS": 0, "DS": 4, "par": [814, 874, 923, 921]},
                                 "1": {"IN": 1, "PC": 1, "WS": -1, "DS": 2, "par": [874, 814, 921, 923]}},
                       "immobile": False, "pv_distrutto": 3, "primo_turno": 415,
                       "testo": "Enters open; cannon prepared. On first turn, conduct 415."}),
}

ESAGONI_PV_22 = ["O4", "W8", "V14", "K14", "J14", "I15"]
SEZ_A = ["E15", "F14", "G14", "H13", "I13"]
SEZ_B = ["P15", "Q16", "R13", "S13", "T12", "T15", "U13", "U15", "V13", "V14"]


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
    20: {
        "titolo": "Facile come bere un bicchier d’acqua", "titolo_originale": "Easy as Apple Pie",
        "data": "Natale 1943, a sud di Cassino", "mappa": "F", "nord": "in alto", "libro": "ss",
        "briefing": "Natale 1943, da qualche parte a sud di Cassino. La squadra torna dalla licenza natalizia e il primo compito è "
                    "scortare un piccolo convoglio che porta il pranzo caldo di Natale al resto della compagnia, di guardia a una "
                    "galleria strategica fra le montagne.",
        "ingresso": "Mappa F, in alto è nord. La squadra entra sui mezzi in A8 oppure in B19 (tutti dallo stesso lato): tre camion "
                    "(autista più un passeggero in cabina) e una jeep con mitragliatrice media (autista e tre passeggeri; spara il "
                    "passeggero 1). Nessuno scende dai mezzi finché non avviene un avvistamento. Ponte di pietra intatto in O4 "
                    "(da P3 a N4), ponte distrutto in K12, relitto d’aereo in K10. Livelli di attivazione: Condizione 1 da 0 a 4, "
                    "Condizione 2 da 0 a 6, Condizione 3 da 0 a 4.",
        "regole_testo": "[b]Convoglio.[/b] Nelle Operazioni guidi il mezzo di testa: gli altri lo seguono in fila, un esagono dietro "
                        "l’altro, ed entrano in mappa uno alla volta. Nei Round ogni mezzo si muove per conto suo. [b]Carichi.[/b] "
                        "Ogni camion porta un carico di pranzi: nel cassone non sale nessuno. Se un camion è fuori uso, il carico si "
                        "passa a un altro mezzo nello stesso esagono (2 controlli Evento nelle Operazioni, 4 azioni nei Round). Un "
                        "camion con 3 carichi va solo piano; la jeep ne porta uno solo con il solo autista, e allora va piano. "
                        "[b]Aggrapparsi.[/b] Se un mezzo è fuori uso ci si può aggrappare ai lati di un camion (al massimo due, 1 PM): "
                        "un solo tiro rapido per turno (−2), chi è ferito cade. [b]Jeep.[/b] 6 caricatori per la mitragliatrice: la "
                        "spara il passeggero 1 senza il −2. [b]Fiume e dirupi.[/b] Gli esagoni XXX delle carte sono invalicabili. "
                        "[b]Granate contro i mezzi.[/b] Da 2 o più esagoni la granata cade nell’esagono del mezzo: con incapacitato "
                        "o ucciso sulla riga Granata all’aperto il mezzo è fuori uso e chi è a bordo tira i danni.",
        "ingresso_breve": "A8 o B19, sui mezzi", "uscita_breve": "si scopre in gioco",
        "ingresso_esagoni": ["A8", "B19"], "uscita_esagoni": [],
        "vittoria_pv": 6, "attivazione": {"1": 4, "2": 6, "3": 4}, "obiettivi": [],
        "regole": {"xxx": True, "dirupi": "impassabili", "convoglio": True, "missione_20": True, "niente_pv_attivazione": True,
                   "terreno_ss": {"O4": {"t": "stream", "ponte": True}, "W7": {"t": "road", "galleria": True},
                                  "W8": {"t": "road", "galleria": True}, "W9": {"t": "road", "galleria": True},
                                  "K10": {"t": "crater"}, "U13": {"t": "road", "arcata": True}}},
        "modifiche_iniziali": {},
        "vittoria_testo": "[b]PV:[/b] +1 per ogni camion uscito, +2 per ogni carico di pranzi uscito, +1 per ogni tedesco attivo "
                          "rimasto in mappa a fine missione; altri premi si scoprono in gioco. Quanti PV servono e da dove si esce "
                          "si scopre durante la missione. Niente PV per l’attivazione dei tedeschi.",
        "testo_fine": "",
    },
    21: {
        "titolo": "Sorpresa, sorpresa!", "titolo_originale": "Surprise, Surprise!",
        "data": "Sicilia, presso Gela, 11 luglio 1943", "mappa": "FH", "nord": "in basso (in alto è sud)", "libro": "ss",
        "briefing": "Luglio 1943, Sicilia. Dopo lo sbarco la squadra presidia gli accessi a una piccola baia, dove arrivano "
                    "rifornimenti e rinforzi. Le case sono state appena sgomberate e tutto sembra tranquillo, ma i tedeschi "
                    "preparano un contrattacco con i carri: tenete la posizione finché il comando non manda aiuto.",
        "ingresso": "Mezza mappa H sopra la mappa F; in alto è sud. Sezione A (4 uomini) negli esagoni di livello 3 E15, F14, G14, "
                    "H13, I13; sezione B (4 uomini) al primo piano degli edifici entro 3 esagoni da S14: P15, Q16, R13, S13, T12, "
                    "T15, U13, U15, V13, V14. Al massimo 2 soldati per esagono. Ponti di pietra intatti in K12 (da K11 a K13) e "
                    "in T7 (da T6 a T8). La squadra ha la radio. I tedeschi arrivano per evento casuale: niente controlli di "
                    "attivazione.",
        "regole_testo": "[b]Dirupi.[/b] Gli esagoni XXX delle carte sono invalicabili. [b]Arrivi.[/b] I tedeschi entrano solo con "
                        "gli eventi casuali. [b]Carri.[/b] Il Jagdpanther e il Panzer entrano aperti con il cannone pronto e vanno "
                        "solo piano finché qualcuno non spara loro. I granatieri sui carri (reazione speciale T) si muovono con il "
                        "carro. [b]Tedeschi nascosti.[/b] Nelle case possono esserci tedeschi rimasti nascosti (reazione speciale H). "
                        "[b]Mezzi americani.[/b] Il cannone navale, lo Sherman e la motovedetta agiscono da soli con il numero "
                        "d’azione tedesco; lo Sherman e la motovedetta seguono i riferimenti di movimento neri delle carte. "
                        "[b]Radio.[/b] È presidiata finché nel suo esagono resta un soldato attivo.",
        "ingresso_breve": "sezioni A e B", "uscita_breve": "si scopre in gioco",
        "ingresso_esagoni": SEZ_A + SEZ_B, "uscita_esagoni": [],
        "vittoria_pv": 8, "attivazione": {"1": 0, "2": 0, "3": 0}, "obiettivi": [],
        "regole": {"xxx": True, "dirupi": "impassabili", "eventi_continui": True, "radio": True, "max_per_esagono": 2,
                   "sezioni": [{"nome": "la sezione A", "n": 4, "esagoni": SEZ_A}, {"nome": "la sezione B", "n": 4, "esagoni": SEZ_B}],
                   "salvi_in_edificio": True, "missione_21": True},
        "modifiche_iniziali": {},
        "vittoria_testo": "[b]Servono 8 PV.[/b] +1 per ogni tedesco attivato, +3 per ciascun carro; −3 se lo Sherman o la "
                          "motovedetta vanno fuori uso, −2 se il cannone navale è distrutto. Come finisce la missione si scopre "
                          "durante il gioco.",
        "testo_fine": "",
        "carri_us": CARRI_US_21,
    },
    22: {
        "titolo": "Un altro ponte di troppo?", "titolo_originale": "Another Bridge Too Far?",
        "data": "Gennaio 1944, a nord-ovest di Montecassino", "mappa": "FG", "nord": "a sinistra (in alto è est)", "libro": "ss",
        "briefing": "Gennaio 1944. I partigiani segnalano una strada attraverso i Monti Aurunci. Il comando manda la squadra a "
                    "vedere se ci sono ponti intatti su cui far passare i carri della divisione per aggirare la linea Gustav. "
                    "Avete un semicingolato con una mitragliatrice media e una jeep.",
        "ingresso": "Mappa F con mezza mappa G sopra (in alto è est). La squadra entra sui mezzi da W1, X1 o Y1. Ponti di pietra "
                    "intatti in O4 (da N4 a P3) e in V14 (da U15 a W14); macerie in K10. Livelli di attivazione: Condizione 1 da 0 "
                    "a 3, Condizione 2 da 0 a 5, Condizioni 3 e 4 da 0 a 8.",
        "regole_testo": "[b]Torrente.[/b] Da O1 a N10 e poi fino a Y15: si attraversa pagando i PM del torrente. [b]Dirupi.[/b] "
                        "Pendenze: 2 PM a piedi, vietati ai mezzi. [b]Ponti.[/b] Da un esagono di ponte si scende fra i sostegni "
                        "con un’azione (e si risale con un’altra): solo lì si trovano e si disinnescano gli esplosivi (2 azioni, "
                        "+1 PV). Chi è sotto il ponte è difficile da colpire (−4, −2 dallo stesso esagono). [b]Semicingolato.[/b] "
                        "Mitragliatrice media al passeggero 1 (senza il −2 dal mezzo), una cassetta. [b]Galleria.[/b] Da W7 a "
                        "W9, buia; i paragrafi con la T valgono per chi la percorre.",
        "ingresso_breve": "W1–Y1, sui mezzi", "uscita_breve": "si scopre in gioco",
        "ingresso_esagoni": ["W1", "X1", "Y1"], "uscita_esagoni": [],
        "vittoria_pv": 21, "attivazione": {"1": 3, "2": 5, "3": 8, "4": 8}, "obiettivi": [],
        "regole": {"dirupi": "pendenza", "galleria_ss": True, "missione_22": True,
                   "terreno_ss": {"O4": {"t": "stream", "ponte": True}, "V14": {"t": "stream", "ponte": True},
                                  "K10": {"t": "rubble"}, "W7": {"t": "road", "galleria": True},
                                  "W8": {"t": "road", "galleria": True}, "W9": {"t": "road", "galleria": True}}},
        "modifiche_iniziali": {},
        "vittoria_testo": "[b]PV:[/b] +1 per ogni esagono fra O4, W8, V14, K14, J14, I15 in cui entra la squadra; +1 per ogni "
                          "esplosivo disinnescato; il resto (e quanti PV servono) si scopre durante la missione.",
        "testo_fine": "",
    },
}


def main():
    base = json.loads((R / "data/paragrafi.json").read_text())
    for n, meta in MISSIONI.items():
        tutti = importlib.import_module(f"paragrafi_ss{n}").P
        (R / f"data/paragrafi_ss{n}.json").write_text(json.dumps(tutti, ensure_ascii=False, indent=1))
        d = {"id": n}
        d.update(meta)
        sq = json.loads(json.dumps(M1["squadra"]))
        if n == 19:
            for a in sq:
                armi, mun = ARMI_19[a["id"]]
                a["porte"] = armi
                a["munizioni"] = mun
        elif n == 20:
            sq += json.loads(json.dumps(CONVOGLIO))
        d["squadra"] = sq
        d["tedeschi"] = {19: TEDESCHI_19, 20: TEDESCHI_20, 21: TEDESCHI_21, 22: TEDESCHI_22}[n]
        d["condizioni"] = condizioni(n)
        (R / f"data/missione{n}.json").write_text(json.dumps(d, ensure_ascii=False, indent=1))
        mancanti = set()
        for c in d["condizioni"].values():
            for v in list(c["esagoni"].values()) + list(c["evento"].values()) + list(c["movimenti"].values()):
                p = ("T" if v.startswith("T:") else "") + v.split(":")[-1]
                if re.fullmatch(r"T?\d{3}", p) and p not in tutti and p not in base:
                    mancanti.add(p)
        for g in d["tedeschi"].values():
            for v in g["colonne"].values():
                for x in v:
                    if str(x) not in tutti and str(x) not in base:
                        mancanti.add(str(x))
        print(n, len(d["condizioni"]), "carte,", len(d["tedeschi"]), "tedeschi; mancanti:", sorted(mancanti))


if __name__ == "__main__":
    main()
