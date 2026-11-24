#!/usr/bin/env python3
"""Carte Condizione di Silver Star trascritte a vista dalle scansioni del mod TTS (l'OCR è troppo incerto).
Ogni riga: 25 caselle (A..Y) + RE. N = NONE, E = EVENT, X = XXX, s1.678 = s1 678, «/D-2» = riferimento rosso.
Scrive data/carte/missioneN.json nello stesso formato delle altre missioni."""
import json, pathlib, re
R = pathlib.Path(__file__).resolve().parent.parent
COL = "ABCDEFGHIJKLMNOPQRSTUVWXY"
N25 = " ".join(["N"] * 25)

CARTE = {
 19: {
  1: {
   0: N25 + " 349",
   3: "N N/239 N/D-2 N N 230 N N/781 N/459 N/I-3 N 550/K-4 E/451 E/129 120 E/125 120 E/128 E/126 E/S-4 E/T-3 E E/V-2 E/W-3 E 349",
   6: "N s1.678/930 s1.673 s1.543 s1.671 547 N s5.540 s5.540 s5.540 s2.236 s5.540 s2.234 s2.554 s8.553/920 s8.553 s8.553/P-5 N/714 E/R-6 N/S-6 E 480 750 480 480 346",
   9: "E s1.678 s1.678 s1.678 N N N s9.716 s9.716 s0.101 s9.716 s9.716 N s9.716 E E E N N N/T-8 N/T-9 N/U-9 N/V-9 N/W-9 N 342",
   12: "480 480 E 480 480 E N N N N N N N N N E N N N E N N E N N 679",
   15: "N N X N N N X N N N N N N N N N N N E N N N E N N 342",
   18: "N N N N N X X X N N N E N N N N N N N N N E N X X 238",
   1: "719 719 719 s9.787 N N N N N N N N N N N N N N N N E E E E E 349",
   4: "N N/B-3 s1.670 s1.670 N N N N N s2.231 550/J-3 s2.234 550/N-4 s2.234/919 E/127 s8.553/O-5 E/123 N/Q-5 N/R-4 N N N N N s3.600/X-3 349",
   7: "N s1.678/B-6 s1.677 s1.673/C-8 546 545 s6.548 s5.540 s2.544 s2.544 s5.540 s2.544 s2.544 N/926 N/453 s0.101 E E N/R-6 N/T-6 480 N 480 N N 676",
   10: "E E s1.678 N N N N N s9.716 s9.716 s9.716 751 s9.716 N N N N N N N N N N N/X-9 s3.429 232",
   13: "N N 480 N N N N N N N N N N N N N E N N N 696 N N N N 346",
   16: "N X X N N N N N N X N N E N N N N N N E N N E N N 238",
   19: "N N N N N N N N N N N N N N N N N N N N N X X N N NONE",
   2: "N N N N/781 230 N 230 N/781 N N N N N E N E N E 120 E/124 E/122 E/121 E E E 232",
   5: "N N/B-4 s1.671 s1.671 s1.670 s1.670 N N N s2.231 550 s2.551 s7.552 s2.234 s8.553/452 N/O-5 s8.553/P-4 N/Q-5 N 750 750 E E E E 676",
   8: "N s1.678/B-7 N/458 s1.678/457 N/D-8 N/E-8 N/F-8 s9.716/G-8 N/456 s9.716/455 N/J-8 s9.716/K-8 s9.716/454 530 N N E 750 N N/T-7 480 N N N N 238",
   11: "E E N E E E E E E E E N N N N N N N E N N E N N N 349",
   14: "X X N N N N N X X N N N N N E N E N N N N E N N N 679",
   17: "N N N N N N X X X N N N N N N N N N N E N N N N N 342",
  },
  2: {
   0: N25 + " NONE",
   3: "N N/239 N/D-2 N N 230 N N/781 N/459 N/J-2 N/J-3 N/K-4 N/675 N/O-4 120/788 N/Q-4 120/P-2 N/S-3 N/T-2 N/U-3 N/U-2 N N/V-2 N/W-3 E NONE",
   6: "N s1.678/930 N N s1.678 N N N N N N N N N s8.533/920 s8.533/718 s8.533/P-5 N/714 E/R-6 N/S-6 E 480 750 480 480 676",
   9: "E s1.678 N/C-8 s1.678/D-8 s1.678 N N s9.716 N/I-8 s0.101 N s9.716 N/M-8 s9.716 E E E N N N/T-8 N/T-9 N/U-9 N/V-9 N/W-9 N 400",
   12: "480 480 E 480 480 E N N N N N N N N N N N N N N N N N N N 998",
   15: "N N X N N N X N N N N N N N E E N N N E E N N N N 679",
   18: "N N N N N X X X N N N N N N N N N N N N N N N X X 400",
   1: "N N N N N N N N N N N N N N N N N N N N/S-2 N E E E E 400",
   4: "N N/B-3 N N N N N N N N N/K-3 N N/M-3 N/M-4 N/P-3 s8.553/O-5 N/R-3 N/S-4 N/T-3 N N N N N s3.600/X-3 995",
   7: "N s1.678/B-6 N N s1.678 N N N N N N N N N/O-7 N/O-6 s0.101/O-7 E/P-6 E 750 N/T-6 480 N 480 N N 679",
   10: "E E s1.678 N N N 751 N s9.716 s9.716 s9.716 s9.716 s9.716 N N N N N N N N N N N/X-9 s3.429 995",
   13: "N N 480 N N N N N N N N N N N N N N E N N 696 E N N N 996",
   16: "N X X N N N N N N X N N N N N N E N N N N N N N N 679",
   19: "N N N N N N N N N N N N N N N N N N N N N X X N N NONE",
   2: "N N N N/781 230 N 230 N/781 N N/I-3 N N/L-3 N/L-2 N/M-2 N N/O-3 N N/Q-3 120/R-2 N/U-2 N/T-1 N/U-2 N E E 997",
   5: "N s1.678/B-4 s1.678 s1.678 N N N N N N N N N N s8.533/N-4 N/931 s8.533/717 N/Q-5 N 750 750 N N N N 996",
   8: "N s1.678/B-7 N/458 N/457 s1.678/D-8 N/E-8 N/F-8 s9.716/G-8 s9.716/456 s9.716/455 s9.716/L-8 s9.716/M-8 s9.716/454 530 N N E 750 N N/T-7 480 N N N N 997",
   11: "E E N E E E E E E E E N N N N N N N N N N N N N N 346",
   14: "X X N N N N N X X N N N N N E N N N N N N E N N N 998",
   17: "N N N N N N X X X N N N N N N N N N N N N N N N N 676",
  },
 },
}
NERI = {"N": "NONE", "E": "EVENT", "X": "XXX"}


def cella(t):
    nero, _, rosso = t.partition("/")
    nero = NERI.get(nero, nero)
    if re.fullmatch(r"s\d\.\d{3}", nero):
        nero = nero.replace(".", ":")
    if rosso:
        rosso = rosso.replace("-", "") if not rosso.isdigit() else rosso
        if rosso.upper().startswith("EX"):
            rosso = "USCITA"
    return nero, rosso


def costruisci():
    for mis, carte in CARTE.items():
        out = {}
        for c, righe in carte.items():
            cond = {"carta": f"m{mis}_c{c}", "esagoni": {}, "evento": {}, "movimenti": {}}
            assert sorted(righe) == list(range(20)), (mis, c, sorted(righe))
            for r, testo in righe.items():
                tok = testo.split()
                assert len(tok) == 26, (mis, c, r, len(tok))
                if r != 19:
                    cond["evento"][str(r)] = NERI.get(tok[25], tok[25])
                if r == 0:
                    continue
                for i, t in enumerate(tok[:25]):
                    h = COL[i] + str(r)
                    nero, rosso = cella(t)
                    cond["esagoni"][h] = nero
                    if rosso:
                        cond["movimenti"][h] = rosso
            out[str(c)] = cond
        (R / "data/carte" / f"missione{mis}.json").write_text(json.dumps(out, ensure_ascii=False, indent=1))
        print("scritta missione", mis, len(out), "condizioni")


if __name__ == "__main__":
    costruisci()
