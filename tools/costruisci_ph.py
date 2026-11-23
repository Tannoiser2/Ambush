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


def tedeschi(nums):
    out = {}
    for n in nums:
        c = CARTE["GE%d" % n]
        d = {"lettera": c["lettera"], "ruolo": RUOLI.get(c["ruolo"], c["ruolo"]), "pv": c["pv"], "armi": c["armi"],
             "granate": c["granate"], "IN": c["IN"], "PC": c["PC"], "WS": c["WS"], "MPA": c["MPA"],
             "gruppi": c["gruppi"], "colonne": {}}
        if c.get("pv_cattura"):
            d["pv_cattura"] = c["pv_cattura"]
        if c.get("esplosivi"):
            d["esplosivi"] = c["esplosivi"]
        for col, v in c["colonne"].items():
            d["colonne"][col] = [int(x) if x is not None else 816 for x in v]
        if c["ruolo"] in COMANDANTI:
            d["comandante"] = True
        out[str(n)] = d
    return out


def condizioni(n):
    d = json.loads((R / f"data/carte/missione{n}.json").read_text())
    return {c: {"esagoni": v["esagoni"], "evento": v["evento"], "movimenti": v["movimenti"]} for c, v in d.items()}


DEPOSITO_16 = ["U15", "U16", "V12", "V13", "V14", "V15", "W13", "W14", "W15"]
ANGOLI = ["A1", "A19", "Y1", "Y19"]

MISSIONI = {
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
    for n, meta in MISSIONI.items():
        mod = importlib.import_module(f"paragrafi_ph{n}")
        for k, v in mod.P.items():
            tutti[k] = v
        meta = dict(meta)
        d = {"id": n}
        nums = meta.pop("germani")
        d.update(meta)
        d["squadra"] = json.loads(json.dumps(M1["squadra"]))
        d["tedeschi"] = tedeschi(nums)
        d["condizioni"] = condizioni(n)
        if n == 16:
            vic = [f"{c}{r}" for c in COL for r in range(1, 20) if any(distanza(f"{c}{r}", a) <= 10 for a in ANGOLI)]
            d["ingresso_esagoni"] = [h for h in vic if h not in DEPOSITO_16]
            d["uscita_esagoni"] = []
        (R / f"data/missione{n}.json").write_text(json.dumps(d, ensure_ascii=False, indent=1))
        mancanti = set()
        for c in d["condizioni"].values():
            for v in list(c["esagoni"].values()) + list(c["evento"].values()) + list(c["movimenti"].values()):
                p = v.split(":")[-1]
                if p.isdigit() and p not in mod.P:
                    mancanti.add(p)
        for g in d["tedeschi"].values():
            for v in g["colonne"].values():
                for x in v:
                    if str(x) not in mod.P and not (800 <= x <= 999):
                        mancanti.add(str(x))
        print(n, len(d["condizioni"]), "carte,", len(d["tedeschi"]), "tedeschi; mancanti:", sorted(mancanti))
    (R / "data/paragrafi_ph.json").write_text(json.dumps(tutti, ensure_ascii=False, indent=1))
    print(len(tutti), "paragrafi Purple Heart")


if __name__ == "__main__":
    main()
