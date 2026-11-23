"""Lettura minima dei record di un database FileMaker 5. Ogni record comincia con C0 C2 (o C1 05 C2) e due byte di
identificativo; seguono campi con etichetta di una lettera, lunghezza e valore; le ripetizioni di un campo seguono come
02 14 <indice> <lunghezza> <valore>. Un record lungo può essere spezzato su più pagine: i pezzi con lo stesso
identificativo si uniscono."""
import re


def _campi(r, j):
    f = {}
    last = ""
    while j < len(r) - 1:
        tag = r[j]
        if tag == 0x02 and j + 3 < len(r) and r[j + 1] == 0x14 and last:
            idx = r[j + 2]; ln = r[j + 3]
            f.setdefault(last + "*", {})[idx] = r[j + 4:j + 4 + ln].decode("latin-1")
            j += 4 + ln
            continue
        t = chr(tag)
        if not ("A" <= t <= "Z"):
            break
        ln = r[j + 1]
        if j + 2 + ln > len(r):
            break
        f[t] = r[j + 2:j + 2 + ln].decode("latin-1")
        last = t
        j += 2 + ln
    return f


def records(path):
    d = open(path, "rb").read()
    uniti = {}
    ordine = []
    for m in re.finditer(rb"(?:\xc0\xc2|\xc1\x05\xc2)(..)", d, re.S):
        rid = m.group(1)
        f = _campi(d, m.end())
        if not f:
            continue
        if rid not in uniti:
            uniti[rid] = {}
            ordine.append(rid)
        for k, v in f.items():
            if k.endswith("*"):
                uniti[rid].setdefault(k, {}).update(v)
            else:
                uniti[rid].setdefault(k, v)
    for rid in ordine:
        yield uniti[rid]
