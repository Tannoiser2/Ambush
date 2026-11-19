#!/usr/bin/env python3
"""Costruisce data/missioneN.json (N = 2..8) da:
- data/carte/missioneN.json   carte Condizione trascritte (tools/costruisci_carte.py)
- tools/carte_tedeschi.json   carte dei tedeschi estratte dal PDF delle carte
- data/missione1.json         squadra pre-generata (la stessa per tutte le missioni)
- i testi qui sotto (briefing, ingresso, vittoria), tradotti dal regolamento originale."""
import json, pathlib, re
R = pathlib.Path(__file__).resolve().parent.parent
CARTE = json.loads((R / "tools/carte_tedeschi.json").read_text())
M1 = json.loads((R / "data/missione1.json").read_text())
COL = "ABCDEFGHIJKLMNOPQRSTUVWXY"
RUOLI = {"Soldier": "Soldato", "Sniper": "Cecchino", "Officer": "Ufficiale", "NCO": "Sottufficiale",
         "Machine Gunner": "Mitragliere", "Assistant Gunner": "Servente", "Veteran Infantry": "Fante veterano",
         "Sentry": "Sentinella", "Panzergrenadier": "Granatiere corazzato", "Volksgrenadier": "Volksgrenadier",
         "Veteran NCO": "Sottufficiale veterano", "Scientist": "Scienziato", "Runner": "Staffetta",
         "Rifleman": "Fuciliere", "Sergeant": "Sergente", "Aide de Camp": "Aiutante di campo", "Engineer": "Geniere",
         "SS General": "Generale delle SS", "Kubelwagen Officer": "Ufficiale sulla Kübelwagen",
         "Staff Car & Driver": "Auto comando e autista", "Jagdpanther": "Jagdpanther", "Panzer IV": "Panzer IV"}

def tedeschi():
    out = {}
    for k, c in CARTE.items():
        if c["lato"] != "GE" or "colonne" not in c or "IN" not in c:
            continue
        d = {"lettera": c["lettera"], "ruolo": RUOLI.get(c["ruolo"], c["ruolo"]), "pv": c["pv"], "armi": c["armi"],
             "granate": c["granate"], "IN": c["IN"], "PC": c["PC"], "WS": c["WS"], "MPA": c["MPA"],
             "gruppi": c["gruppi"], "colonne": {}}
        for col, v in c["colonne"].items():
            d["colonne"][col.replace("*", "")] = v
        if c["ruolo"] in ("Officer", "NCO", "Veteran NCO", "Sergeant", "SS General"):
            d["comandante"] = True
        testo = " ".join(c["testo"].split())
        m = re.search(r"(?i)on first turn use (\d{3})", testo)
        if m:
            d["primo_turno"] = int(m.group(1))
        m = re.search(r"(?i)if special reaction (\w) comes into effect use (\d{3})", testo)
        if m:
            d["reazione_par"] = {m.group(1): int(m.group(2))}
        if "Staff Car" in c["ruolo"]:
            d["veicolo"] = "auto_comando"
        m = re.search(r"\+(\d) VP if disabled", testo)
        if m:
            d["pv_veicolo"] = int(m.group(1))
        m = re.search(r"\+(\d) VP if incapacitated OR killed", testo)
        if m:
            d["pv_eliminato"] = int(m.group(1))
        m = re.search(r"If captured \+(\d) VP for exiting", testo)
        if m:
            d["pv_uscita_prigioniero"] = int(m.group(1))
        m = re.search(r"\+(\d) VP if captured", testo)
        if m:
            d["pv_cattura"] = int(m.group(1))
        out[str(c["num"])] = d
    # Carri (Panzer IV, Jagdpanther): tabella per numero di uomini dell’equipaggio.
    for k, c in CARTE.items():
        if c["lato"] != "GE" or "Crew" not in c["testo"]:
            continue
        righe_t = c["testo"].splitlines()
        i = next(j for j, l in enumerate(righe_t) if l.strip().startswith("Crew"))
        intest = righe_t[i].split()[5:]
        gruppi = [[int(x.split("-")[0]), int(x.split("-")[-1])] for x in intest]
        righe = {}
        for l in righe_t[i + 1:i + 6]:
            n = l.replace("+", "").split()
            if len(n) < 9:
                continue
            righe[n[0]] = {"IN": int(n[1]), "PC": int(n[2]), "WS": int(n[3]), "DS": int(n[4]), "par": [int(x) for x in n[5:9]]}
        modello = "jagdpanther" if "Jagd" in c["ruolo"] else "panzer4"
        pv = re.search(r"\+(\d) VP if knocked out", c["testo"])
        r5 = righe.get("5", {"IN": 5, "PC": 8, "WS": 2, "DS": 8})
        out[str(c["num"])] = {"lettera": c["lettera"], "ruolo": c["ruolo"], "pv": c["pv"], "armi": [], "granate": 0,
            "IN": r5["IN"], "PC": r5["PC"], "WS": r5["WS"], "MPA": 6, "DS": r5["DS"],
            "gruppi": [[0, 9]], "colonne": {"1-6": [800]},
            "carro": {"modello": modello, "gruppi": gruppi, "righe": righe, "pv_distrutto": int(pv.group(1)) if pv else 0,
                      "testo": " ".join(l.strip() for l in righe_t[1:i] if l.strip())}}
    # Carta 19 (Kübelwagen): autista S e ufficiale M, entrambi con la pistola. Le azioni dipendono da chi è attivo
    # (le gestisce scripts/motore/veicoli.gd); le colonne servono solo a dare un paragrafo di riserva.
    riserva = {"gruppi": [[0, 9]], "colonne": {"1-6": [802], "S": [813]}}
    out["19"] = dict(lettera="S", ruolo="Autista della Kübelwagen", pv=0, armi=["pistol"], granate=0, IN=3, PC=4, WS=-2, MPA=4, DS=6, **riserva)
    out["119"] = dict(lettera="M", ruolo="Ufficiale della Kübelwagen", pv=0, armi=["pistol"], granate=0, IN=4, PC=8, WS=0, MPA=4, DS=4, comandante=True, **riserva)
    return out

def esagoni(col_da, col_a, riga_da, riga_a):
    return [f"{COL[c]}{r}" for c in range(COL.index(col_da), COL.index(col_a) + 1) for r in range(riga_da, riga_a + 1)]

MISSIONI = {
 2: {
  "titolo": "Avanzata su Chasoul", "titolo_originale": "Advance on Chasoul", "data": "Francia, agosto 1944", "mappa": "B",
  "nord": "in alto",
  "briefing": "Agosto 1944. La divisione da cui dipende la tua squadra corre attraverso la Francia verso il confine tedesco, mentre la resistenza nemica si sgretola. In attesa del carburante, il reggimento manda avanti i tuoi uomini a esplorare il paesino di Chasoul. I tedeschi si ritirano più in fretta di quanto tu riesca ad avanzare: non è attesa opposizione, e i tuoi uomini dovrebbero poter occupare il villaggio fino al cambio.",
  "ingresso": "Mappa B, nord in alto. I soldati entrano dal margine ovest, in qualsiasi esagono da A6 ad A15 compresi. All’inizio non ci sono segnalini sulla mappa. Nessuna regola speciale; il corso d’acqua è un ruscello. Si usa la squadra pre-generata con il suo equipaggiamento.",
  "ingresso_breve": "dal margine ovest (A6–A15)", "uscita_breve": "dal margine ovest, da A6 ad A15",
  "ingresso_esagoni": [f"A{r}" for r in range(6, 16)],
  "vittoria_pv": 25, "attivazione": {"1": 1, "2": 3, "3": 5, "4": 6, "5": 7, "6": 6},
  "obiettivi": ["O6", "P5", "Q5"], "regole": {"pv_edifici": True},
  "vittoria_testo": "[b]Vittoria: 25 PV.[/b] Ottieni 1 PV per ogni esagono di edificio in cui entra un tuo soldato; altri modi di guadagnare PV si scoprono durante la missione. La missione termina in uno di due modi:\n1. Tutti gli esagoni di edificio sono stati raggiunti e tutti i soldati attivi sono nella stazione ferroviaria (O6, P5 e Q5).\n2. Tutti i soldati attivi escono dalla mappa da un esagono d’ingresso (A6–A15).\nPerdi 2 PV per ogni americano ucciso o incapacitato. Un incapacitato non costa PV se lo porti fuori mappa da A6–A15 o, quando tutti gli edifici sono stati raggiunti, dentro la stazione.",
  "testo_fine": "Tutti gli edifici sono stati raggiunti e la squadra è nella stazione: la missione termina. I soldati incapacitati portati nella stazione non fanno perdere punti.",
 },
}

def edifici_b():
    m = json.loads((R / "data/mappa_b.json").read_text())
    return sorted([h for h, v in m["esagoni"].items() if "building" in v["t"]], key=lambda h: (COL.index(h[0]), int(h[1:])))

MISSIONI[3] = {
  "titolo": "Un freddo mattino in Belgio", "titolo_originale": "A Cold Morning in Belgium", "data": "Belgio, inverno 1944", "mappa": "B",
  "nord": "a sinistra (l’est è in alto)",
  "briefing": "La tua squadra, di guarnigione in un settore tranquillo del fronte, è accantonata in un villaggio appena a est di un fiume. In questo mattino nebbioso e innevato gli uomini hanno l’ordine di pattugliare gli edifici bombardati lì vicino, in cerca di esploratori tedeschi.",
  "ingresso": "Mappa B, con l’est in alto (le coordinate non cambiano). Disponi i soldati in tre edifici a tua scelta; la jeep della squadra parte in un esagono scoperto accanto alla strada. Nell’esagono di edificio L10 c’è un deposito di carburante con decine di taniche piene. La squadra ha una radio. Non ci sono livelli di attivazione: tutti i tedeschi entrano per evento casuale.",
  "regole_testo": "[b]Regole speciali.[/b] Nebbia leggera: si vede al massimo a 6 esagoni, salvo diversa indicazione di un paragrafo. Nei Round non si fanno controlli di paragrafo entrando negli esagoni (nelle Operazioni sì). Il corso d’acqua da A6 a Y17 è un fiume: si attraversa solo su un ponte intatto.",
  "ingresso_breve": "in tre edifici a tua scelta", "uscita_breve": "il margine ovest, da A13 ad A19",
  "uscita_esagoni": [f"A{r}" for r in range(13, 20)],
  "vittoria_pv": 25, "attivazione": {},
  "obiettivi": ["A3", "A4", "B3", "C3", "T3", "U4", "V3"],
  "regole": {"vista": 6, "niente_controlli_round": True, "fiume": True, "pv_esagoni": ["A3", "A4", "B3", "C3", "T3", "U4", "V3"],
             "max_edifici": 3, "jeep": True, "radio": True, "deposito": "L10"},
  "vittoria_testo": "[b]Vittoria: 25 PV.[/b] Ottieni 1 PV per ciascuno di questi esagoni in cui entra un tuo soldato: A3, A4, B3, C3, T3, U4 e V3; altri modi si scoprono durante la missione. Un incapacitato non costa PV se lo porti fuori mappa da A13–A19. Come finisce la missione lo scoprirai giocando.",
  "testo_fine": "",
}

MISSIONI[4] = {
  "titolo": "Lancio notturno nel D-Day", "titolo_originale": "D-Day Night Drop to Destiny", "data": "Normandia, 6 giugno 1944", "mappa": "B",
  "nord": "in alto",
  "briefing": "D-Day, 6 giugno 1944. All’alba il reggimento della tua squadra si lancia col paracadute sulla penisola del Cotentin, a sostegno degli sbarchi di Utah Beach. La squadra deve catturare intatti due ponti in un piccolo borgo vicino a Carentan. È prevista resistenza, ma la ricognizione non ha visto carri né armi pesanti vicino alla zona di lancio.",
  "ingresso": "Mappa B, nord in alto. Disponi i soldati sugli esagoni da Y6 a Y15, uno per esagono: la cassa delle armi occupa un esagono libero. Quando dai il via, ognuno scende col paracadute verso ovest (dado pari: nord-ovest; dispari: sud-ovest) finché la carta della Condizione 1 non dice «Atterra». All’atterraggio il terreno decide se il lancio va bene. Poi si controllano gli esagoni occupati con la nuova Condizione.",
  "regole_testo": "[b]Regole speciali.[/b] Notte: si vede al massimo a 5 esagoni, salvo gli esagoni illuminati da un razzo. Il corso d’acqua da A6 a Y17 è un fiume: si attraversa solo sui ponti intatti. Nei Round chi è appena atterrato deve togliersi il paracadute (due azioni, accovacciato o in piedi) prima di fare altro; nelle Operazioni lo toglie da solo. Il fucile automatico, il bazooka e i suoi razzi sono nella cassa: per aprirla serve un’azione da accovacciati nel suo esagono, poi si prende l’equipaggiamento.",
  "ingresso_breve": "sugli esagoni da Y6 a Y15, uno per esagono", "uscita_breve": "qualsiasi esagono del bordo",
  "ingresso_esagoni": [f"Y{r}" for r in range(6, 16)],
  "vittoria_pv": 10, "attivazione": {"2": 2, "3": 5, "4": 8, "5": 8, "6": 8},
  "obiettivi": ["G13", "G14"],
  "regole": {"vista": 5, "fiume": True, "lancio": True, "disinnesco": True, "uscita_bordo": True, "uno_per_esagono": True,
             "fine_ponti": True, "niente_salvataggio": True},
  "squadra_armi": {"A": ["smg"], "B": ["carbine"], "C": ["carbine"], "D": ["carbine"], "E": ["carbine"], "F": ["smg"], "G": ["carbine"], "H": ["carbine"]},
  "squadra_munizioni": {"A": {"smg": 3, "granata": 2}, "B": {"carbine": 3, "granata": 2}, "C": {"carbine": 3, "granata": 2},
                        "D": {"carbine": 3, "granata": 2}, "E": {"carbine": 3, "granata": 2}, "F": {"smg": 3, "granata": 2},
                        "G": {"carbine": 3, "granata": 2}, "H": {"carbine": 3, "granata": 2}},
  "cassa": {"armi": ["ar", "bazooka", "smg"], "munizioni": {"ar": 3, "bazooka": 3, "smg": 2}},
  "vittoria_testo": "[b]Vittoria: 10 PV.[/b] Un ponte catturato intatto (disinnescando le cariche: quattro turni, anche divisi tra più soldati) vale 4 PV; entrambi 10 PV. Valgono anche le attivazioni e le catture dei tedeschi. In questa missione gli incapacitati costano sempre PV. Fine: nelle Condizioni 4–6 quando non ci sono tedeschi attivi e entrambi i ponti sono catturati o saltati; oppure quando tutti i soldati attivi sono usciti da un bordo; oppure se muoiono tutti.",
  "testo_fine": "",
}

MISSIONI[5] = {
  "titolo": "Operazione Borseggio", "titolo_originale": "Operation Pickpocket", "data": "Olanda, 4 luglio 1944", "mappa": "B",
  "nord": "in alto",
  "briefing": "4 luglio 1944. La tua squadra si è offerta volontaria per un pericoloso raid di commando dietro le linee tedesche: con l’aiuto della resistenza olandese deve infiltrarsi in Olanda e colpire una base segreta di razzi vicino all’Aia. Il comando alleato vuole i documenti sul misterioso razzo V-2 e la distruzione della base.",
  "ingresso": "Mappa B, nord in alto. I soldati entrano dal margine sud o ovest, tra A12 e L19 compresi. All’inizio non ci sono segnalini sulla mappa. Equipaggiamento leggero (niente fucili automatici, bazooka o mitragliatrici medie) più due cariche da demolizione.",
  "regole_testo": "[b]Regole speciali.[/b] Il corso d’acqua da A6 a Y17 è un fiume: si entra in un suo esagono solo su un ponte intatto o da un guado. I guadi si scoprono durante la missione (segnaposto GUADO) e si entrano da qualsiasi esagono di terra adiacente.",
  "ingresso_breve": "dal margine sud o ovest, tra A12 e L19", "uscita_breve": "il margine sud o ovest, tra A12 e L19",
  "ingresso_esagoni": [f"A{r}" for r in range(12, 20)] + [f"{c}19" for c in "BCDEFGHIJKL"],
  "vittoria_pv": 15, "attivazione": {"1": 1, "2": 3, "3": 5, "4": 7},
  "obiettivi": [],
  "regole": {"fiume": True, "documenti": True, "fine_uscita": True},
  "squadra_armi": {"A": ["smg"], "B": ["carbine"], "C": ["carbine"], "D": ["carbine"], "E": ["sar"], "F": ["sar", "satchel"], "G": ["smg"], "H": ["sar", "satchel"]},
  "squadra_munizioni": {"A": {"smg": 4, "granata": 2}, "B": {"carbine": 4, "granata": 2}, "C": {"carbine": 4, "granata": 2},
                        "D": {"carbine": 4, "granata": 2}, "E": {"sar": 4, "granata": 2}, "F": {"sar": 3, "granata": 2},
                        "G": {"smg": 4, "granata": 2}, "H": {"sar": 3, "granata": 2}},
  "vittoria_testo": "[b]Vittoria: 15 PV.[/b] I punti arrivano dai documenti trovati e dalle installazioni distrutte, come scoprirai giocando (le installazioni si distruggono lanciando una carica da demolizione nel loro esagono). I documenti valgono solo se il soldato che li porta esce dalla mappa: se cade, un altro può raccoglierli. La missione termina quando tutti i soldati attivi sono usciti tra A12 e L19; un incapacitato portato fuori da lì non costa PV.",
  "testo_fine": "",
}

def verifica(n, d):
    """Ogni riferimento delle carte e delle carte dei tedeschi attivati deve avere il suo paragrafo."""
    P = json.loads((R / "data/paragrafi.json").read_text())
    mancanti, tedeschi_usati = set(), set()
    for c in d["condizioni"].values():
        for v in list(c["esagoni"].values()) + list(c["evento"].values()) + list(c["movimenti"].values()):
            for num in re.findall(r"\d{3}", v):
                if num not in P:
                    mancanti.add(num)
    def visita(ops):
        for o in ops:
            if o.get("op") == "goto" and o["p"] not in P:
                mancanti.add(o["p"])
            if o.get("op") == "activate":
                for g, _h in o["g"]:
                    tedeschi_usati.add(str(g))
            if o.get("op") == "catena":
                for _h, b in o["passi"]:
                    visita(b)
            for k in ("ok", "ko", "then", "else", "any", "all_fail"):
                if k in o:
                    visita(o[k])
            if o.get("op") == "die":
                for _, _, b in o["b"]:
                    visita(b)
    for p in P.values():
        visita(p["ops"])
    for g in tedeschi_usati:
        if g not in d["tedeschi"]:
            continue
        for col in d["tedeschi"][g]["colonne"].values():
            for num in col:
                if num is not None and "%03d" % int(num) not in P:
                    mancanti.add("%03d" % int(num))
    return sorted(mancanti)

def main():
    ted = tedeschi()
    for n, meta in MISSIONI.items():
        carte = json.loads((R / f"data/carte/missione{n}.json").read_text())
        d = {"id": n}
        d.update(meta)
        d["squadra"] = json.loads(json.dumps(M1["squadra"]))
        for s in d["squadra"]:
            if s["id"] in meta.get("squadra_armi", {}):
                s["porte"] = meta["squadra_armi"][s["id"]]
                s["munizioni"] = meta["squadra_munizioni"][s["id"]]
        d["tedeschi"] = ted
        if n == 3:
            d["ingresso_esagoni"] = edifici_b()
        d["condizioni"] = {k: {"esagoni": v["esagoni"], "evento": v["evento"], "movimenti": v["movimenti"]} for k, v in carte.items()}
        if n == 4 and "4" not in d["condizioni"]:
            # Manca la carta della Condizione 4: si usa quella della 5 (stessi livelli di attivazione).
            d["condizioni"]["4"] = dict(d["condizioni"]["5"], sostituita=5)
        (R / f"data/missione{n}.json").write_text(json.dumps(d, ensure_ascii=False, indent=1))
        print(n, len(d["condizioni"]), len(ted), "mancanti:", verifica(n, d))

if __name__ == "__main__":
    main()
