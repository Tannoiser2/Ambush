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
PRIMO_TURNO_DA_NOTE = {4, 6, 8, 9, 10, 11, 12, 14, 15, 16, 17, 35, 40, 41, 42, 44, 45, 52}
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
    14: {
        "titolo": "Ricognizione in forze", "titolo_originale": "Reconnaissance in Force",
        "data": "A sud di Caen, 22 luglio 1944", "mappa": "C", "nord": "a destra (in alto è ovest)", "libro": "ph",
        "briefing": "22 luglio 1944, a sud di Caen. In vista di una grande offensiva alleata la squadra parte per una ricognizione in "
                    "forze lungo il perimetro, per scoprire le posizioni tedesche. L’appuntamento è con la squadra 2 della compagnia "
                    "Baker all’incrocio J8, un nodo stradale importante: bisogna arrivarci il prima possibile e ricongiungersi.",
        "ingresso": "Mappa C, in alto è ovest. La squadra, caricata sulle due jeep (quattro uomini per jeep), entra dal bordo nord in Y7. "
                    "Ricevi una radio, portata dal sergente.",
        "regole_testo": "[b]Fiume.[/b] Il corso d’acqua dal lago a Y15 è un fiume: si attraversa solo sui ponti intatti. [b]Jeep.[/b] Due "
                        "jeep sotto il tuo controllo, quattro uomini ciascuna. [b]Radio.[/b] La porta il sergente A: è presidiata "
                        "finché lui è attivo in mappa.",
        "ingresso_breve": "bordo nord, Y7 (sulle jeep)", "uscita_breve": "bordo nord, Y1–Y19",
        "ingresso_esagoni": ["Y7"], "uscita_esagoni": ["Y%d" % r for r in range(1, 20)],
        "vittoria_pv": 20, "attivazione": {"1": 1, "2": 6, "3": 8}, "obiettivi": [],
        "regole": {"fiume": True, "jeep_caricate": 2, "radio_portata_ph": True, "mg_jeep_opzionale": True},
        "vittoria_testo": "[b]Vittoria e fine: si scoprono durante il gioco.[/b]",
        "testo_fine": "",
        "germani": [17, 35, 40, 41, 42, 43, 44, 45],
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
                    "W15). Dopo lo schieramento si leggono le carte degli esagoni occupati. Ricevi gratis due jeep.",
        "regole_testo": "[b]Notte di luna.[/b] Si vede fino a sei esagoni. [b]Fiume.[/b] Il fiume si attraversa solo sui ponti intatti. "
                        "[b]In allerta.[/b] All’inizio dei Round la consapevolezza si determina normalmente, ma nel primo Round chi è consapevole è "
                        "in comando e nel secondo Round tutti sono consapevoli e in comando; poi il comando torna normale. "
                        "[b]Esplosivi.[/b] Un soldato nell’esagono di un esplosivo lo disinnesca in due azioni.",
        "ingresso_breve": "schieramento entro 10 esagoni dagli angoli", "uscita_breve": "nessuna",
        "vittoria_pv": 24, "attivazione": {"1": 1, "2": 3, "3": 6, "4": 8, "5": 8}, "obiettivi": [],
        "regole": {"vista": 6, "fiume": True, "jeep": True, "jeep_n": 2, "deposito": DEPOSITO_16, "angoli": ANGOLI,
                   "niente_pv_incapacitati": True, "allerta": True},
        "vittoria_testo": "[b]Vittoria: 24 PV[/b] (si scopre durante il gioco). Valgono le attivazioni dei tedeschi, 1 PV per ogni "
                          "esagono del deposito intatto e −2 PV per ogni esagono distrutto, 2 PV per ogni esplosivo disinnescato. La "
                          "missione finisce quando non ci sono tedeschi attivi in mappa (e, se sono stati piazzati esplosivi, quando "
                          "sono tutti disinnescati o saltati).",
        "testo_fine": "",
        "germani": [20, 21, 28, 29, 36, 37, 38, 39],
    },
}

MISSIONI[17] = {
    "titolo": "Sul filo del rasoio", "titolo_originale": "The Racer’s Edge",
    "data": "Germania occidentale, 15 marzo 1945", "mappa": "BE", "nord": "a destra (in alto è ovest)", "libro": "ph",
    "briefing": "15 marzo 1945, Germania occidentale. In testa a una delle tenaglie alleate, la squadra ha raggiunto la Mosella! Gli "
                "ordini: distruggere tutti i ponti sul fiume, tagliare la ritirata ai resti tedeschi e chiudere la sacca.",
    "ingresso": "Mappe B ed E, in alto è ovest. La squadra entra da un esagono dei bordi sud e ovest tra A5 e H1. Ponte di legno in G11, "
                "ponti di pietra in J11 e R10; gli edifici a ovest del fiume sono macerie. Ricevi 5 cariche da demolizione gratis.",
    "regole_testo": "[b]Fiume.[/b] Il fiume da A6 a Y11 si attraversa solo sui ponti intatti. [b]Ponti.[/b] Sul ponte si scende sui "
                    "sostegni (2 PM per scendere o risalire) e si piazzano le cariche: una per il ponte di legno, due per quelli di "
                    "pietra (un’azione ciascuna). La spoletta si regola da 1 a 4 turni: il ponte salta all’inizio del turno indicato, "
                    "prima di ogni azione (nelle Operazioni appena la squadra si è allontanata); chi è sopra o sotto muore. Sotto il ponte "
                    "si è visti come accovacciati sul ponte e al tiro si conta come in un interno; ferito o in panico, chi è sotto cade "
                    "nel fiume se il dado supera la sua IN. [b]Vittoria: 28 PV.[/b] Niente PV per le attivazioni: 10 PV "
                    "per ogni ponte distrutto e 1 PV per ogni tedesco ucciso, catturato o incapacitato.",
    "ingresso_breve": "bordi sud e ovest, A5–H1", "uscita_breve": "bordi sud e ovest, A5–H1 (dalla Condizione 3)",
    "ingresso_esagoni": ["A1", "A2", "A3", "A4", "A5"] + ["%s1" % c for c in "BCDEFGH"],
    "uscita_esagoni": ["A1", "A2", "A3", "A4", "A5"] + ["%s1" % c for c in "BCDEFGH"],
    "vittoria_pv": 28, "attivazione": {"1": 4, "2": 5, "3": 7, "4": 8}, "obiettivi": [],
    "regole": {"fiume": True, "ponti_pietra": ["J11", "R10"], "ponti_timer": True, "cariche_gratis": 5, "macerie_iniziali": [],
               "fine_ponti_17": True, "binario": []},
    "vittoria_testo": "[b]Vittoria: 28 PV.[/b] Niente PV per le attivazioni dei tedeschi: 10 PV per ogni ponte distrutto e 1 PV per ogni "
                      "tedesco ucciso, catturato o incapacitato; altri PV si scoprono in gioco. La missione finisce nelle Condizioni 3 o 4: "
                      "1. senza tedeschi attivi in mappa e con tutti e tre i ponti minati o distrutti (o senza più cariche): tutti i ponti "
                      "contano come distrutti; 2. con i tre ponti distrutti e nessuna linea di vista tra americani e tedeschi attivi; 3. "
                      "quando non ci sono più americani attivi in mappa (si esce da A5–H1). Nei primi due casi non si perdono PV per gli "
                      "incapacitati.",
    "testo_fine": "",
    "germani": [22, 23, 24, 48, 49, 50, 52, 53, 55, 56],
}

MISSIONI[18] = {
    "titolo": "Il mattino dopo", "titolo_originale": "The Morning After",
    "data": "Ardenne, 20 dicembre 1944", "mappa": "BE", "nord": "a sinistra (in alto è est)", "libro": "ph",
    "briefing": "20 dicembre 1944, Ardenne. Da giorni i tedeschi dilagano dove prima c’erano le linee alleate. Il reggimento, isolato, "
                "ha dato l’ordine di resistere. All’alba gli uomini si svegliano nel paesino che difendono da giorni: i rifornimenti "
                "scarseggiano, la squadra è stremata e lungo tutto il fronte si contano le munizioni chiedendosi quanto si potrà resistere.",
    "ingresso": "Mappe B ed E, in alto è est. La squadra comincia in K15. Un soldato a caso comincia ferito; la radio è gratis (la porta "
                "il sergente A). Prima della missione si tira, per ogni soldato e ogni tipo di munizione, sulla tabella delle munizioni "
                "consumate (in automatico). Macerie in B11, C11, E11, D13, G13, G16, O18 e P18; guadi in I11, O10 e V11. Non ci sono "
                "livelli di attivazione.",
    "regole_testo": "[b]Fiume.[/b] Il corso d’acqua da A6 a Y11 è un fiume: si entra nei suoi esagoni solo dai ponti intatti o dai guadi. "
                    "[b]Guadi.[/b] Solo in questa missione i mezzi attraversano i guadi spendendo 3 PM. [b]Munizioni.[/b] Una parte delle "
                    "munizioni è stata consumata nei giorni precedenti.",
    "ingresso_breve": "K15", "uscita_breve": "bordo ovest, A19–Y19 (solo dopo l’ordine di ripiegare)",
    "ingresso_esagoni": ["K15"],
    "uscita_esagoni": ["%s19" % c for c in COL],
    "vittoria_pv": 0, "attivazione": {}, "obiettivi": [],
    "regole": {"fiume": True, "munizioni_consumate": True, "macerie_iniziali": ["B11", "C11", "E11", "D13", "G13", "G16", "O18", "P18"],
               "guadi_iniziali": ["I11", "O10", "V11"], "guadi_veicoli": 3, "radio_portata_ph": True, "ferito_casuale": True,
               "est_in_alto": True, "missione_18": True},
    "vittoria_testo": "[b]Vittoria e fine: si scoprono durante il gioco.[/b]",
    "testo_fine": "",
    "germani": [19, 25, 26, 27, 33, 34, 57, 58, 59, 60],
}


BINARIO_BE = ["Y5", "X4", "W5", "V4", "U5", "T4", "S5", "R5", "Q6", "P6", "O7", "N7", "M8", "L8", "K9", "J9", "I10", "H10", "G11",
              "F11", "E12", "D12", "C13", "B12", "A13"]
MACERIE_17 = ["L5", "M5", "M6", "K7", "N9", "O6", "P5", "Q5", "Q8", "R7", "P9", "S9"]


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
        if n == 17:
            d["regole"]["macerie_iniziali"] = MACERIE_17
            d["regole"]["binario"] = BINARIO_BE
            for g in d["tedeschi"].values():
                g["pv"] = 0
                g.pop("pv_cattura", None)
            # il 23 non ha colonne di Condizione: assiste la mitragliatrice del 22 (poi reazione speciale X), un turno per Round
            d["tedeschi"]["23"]["colonne"]["1-4"] = [840, 840, 840, 840]
            d["tedeschi"]["23"]["assiste"] = 22
            d["tedeschi"]["23"]["un_turno"] = True
            ev = d["condizioni"]["4"]["evento"]
            for k, v in ev.items():
                if v == "634":
                    ev[k] = "639"  # lettura della carta: 634 è un evento della Missione 13 (faro); 577 rimanda a 639
        if n == 18:
            d["carri_us"] = {str(k): mezzo(CARTE["US%d" % k]) for k in (1, 2, 3)}
            for k, c in d["carri_us"].items():
                for r in c["carro"]["righe"].values():
                    r["par"] = [x if x is not None else 969 for x in r["par"]]
                c["carro"]["primo_turno"] = 944
            for g in d["tedeschi"].values():
                if g.get("carro"):
                    g["carro"]["primo_turno"] = 923
        if n == 14:
            # lettura della carta: W18 rimanda a 449 (paragrafo d’altra missione); come X15 è la reazione speciale L (499)
            d["condizioni"]["3"]["movimenti"]["W18"] = "499"
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
