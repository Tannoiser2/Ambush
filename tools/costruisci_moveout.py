#!/usr/bin/env python3
"""Costruisce le missioni di Move Out! (9–12) e data/paragrafi_mo.json.

Fonti:
- tools/carte_moveout.json   carte dei tedeschi GE11–57 e dei mezzi americani (Move Out!)
- tools/carte_excel.json      carte Condizione Mov_M<n>_C<c> (foglio Excel del modulo TTS)
- tools/paragrafi_mo<n>.py    testo italiano e ops dei paragrafi di ciascuna missione
- data/missione1.json         squadra pre-generata
"""
import importlib, json, pathlib, re, sys

R = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(R / "tools"))
CARTE = json.loads((R / "tools/carte_moveout.json").read_text())
EXCEL = json.loads((R / "tools/carte_excel.json").read_text())
M1 = json.loads((R / "data/missione1.json").read_text())

RUOLI = {"Soldier": "Soldato", "Elite Veteran": "Veterano scelto", "Major": "Maggiore", "Lieutenant": "Tenente",
         "Sergeant": "Sergente", "Officer": "Ufficiale", "NCO": "Sottufficiale", "Veteran NCO": "Sottufficiale veterano",
         "Machine Gunner": "Mitragliere", "Assistant Gunner": "Servente", "Sniper": "Cecchino",
         "Veteran Infantry": "Fante veterano", "Volksgrenadier": "Volksgrenadier", "Hitler Youth": "Gioventù hitleriana",
         "Sentry": "Sentinella", "Rifleman": "Fuciliere", "Panzergrenadier": "Granatiere corazzato", "Guard": "Guardia"}
COMANDANTI = ("Officer", "NCO", "Veteran NCO", "Sergeant", "Lieutenant", "Major", "Captain")
SOSTITUZIONI_PAR = {835: 833}  # 835 manca dal libretto: si usa 833 (stessa famiglia di autoconservazione)


def pulisci_rif(v):
    """Ripulisce le letture del foglio Excel: EVENT', NONE-, 435R, NOME..."""
    v = str(v).strip()
    v = {"s5:147": "s5:647", "S3-'490": "s3:490"}.get(v, v)
    if v.startswith("T-"):
        v = v[2:]  # paragrafi «T» della galleria (Missione 12): l’elenco è in regole.paragrafi_t
    m = re.match(r"^(s\d:)?(\d{3,4})", v)
    if m:
        return (m.group(1) or "") + m.group(2)
    if v.upper().startswith("EV") or v == "SMENT":
        return "EVENT"
    if v.upper().startswith("LAND"):
        return "LAND"
    return "NONE"


def _adiacente(a, b):
    ca, ra = ord(a[0]) - 65, int(a[1:])
    cb, rb = ord(b[0]) - 65, int(b[1:])
    if abs(ca - cb) > 1 or (ca, ra) == (cb, rb):
        return False
    if ca == cb:
        return abs(ra - rb) == 1
    # colonne pari (A=0, C, E...) spostate in alto rispetto alle dispari
    return rb - ra in ((0, 1) if ca % 2 == 1 else (-1, 0))


def pulisci_mov(h, v):
    """Movimento rosso: esagono adiacente, LAND, o paragrafo. Letture Excel guaste corrette o scartate."""
    v = str(v).strip()
    if v.upper().startswith("LAND"):
        return "LAND"
    if v.upper() == "USCITA":
        return "USCITA"
    # «O» letta come «0»/«C0»/«ON»/«OR»: correzioni verificate sull’adiacenza
    v = {("D2", "CO"): "C2", ("D5", "CO"): "C5", ("P5", "ON"): "O5", ("P6", "OR"): "O6"}.get((h, v), v)
    v = v.replace("_", "")
    if re.match(r"^[A-Y]-?I\d$", v):
        v = v[0] + "1" + v[-1]
    m = re.match(r"^(\d{3})-?$", v)
    if m:
        return m.group(1) if v != "005" else ""
    m = re.match(r"^2014-01-01", v)
    if m:
        v = "J14"  # «J-14» letto da Excel come data
    v = v.replace("=", "").replace("-", "")
    if re.match(r"^[06]\d+$", v):
        v = {"0": "O", "6": "G"}[v[0]] + v[1:]
    if re.match(r"^S1\d$", v):
        v = "S" + v[1:].replace("10", "10")
    if v == "S10" or re.match(r"^[A-Y]\d+$", v):
        return v if _adiacente(h, v) else ""
    return ""


MODELLI_CARRO = {"Panzer IV": "panzer4", "Jagdpanther": "jagdpanther"}


def carro(n, c):
    """Carta di un carro di Move Out! nel formato dei carri del gioco base."""
    r5 = c["equipaggio"]["5"]
    return {"lettera": c["lettera"], "ruolo": c["ruolo"], "pv": 0, "armi": [], "granate": 0,
            "IN": r5["IN"], "PC": r5["PC"], "WS": r5["WS"], "DS": r5["DS"], "MPA": 6,
            "gruppi": [[0, 9]], "colonne": {"1-6": [800]},
            "carro": {"modello": MODELLI_CARRO.get(c["ruolo"], "panzer4"), "gruppi": c["gruppi"], "righe": c["equipaggio"],
                      "pv_distrutto": int(c.get("pv_distrutto", 0)), "primo_turno": 0, "testo": c.get("note", "")}}


def tedeschi(nums):
    out = {}
    for n in nums:
        c = CARTE["GE%d" % n]
        if c.get("veicolo") is True and "equipaggio" in c:
            out[str(n)] = carro(n, c)
            continue
        d = {"lettera": c["lettera"], "ruolo": RUOLI.get(c["ruolo"], c["ruolo"]), "pv": c["pv"], "armi": c["armi"],
             "granate": c["granate"], "IN": c["IN"], "PC": c["PC"], "WS": c["WS"], "MPA": c["MPA"],
             "gruppi": c["gruppi"], "colonne": {}}
        for col, v in c["colonne"].items():
            col = col.replace("*", "").strip()
            if re.match(r"^[\d ,]+$", col) and ("," in col or " " in col):
                col = ",".join(ch for ch in col if ch.isdigit())
            d["colonne"][col] = [SOSTITUZIONI_PAR.get(int(x), int(x)) for x in v]
        if c["ruolo"] in COMANDANTI:
            d["comandante"] = True
        for k in ("primo_turno", "equipaggio", "veicolo", "pv_veicolo", "carro", "pv_uscita_prigioniero"):
            if k in c:
                d[k] = c[k]
        out[str(n)] = d
    return out


def condizioni(n):
    out = {}
    for c in range(1, 7):
        x = EXCEL.get(f"Mov_M{n}_C{c}")
        if not x:
            continue
        out[str(c)] = {
            "esagoni": {h: pulisci_rif(v) for h, v in x["esagoni"].items()},
            "evento": {e: pulisci_rif(v) for e, v in x["evento"].items()},
            "movimenti": {h: m for h, m in ((h, pulisci_mov(h, v)) for h, v in x["movimenti"].items()) if m},
        }
    return out


def ruscelli(mappa):
    m = json.loads((R / f"data/mappa_{mappa.lower()}.json").read_text())["esagoni"]
    return sorted(h for h, x in m.items() if x.get("t") == "stream" and not x.get("ponte"))


MISSIONI = {
    12: {
        "titolo": "Per la cruna dell’ago", "titolo_originale": "Through the Eye of the Needle",
        "data": "Parigi, 16 agosto 1944", "mappa": "A", "nord": "in alto", "libro": "mo",
        "briefing": "16 agosto 1944. Durante una pattuglia di routine alla periferia di Parigi metà della squadra è stata "
                    "catturata. Quando i soldati non si sono presentati all’ora stabilita, il caposquadra ha deciso di sua "
                    "iniziativa di cercarli e, se possibile, liberarli.",
        "ingresso": "Mappa A, nord in alto. A è libero; B e altri tre soldati estratti a caso sono prigionieri e senz’armi. "
                    "I quattro rimasti entrano dal bordo nord, tra Q1 e W1. Il ponte in M12 è distrutto.",
        "regole_testo": "[b]Fiume.[/b] Il corso d’acqua da H1 a O19 è un fiume: si attraversa solo sui ponti intatti. "
                        "[b]Notte.[/b] È mezzanotte: si vede solo fino a quattro esagoni. [b]Galleria.[/b] Se il paragrafo "
                        "lo rivela, nella galleria si leggono solo i paragrafi T e nessun tedesco vede chi ci cammina.",
        "ingresso_breve": "bordo nord, Q1–W1", "uscita_breve": "mappa B, bordo ovest (A1–A19)",
        "ingresso_esagoni": ["Q1", "R1", "S1", "T1", "U1", "V1", "W1"], "uscita_esagoni": ["A%d" % i for i in range(1, 20)],
        "vittoria_pv": 19, "attivazione": {"1": 0, "2": 1, "3": 6, "4": 1, "5": 8}, "obiettivi": [],
        "regole": {"prigionieri_mo": True, "vista": 4, "fiume": True, "fine_condizione": 3, "uscita_mappa": "B",
                   "paragrafi_t": ["976", "977"]},
        "vittoria_testo": "[b]Vittoria: 19 PV.[/b] Valgono le attivazioni dei tedeschi e 5 PV per ogni compagno liberato e "
                          "portato fuori alla fine. Gli incapacitati della Condizione 1 non costano PV; nelle altre Condizioni "
                          "le perdite contano come sempre. Il modo in cui finisce la missione sarà rivelato durante il gioco.",
        "testo_fine": "",
        "germani": [11, 17, 18, 19, 54, 55, 56, 57],
    },
    10: {
        "titolo": "Assalto per uccidere", "titolo_originale": "Assault to Kill",
        "data": "Saint-Lô, 21 giugno 1944", "mappa": "A", "nord": "in alto", "libro": "mo",
        "briefing": "È il D-Day più quindici e i tedeschi contrattaccano ancora le linee alleate vicino alla città strategica di "
                    "Saint-Lô. La squadra fa da osservatore avanzato per l’artiglieria; se l’assalto tedesco sfonda, deve "
                    "avanzare in città e tenerla il più a lungo possibile, ripiegando solo se la posizione diventa insostenibile. "
                    "Dal comando di divisione arriverà poco aiuto: gli assalitori sono probabilmente della Panzer Lehr.",
        "ingresso": "Nella Condizione 1 la squadra non è in mappa: sulla mappa A (nord in alto) quattordici tedeschi partono "
                    "dalla riga 19, in piedi, e tu dirigi i mortai. Quando l’ultimo tedesco attivo è uscito dalla mappa A o è "
                    "fuori combattimento si passa alla Condizione 2 sulla mappa B (in alto c’è l’ovest): la squadra entra dal "
                    "bordo nord, da Y1 a Y19. Ricevi gratis un bazooka con quattro razzi in più.",
        "regole_testo": "[b]Mortai.[/b] Nella Condizione 1 comandi due colpi di mortaio per turno (abilità 3, niente panico). "
                        "Tocca un esagono: se il colpo è nuovo si disperde secondo il diagramma del colpo di aggiustamento "
                        "(percentuale), se è entro due esagoni dal colpo precedente lo «sposti» col diagramma più stretto (un "
                        "dado), se tocchi lo stesso esagono mantieni il tiro senza dispersione. I tedeschi nell’esagono colpito "
                        "tirano per i danni come da granata (dentro, in terreno libero, strada, copertura o ruscello; fuori, in "
                        "cespugli, bosco o edificio); i carri tirano un dado. [b]Ruscello.[/b] Si attraversa ovunque, al costo "
                        "della tabella del movimento. Nella Condizione 1 non ci sono eventi casuali.",
        "ingresso_breve": "mappa B, bordo nord (Y1–Y19), dalla Condizione 2", "uscita_breve": "bordo nord, Y1–Y19 (per mettere in salvo gli incapacitati)",
        "ingresso_esagoni": ["Y%d" % i for i in range(1, 20)], "uscita_esagoni": ["Y%d" % i for i in range(1, 20)],
        "vittoria_pv": 10, "attivazione": {}, "obiettivi": [],
        "regole": {"sbarramento": True, "fine_condizione": 4, "mappa_2": "B",
                   "tedeschi_iniziali": {"22": "A19", "24": "B19", "23": "D19", "25": "E19", "26": "F19", "13": "H19",
                                         "15": "I19", "14": "J19", "16": "K19", "27": "L19", "34": "Q19", "36": "R19",
                                         "35": "S19", "37": "T19"}},
        "vittoria_testo": "[b]Vittoria: 10 PV.[/b] Si parte da zero e le attivazioni non valgono nulla: guadagni i PV dei "
                          "tedeschi uccisi o incapacitati, degli ufficiali catturati e dei mezzi messi fuori uso; perdi i PV dei "
                          "soldati americani uccisi o incapacitati (gli incapacitati portati fuori dal bordo nord, Y1–Y19, non "
                          "costano) e il valore di ogni tedesco o mezzo che esce dal bordo nord. La missione finisce solo nella "
                          "Condizione 4, appena non ci sono più americani attivi in mappa; i tedeschi rimasti in mappa contano "
                          "come usciti (tranne i mezzi immobilizzati).",
        "testo_fine": "",
        "germani": [13, 14, 15, 16, 22, 23, 24, 25, 26, 27, 34, 35, 36, 37],
    },
    11: {
        "titolo": "La nebbia della guerra", "titolo_originale": "The Fog of War",
        "data": "Ardenne, dicembre 1944", "mappa": "A", "nord": "in alto", "libro": "mo",
        "briefing": "Foresta delle Ardenne, dicembre 1944. I tedeschi sono stati respinti fino ai confini della Germania e "
                    "sembra che la guerra finirà presto. La squadra dorme tranquilla in un villaggio accogliente di un settore "
                    "quieto del fronte. C’è una sola sentinella. Si avvicina Natale: i soldati sognano l’Iowa, le ragazze e casa.",
        "ingresso": "Mappa A, nord in alto. Metti un solo soldato a tua scelta, la sentinella, in Y8. Il resto della squadra "
                    "dorme fuori mappa: entrerà in un modo che sarà rivelato da un paragrafo (non si usa l’ingresso dal bordo "
                    "della regola 6/10).",
        "regole_testo": "[b]Regole speciali.[/b] Il ruscello è ghiacciato e conta come terreno libero: si entra normalmente, "
                        "ma il ghiaccio può cedere (paragrafo 431). Un soldato caduto in acqua è bagnato fino alla fine della "
                        "missione. Le reazioni speciali dei tedeschi saranno rivelate durante il gioco.",
        "ingresso_breve": "in Y8 (solo la sentinella)", "uscita_breve": "bordo ovest, da A1 ad A19",
        "ingresso_esagoni": ["Y8"], "uscita_esagoni": ["A%d" % i for i in range(1, 20)],
        "vittoria_pv": 20, "attivazione": {}, "obiettivi": [],
        "regole": {"sentinella": True, "ghiaccio": True, "sveglia": True, "fine_condizione": 3, "niente_attivazione": True,
                   "pv_uscita": {"A%d" % i: 2 for i in range(1, 20)}},
        "vittoria_testo": "[b]Vittoria: 20 PV.[/b] Valgono le attivazioni e le catture dei tedeschi; altri PV saranno rivelati "
                          "durante il gioco. Il modo in cui finisce la missione sarà rivelato da un paragrafo.",
        "testo_fine": "",
        "germani": [28, 29, 38, 39, 42, 43, 44, 45, 46, 47, 48, 49],
    },
}


def main():
    tutti = {}
    for n, meta in MISSIONI.items():
        mod = importlib.import_module(f"paragrafi_mo{n}")
        for k, v in mod.P.items():
            if k in tutti and tutti[k]["it"] != v["it"]:
                print(f"  attenzione: paragrafo {k} diverso tra missioni")
            tutti[k] = v
        meta = dict(meta)
        d = {"id": n}
        nums = meta.pop("germani")
        d.update(meta)
        d["squadra"] = json.loads(json.dumps(M1["squadra"]))
        d["tedeschi"] = tedeschi(nums)
        d["condizioni"] = condizioni(n)
        if n == 10:
            # Niente PV per le attivazioni: valgono le perdite inflitte (e le catture degli ufficiali).
            for g in d["tedeschi"].values():
                if "carro" in g:
                    g["pv_valore"] = g["carro"]["pv_distrutto"]
                    continue
                g["pv_valore"] = g["pv"]
                g["pv_eliminato"] = g["pv"]
                if g.get("comandante"):
                    g["pv_cattura"] = g["pv"]
                g["pv"] = 0
            for a in d["squadra"]:
                if "bazooka" in a["porte"]:
                    a["munizioni"]["bazooka"] = int(a["munizioni"].get("bazooka", 0)) + 4
                    break
        if n == 11:
            d["modifiche_iniziali"] = {h: "clear" for h in ruscelli("A")}
        if n == 12:
            d["modifiche_iniziali"] = {"M12": "stream"}
        (R / f"data/missione{n}.json").write_text(json.dumps(d, ensure_ascii=False, indent=1))
        mancanti = set()
        for c in d["condizioni"].values():
            for v in list(c["esagoni"].values()) + list(c["evento"].values()):
                p = v.split(":")[-1]
                if p.isdigit() and p not in mod.P:
                    mancanti.add(p)
        for g in d["tedeschi"].values():
            for v in g["colonne"].values():
                for x in v:
                    if str(x) not in mod.P and not (800 <= x <= 999):
                        mancanti.add(str(x))
        print(n, len(d["condizioni"]), "carte,", len(d["tedeschi"]), "tedeschi; mancanti:", sorted(mancanti))
    (R / "data/paragrafi_mo.json").write_text(json.dumps(tutti, ensure_ascii=False, indent=1))
    print(len(tutti), "paragrafi Move Out!")


if __name__ == "__main__":
    main()
