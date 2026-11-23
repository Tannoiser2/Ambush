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


def tedeschi(nums):
    out = {}
    for n in nums:
        c = CARTE["GE%d" % n]
        d = {"lettera": c["lettera"], "ruolo": RUOLI.get(c["ruolo"], c["ruolo"]), "pv": c["pv"], "armi": c["armi"],
             "granate": c["granate"], "IN": c["IN"], "PC": c["PC"], "WS": c["WS"], "MPA": c["MPA"],
             "gruppi": c["gruppi"], "colonne": {}}
        for col, v in c["colonne"].items():
            d["colonne"][col.replace("*", "")] = [SOSTITUZIONI_PAR.get(int(x), int(x)) for x in v]
        if c["ruolo"] in COMANDANTI:
            d["comandante"] = True
        for k in ("primo_turno", "equipaggio", "veicolo", "pv_veicolo", "carro"):
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
        if n == 11:
            d["modifiche_iniziali"] = {h: "clear" for h in ruscelli("A")}
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
