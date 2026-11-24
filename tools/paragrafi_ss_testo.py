#!/usr/bin/env python3
"""Paragrafi inglesi di Silver Star dall'OCR del libretto (tools/libretto_ss/p-*.txt) → tools/paragrafi_ss_en.json."""
import json, re, pathlib
Q = pathlib.Path(__file__).parent
blocchi = []   # [numero letto, testo] in ordine di lettura
cur = None
for n in range(9, 41):
    p = Q / "libretto_ss" / f"p-{n:02d}.txt"
    if not p.exists():
        continue
    for riga in p.read_text().splitlines():
        if riga.startswith("SILVER STAR RULES"):
            continue
        mt = re.match(r"^\s*T ([0-9]{3})[.,]\s+(.*)", riga)
        if mt:  # paragrafi della galleria (Missione 20): «T 358»
            blocchi.append(["T" + mt.group(1), mt.group(2)])
            continue
        m = re.match(r"^\s*(?:4(?=105\.))?([0-9OoSl]{3})[.,]\s+(.*)", riga)
        num = None
        if m:
            t = m.group(1).replace("O", "0").replace("o", "0").replace("S", "5").replace("l", "1")
            if t.isdigit() and 100 <= int(t) <= 999:
                num = int(t)
        if num is not None and blocchi and re.search(r"\b[Ss]ee\s*$", blocchi[-1][1]):
            num = None  # «See\n612.» è un rimando spezzato a capo, non l'inizio di un paragrafo
        if num is not None:
            blocchi.append([num, m.group(2)])
        elif blocchi:
            blocchi[-1][1] += "\n" + riga
# Numeri letti male (487 al posto di 137): in una sequenza crescente si rimettono al posto giusto.
nums = [b[0] for b in blocchi]
idx = [i for i, v in enumerate(nums) if isinstance(v, int)]
for j in range(1, len(idx) - 1):
    i = idx[j]
    a, x, b = nums[idx[j - 1]], nums[i], nums[idx[j + 1]]
    if not (a < x < b) and b - a == 2:
        nums[i] = a + 1
    elif not (a < x < b) and 2 < b - a <= 4 and str(a + 1)[-1] == str(x)[-1]:
        nums[i] = a + 1
# «1» letto «4» (482 al posto di 182), anche più volte di fila: vale solo se diventa il successivo esatto del precedente.
idx = [i for i, v in enumerate(nums) if isinstance(v, int)]
for j in range(1, len(idx)):
    a, x = nums[idx[j - 1]], nums[idx[j]]
    if str(x)[0] == "4" and x - 300 == a + 1:
        nums[idx[j]] = x - 300
# Due numeri sbagliati di fila (136, 487, 438, 139).
idx = [i for i, v in enumerate(nums) if isinstance(v, int)]
for j in range(1, len(idx) - 2):
    a, x, y, b = (nums[idx[j + d]] for d in (-1, 0, 1, 2))
    if b - a == 3 and not (a < x < y < b):
        nums[idx[j]], nums[idx[j + 1]] = a + 1, a + 2
out = {}
for n, (num, testo) in zip(nums, blocchi):
    k = str(n)
    while k in out:
        k += "_bis"
    out[k] = testo
# Paragrafi finiti dentro il precedente perché l'OCR ha letto male il numero («6565.» = 655).
for k, nuovo, segno in (("654", "655", "6565.",),):
    if k in out and segno in out[k] and nuovo not in out:
        out[k], out[nuovo] = out[k].split(segno, 1)
for k in out:
    out[k] = re.sub(r"\n{2,}", "\n", out[k]).strip()
(Q / "paragrafi_ss_en.json").write_text(json.dumps(dict(sorted(out.items())), ensure_ascii=False, indent=1))
print(len(out), "paragrafi")
