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
        out[str(c["num"])] = d
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
                if num is not None and str(num) not in P:
                    mancanti.add(str(num))
    return sorted(mancanti)

def main():
    ted = tedeschi()
    for n, meta in MISSIONI.items():
        carte = json.loads((R / f"data/carte/missione{n}.json").read_text())
        d = {"id": n}
        d.update(meta)
        d["squadra"] = M1["squadra"]
        d["tedeschi"] = ted
        d["condizioni"] = {k: {"esagoni": v["esagoni"], "evento": v["evento"], "movimenti": v["movimenti"]} for k, v in carte.items()}
        (R / f"data/missione{n}.json").write_text(json.dumps(d, ensure_ascii=False, indent=1))
        print(n, len(d["condizioni"]), len(ted), "mancanti:", verifica(n, d))

if __name__ == "__main__":
    main()
