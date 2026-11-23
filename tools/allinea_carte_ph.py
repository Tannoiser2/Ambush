#!/usr/bin/env python3
"""Allinea le carte Condizione di Purple Heart (13–18) lette con l’OCR ai dati del programma d’aiuto
«ePurpleHeart» (database FileMaker AmbMissioncards, estratto in tools/carte_ph_programma.json):
dove il programma dà un valore valido (riferimento nero, paragrafo esistente, esagono adiacente o uscita) vince lui.
Si lancia in coda a tools/costruisci_carte.py."""
import json, pathlib, re, sys
QUI = pathlib.Path(__file__).parent
sys.path.insert(0, str(QUI))
from rossi_carte import vicini

P = json.loads((QUI / "paragrafi_ph_en.json").read_text())
DB = json.loads((QUI / "carte_ph_programma.json").read_text())


def nero(p, t):
    t = t.strip()
    if p:
        return (t.lower() + ":" + p) if re.fullmatch(r"[sS]\d", t) else p
    t = t.upper()
    return t if t in ("NONE", "EVENT", "XXX", "LAND") else None


def rosso(h, mv):
    mv = mv.strip().upper()
    if not mv:
        return ""
    if mv.startswith("EX"):
        return "USCITA"
    if re.fullmatch(r"\d{3}", mv):
        return mv if mv in P else None
    m = re.fullmatch(r"([A-Y])-?0?(\d{1,2})", mv)
    if m:
        x = m.group(1) + str(int(m.group(2)))
        return x if x in vicini(h) else None
    return None


def allinea():
    cambi = 0
    for mis in range(13, 19):
        f = QUI.parent / "data" / "carte" / f"missione{mis}.json"
        d = json.loads(f.read_text())
        for c, v in d.items():
            for h, (p, mv, t) in DB.get(f"{mis}_{c}", {}).items():
                if h.startswith("RE"):
                    r = str(int(h[2:]))
                    x = nero(p, t)
                    if r != "19" and x and v["evento"].get(r) != x:
                        v["evento"][r] = x; cambi += 1
                    continue
                if h not in v["esagoni"]:
                    continue
                x = nero(p, t)
                if x and x != v["esagoni"][h]:
                    v["esagoni"][h] = x; cambi += 1
                y = rosso(h, mv)
                if y is not None and y != v["movimenti"].get(h, ""):
                    if y:
                        v["movimenti"][h] = y
                    else:
                        v["movimenti"].pop(h, None)
                    cambi += 1
        f.write_text(json.dumps(d, ensure_ascii=False, indent=1))
    print("carte Purple Heart allineate al programma:", cambi, "correzioni")


if __name__ == "__main__":
    allinea()
