"""Costruisce data/carte/missioneN.json dalle letture OCR (tools/letture) delle carte missione,
dalle correzioni controllate a vista (tools/correzioni_carte.json) e dai riferimenti rossi
risolti con gli esagoni adiacenti (tools/rossi_carte.py).
Formato di ogni condizione: {"esagoni": {"A1": "NONE"|"EVENT"|"LAND"|"XXX"|"NNN"|"sN:NNN"},
"evento": {"0".."18": valore}, "movimenti": {"A1": "B2"|"NNN"|"USCITA"}}."""
import json, re, sys, pathlib
QUI = pathlib.Path(__file__).parent
sys.path.insert(0, str(QUI))
from rossi_carte import risolvi
CARTE = {2: ["m2_c1", "m2_c2", "m2_c3", "m2_c4", "m2_c5", "m2_c6"],
         3: ["m3_c1", "m3_c2", "m3_c3", "m4_c4"],
         4: ["m4_c1", "m4_c2", "m4_c3", None, "m4_c5", "m4_c6"],
         5: ["m5_c1", "m5_c2", "m5_c3", "m5_c4"],
         6: ["m6_c1", "m6_c2", "m6_c3", "m6_c4"],
         7: ["m7_c1", "m7_c2", "m7_c3", "m7_c4"],
         8: ["m8_c1", "m8_c2", "m8_c3", "m8_c4", "m8_c5"]}
VALIDO = re.compile(r"NONE|EVENT|LAND|XXX|\d{3}|s\d:\d{3}")
COR = json.load(open(QUI / "correzioni_carte.json"))
dubbi = []

def rosso(nome, k, v):
    r, c = k.split("|")
    cor = COR.get(nome, {})
    if k + ">" in cor:
        return cor[k + ">"] or None
    ls = [v.get("rosso")]
    if not any(ls):
        return None
    t = (ls[0] or "").strip()
    if re.fullmatch(r"\d{3}", t):
        return t
    if re.search(r"[Ee][Xx]|xit", t):
        return "USCITA"
    ll = (v.get("rosso_l") or "").strip()
    m = re.fullmatch(r"([A-Y])-?(\d{1,2})", t)
    if m and ll[:1] == m.group(1) and 1 <= int(m.group(2)) <= 19:
        return m.group(1) + m.group(2)
    # lettera ambigua (0/O/Q, 1/I/T, 8/S, 6/G) ma numero esatto: basta che un solo vicino combaci
    from rossi_carte import vicini, CL
    m2 = re.fullmatch(r"(.)-?(\d{1,2})", t.replace(" ", ""))
    if m2:
        cls = CL.get(m2.group(1), m2.group(1))
        ok = [h for h in vicini(c + r) if h[1:] == m2.group(2) and CL.get(h[0], h[0]) == cls]
        if len(ok) == 1:
            return ok[0]
    dest, marg = risolvi(c + r, ls, ll[0] if ll[:1].isalpha() else None)
    if marg < 0.35:
        dubbi.append((nome, k, ls, dest))
    return dest

for mis, nomi in CARTE.items():
    out = {}
    for i, nome in enumerate(nomi):
        if nome is None:
            continue
        let = json.load(open(QUI / "letture" / f"{nome}.json"))
        cor = COR.get(nome, {})
        cond = {"carta": nome, "esagoni": {}, "evento": {}, "movimenti": {}}
        for k, v in let.items():
            if k.startswith("_"):
                continue
            r, c = k.split("|")
            val = cor.get(k, v["norm"])
            if c == "RE":
                if r != "19":
                    cond["evento"][r] = val
                    if not VALIDO.fullmatch(val):
                        dubbi.append((nome, k, val, "nero"))
                continue
            if r == "0":
                continue
            cond["esagoni"][c + r] = val
            if not VALIDO.fullmatch(val):
                dubbi.append((nome, k, val, "nero"))
            d = rosso(nome, k, v)
            if d:
                cond["movimenti"][c + r] = d
        out[str(i + 1)] = cond
    json.dump(out, open(QUI.parent / "data" / "carte" / f"missione{mis}.json", "w"), ensure_ascii=False, indent=1)
print("dubbi:", len(dubbi))
for d in dubbi:
    print(d)
