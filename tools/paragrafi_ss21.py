# -*- coding: utf-8 -*-
"""Silver Star – Missione 21 «Sorpresa, sorpresa!» (Surprise, Surprise!; mappa F con mezza H, in alto è sud; Gela, 19 luglio 1943).

La squadra difende gli accessi a una piccola baia; i tedeschi arrivano per evento casuale. Testo inglese: tools/paragrafi_ss_en.json.
Operazioni «ss_*»: scripts/motore/missione21_ss.gd.
"""
from paragrafi_m1 import pc, act, see, die, if_, S, NOT, ALL, sighting, activate, cond, EVENT

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def mov(pid, it, ops):
    par(pid, it, ops, "movimento")


def enter(h):
    return {"op": "g_enter", "hex": h}


VEIC = {"vehicle_moving": True}
DISPARI = {"ss_dispari": True}


def pari_dispari(d, pr):
    return [die(*[(i, i, d if i % 2 else pr) for i in range(10)])]


CINGOLI = ("Per il rumore dei cingoli, gli americani inconsapevoli a meno di 6 esagoni dall’ingresso del carro fanno un "
           "controllo di percezione (+2) per diventare consapevoli.")

# ------------------------------------------------------------------ controlli evento delle carte
par("470", "1. Se s0 non è avvenuto, vedi 360.\n2. Se s4 non è avvenuto, vedi 363.\n3. Se s5 non è avvenuto, vedi 362.\n4. Se s3 non è "
           "avvenuto, vedi 361.\n5. Se non hai ancora letto il 701, leggilo ora.\n6. Se un tedesco è a sud del fiume e s8 non è "
           "avvenuto, vedi 690.\n7. Nessun evento.",
    [if_(NOT(S(0)), [see("360")], [if_(NOT(S(4)), [see("363")], [if_(NOT(S(5)), [see("362")], [if_(NOT(S(3)), [see("361")],
        [if_(NOT({"ss_letto_701": True}), [see("701")], [if_(ALL({"ss_tedesco_a_sud": True}, NOT(S(8))), [see("690")])])])])])])])
par("475", "1. Se s3 non è avvenuto, vedi 361.\n2. Se s0 non è avvenuto, vedi 365.\n3. Se s4 non è avvenuto, vedi 363.\n4. Se s5 non è "
           "avvenuto, vedi 368.\n5. Se non hai ancora letto il 701, leggilo ora.\n6. Se un tedesco è a sud del fiume e s8 non è "
           "avvenuto, vedi 690.\n7. Nessun evento.",
    [if_(NOT(S(3)), [see("361")], [if_(NOT(S(0)), [see("365")], [if_(NOT(S(4)), [see("363")], [if_(NOT(S(5)), [see("368")],
        [if_(NOT({"ss_letto_701": True}), [see("701")], [if_(ALL({"ss_tedesco_a_sud": True}, NOT(S(8))), [see("690")])])])])])])])
par("479", "1. Se s4 non è avvenuto, vedi 363.\n2. Se s5 non è avvenuto, vedi 364.\n3. Se s0 non è avvenuto, vedi 369.\n4. Se s3 non è "
           "avvenuto, vedi 361.\n5. Se non hai ancora letto il 701, leggilo ora.\n6. Se s8 non è avvenuto e un tedesco è a sud del "
           "fiume, vedi 690.\n7. Nessun evento.",
    [if_(NOT(S(4)), [see("363")], [if_(NOT(S(5)), [see("364")], [if_(NOT(S(0)), [see("369")], [if_(NOT(S(3)), [see("361")],
        [if_(NOT({"ss_letto_701": True}), [see("701")], [if_(ALL({"ss_tedesco_a_sud": True}, NOT(S(8))), [see("690")])])])])])])])
par("478", "1. Se s6 non è avvenuto, vedi 472.\n2. Altrimenti tira un dado: 0–1: 212; 2–3: 116; 4–5: 221; 6–7: 117; 8–9: 222.",
    [if_(NOT(S(6)), [see("472")], [die((0, 1, [see("212")]), (2, 3, [see("116")]), (4, 5, [see("221")]), (6, 7, [see("117")]),
                                       (8, 9, [see("222")]))])])
par("212", "Un soldato porta una granata difettosa: nelle Operazioni è un americano, nei Round tira un dado (dispari un americano, pari "
           "un tedesco), poi a caso. Fa un controllo di percezione: se riesce la getta in un esagono vuoto adiacente, dove esplode senza "
           "danni; se fallisce, esplode addosso a lui (come al chiuso) e a chi è nell’esagono. Solo una volta per missione.",
    [{"op": "ss_granata_difettosa"}])
par("116", "Un tedesco a caso va fuori di testa: 2 turni per Round (se non è ferito), a ogni turno si alza, fa un tiro rapido al bersaglio "
           "più vicino e corre verso l’americano più vicino con metà dei suoi PM; non usa granate, non va nel panico, +2 all’abilità "
           "nell’assalto. Solo una volta per missione.", [{"op": "ss_berserk_de"}])
par("117", "Nelle Operazioni nessun evento. Nei Round un americano a caso (non un comandante) va nel panico e si butta a terra: si "
           "riprende quando un compagno entra nel suo esagono e spende un’azione. Solo una volta per missione.", [{"op": "ss_panico_us"}])
par("221", "Un americano a caso (non un comandante) va fuori di testa: 2 turni per Round, spara di rapido al più vicino e corre verso "
           "il tedesco attivo più vicino; assalta chi trova nel suo esagono; non va nel panico, +2 nell’assalto. Un compagno che lo "
           "raggiunge può placcarlo. Solo una volta per missione.", [{"op": "ss_berserk_us"}])
par("222", "Un soldato a caso ha un’arma col calcio rotto (fucili, carabine, semiautomatici, BAR, mitra, mitragliatrici leggere): −1 per "
           "colpire con quell’arma. Senza tedeschi attivi tocca a un americano, altrimenti un dado: dispari un americano, pari un "
           "tedesco. Solo una volta per missione.", [{"op": "ss_calcio_rotto"}])
par("697", "Se il Jagdpanther (21) o il Panzer (30) si è mosso di 4 o più esagoni nel Round precedente, uno dei due (a caso) perde un "
           "cingolo e non si muove più (può ancora sparare). Solo una volta per missione. Altrimenti nessun evento.",
    [{"op": "ss_cingolo"}])
par("698", "Un’arma tedesca usata nel Round precedente (compresi cannoni e mitragliatrici dei carri) finisce le munizioni.",
    [{"op": "ammo_out"}])
par("993", "Un americano non prono, a caso, in un esagono che non sia strada né scoperto, cade: controllo di percezione; se riesce cade "
           "solo prono, altrimenti tira i danni della pistola. Solo una volta per missione.", [{"op": "ss_caduta_21"}])
par("995", "Un tedesco ferito, a caso, diventa incapacitato per la perdita di sangue. Solo una volta per missione.",
    [{"op": "dissanguamento", "chiave": "995", "lato": "de"}])
par("996", "Un tedesco incapacitato, a caso, muore per le ferite. Solo una volta per missione.",
    [{"op": "morte_incapacitato", "chiave": "996", "lato": "de"}])
par("997", "Un americano ferito, a caso, diventa incapacitato per la perdita di sangue. Solo una volta per missione.",
    [{"op": "dissanguamento", "chiave": "997", "lato": "us"}])
par("998", "Un americano incapacitato, a caso, muore per le ferite. Solo una volta per missione.",
    [{"op": "morte_incapacitato", "chiave": "998", "lato": "us"}])
par("242", "Trappola esplosiva! Esegui la procedura della trappola esplosiva.", [{"op": "boobytrap"}])

# ------------------------------------------------------------------ arrivi dei tedeschi
def jagd(pid, hexes, it_adv, adv_ops, due=False):
    par(pid, f"[s0] Contrattacco! Attiva il Jagdpanther (tedesco 21) in {hexes if isinstance(hexes, str) else ', '.join(hexes)} e vedi subito "
             f"580. Iniziano i Round. {CINGOLI} {it_adv}",
        sighting(0) + [{"op": "ss_jagd", "hex": hexes, "due": due}, see("580")] + adv_ops)


jagd("360", "B19", "Tira un dado: dispari vantaggio tedesco, pari americano.",
     pari_dispari([{"op": "ss_vantaggio", "lato": "de"}], [{"op": "ss_vantaggio", "lato": "us"}]))
jagd("365", "P19", "Tira un dado: dispari vantaggio americano, pari tedesco.",
     pari_dispari([{"op": "ss_vantaggio", "lato": "us"}], [{"op": "ss_vantaggio", "lato": "de"}]))
jagd("369", "Y16", "", [])
jagd("422", ["P19", "B19", "Y16"], "Il Jagdpanther riceve 2 turni in questo Round (primo esagono libero da americani).", [], due=True)
par("580", "[s1] Attiva i tedeschi 31 e 32 nella reazione speciale T, sul Jagdpanther: ricevono 2 turni in questo Round.", sighting(1))
NASC = ("La squadra non ha perquisito bene le case: un tedesco nascosto esce dal suo rifugio, in piedi, nel primo esagono libero da "
        "americani fra {lista}, nella reazione speciale H. Iniziano i Round. Gli americani che lo vedono fanno un controllo di "
        "percezione: se almeno uno riesce vantaggio americano (e chi riesce senza panico riceve 2 turni), altrimenti tedesco.")
par("361", "[s3] " + NASC.format(lista="T15, Q16, R13, U15, T12") + " È il tedesco 33.",
    sighting(3) + [{"op": "ss_nascosto", "g": 33, "hex": ["T15", "Q16", "R13", "U15", "T12"]}])
par("363", "[s4] " + NASC.format(lista="F14, G14, H13, I13, E15, F13") + " È il tedesco 34.",
    sighting(4) + [{"op": "ss_nascosto", "g": 34, "hex": ["F14", "G14", "H13", "I13", "E15", "F13"]}])
par("362", "[s5] Attiva i tedeschi 35 e 36 accovacciati in H19. Iniziano i Round.",
    sighting(5) + [activate([(35, "H19"), (36, "H19")], "crouching")])
par("364", "[s5] Contrattacco! Attiva i tedeschi 35 e 36 accovacciati in K19. Iniziano i Round.",
    sighting(5) + [activate([(35, "K19"), (36, "K19")], "crouching")])
par("368", "[s5] Contrattacco! Attiva i tedeschi 35 e 36 accovacciati in S19. Iniziano i Round.",
    sighting(5) + [activate([(35, "S19"), (36, "S19")], "crouching")])
par("507", "[s5] Contrattacco! Attiva i tedeschi 35 e 36 accovacciati nel primo esagono libero da americani fra H19, K19, S19. Iniziano "
           "i Round, vantaggio americano.",
    sighting(5) + [{"op": "ss_due_in_libero", "g": [35, 36], "hex": ["H19", "K19", "S19"], "adv": "us"}])
par("434", "Vedi 472. Nessun tedesco si attiva in un esagono con un americano.", [see("472")])
par("472", "[s6] Attiva il Panzer (tedesco 30) nell’esagono dato da un dado (0–2 B19, 3–5 P19, 6–8 Y16, 9 Y10) con sopra i tedeschi 22 e "
           "23 nella reazione speciale T; il 24 e il 25 in piedi in due esagoni diversi a caso fra H19, Y17 e S19. Iniziano i Round. " +
           CINGOLI + " Se almeno uno riesce, o sono già tutti consapevoli, vantaggio americano; altrimenti tedesco.",
    sighting(6) + [{"op": "ss_panzer"}, {"op": "ss_vantaggio_consapevoli"}])

# ------------------------------------------------------------------ radio, soccorsi e fine
par("701", "Se la radio è presidiata, vedi 471. Se non lo è, vedi 471 quando lo sarà. Se la radio è (o viene) distrutta, vedi 589.",
    [{"op": "ss_701"}])
par("471", "Il comando dice che potete ripiegare verso il villaggio sulla baia, nell’angolo sud-est della mappa. Respingete il "
           "contrattacco da soli mentre il comando cerca di mandarvi aiuto.", [])
par("589", "Il sergente decide una difesa ritardatrice, ripiegando verso il villaggio sulla baia nell’angolo sud-est della mappa.", [])
par("690", "Se la radio è presidiata, vedi 366. Se non è presidiata o è distrutta, tira un dado: dispari vedi 582, pari vedi 587.",
    [if_({"radio": True}, [see("366")], pari_dispari([see("582")], [see("587")]))])
par("366", "Il comando vuole sapere se riuscite a resistere. Se pensi di sì, scegli 582; se pensi di no, scegli 587.",
    [{"op": "scelta_attiva", "par": "582", "testo": "Resistiamo (582)"}, {"op": "scelta_attiva", "par": "587", "testo": "Non resistiamo (587)"}])
par("582", "[s8] Arrivano i soccorsi! Lo Sherman US 04 entra (dado dispari in A11 verso B11, pari in Y4 verso X3). Non è ai tuoi ordini: "
           "agisce con il numero d’azione tedesco e segue i riferimenti di movimento neri delle carte. Si toglie la reazione speciale D "
           "a tutti i tedeschi. Se s7 non è avvenuto, vedi 473. La missione finisce quando non ci sono più tedeschi attivi in mappa. "
           "Servono 8 PV. I feriti gravi in un edificio non costano PV.",
    sighting(8) + [{"op": "ss_sherman"}, {"op": "ss_togli_d"}, {"op": "ss_scelte_via"}, if_(NOT(S(7)), [see("473")])])
par("587", "[s8] Attiva la motovedetta US 05 in A1 rivolta verso B1. Se s6 non è avvenuto vedi 472; se s7 non è avvenuto vedi 473. Si "
           "passa alla Condizione 3; iniziano i Round; si toglie la reazione speciale D a tutti i tedeschi. La missione finisce quando "
           "(1) non ci sono più tedeschi attivi, oppure (2) tutti gli americani attivi (tranne i serventi del cannone navale) sono usciti "
           "con la motovedetta. Nel caso 1 i feriti gravi in un edificio non costano PV; nel caso 2 vanno portati via. Servono 8 PV.",
    sighting(8) + [{"op": "ss_motovedetta"}, {"op": "ss_scelte_via"}, if_(NOT(S(6)), [see("472")]), if_(NOT(S(7)), [see("473")]),
                   cond(3), {"op": "ss_togli_d"}, {"op": "ss_inizia_round"}])
par("473", "[s7] Una squadra con un cannone navale sorveglia la baia: attiva US 03 in D2, che copre D3, E3 ed E2. Iniziano i Round "
           "(vantaggio tedesco se l’ha causato un movimento tedesco, altrimenti americano). Vedi 253. Se s8 non è avvenuto, all’inizio del "
           "prossimo Round leggi il 690 al posto del controllo Evento.",
    sighting(7) + [{"op": "ss_cannone_navale"}, {"op": "ss_inizia_round"}, if_(NOT(S(8)), [{"op": "ss_690_al_round"}])])
par("253", "Il cannone navale: si carica con un’azione e spara con un’azione (non nello stesso turno), solo i suoi serventi; l’abilità "
           "del tiratore conta. Spara solo nel settore coperto (in questa versione non si gira il settore). Contro il cannone: con le "
           "armi esplosive si tira la penetrazione (leggera: i serventi tirano sulla riga della pistola; media: del fucile "
           "semiautomatico; pesante: cannone distrutto e serventi sulla riga della mitragliatrice media).", [])
par("588", "La motovedetta ha 6 punti equipaggio e non va nel panico. Ferma a 2 esagoni da un americano della squadra, raccoglie a bordo "
           "chi è nel suo esagono o in uno adiacente; spara con la mitragliatrice pesante. Quando tutta la squadra è a bordo fa un "
           "controllo di percezione a turno: se riesce esce dal bordo sud. Segue i riferimenti di movimento neri della Condizione 3.", [])
par("703", "La squadra può uscire dalla mappa da W1, X1 o Y1. Chi esce non rientra. Valgono le condizioni di vittoria del 587.",
    [{"op": "ss_barca_affondata"}])
par("702", "Si passa alla Condizione 2. Se s7 non è avvenuto, vedi 473. Se s8 non è avvenuto, vedi 690.",
    [cond(2), if_(NOT(S(7)), [see("473")]), if_(NOT(S(8)), [see("690")])])
par("581", "Controllo di percezione: se riesce vedi 700; altrimenti nessun evento.", [pc(0, [see("700")])])
par("691", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 699; altrimenti nessun evento.", [EVENT, pc(0, [see("699")])])
par("699", "[s9] In questo esagono ci sono un bazooka con due razzi e una carica da demolizione non innescata.",
    sighting(9) + [{"op": "ss_bottino_699"}])
par("700", "[s2] C’è un guado in H11, fra H10 e H12 (segnalino).", sighting(2) + [{"op": "ss_guado_h11"}])
par("692", "[s2] C’è un guado in H11, fra H12 e H10 (segnalino): il tedesco entra in H11.",
    sighting(2) + [{"op": "ss_guado_h11"}, enter("H11")])
par("696", "Sulla strada nessun evento; al piano superiore di U13 vedi 242.", [])

# ------------------------------------------------------------------ movimento (riferimenti rossi)
mov("140", "Con un numero d’azione dispari entra in E16, con un pari in F16.", [if_(DISPARI, [enter("E16")], [enter("F16")])])
mov("141", "Se si muove un mezzo: con un dispari entra in K13, con un pari in L14. Se si muove un soldato, entra in K13.",
    [if_(VEIC, [if_(DISPARI, [enter("K13")], [enter("L14")])], [enter("K13")])])
mov("142", "Con un dispari entra in P13, con un pari in Q15.", [if_(DISPARI, [enter("P13")], [enter("Q15")])])
mov("143", "Se si muove un mezzo, entra in I12. Se si muove un soldato e nessun tedesco attivo è a sud del fiume, vedi 692; altrimenti "
           "entra in I12.",
    [if_(VEIC, [enter("I12")], [if_({"ss_tedesco_a_sud": True}, [enter("I12")], [see("692")])])])
mov("144", "Se si muove un soldato entra in U12; un mezzo con un dispari in U12, con un pari in W12.",
    [if_(VEIC, [if_(DISPARI, [enter("U12")], [enter("W12")])], [enter("U12")])])
mov("145", "Con un dispari entra in Q17, con un pari in O17.", [if_(DISPARI, [enter("Q17")], [enter("O17")])])
mov("146", "Se si muove un soldato entra in V14; un mezzo con un dispari in W14, con un pari in V15.",
    [if_(VEIC, [if_(DISPARI, [enter("W14")], [enter("V15")])], [enter("V14")])])
mov("147", "Con un dispari entra in I19, altrimenti in G19.", [if_(DISPARI, [enter("I19")], [enter("G19")])])
mov("148", "Con un dispari entra in S18, con un pari in R18.", [if_(DISPARI, [enter("S18")], [enter("R18")])])
mov("149", "Se c’è un americano attivo nell’edificio D9 o C9, entra in D9; altrimenti in D10.",
    [if_({"ss_us_in_edificio": ["D9", "C9"]}, [enter("D9")], [enter("D10")])])
mov("250", "Finché non viene detto altrimenti, questo mezzo tedesco ignora le parti dei suoi paragrafi che lo fanno muovere. Quando "
           "spara col cannone mira, nell’ordine, a un mezzo americano, al cannone anticarro americano, a un americano visibile in un "
           "edificio, altrimenti all’edificio più vicino (+4 contro un muro). Se s7 non è avvenuto, vedi 473.",
    [{"op": "ss_250"}, if_(NOT(S(7)), [see("473")])])
mov("251", "Se si muove un mezzo tedesco, entra in K10. Se si muove un soldato: con un dispari entra in L10, con un pari in J10.",
    [if_(VEIC, [enter("K10")], [if_(DISPARI, [enter("L10")], [enter("J10")])])])
mov("252", "Se si muove un mezzo tedesco, vedi 250. Se si muove un soldato, entra in P7.", [if_(VEIC, [see("250")], [enter("P7")])])
mov("254", "Se si muove un mezzo tedesco, entra in O7; un soldato in O8.", [if_(VEIC, [enter("O7")], [enter("O8")])])
mov("255", "Se c’è un americano attivo (tranne i serventi del cannone) in mappa e non in barca, la motovedetta resta in P1: raccoglie "
           "a bordo chi è accanto e spara con la mitragliatrice pesante. Se sono tutti a bordo, esce.", [])
mov("256", "Se c’è un americano o un mezzo americano attivo a est di questo esagono, entra in F8; altrimenti in H8.",
    [if_({"ss_us_a_est": True}, [enter("F8")], [enter("H8")])])
mov("257", "Se vede una barca americana attiva, non si muove; altrimenti entra in H8.",
    [if_({"ss_barca_us_vista": True}, [{"op": "nothing"}], [enter("H8")])])
mov("258", "Se si muove un mezzo tedesco e vede una barca americana attiva, non si muove; altrimenti entra in K9.",
    [if_(ALL(VEIC, {"ss_barca_us_vista": True}), [{"op": "nothing"}], [enter("K9")])])
mov("259", "Se si muove un soldato entra in P5; un mezzo in N4.", [if_(VEIC, [enter("N4")], [enter("P5")])])
mov("367", "Se si muove un mezzo tedesco e vede una barca americana attiva, non si muove; altrimenti entra in P6.",
    [if_(ALL(VEIC, {"ss_barca_us_vista": True}), [{"op": "nothing"}], [enter("P6")])])
mov("424", "Se si muove un mezzo entra in N7; un soldato in P7.", [if_(VEIC, [enter("N7")], [enter("P7")])])
mov("445", "Se si muove un mezzo entra in Q8; un soldato in P7.", [if_(VEIC, [enter("Q8")], [enter("P7")])])
mov("693", "Se vede un mezzo americano, passa alla reazione speciale D. Altrimenti entra in P6 (togliendo la reazione D).",
    [if_({"ss_mezzo_us_visto": True}, [{"op": "g_reaction", "r": "D"}], [{"op": "g_reaction", "r": ""}, enter("P6")])])
mov("694", "1. Se vede un mezzo americano, passa alla reazione speciale D.\n2. Se in P4 ci sono più tedeschi che in R4, toglie la "
           "reazione D ed entra in Q5.\n3. Toglie la reazione D ed entra in P4.",
    [if_({"ss_mezzo_us_visto": True}, [{"op": "g_reaction", "r": "D"}],
         [{"op": "g_reaction", "r": ""}, if_({"ss_piu_in": ["P4", "R4"]}, [enter("Q5")], [enter("P4")])])])
mov("695", "Se si muove un mezzo entra in O6; un soldato in P5.", [if_(VEIC, [enter("O6")], [enter("P5")])])
mov("781", "Passa alla reazione speciale D.", [{"op": "g_reaction", "r": "D"}])

# ------------------------------------------------------------------ azioni (codice in tedeschi_ss.gd / missione21_ss.gd)
AZ = {
 "425": "Sul carro (reazione T). 1. Se il carro è immobilizzato o è stato bersagliato, toglie la reazione T. 2. Se è nell’esagono del "
        "carro: con un dispari 840, con un pari 868. 3. Altrimenti, con il numero d’azione: 0–3: 803, 4–5: 809, 6–8: 868, 9: 800.",
 "426": "Sul carro (reazione T). 1. Se il carro è immobilizzato o è stato bersagliato, toglie la reazione T. 2. Nell’esagono del carro: "
        "con un pari 800, con un dispari 868. 3. Altrimenti: 0–2: 862, 3–4: 863, 5–6: 864, 7–9: 858.",
 "584": "Sul Jagdpanther (reazione T): come il 425.",
 "585": "Sul Jagdpanther (reazione T). 1. Se il Jagdpanther è immobilizzato o è stato bersagliato, toglie la reazione T. 2. Nel suo "
        "esagono: con un dispari 868, con un pari 800. 3. Altrimenti: 0–2: 862, 3–4: 863, 5–6: 864, 7–9: 858.",
 "583": "Reazione H. 1. Con un americano nell’esagono, assalto per uccidere. 2. Con un americano accanto e una granata, la lancia; senza "
        "granate, miglior tiro al più facile. 3. Con un americano in vista più lontano, corre verso il più vicino. 4. Senza americani in "
        "vista e in I13, toglie la reazione H e ritira il numero d’azione. 5. Altrimenti va verso il bordo in alto finché la carta non "
        "gli dà un movimento, poi toglie la reazione H.",
 "586": "Reazione H. Come il 583, ma senza granate carica d’assalto il vicino; senza americani in vista va verso il bordo in alto finché "
        "la carta non gli dà un movimento.",
 "474": "Servente del cannone navale. 1. Con un tedesco nell’esagono, assalto. 2. Con tedeschi a meno di 4 esagoni e una granata, la "
        "lancia. 3. Con il cannone carico e un mezzo tedesco in vista, spara col cannone al più vicino. 4. Se il cannone è scarico, lo "
        "carica. 5. Miglior tiro con la carabina al più facile entro 6 esagoni. 6. Si accovaccia.",
 "476": "Servente del cannone navale. 1. Assalto a chi è nell’esagono. 2. Con un tedesco accanto e una granata, la lancia. 3. Se il "
        "cannone è scarico, lo carica. 4. Con il cannone carico e un mezzo tedesco in vista, spara al più facile. 5. Miglior tiro con la "
        "carabina al più vicino. 6. Niente.",
 "477": "Servente del cannone navale. 1. Assalto a chi è nell’esagono. 2. Con un tedesco accanto, miglior tiro al più facile. 3. Se il "
        "cannone è scarico, lo carica. 4. Con il cannone carico e un mezzo tedesco in vista, spara al più vicino. 5. Con un tedesco a "
        "2–3 esagoni e una granata, la lancia. 6. Miglior tiro al più facile. 7. Si accovaccia.",
 "704": "Motovedetta: va veloce fermandosi a 2 esagoni da un americano della squadra, spara con la mitragliatrice pesante al bersaglio "
        "più facile, raccoglie a bordo la squadra.",
 "705": "Motovedetta: raccoglie a bordo la squadra, va piano fermandosi a 2 esagoni da un americano, spara al più vicino.",
 "337": "Motovedetta: spara al bersaglio più facile, raccoglie a bordo la squadra, va veloce fermandosi a 2 esagoni da un americano.",
}
for k, v in AZ.items():
    par(k, v, [], "azione")
