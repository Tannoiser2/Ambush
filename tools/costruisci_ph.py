#!/usr/bin/env python3
"""Costruisce le missioni di Purple Heart (13–18) e data/paragrafi_ph.json.

Fonti:
- tools/carte_ph.json        carte dei tedeschi del mazzo Purple Heart (GE04–GE40, OCR del foglio del mod TTS)
- data/carte/missioneN.json  carte Condizione (OCR, tools/costruisci_carte.py)
- tools/paragrafi_ph<n>.py   testo italiano e ops dei paragrafi di ciascuna missione
- data/missione1.json        squadra pre-generata
"""
import importlib, json, pathlib, re, sys

R = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(R / "tools"))
CARTE = json.loads((R / "tools/carte_ph.json").read_text())
M1 = json.loads((R / "data/missione1.json").read_text())
RUOLI = {"Commando": "Commando", "Machinegunner": "Mitragliere", "Panzergrenadier": "Granatiere corazzato",
         "Scout": "Esploratore", "Bodyguard": "Guardia del corpo", "Officer": "Ufficiale", "Sergeant": "Sergente",
         "Major": "Maggiore", "Field Marshal": "Feldmaresciallo", "Volksgrenadier": "Volksgrenadier",
         "Veteran Infantry": "Fante veterano", "Motorcycle and Driver": "Motociclista", "Kubelwagen and Driver": "Kübelwagen e autista",
         "Staff Car and Driver": "Auto comando e autista"}
COMANDANTI = ("Officer", "Sergeant", "Major", "Field Marshal")
COL = "ABCDEFGHIJKLMNOPQRSTUVWXY"


def distanza(a, b):
    def cubo(h):
        q = COL.index(h[0]); r = int(h[1:]) - 1
        z = r - (q - (q & 1)) // 2
        return q, -q - z, z
    x1, y1, z1 = cubo(a); x2, y2, z2 = cubo(b)
    return max(abs(x1 - x2), abs(y1 - y2), abs(z1 - z2))


MODELLI = {"Panzer IV": "panzer4", "\"E\" Boat": "eboat", "E Boat": "eboat", "Sherman Tank": "sherman"}


def mezzo(c):
    """Carta di un mezzo (equipaggio 1–5) nel formato dei carri del gioco."""
    eq = c["equipaggio"]
    tutte = [tuple(eq[str(k)]["valori"][d] for k in range(1, 6)) for d in range(10)]
    gr = []
    for d in range(10):
        if gr and tutte[gr[-1][0]] == tutte[d]:
            gr[-1][1] = d
        else:
            gr.append([d, d])
    righe = {k: {"IN": v["IN"], "PC": v["PC"], "WS": v["WS"], "DS": v["DS"], "par": [v["valori"][a] for a, _ in gr]} for k, v in eq.items()}
    r5 = righe["5"]
    modello = MODELLI.get(c["ruolo"], "eboat" if "Boat" in c["ruolo"] else "panzer4")
    return {"lettera": c["lettera"], "ruolo": {"panzer4": "Panzer IV", "eboat": "Motosilurante", "sherman": "Sherman"}[modello],
            "pv": c["pv"], "armi": [], "granate": 0, "IN": r5["IN"], "PC": r5["PC"], "WS": r5["WS"], "DS": r5["DS"], "MPA": 6,
            "gruppi": [[0, 9]], "colonne": {"1-6": [800]},
            "carro": {"modello": modello, "gruppi": gr, "righe": righe, "immobile": False,
                      "pv_distrutto": int(c.get("pv_distrutto", 0)), "primo_turno": int(c.get("primo_turno", 0)) or
                      int((__import__("re").search(r"conduct\s*(\d{3})", c.get("note", "")) or [0, 0])[1]),
                      "testo": c.get("note", "")}}


CANE = {"lettera": "", "ruolo": "Cane da guardia", "pv": 0, "armi": [], "granate": 0, "IN": 5, "PC": 9, "WS": 2, "MPA": 6,
        "gruppi": [[0, 9]], "colonne": {"1-6": [391], "S": [391], "A": [391]}}


# Primo turno dalle note (la colonna della Missione 15; le note OCR sono troncate: valori dal database del programma).
PRIMO_TURNO_DA_NOTE = {4, 6, 8, 9, 10, 11, 12, 14, 15, 16}
PRIMO_FISSO = {4: 814, 6: 814, 8: 814, 16: 814, 9: 840, 10: 840, 11: 840, 12: 840, 14: 840, 15: 840}


def tedeschi(nums):
    out = {}
    for n in nums:
        if n in (91, 92):
            out[str(n)] = dict(CANE)
            continue
        c = CARTE["GE%d" % n]
        if c.get("veicolo"):
            out[str(n)] = mezzo(c)
            continue
        d = {"lettera": c["lettera"], "ruolo": RUOLI.get(c["ruolo"], c["ruolo"]), "pv": c["pv"], "armi": c["armi"],
             "granate": c["granate"], "IN": c["IN"], "PC": c["PC"], "WS": c["WS"], "MPA": c["MPA"],
             "gruppi": c["gruppi"], "colonne": {}}
        if c.get("pv_cattura"):
            d["pv_cattura"] = c["pv_cattura"]
        if c.get("DS") is not None:
            d["DS"] = c["DS"]
        if c.get("esplosivi"):
            d["esplosivi"] = c["esplosivi"]
        nota = c.get("note") or ""
        m = re.search(r"first turn,\s*(?:use|conduct)\s*(\d{3})", nota)
        if m and n in PRIMO_TURNO_DA_NOTE:
            d["primo_turno"] = int(m.group(1))
        if "while in active vehicle" in nota:
            d["ignora_s_veicolo"] = True
        for col, v in c["colonne"].items():
            d["colonne"][col] = [int(x) if x is not None else 816 for x in v]
        if c["ruolo"] in COMANDANTI:
            d["comandante"] = True
        if n in PRIMO_FISSO:
            d["primo_turno"] = PRIMO_FISSO[n]
            d["ignora_s_veicolo"] = True
        out[str(n)] = d
    return out


def condizioni(n):
    d = json.loads((R / f"data/carte/missione{n}.json").read_text())
    return {c: {"esagoni": v["esagoni"], "evento": v["evento"], "movimenti": v["movimenti"]} for c, v in d.items()}


DEPOSITO_16 = ["U15", "U16", "V12", "V13", "V14", "V15", "W13", "W14", "W15"]
ANGOLI = ["A1", "A19", "Y1", "Y19"]

MISSIONI = {
    13: {
        "titolo": "Dispersi", "titolo_originale": "Drop Outs",
        "data": "Francia del nord, 6 giugno 1944", "mappa": "A", "nord": "a sinistra (in alto è est)", "libro": "ph",
        "briefing": "6 giugno 1944, da qualche parte nella Francia del nord. Nell’assalto aereo che precede il D-Day la squadra è stata "
                    "lanciata a chilometri dalla zona prevista. Per tutta la notte ha cercato invano di unirsi ad altri reparti "
                    "alleati. Sta per albeggiare: forse non resta che arrendersi… che cosa possono fare così pochi contro così tanti?",
        "ingresso": "Mappa A, in alto è est. Prima della missione ogni soldato fa il controllo dell’atterraggio (terreno e qualità "
                    "dell’atterraggio, tirati in automatico): può finire ferito, incapacitato o annegato nel fiume. Poi la squadra "
                    "entra da un esagono tra I1 e Y1.",
        "regole_testo": "[b]Notte.[/b] Si vede fino a quattro esagoni. [b]Fiume.[/b] Il fiume da H1 a R16 si attraversa solo sui ponti "
                        "intatti. [b]Lancio.[/b] La squadra tiene il suo equipaggiamento (la cassa delle armi non è gestita); si "
                        "perdono 2 PV per ogni soldato incapacitato o ucciso nel lancio.",
        "ingresso_breve": "bordo est, I1–Y1", "uscita_breve": "qualsiasi bordo (dalla Condizione 3)",
        "ingresso_esagoni": ["%s1" % c for c in "IJKLMNOPQRSTUVWXY"],
        "vittoria_pv": 21, "attivazione": {"1": 1, "2": 3, "3": 5, "4": 8}, "obiettivi": [],
        "regole": {"vista": 4, "fiume": True, "atterraggio_ph": True, "uscita_bordo": True, "fine_condizione": 3},
        "vittoria_testo": "[b]Vittoria e fine: si scoprono durante il gioco.[/b] Valgono le attivazioni dei tedeschi; si perdono 2 PV per "
                          "ogni soldato incapacitato o ucciso nel lancio.",
        "testo_fine": "",
        "germani": [61, 62, 63, 64, 65, 66, 67, 68, 69, 91, 92],
    },
    15: {
        "titolo": "Ritorno a casa", "titolo_originale": "Homecoming",
        "data": "Valle del Rodano, 25 agosto 1944", "mappa": "C", "nord": "a destra (in alto è ovest)", "libro": "ph",
        "briefing": "25 agosto 1944, valle del Rodano. Durante un’incursione in profondità dietro le linee la squadra è rimasta tagliata "
                    "fuori e isolata. Dopo dodici ore di combattimenti è finalmente uscita dall’accerchiamento: ora gli uomini tornano "
                    "al campo, stremati ma fieri di una missione ben riuscita.",
        "ingresso": "Mappa C, in alto è ovest. Prima della missione si tira, per ogni soldato e ogni tipo di munizione, sulla tabella "
                    "delle munizioni consumate (in automatico). La squadra entra dal bordo nord tra Y15 e Y19; il campo è oltre il "
                    "bordo sud. La diga è in N5. Non ci sono livelli di attivazione.",
        "regole_testo": "[b]Diga.[/b] In N5 si entra e se ne esce solo da O5 e M6. [b]Letto asciutto.[/b] Per via della diga il fiume da N6 "
                        "a Y15 è asciutto e vale come copertura (il ponte in S9 è intatto). [b]Munizioni.[/b] Una parte delle munizioni "
                        "è stata consumata nei combattimenti del giorno prima.",
        "ingresso_breve": "bordo nord, Y15–Y19", "uscita_breve": "nessuna",
        "ingresso_esagoni": ["Y15", "Y16", "Y17", "Y18", "Y19"],
        "vittoria_pv": 3, "attivazione": {}, "obiettivi": [],
        "regole": {"diga": True, "munizioni_consumate": True},
        "vittoria_testo": "[b]Vittoria e fine: si scoprono durante il gioco.[/b]",
        "testo_fine": "",
        "germani": [4, 6, 8, 9, 10, 11, 12, 14, 15, 16],
    },
    16: {
        "titolo": "In guardia", "titolo_originale": "On Guard",
        "data": "Valle del Rodano, 3 settembre 1944", "mappa": "C", "nord": "a sinistra (in alto è est)", "libro": "ph",
        "briefing": "Le linee di rifornimento alleate si allungano mentre i tedeschi si ritirano sempre più in fretta: il generale "
                    "Truscott sa che l’avanzata corazzata si fermerà quando finirà la benzina. La tua squadra di veterani, scelta dal "
                    "generale in persona, deve sorvegliare il deposito avanzato di carburante vicino a Digione. Non deluderlo!",
        "ingresso": "Mappa C, in alto è est. Schiera la squadra su un ampio perimetro: almeno due uomini entro 10 esagoni da ciascun "
                    "angolo della mappa (A1, A19, Y1, Y19). Nessuno può cominciare nel deposito (U15, U16, V12, V13, V14, V15, W13, W14, "
                    "W15). Dopo lo schieramento si leggono le carte degli esagoni occupati. Ricevi gratis una jeep.",
        "regole_testo": "[b]Notte di luna.[/b] Si vede fino a sei esagoni. [b]Fiume.[/b] Il fiume si attraversa solo sui ponti intatti. "
                        "[b]In allerta.[/b] Tutti i soldati sono in allerta (in questa versione: regole normali di consapevolezza). "
                        "[b]Esplosivi.[/b] Un soldato nell’esagono di un esplosivo lo disinnesca in due azioni.",
        "ingresso_breve": "schieramento entro 10 esagoni dagli angoli", "uscita_breve": "nessuna",
        "vittoria_pv": 24, "attivazione": {"1": 1, "2": 3, "3": 6, "4": 8, "5": 8}, "obiettivi": [],
        "regole": {"vista": 6, "fiume": True, "jeep": True, "deposito": DEPOSITO_16, "angoli": ANGOLI, "niente_pv_incapacitati": True},
        "vittoria_testo": "[b]Vittoria: 24 PV[/b] (si scopre durante il gioco). Valgono le attivazioni dei tedeschi, 1 PV per ogni "
                          "esagono del deposito intatto e −2 PV per ogni esagono distrutto, 2 PV per ogni esplosivo disinnescato. La "
                          "missione finisce quando non ci sono tedeschi attivi in mappa (e, se sono stati piazzati esplosivi, quando "
                          "sono tutti disinnescati o saltati).",
        "testo_fine": "",
        "germani": [20, 21, 28, 29, 36, 37, 38, 39],
    },
}


def main():
    tutti = {}
    for n in MISSIONI:
        for k, v in importlib.import_module(f"paragrafi_ph{n}").P.items():
            if k in tutti and tutti[k]["ops"] != v["ops"]:
                print("ATTENZIONE: paragrafo", k, "definito in modo diverso da più missioni")
            tutti.setdefault(k, v)
    for n, meta in MISSIONI.items():
        mod = importlib.import_module(f"paragrafi_ph{n}")
        meta = dict(meta)
        d = {"id": n}
        nums = meta.pop("germani")
        d.update(meta)
        d["squadra"] = json.loads(json.dumps(M1["squadra"]))
        d["tedeschi"] = tedeschi(nums)
        d["condizioni"] = condizioni(n)
        if n == 13:
            for g in d["tedeschi"].values():
                g.pop("pv_cattura", None) if g.get("ruolo") == "Cane da guardia" else None
        if n == 16:
            vic = [f"{c}{r}" for c in COL for r in range(1, 20) if any(distanza(f"{c}{r}", a) <= 10 for a in ANGOLI)]
            d["ingresso_esagoni"] = [h for h in vic if h not in DEPOSITO_16]
            d["uscita_esagoni"] = []
        (R / f"data/missione{n}.json").write_text(json.dumps(d, ensure_ascii=False, indent=1))
        mancanti = set()
        for c in d["condizioni"].values():
            for v in list(c["esagoni"].values()) + list(c["evento"].values()) + list(c["movimenti"].values()):
                p = v.split(":")[-1]
                if p.isdigit() and p not in tutti:
                    mancanti.add(p)
        for g in d["tedeschi"].values():
            for v in g["colonne"].values():
                for x in v:
                    if str(x) not in tutti and not (800 <= x <= 999):
                        mancanti.add(str(x))
        print(n, len(d["condizioni"]), "carte,", len(d["tedeschi"]), "tedeschi; mancanti:", sorted(mancanti))
    (R / "data/paragrafi_ph.json").write_text(json.dumps(tutti, ensure_ascii=False, indent=1))
    print(len(tutti), "paragrafi Purple Heart")


if __name__ == "__main__":
    main()
