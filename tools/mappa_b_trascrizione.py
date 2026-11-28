# terreno della mappa B letto a vista, per riquadro. Formato: "ESAGONO:tipo" (q calcolata dopo, salvo "@n")
T = {}
def put(s):
    for tok in s.split():
        h, t = tok.split(":")
        q = None
        if "@" in t:
            t, q = t.split("@"); q = int(q)
        T[h] = {"W": "woods", "B": "brush", "C": "cover", "R": "road", "S": "stream", "X": "rough", ".": "clear",
                "SB": "stone_building", "WB": "wood_building", "P": "bridge", "F": "ford", "D": "road"}[t], q
put("A1:W B1:W C1:W D1:W E1:W F1:W G1:W H1:W I1:W A2:B B2:. C2:B D2:B E2:B F2:B G2:W H2:. "
    "A3:X B3:X C3:X D3:. E3:B F3:B G3:B H3:C A4:X B4:R C4:R D4:R E4:B F4:. G4:C H4:B "
    "A5:R B5:S C5:S D5:S E5:R F5:R G5:. H5:B A6:S B6:. C6:. D6:. E6:S F6:S G6:R H6:R")
put("I1:W J1:W K1:W L1:W M1:W N1:W O1:W P1:W Q1:B R1:B I2:. J2:B K2:B L2:W M2:B N2:. O2:B P2:. Q2:W R2:W "
    "I3:. J3:. K3:. L3:. M3:. N3:. O3:. P3:. Q3:B R3:C I4:C J4:. K4:. L4:. M4:. N4:. O4:. P4:. Q4:. R4:. "
    "I5:. J5:. K5:. L5:SB M5:SB N5:. O5:. P5:WB Q5:WB R5:R I6:. J6:R K6:R L6:R M6:SB N6:. O6:WB P6:R Q6:R")
put("S1:. T1:. U1:. V1:. W1:. X1:. Y1:. S2:B T2:W U2:. V2:. W2:. X2:. Y2:. "
    "S3:W@1 T3:X@1 U3:W V3:X W3:. X3:.@1 Y3:. R3:C@1 S4:. T4:. U4:X@1 V4:. W4:.@1 X4:. Y4:. "
    "S5:R T5:R U5:. V5:. W5:. X5:. Y5:. R6:. S6:. T6:B U6:R V6:R W6:. X6:. Y6:.")
put("A7:B B7:B C7:. D7:. E7:. F7:. G7:S H7:. A8:W B8:W C8:B D8:B E8:. F8:B G8:S H8:. "
    "A9:W B9:B C9:B D9:. E9:B F9:S G9:S H9:. A10:W B10:W C10:B D10:B E10:B F10:S G10:B H10:. "
    "A11:W B11:W C11:. D11:B E11:C F11:C G11:S H11:. A12:W B12:W C12:B D12:C E12:B F12:C G12:S H12:. "
    "A13:W B13:. C13:. D13:. E13:C F13:. G13:P H13:R")
put("J7:. K7:SB L7:. M7:R N7:R O7:R P7:. Q7:. J8:. K8:. L8:. M8:R N8:. O8:R P8:R Q8:SB "
    "J9:. K9:. L9:R M9:. N9:SB O9:. P9:WB Q9:. J10:. K10:R L10:WB M10:SB N10:WB O10:. P10:. Q10:WB "
    "J11:R K11:. L11:. M11:. N11:. O11:. P11:. Q11:. J12:R K12:. L12:W M12:W N12:W O12:. P12:. Q12:. "
    "J13:WB K13:. L13:R M13:R N13:W O13:. P13:. Q13:.")
put("R7:SB S7:. T7:B U7:B V7:W W7:R X7:R Y7:. R8:. S8:. T8:. U8:W V8:W W8:B X8:B Y8:R "
    "R9:R S9:WB T9:. U9:. V9:. W9:W X9:W Y9:. R10:R S10:. T10:. U10:. V10:B W10:W X10:W Y10:W "
    "R11:R S11:. T11:. U11:B V11:B W11:B X11:W Y11:W R12:R S12:. T12:. U12:B V12:. W12:B X12:W Y12:W "
    "R13:R S13:SB T13:. U13:. V13:. W13:B X13:W Y13:W S14:SB")
put("A14:B B14:. C14:. D14:. E14:. F14:R G14:P H14:. A15:. B15:. C15:. D15:R E15:R F15:. G15:S H15:. "
    "A16:. B16:R C16:R D16:. E16:. F16:. G16:S H16:S I16:S A17:R B17:. C17:. D17:B E17:. F17:W G17:W H17:B "
    "A18:. B18:W C18:W D18:W E18:B F18:W G18:W H18:W A19:W B19:W C19:W D19:W E19:W F19:W G19:W H19:W")
put("I14:R J14:R K14:R L14:W M14:W N14:B O14:. P14:B Q14:. I15:. J15:B K15:W L15:W M15:B N15:W O15:B P15:. Q15:. "
    "J16:S K16:. L16:S M16:W N16:S O16:S P16:S Q16:S R15:S I17:. J17:B K17:S L17:. M17:S N17:. O17:. P17:. Q17:. "
    "I18:B J18:B K18:. L18:W M18:B N18:B O18:. P18:. Q18:. I19:W J19:W K19:W L19:W M19:W N19:W O19:B P19:B Q19:B")
put("R14:R S15:R T14:. T15:R U14:. U15:. U16:R V14:. V15:. V16:R W14:. W15:B W16:R X14:B X15:R Y14:W Y15:. Y16:R "
    "R16:. S16:S T16:S T17:S U17:. U18:S V17:S W17:S X16:S Y17:S R17:. S17:. X17:. R18:. S18:. T18:. W18:B Y18:B "
    "V18:W X18:W R19:B S19:B T19:W U19:W V19:W W19:W X19:W Y19:W")
COL = "ABCDEFGHIJKLMNOPQRSTUVWXY"
mancano = [f"{c}{r}" for c in COL for r in range(1, 20) if f"{c}{r}" not in T]
if __name__ == "__main__":
    print(len(T), mancano)
put("I7:R I8:. I9:. I10:. I11:. I12:. I13:R")
import json
def vicini(h):
    q = COL.index(h[0]); r = int(h[1:])
    pari = [(0,-1),(1,-1),(1,0),(0,1),(-1,0),(-1,-1)]; dis = [(0,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0)]
    for dq, dr in (dis if q & 1 else pari):
        if 0 <= q+dq < 25 and 1 <= r+dr <= 19: yield f"{COL[q+dq]}{r+dr}"
def livelli():
    blu = json.load(open("/home/claude/strumenti/blu_b.json"))
    Q = {}
    for h, (t, q) in T.items():
        b = blu[h][0]
        r = int(h[1:])
        if b > 0 and r >= 18: b += 5
        if q: Q[h] = q
        elif b < 0: Q[h] = None
        else: Q[h] = 1 if b > 226 else (2 if b >= 213 else 3)
    for _ in range(4):
        for h in Q:
            if Q[h] is None:
                v = [Q[n] for n in vicini(h) if Q.get(n)]
                if v: Q[h] = max(set(v), key=v.count)
    return Q
def livelli_finali():
    Q = livelli()
    out = {}
    for h, q in Q.items():
        c = COL.index(h[0]); r = int(h[1:]); t = T[h][0]
        giallo = q >= 2
        if T[h][1]: out[h] = T[h][1]; continue
        if t == 'stream': out[h] = 1; continue
        alto = (r <= 3) or (r == 4 and 4 <= c <= 8) or (c <= 3 and 6 <= r <= 13) or (c >= 21 and 7 <= r <= 13)
        out[h] = (3 if alto else 2) if giallo else 1
    # gli edifici e le strade nel bianco del villaggio sono al livello 1; maggioranza dei vicini per gli isolati
    for _ in range(2):
        for h in out:
            if T[h][1] or T[h][0] == 'stream': continue
            v = [out[n] for n in vicini(h)]
            m = max(set(v), key=v.count)
            if v.count(m) >= 5 and out[h] != m: out[h] = m
    return out
CRESTE = ("B6|C7 B6|B7 A7|B7 A8|B7 A8|B8 A8|A9 A11|A12 A11|B11 B10|B11 B11|C11 C11|C12 C11|D11 D10|D11 "
          "U8|V7 V7|V8 V9|W9 W9|W10 X11|Y11 X11|X12 N12|O13 N13|O13 N13|O14 O14|P13 P13|P14 O14|O15 "
          "M14|N13 L14|M14 L14|M15").split()
APERTURE = {
 "window": ("K5|L5 K6|L5 M6|N6 M6|M7 M5|N5 J6|K7 K7|L7 K7|K8 Q5|R4 N6|O6 L9|L10 K11|L10 L10|L11 "
            "N8|N9 M10|M11 M9|M10 N10|N11 P8|P9 O10|P9 Q10|R10 Q9|Q10 R7|S7 R7|S8 Q8|Q9 S9|T8 S9|T9 "
            "S12|S13 R13|S13 S13|T13 R14|S14 S14|T14 I13|J13 J12|J13").split(),
 "door": ("M4|M5 K6|K7 P4|P5 O6|P6 P5|Q6 Q5|R5 L10|M11 N9|O9 M11|N10 Q10|Q11 R6|R7 P8|Q8 S9|S10 "
          "S14|S15 J13|J14").split()}
SCARPATE = ("H9|I10 H10|I10 H10|I11 H11|I11 H11|I12 I10|I9 I9|J9 J10|J9 J8|J9 J8|K9 J9|K10 K10|K9 K8|K9 "
            "I12|I13 H12|H13 G13|H12 G12|H12 C14|D13 C14|D14 C14|B14 C14|C15 D13|D14 D13|E14 "
            "D14|D15 D14|E15 E14|E15 E14|F14 F13|F14 E13|F13 F12|F13 F12|G13 "
            "O15|O16 O16|O17 P16|Q17 Q16|Q17 Q16|R16 R15|R16 R15|S16 S16|S17 S16|T16 L16|M16 M16|N16 "
            "U8|V8 U9|V9 W15|X15 X14|X15 X14|Y15 X15|Y15 W15|X14").split()
EDIFICI = {"stone_building": "K7 L5 M5 M6 M10 N9 Q8 R7 S13 S14".split(),
           "wood_building": "O6 P5 Q5 L10 N10 P9 Q10 S9 J13".split()}
PONTI = {"G14": "pietra", "G13": "legno"}
def costruisci():
    Q = livelli_finali()
    es = {}
    for h, (t, q) in T.items():
        rec = {"t": t, "q": Q[h]}
        if t == "bridge":
            rec["t"] = "road" if PONTI.get(h) == "pietra" else "clear"
            rec["ponte"] = True
        es[h] = rec
    for t, hs in EDIFICI.items():
        for h in hs: es[h]["t"] = t
    es["S13"]["piani"] = 2  # campanile: piano terra e piano superiore
    lati = {}
    for k in CRESTE: a, b = sorted(k.split("|")); lati[f"{a}|{b}"] = "crest"
    for k in SCARPATE: a, b = sorted(k.split("|")); lati[f"{a}|{b}"] = "embankment"
    for tipo, lst in APERTURE.items():
        for k in lst: a, b = sorted(k.split("|")); lati[f"{a}|{b}"] = tipo
    return {"mappa": "B", "esagoni": es, "lati": lati, "alture_obiettivo": [],
            "note": "Mappa B trascritta dalla scansione: terreno a vista per esagono; livelli dal colore di fondo (1 bianco, 2 giallo chiaro, 3 giallo carico sulle alture di nord, ovest ed est); creste e scarpate lette a vista (approssimate); ponte di pietra G14 (strada), ponte di legno G13 (ferrovia). Porte e finestre lette a vista (approssimate). Il campanile di S13 ha due piani (campo «piani»)."}
