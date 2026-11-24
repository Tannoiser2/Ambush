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
 20: {
  1: {
   0: N25 + " 990",
   3: "E N s2.630 s2.630 s2.630 570 105 X X X N/L-3 s2.532/L-2 N s1.468 X N N N N E N N N N E 997",
   6: "N 105 105 N 105 N 105 X X X 102 s2.131 N s1.468 X N N s1.534 N N N N 245 N N 998",
   9: "105 N X N N N N N s2.532 N N/531 N N X s1.534 X N 334 334 334 N N T794 N N 999",
   12: "X X N X X N X N N s5.685 601 N N s4.535 s4.535 s4.138 s4.138 s4.137 N s3.712/243 N N N N N 996",
   15: "N N X N N N/E-16 X N/357 N/354 s5.685/I-16 s5.685/244 s7.104/K-15 s7.103/L-15 s4.138/682 N/463 N/333 s4.138/P-14 N/573 s4.137 N/S-16 N/T-15 N N N E 992",
   18: "N/A-19 N N/C-19 N N/D-18 X X X N/I-19 N s5.685 N E N E N E N E E N N N X X 995",
   1: "N E N s2.630 N N N s2.528 N/I-2 N/I-2 N s2.532 N s1.468 X N N N N N N N E N N 991",
   4: "N E N N 105 N 335 s0.350 X X X X N s1.468 N N N N N N E N N N E 999",
   7: "105 N N 105 N 105 s2.528 N/I-8 X X X N s1.468 X X s1.534 s1.534 X s1.534 s1.534 N N T358 N N 991",
   10: "105 105 X 105 105 105 105 105 105 105 N N N X s1.534 s1.534 X 334 N 334 N N 245 N N 990",
   13: "N N X N N N N N N N s5.685 N s4.536/688 s4.535/M-13 N N/O-14 s4.138 s4.137/Q-14 N/R-13 s4.134/S-14 s3.133/689 s3.712/686 N N N 992",
   16: "N X X N/C-17 N/D-16 N/E-17 N/356 N/G-16 N/H-16 X s5.685 N/K-17 N/355 s4.138 N/N-15 s4.536 s4.138/P-15 N/Q-16 N/684 N N N N N N 996",
   19: "N/688 799 N/688 N/C-19 N/D-19 N/E-19 N/F-19 N/G-19 N/H-19 N s5.685 N N E N E N E N N E X X N N NONE",
   2: "N N s2.630 N s2.630 105 N X N/J-2 N/K-3 N s2.532/531 N s1.468 X N N N E N N N N E N 992",
   5: "N N N 105 105 N X X s2.131 135 X X X s1.468 X N N N N N N N N N N 997",
   8: "713 105 105 X 105 N s2.528 s2.528 N/J-8 s2.532/K-9 X s1.468 s1.468 X s1.534 X X N X s1.534 N N N N N 995",
   11: "N 105 105 105 N X N X X X N X X X N s4.137 s1.534 N 334 N N N N N N 993",
   14: "X X N N N N N X X s5.685/I-15 s5.685 s7.103 s7.104 s4.134/246 242/333 N/572 s4.138/247 s4.138/Q-15 s4.137/R-14 s4.137 s4.137 N/U-15 N N N 999",
   17: "N N/A-18 N/B-17 N/C-18 N/687 N X X X N/I-18 s5.685/J-17 N N N s4.138 N N N N N E N N N N 993",
  },
  2: {
   0: N25 + " 999",
   3: "N N s2.630 s2.630 s2.630 N 105 X X X N/L-3 s2.532/L-2 N s1.468 X N N N N N N N N N E 998",
   6: "N 105 105 N 105 N 105 X X X N s2.131 N s1.468 X N N N N N N N 245 N N 997",
   9: "105 N X N N N N N s2.532 N N/531 N N X s1.534 X N 334 334 334 N N T794 N N 990",
   12: "X X N X X N X N N N 601 N N s4.535 s4.535 s4.138 s4.138 s4.137 N s3.712/243 N N N N N 995",
   15: "N N X N N/688 N/E-16 X N/357 N/354 N/I-16 N/244 s7.104/K-15 s7.103/L-15 s4.138/682 N/463 N/O-16 s4.138/P-14 N/573 s4.137 N/S-16 N/T-15 N N N E 992",
   18: "N/A-19 N N/C-19 N/C-19 N/D-18 X X X N/I-19 N/I-18 N N N E N E N N N E N N N X X 996",
   1: "E N E s2.630 E N E s2.528 N/I-2 N/I-2 N s2.532 N N X N N N N N N N E E E 993",
   4: "N N N N N N 335 s0.350 X X X X N s1.468 N N N N N N N N N N N 990",
   7: "N N N N N N s2.528 N/I-8 X X X N s1.468 X X s1.534 s1.534 X s1.534 s1.534 N N T358 N N 993",
   10: "N N X N N N N N N N N N N X s1.534 s1.534 X 334 N 334 N N 245 N N 999",
   13: "N N X N N N/G-13 N/H-13 N/G-14 N/J-13 N/688 N E s4.536/688 s4.535/M-13 N N/O-14 s4.138 s4.137/Q-14 N/R-13 N/S-14 s3.133/689 s3.712/686 N N N 992",
   16: "N X X N/C-17 N/D-16 N/E-17 N/356 N/G-16 N/H-16 X N N/K-17 N/355 s4.138 N/N-15 s4.536 N/P-15 N/Q-16 N/684 N N N N E N 995",
   19: "N/688 N N/688 N/C-19 N/D-19 N/E-19 N/F-19 N/G-19 N/H-19 N N N E N N E E E E N N X X N N NONE",
   2: "N E s2.630 E s2.630 E N X N/J-2 N/K-3 N s2.532/531 N s1.468 X N N N N N N N N E E 997",
   5: "N N N N N N X X N N X X X s1.468 X N N N N N N N N N N 992",
   8: "N N N X N N s2.528 s2.528 N/J-8 s2.532/K-9 X s1.468 s1.468 X s1.534 X X N X s1.534 N N N N N 996",
   11: "N N N N N X N X X X N X X X E s4.137 s4.137 N 334 N N E N E E 991",
   14: "X X N N N N/E-15 N/F-14 X X N/I-15 N N N s4.134/246 242/571 N/572 s4.138/247 N/Q-15 N/R-14 N s4.137 N/U-15 N N N 990",
   17: "N N/A-18 N/B-17 N/C-18 N/687 N X X X N/I-18 N/J-17 N N N s4.138 N N N N E E E E N N 991",
  },
  3: {
   0: N25 + " 990",
   3: "E N N/C-4 N N/E-4 N N X X X N/J-2 N/K-3 s5.220 683 X N N N N s1.797 N N N E N 997",
   6: "N N/A-7 N/B-6 N N N N X X X s5.220 s0.112 s5.220 683 X N N N N N N N 245 N N 991",
   9: "N N X N N N N N N N N/J-8 N s5.220 X N X N 658 658 658 N N N N N 999",
   12: "X X N X X N X N N N 601 795 N s4.535 N E N N N s3.712 N N N N N 992",
   15: "N s6.790 X 537 105/F-14 105 X N N N N 795/431 s4.134 s4.137 s4.138 s4.535 N N N N N N E N E 996",
   18: "105 s6.103 s6.104 537/E-19 537 X X X N/J-17 N N 795 N N N s4.138 E N N E N E N X X 993",
   1: "N N E N N N N N/G-2 N N N N s5.220 683 X N N E E E E E E E E 992",
   4: "N N N/C-5 N N/E-5 336 N s0.113 X X X X s5.220 683 X N E N N s1.796 s1.797 s1.798 N N E 990",
   7: "N/688 N N N/C-8 N N/E-8 N/F-7 N/G-7 X X X s5.220 s0.119 X X N N X N N N N T794 N N 998",
   10: "N N X N E N N E N N E N s5.220 X N N X 658 N 658 N N 245 N N 990",
   13: "N N X N N N N N/I-13 N/431 N N 795 N N s4.535 N N 242 N N s3.133 s3.712 N N E 996",
   16: "N X X 537 537 s2.792 N N N X N/L-15 795 s4.134 s4.137 s4.138 s4.536 N N N s4.134 N E N E N 992",
   19: "105 713 105 537 N/F-19 N/G-19 N/H-19 N/I-19 N/I-18 N N 795 E N N s4.138 N N E N N X X N N NONE",
   2: "N E N N/C-3 N N/E-3 N/F-2 X N/H-1 N/I-2 N N s5.220 683 X N E E N N N N E N N 991",
   5: "N N N/C-6 N/C-6 N/D-5 N X X N s0.113 X X X 683 X N N N N s1.797 s1.797 s1.798 N N N 997",
   8: "N N N/688 X N/D-7 N N N N/H-7 N/I-8 X N s5.220 X N X X N N N N N N N N 993",
   11: "N N N N N X N X X X N X X X E N N N 658 N N N N N N 995",
   14: "X X N N N N/G-14 N/H-13 X X N N 795 s4.137 s4.137 s4.536 s4.248 N N N N s4.137 712 N E N 999",
   17: "N 105 105 s6.578 s6.790 537 X X X N/K-17 N/K-16 795 N s4.137 N s4.536 N E N N E N E N N 995",
  },
 },
}
NERI = {"N": "NONE", "E": "EVENT", "X": "XXX"}


def cella(t):
    nero, _, rosso = t.partition("/")
    nero = NERI.get(nero, nero)
    if re.fullmatch(r"T\d{3}", nero):
        nero = "T:" + nero[1:]  # paragrafo letto solo da chi si muove nella galleria
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
