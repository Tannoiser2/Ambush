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
        m = re.match(r"^\s*([0-9OoSl]{3})[.,]\s+(.*)", riga)
        num = None
        if m:
            t = m.group(1).replace("O", "0").replace("o", "0").replace("S", "5").replace("l", "1")
            if t.isdigit() and 100 <= int(t) <= 999:
                num = int(t)
        if num is not None:
            blocchi.append([num, m.group(2)])
        elif blocchi:
            blocchi[-1][1] += "\n" + riga
# Numeri letti male (487 al posto di 137): in una sequenza crescente si rimettono al posto giusto.
nums = [b[0] for b in blocchi]
for i in range(1, len(nums) - 1):
    a, x, b = nums[i - 1], nums[i], nums[i + 1]
    if not (a < x < b) and b - a == 2:
        nums[i] = a + 1
    elif not (a < x < b) and 2 < b - a <= 4 and str(a + 1)[-1] == str(x)[-1]:
        nums[i] = a + 1
out = {}
for n, (num, testo) in zip(nums, blocchi):
    k = str(n)
    while k in out:
        k += "_bis"
    out[k] = testo
for k in out:
    out[k] = re.sub(r"\n{2,}", "\n", out[k]).strip()
(Q / "paragrafi_ss_en.json").write_text(json.dumps(dict(sorted(out.items())), ensure_ascii=False, indent=1))
print(len(out), "paragrafi")
