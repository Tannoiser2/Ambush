# -*- coding: utf-8 -*-
"""Paragrafi della Missione 7 «Esca per la trappola» (mappa A, il sud è in alto; i tedeschi entrano da est)."""
from paragrafi_m1 import pc, act, see, if_, S, NOT, ALL, sighting, activate, cond, P as P1
from paragrafi_m2 import P as P2
from paragrafi_m3 import P as P3
from paragrafi_m4 import P as P4, chain, dado_pari
from paragrafi_m5 import P as P5
from paragrafi_m6 import P as P6

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def enter(h):
    return {"op": "g_enter", "hex": h}


VEDE = {"g_vede_us": True}
VEICOLO = {"vehicle_moving": True}


def vede_entro(n):
    return {"g_vede_entro": n}


par("052", "• Se vedi 3 o più bersagli attivi, entra in E4.\n• Altrimenti entra in E5.",
    [if_({"g_vede_almeno": 3}, [enter("E4")], [enter("E5")])], "movimento")
par("053", "• Se vedi un bersaglio attivo, entra in K4.\n• Altrimenti entra in L2.", [if_(VEDE, [enter("K4")], [enter("L2")])], "movimento")
par("054", "• Se vedi un bersaglio attivo, entra in N4.\n• Altrimenti entra in N5.", [if_(VEDE, [enter("N4")], [enter("N5")])], "movimento")
par("058", "• Se un americano attivo è entro 3 esagoni dal ponte, entra in K12.\n• Altrimenti entra in K11.",
    [if_({"us_entro": ["M12", 3]}, [enter("K12")], [enter("K11")])], "movimento")
par("059", "1. Se non vedi americani attivi, entra in F16.\n2. Se non ne vedi entro 7 esagoni, entra in F16.\n3. Se ne vedi uno solo, entra in F16.\n4. Altrimenti entra in E15.",
    [if_(ALL(vede_entro(7), {"g_vede_almeno": 2}), [enter("E15")], [enter("F16")])], "movimento")
par("064", "1. Se non vedi americani attivi, entra in P4.\n2. Se non ne vedi entro 6 esagoni, entra in P4.\n3. Se ne vedi uno solo, entra in P4.\n4. Altrimenti entra in O3.",
    [if_(ALL(vede_entro(6), {"g_vede_almeno": 2}), [enter("O3")], [enter("P4")])], "movimento")
par("067", "• Se si muove un veicolo, entra in M17.\n• Se si muove un soldato e non vede americani attivi, entra in M17; se ne vede, entra in M18.",
    [if_(VEICOLO, [enter("M17")], [if_(VEDE, [enter("M18")], [enter("M17")])])], "movimento")
par("078", "[s2] Attiva i tedeschi 22 e 23 nell’esagono A2, in piedi. Iniziano i Round.",
    sighting(2) + [activate([(22, "A2"), (23, "A2")], "standing")])
par("082", "1. Se non c’è stato s6, vedi 728.\n2. Se non c’è stato s3, vedi 875.\n3. Se ci sono stati s3 e s6, passa alla Condizione 4.",
    chain((NOT(S(6)), [see("728")]), (NOT(S(3)), [see("875")]), last=[cond(4)]))
par("085", "[s9] Attiva il tedesco 33 nell’esagono J1, in piedi. Iniziano i Round.",
    sighting(9) + [activate([(33, "J1")], "standing")])
par("552", "• Se vedi un bersaglio attivo, entra in M7.\n• Altrimenti entra in N7.", [if_(VEDE, [enter("M7")], [enter("N7")])], "movimento")
par("553", "• Se il tedesco 22 o il 23 (o entrambi) è inattivo, entra in F8.\n• Se sono attivi o non ancora attivati, entra in F9.",
    [if_({"inattivo_uno": [22, 23]}, [enter("F8")], [enter("F9")])], "movimento")
par("557", "• Se si muove un veicolo, entra in G9.\n• Se si muove un tedesco con numero 29 o inferiore, entra in G9.\n• Se 30 o superiore, entra in G8.",
    [if_(VEICOLO, [enter("G9")], [if_({"g_le": 29}, [enter("G9")], [enter("G8")])])], "movimento")
par("558", "[s7] Attiva i tedeschi 29, 30 e 31 nell’esagono A9, in piedi. Iniziano i Round.",
    sighting(7) + [activate([(29, "A9"), (30, "A9"), (31, "A9")], "standing")])
par("562", "1. Se non c’è stato s4, vedi 722.\n2. Se non c’è stato s5, vedi 715.\n3. Se ci sono stati s4 e s5, passa alla Condizione 3.",
    chain((NOT(S(4)), [see("722")]), (NOT(S(5)), [see("715")]), last=[cond(3)]))
par("598", "[s9] Attiva il tedesco 33 nell’esagono P19, in piedi. Iniziano i Round.",
    sighting(9) + [activate([(33, "P19")], "standing")])
par("704", "• Se vedi 3 o più bersagli attivi, entra in H5.\n• Altrimenti entra in H6.",
    [if_({"g_vede_almeno": 3}, [enter("H5")], [enter("H6")])], "movimento")
par("705", "• Se vedi un bersaglio attivo, entra in W2.\n• Altrimenti entra in W3.", [if_(VEDE, [enter("W2")], [enter("W3")])], "movimento")
par("706", "• Se vedi un bersaglio attivo, entra in H8.\n• Altrimenti entra in H7.", [if_(VEDE, [enter("H8")], [enter("H7")])], "movimento")
par("709", "• Se si muove un veicolo, entra in K11.\n• Se si muove un soldato e nessun americano attivo è entro 2 esagoni dal ponte, entra in K11; altrimenti entra in K10.",
    [if_(VEICOLO, [enter("K11")], [if_({"us_entro": ["M12", 2]}, [enter("K10")], [enter("K11")])])], "movimento")
par("714", "1. Se non c’è stato s2, vedi 078.\n2. Se non c’è stato s7, vedi 558.\n3. Se ci sono stati s2 e s7, passa alla Condizione 2.",
    chain((NOT(S(2)), [see("078")]), (NOT(S(7)), [see("558")]), last=[cond(2)]))
par("715", "[s5] Attiva il tedesco 54 nell’esagono A6. Iniziano i Round. Vantaggio tedesco. Il tedesco 54 riceve 2 turni in questo Round.",
    sighting(5) + [activate([(54, "A6")], "crouching", adv="de", two=[54])])
par("722", "[s4] Attiva i tedeschi 46, 43 e 44 nell’esagono A16, in piedi. Iniziano i Round.",
    sighting(4) + [activate([(46, "A16"), (43, "A16"), (44, "A16")], "standing")])
par("726", "[s1] Attiva il tedesco 18 nell’esagono P19, in piedi. Iniziano i Round.", sighting(1) + [activate([(18, "P19")], "standing")])
par("728", "[s6] Attiva i tedeschi 87 e 88 nell’esagono I19, in piedi. Iniziano i Round.",
    sighting(6) + [activate([(87, "I19"), (88, "I19")], "standing")])
par("735", "[s1] Attiva il tedesco 18 nell’esagono J1, in piedi. Iniziano i Round.", sighting(1) + [activate([(18, "J1")], "standing")])
par("871", "• Se vedi un bersaglio attivo, entra in X6.\n• Altrimenti entra in X5.", [if_(VEDE, [enter("X6")], [enter("X5")])], "movimento")
par("873", "1. Se non c’è stato s9, tira un dado: dispari 598, pari 085.\n2. Se non c’è stato s1, tira un dado: dispari 726, pari 735.\n3. Se ci sono stati s1 e s9, nessun evento.",
    chain((NOT(S(9)), [dado_pari([see("085")], [see("598")])]), (NOT(S(1)), [dado_pari([see("735")], [see("726")])])))
par("875", "[s3] Attiva il tedesco 4 nell’esagono D19. Iniziano i Round. Vantaggio tedesco. Il tedesco 4 riceve 2 turni in questo Round.",
    sighting(3) + [activate([(4, "D19")], "crouching", adv="de", two=[4])])
par("989", "• Se si muove un tedesco con numero 50 o inferiore, entra in O12.\n• Se 51 o superiore, entra in O18.",
    [if_({"g_le": 50}, [enter("O12")], [enter("O18")])], "movimento")
par("990", "• Se si muove un veicolo, entra in P12.\n• Se si muove un soldato e vede un bersaglio attivo, entra in O14; altrimenti in P13.",
    [if_(VEICOLO, [enter("P12")], [if_(VEDE, [enter("O14")], [enter("P13")])])], "movimento")
par("991", "• Se si muove un veicolo, entra in P14.\n• Se si muove un soldato e vede un bersaglio attivo, entra in O16; altrimenti in P14.",
    [if_(VEICOLO, [enter("P14")], [if_(VEDE, [enter("O16")], [enter("P14")])])], "movimento")
par("994", "• Se vedi un bersaglio attivo entro 6 esagoni, entra in R17.\n• Altrimenti entra in R16.",
    [if_(vede_entro(6), [enter("R17")], [enter("R16")])], "movimento")
par("995", "• Se si muove un veicolo, entra in W14.\n• Se si muove un soldato e vede un bersaglio attivo entro 6 esagoni, entra in W15; altrimenti in W14.",
    [if_(VEICOLO, [enter("W14")], [if_(vede_entro(6), [enter("W15")], [enter("W14")])])], "movimento")
par("997", "• Se vedi un bersaglio attivo entro 7 esagoni, entra in V15.\n• Altrimenti entra in U15.",
    [if_(vede_entro(7), [enter("V15")], [enter("U15")])], "movimento")

for k in list(P):
    if k in P1 or k in P2 or k in P3 or k in P4 or k in P5 or k in P6:
        del P[k]
