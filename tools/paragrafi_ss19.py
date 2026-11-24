# -*- coding: utf-8 -*-
"""Silver Star – Missione 19 «Fradici» (mappa F con mezza mappa H; Sicilia, agosto 1943).

Incursione notturna in una cala vicino a Messina: due canoe e quattro sommozzatori devono distruggere le chiatte di rifornimento
tedesche con gli esplosivi a tempo. Testo inglese: tools/paragrafi_ss_en.json (OCR del libretto, riletto a mano).
Le operazioni «ss_*» sono in scripts/motore/missioni_ss.gd e tedeschi_ss.gd.
"""
from paragrafi_m1 import pc, act, see, die, if_, S, NOT, ALL, sighting, activate, cond, EVENT

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def mov(pid, it, ops):
    par(pid, it, ops, "movimento")


def enter(h):
    return {"op": "g_enter", "hex": h}


SUP = {"ss_sott_acqua": False}
SOTTO = {"ss_sott_acqua": True}
VEIC = {"vehicle_moving": True}


def sup_sotto(it, ops_sup, ops_sotto):
    return it, [if_(SOTTO, ops_sotto, ops_sup)]


# ------------------------------------------------------------------ eventi casuali e controlli generali
par("100", "Campo minato! Esegui la procedura del campo minato. Se sei nella Condizione 1 e la mina esplode, vedi 235.",
    [{"op": "minefield"}, if_(ALL(NOT({"no_mine_blast": True}), {"cond_in": [1]}), [see("235")])])
par("750", "Campo minato! Esegui la procedura del campo minato. Se la mina esplode e s3 non è ancora avvenuto, vedi 235.",
    [{"op": "minefield"}, if_(ALL(NOT({"no_mine_blast": True}), NOT(S(3))), [see("235")])])
par("751", "Campo minato! Esegui la procedura del campo minato. Se la mina esplode e s9 non è ancora avvenuto, vedi 430.",
    [{"op": "minefield"}, if_(ALL(NOT({"no_mine_blast": True}), NOT(S(9))), [see("430")])])
par("101", "Colloca un segnalino Evento. Effettua un controllo di percezione: se riesce vedi 109; se fallisce, nessun evento.",
    [EVENT, pc(0, [see("109")])])
par("109", "[s0] È un magazzino tedesco. In questo esagono ci sono una pistola mitragliatrice con 3 caricatori, un fucile a otturatore "
           "con 3 caricatori, 3 granate e una carica da demolizione non innescata. La carica si può lanciare in una chiatta per "
           "distruggerla (−1 se lanciata da fuori dell’esagono della chiatta).",
    sighting(0) + [{"op": "ss_magazzino"}])
par("120", "Se si muove un soldato, vedi 100. Se è in una canoa spiaggiata, nessun evento.",
    [if_({"ss_in_canoa": True}, [], [see("100")])])
par("230", "Se è in canoa, nessun evento. Se c’è un soldato in acqua, quello con la percezione più alta effettua un controllo di "
           "percezione: se riesce vedi 340, se fallisce vedi 450.",
    [if_({"ss_in_canoa": True}, [], [pc(0, [see("340")], [see("450")])])])
par("231", "Colloca un segnalino Evento.\n1. In superficie: controllo di percezione (−2). Se riesce vedi 561; se fallisce, controllo "
           "di attivazione (−2): se riesce vedi 562, altrimenti nessun evento.\n2. Sott’acqua: controllo di attivazione (−2). Se riesce "
           "vedi 562; se fallisce, controllo di percezione (−2): se riesce vedi 561, altrimenti nessun evento.",
    [EVENT, if_(SOTTO, [act(-2, [see("562")], [pc(-2, [see("561")])])], [pc(-2, [see("561")], [act(-2, [see("562")])])])])
par("232", "Se è avvenuto un avvistamento diverso da s9:\n1. se s6 non è avvenuto, vedi 323;\n2. se s7 non è avvenuto, vedi 338;\n"
           "3. se s6 e s7 sono avvenuti entrambi, vedi 342.\nAltrimenti nessun evento.",
    [if_({"ss_avvistamento_tranne_9": True}, [if_(NOT(S(6)), [see("323")], [if_(NOT(S(7)), [see("338")], [see("342")])])])])
par("238", "Se è avvenuto un avvistamento diverso da s9:\n1. se s7 non è avvenuto, vedi 338;\n2. se s6 non è avvenuto, vedi 323;\n"
           "3. se s6 e s7 sono avvenuti entrambi, vedi 349.\nAltrimenti nessun evento.",
    [if_({"ss_avvistamento_tranne_9": True}, [if_(NOT(S(7)), [see("338")], [if_(NOT(S(6)), [see("323")], [see("349")])])])])
par("234", "1. In superficie: controllo di percezione. Se riesce vedi 561; se fallisce, controllo di attivazione: se riesce vedi 562, "
           "altrimenti nessun evento.\n2. Sott’acqua: controllo di percezione (−1). Se riesce vedi 561; se fallisce, controllo di "
           "attivazione (−1): se riesce vedi 563, altrimenti nessun evento.",
    [if_(SOTTO, [pc(-1, [see("561")], [act(-1, [see("563")])])], [pc(0, [see("561")], [act(0, [see("562")])])])])
par("236", "Colloca un segnalino Evento.\n1. In superficie: controllo di percezione (−1). Se riesce vedi 561; se fallisce, controllo "
           "di attivazione (−1): se riesce vedi 562, altrimenti nessun evento.\n2. Sott’acqua: controllo di attivazione (−1). Se riesce "
           "vedi 562, altrimenti nessun evento.",
    [EVENT, if_(SOTTO, [act(-1, [see("562")])], [pc(-1, [see("561")], [act(-1, [see("562")])])])])
par("235", "[s3] Arrivano rinforzi tedeschi: i tedeschi 10–15 su un camion. Tira un dado: con un dispari il camion entra in Y4, con "
           "un pari in Y10. I tedeschi 10–15 si attivano nella reazione speciale T. Iniziano i Round, vantaggio tedesco. Il "
           "tedesco 10 riceve 2 turni in questo Round.",
    sighting(3) + [die((1, 1, [{"op": "ss_camion", "hex": "Y4"}]), (3, 3, [{"op": "ss_camion", "hex": "Y4"}]),
                       (5, 5, [{"op": "ss_camion", "hex": "Y4"}]), (7, 7, [{"op": "ss_camion", "hex": "Y4"}]),
                       (9, 9, [{"op": "ss_camion", "hex": "Y4"}]),
                       (0, 0, [{"op": "ss_camion", "hex": "Y10"}]), (2, 2, [{"op": "ss_camion", "hex": "Y10"}]),
                       (4, 4, [{"op": "ss_camion", "hex": "Y10"}]), (6, 6, [{"op": "ss_camion", "hex": "Y10"}]),
                       (8, 8, [{"op": "ss_camion", "hex": "Y10"}]))])
par("429", "[s3] Un camion di tedeschi entra in mappa diretto al villaggio: i tedeschi 10–15 su un camion in Y4, tutti nella reazione "
           "speciale T. Iniziano i Round, vantaggio tedesco. Il tedesco 10 riceve 2 turni in questo Round.",
    sighting(3) + [{"op": "ss_camion", "hex": "Y4"}])
par("600", "[s3] Un camion di tedeschi entra in mappa diretto al villaggio: i tedeschi 10–15 su un camion in Y10, tutti nella "
           "reazione speciale T. Iniziano i Round, vantaggio tedesco. Il tedesco 10 riceve 2 turni in questo Round.",
    sighting(3) + [{"op": "ss_camion", "hex": "Y10"}])
par("237", "Le chiatte (segnalino 237). Sono mezzi grandi allo scoperto per il fuoco; chi è su una chiatta è in copertura; non "
           "bloccano la vista. Si sale su una chiatta con 2 PM da un esagono di terra adiacente o con un’azione dall’acqua. Ogni "
           "chiatta distrutta vale 3 PV. Si distrugge con: 1) penetrazione M o H di un bazooka (muore chi è a bordo); 2) l’esplosione "
           "di un esplosivo a tempo applicato alla chiatta (un’azione nell’esagono della chiatta, in superficie o sott’acqua; salta "
           "alla fine del Round successivo, ratés 05 come la carica): chi è a bordo muore, chi è in acqua nell’esagono subisce danni "
           "sulla riga Carica all’aperto (in superficie non prono, sott’acqua prono); 3) una carica da demolizione esplosa sulla "
           "chiatta (−1 da fuori dell’esagono); 4) una granata, se il primo tiro sulla riga Granata al chiuso dà incapacitato o "
           "ucciso. Da adesso i sommozzatori possono salire sulle chiatte, ma non ancora entrare in un esagono di terra.",
    [{"op": "ss_nota_237"}])
par("239", "Se è su un veicolo, togli la reazione speciale T, scende in piedi (1 PM) ed entra in C3. Altrimenti entra in C3.",
    [{"op": "ss_scende_camion"}, enter("C3")])
par("242", "Trappola esplosiva! Esegui la procedura della trappola esplosiva.", [{"op": "boobytrap"}])
par("323", "[s6] Attiva il tedesco 70 (sommozzatore) in superficie in F7. Iniziano i Round.",
    sighting(6) + [{"op": "ss_sub_tedesco", "g": 70, "hex": "F7"}])
par("338", "[s7] Attiva il tedesco 71 (sommozzatore) in superficie in L4. Iniziano i Round.",
    sighting(7) + [{"op": "ss_sub_tedesco", "g": 71, "hex": "L4"}])
par("332", "Attiva il tedesco 52 accovacciato in M9 e il tedesco 53 accovacciato in I9, entrambi nella reazione speciale A. "
           "Iniziano i Round, vantaggio americano.",
    [activate([(52, "M9"), (53, "I9")], "crouching", adv="us", reaction="A")])
par("430", "Attiva il tedesco 52 accovacciato in M9 e il tedesco 53 accovacciato in I9, entrambi nella reazione speciale A. "
           "Iniziano i Round, vantaggio tedesco.",
    [activate([(52, "M9"), (53, "I9")], "crouching", adv="de", reaction="A")])
par("340", "C’è una trappola subacquea in questo esagono. Chi ha superato il controllo torna nell’esagono da cui è venuto; chi è "
           "entrato con lui fa ora il suo controllo di percezione: se lo supera torna indietro anche lui, se lo fallisce esegue la "
           "procedura della trappola, non prono. Se la trappola esplode, vedi 560.",
    [{"op": "ss_trappola_sub", "superato": True}])
par("450", "C’è una trappola subacquea in questo esagono. Chi ha fallito il controllo conta non prono; gli altri entrati con lui fanno "
           "il controllo di percezione: chi lo supera conta prono, chi lo fallisce no. Esegui la procedura della trappola; se esplode, "
           "vedi subito 560.",
    [{"op": "ss_trappola_sub", "superato": False}])
par("341", "[s1] Attiva la barca di guardia 60 in C7 e il tedesco 54 accovacciato in C9, nella reazione speciale A. Iniziano i Round, "
           "vantaggio tedesco. Se s4 non è avvenuto, vedi 541.",
    sighting(1) + [{"op": "ss_barca_guardia", "g": 60, "hex": "C7"},
                   activate([(54, "C9")], "crouching", adv="de", reaction="A"), if_(NOT(S(4)), [see("541")])])
par("542", "[s1] Attiva la barca di guardia 60 in C7 e il tedesco 54 accovacciato in C9, nella reazione speciale A. Iniziano i Round. "
           "Se s4 non è avvenuto, vedi 541.",
    sighting(1) + [{"op": "ss_barca_guardia", "g": 60, "hex": "C7"},
                   activate([(54, "C9")], "crouching", reaction="A"), if_(NOT(S(4)), [see("541")])])
par("783", "[s1] Attiva la barca di guardia 60 in C7 e il tedesco 54 accovacciato in C9, nella reazione speciale A. Se s4 non è "
           "avvenuto, vedi 541. Iniziano i Round, vantaggio americano; il soldato che ha superato il controllo è consapevole e "
           "riceve 2 turni in questo Round.",
    sighting(1) + [{"op": "ss_barca_guardia", "g": 60, "hex": "C7"},
                   activate([(54, "C9")], "crouching", adv="us", us_two=True, aware=True, reaction="A"), if_(NOT(S(4)), [see("541")])])
par("342", "Se s1, s2 o entrambi sono avvenuti:\n1. se s8 non è avvenuto, vedi 419;\n2. se s9 non è avvenuto, vedi 430;\n"
           "3. se s3 non è avvenuto, vedi 235;\n4. se la vista è di 3 esagoni, vedi 640;\n5. se s4 e s5 sono avvenuti e restano 2 "
           "chiatte attive o meno, vedi 789;\n6. altrimenti nessun evento.\nSe né s1 né s2 sono avvenuti, nessun evento.",
    [if_({"ss_s1_o_s2": True}, [if_(NOT(S(8)), [see("419")], [if_(NOT(S(9)), [see("430")], [if_(NOT(S(3)), [see("235")],
        [if_({"ss_vista": 3}, [see("640")], [if_(ALL(S(4), S(5), {"ss_chiatte_max": 2}), [see("789")])])])])])])])
par("349", "Se s1, s2 o entrambi sono avvenuti:\n1. se s9 non è avvenuto, vedi 430;\n2. se s8 non è avvenuto, vedi 419;\n"
           "3. se s3 non è avvenuto, vedi 235;\n4. se la vista è di 3 esagoni, vedi 640;\n5. se s4 e s5 sono avvenuti e restano 2 "
           "chiatte attive o meno, vedi 789;\n6. altrimenti nessun evento.\nSe né s1 né s2 sono avvenuti, nessun evento.",
    [if_({"ss_s1_o_s2": True}, [if_(NOT(S(9)), [see("430")], [if_(NOT(S(8)), [see("419")], [if_(NOT(S(3)), [see("235")],
        [if_({"ss_vista": 3}, [see("640")], [if_(ALL(S(4), S(5), {"ss_chiatte_max": 2}), [see("789")])])])])])])])
par("346", "Un sommozzatore (anche tedesco, se ce ne sono di attivi) resta senz’aria: può ancora nuotare sott’acqua, ma deve finire "
           "ogni Round in superficie (diventa un nuotatore). Solo una volta per missione; se ricapita, si tira un nuovo evento.",
    [{"op": "ss_senz_aria"}])
par("400", "Un’arma tedesca usata nel Round precedente finisce le munizioni (a caso se più d’una). Può capitare più volte.",
    [{"op": "ammo_out"}])
par("419", "[s8] Attiva il tedesco 51 accovacciato in P5, nella reazione speciale A. Iniziano i Round, vantaggio tedesco.",
    sighting(8) + [activate([(51, "P5")], "crouching", adv="de", reaction="A")])
par("715", "[s8] Attiva il tedesco 51 accovacciato in P5, nella reazione speciale A. Iniziano i Round, vantaggio americano.",
    sighting(8) + [activate([(51, "P5")], "crouching", adv="us", reaction="A")])
par("480", "[s9] Il soldato nota che il ponte in O4 è indebolito dagli anni e dall’incuria: potrebbe non reggere.",
    sighting(9))
par("530", "Se si entra in questo esagono da M9 e s0 non è avvenuto, vedi 101. Se si entra da un altro esagono e s9 non è avvenuto, "
           "vedi 716. Altrimenti nessun evento.",
    [if_(ALL({"ss_entrato_da": "M9"}, NOT(S(0))), [see("101")], [if_(ALL(NOT({"ss_entrato_da": "M9"}), NOT(S(9))), [see("716")])])])
par("540", "[s5] Ci sono chiatte tedesche di rifornimento qui vicino. Tira un dado: con un dispari le chiatte sono in J7, L7, N6; con "
           "un pari in I7, M7, N5. Vedi 237 per le chiatte.",
    sighting(5) + [{"op": "ss_chiatte", "dispari": ["J7", "L7", "N6"], "pari": ["I7", "M7", "N5"]}, see("237")])
par("541", "[s4] C’è una chiatta tedesca di rifornimento qui vicino. Tira un dado: con un dispari è in C6, con un pari in D7. "
           "Vedi 237 per le chiatte.",
    sighting(4) + [{"op": "ss_chiatte", "dispari": ["C6"], "pari": ["D7"]}, see("237")])
par("543", "1. In superficie: controllo di percezione. Se riesce vedi 783; se fallisce, controllo di attivazione: se riesce vedi 341, "
           "altrimenti, se s4 non è avvenuto, vedi 541.\n2. Sott’acqua: controllo di percezione. Se riesce vedi 783; se fallisce, "
           "controllo di attivazione (−1): se riesce vedi 341, altrimenti, se s4 non è avvenuto, vedi 541.",
    [if_(SOTTO, [pc(0, [see("783")], [act(-1, [see("341")], [if_(NOT(S(4)), [see("541")])])])],
         [pc(0, [see("783")], [act(0, [see("341")], [if_(NOT(S(4)), [see("541")])])])])])
par("544", "[s2] Attiva la barca di guardia 61 in M5. Iniziano i Round. Se s5 non è avvenuto, vedi 540.",
    sighting(2) + [{"op": "ss_barca_guardia", "g": 61, "hex": "M5"}, if_(NOT(S(5)), [see("540")])])


def sub6(pid, mod_txt, mod):
    par(pid, f"Se s6 non è avvenuto, vedi 323. Se s1 non è avvenuto, vedi 670; se s1 è avvenuto, controllo di percezione{mod_txt}: se "
             "riesce vantaggio americano, se fallisce vantaggio tedesco. Se s1 e s6 sono avvenuti entrambi, colloca un segnalino "
             "Evento: nessun evento.",
        [if_(ALL(S(1), S(6)), [EVENT], [if_(NOT(S(6)), [see("323")]),
                                        if_(NOT(S(1)), [see("670")], [pc(mod, [{"op": "ss_vantaggio", "lato": "us"}],
                                                                      [{"op": "ss_vantaggio", "lato": "de"}])])])])


sub6("545", " (+1)", 1)
sub6("546", "", 0)
sub6("547", "", 0)
par("548", "Controllo di percezione: se riesce vedi 323 con vantaggio americano; se fallisce, controllo di attivazione: se riesce "
           "vedi 323 con vantaggio tedesco, altrimenti vedi 323.",
    [pc(0, [see("323"), {"op": "ss_vantaggio", "lato": "us"}], [act(0, [see("323"), {"op": "ss_vantaggio", "lato": "de"}], [see("323")])])])


def sub7(pid, chk):
    par(pid, f"Se s7 non è avvenuto, vedi 338. Se s2 non è avvenuto, vedi {chk}; se s2 è avvenuto, controllo di percezione: se riesce "
             "vantaggio americano, se fallisce vantaggio tedesco. Se s2 e s7 sono avvenuti entrambi, colloca un segnalino Evento: "
             "nessun evento.",
        [if_(ALL(S(2), S(7)), [EVENT], [if_(NOT(S(7)), [see("338")]),
                                        if_(NOT(S(2)), [see(chk)], [pc(0, [{"op": "ss_vantaggio", "lato": "us"}],
                                                                       [{"op": "ss_vantaggio", "lato": "de"}])])])])


sub7("550", "236")
sub7("551", "234")
par("552", "Controllo di percezione (+1): se riesce vedi 338 con vantaggio americano; se fallisce vedi 338 con vantaggio tedesco.",
    [pc(1, [see("338"), {"op": "ss_vantaggio", "lato": "us"}], [see("338"), {"op": "ss_vantaggio", "lato": "de"}])])
par("553", "Controllo di percezione: se riesce vedi 715; se fallisce vedi 419.", [pc(0, [see("715")], [see("419")])])
par("533", "Controllo di percezione: se riesce vedi 715; se fallisce vedi 419.", [pc(0, [see("715")], [see("419")])])
par("554", "Un esplosivo a tempo (a caso se più d’uno) esplode prima del previsto: la chiatta a cui è applicato è distrutta e chi è a "
           "bordo muore. Chi è in acqua nell’esagono subisce danni sulla riga Carica all’aperto (in superficie non prono, sott’acqua "
           "prono), senza controllo di percezione. Può capitare più volte.",
    [{"op": "ss_esplosivo_prematuro"}])
par("679", "Se non ci sono esplosivi a tempo innescati, nessun evento. Altrimenti vedi 554.",
    [if_({"ss_esplosivi_innescati": True}, [see("554")])])
par("560", "[s1, s2, s4 e s5] Attiva la barca di guardia 60 in C7 e la 61 in M5. Iniziano i Round, vantaggio tedesco. Tira un dado: "
           "con un dispari le chiatte sono in C5, I7, M7, N5; con un pari in D7, J7, L7, N6. Vedi 237.",
    sighting(1, 2, 4, 5) + [{"op": "ss_barca_guardia", "g": 60, "hex": "C7"}, {"op": "ss_barca_guardia", "g": 61, "hex": "M5", "adv": "de"},
                            {"op": "ss_chiatte", "dispari": ["C5", "I7", "M7", "N5"], "pari": ["D7", "J7", "L7", "N6"]}, see("237")])
par("561", "[s2] Attiva la barca di guardia 61 in M5. Iniziano i Round, vantaggio americano. L’americano che ha superato il controllo "
           "è consapevole e riceve 2 turni in questo Round. Se s5 non è avvenuto, vedi 540.",
    sighting(2) + [{"op": "ss_barca_guardia", "g": 61, "hex": "M5", "adv": "us", "us_two": True}, if_(NOT(S(5)), [see("540")])])
par("562", "[s2] Attiva la barca di guardia 61 in M5. Iniziano i Round, vantaggio tedesco. Se s5 non è avvenuto, vedi 540.",
    sighting(2) + [{"op": "ss_barca_guardia", "g": 61, "hex": "M5", "adv": "de"}, if_(NOT(S(5)), [see("540")])])
par("563", "[s2 e s5] Attiva la barca di guardia 61 in M5. Iniziano i Round; la barca riceve 2 turni in questo Round. Tira un dado: "
           "con un dispari le chiatte sono in J7, L7, N6; con un pari in I7, M7, N5. Vedi 237.",
    sighting(2, 5) + [{"op": "ss_barca_guardia", "g": 61, "hex": "M5", "two": True},
                      {"op": "ss_chiatte", "dispari": ["J7", "L7", "N6"], "pari": ["I7", "M7", "N5"]}, see("237")])
par("640", "Spunta l’alba: la vista arriva a 5 esagoni.", [{"op": "vista", "n": 5}])
par("670", "Colloca un segnalino Evento.\n1. In superficie: controllo di percezione (−2). Se riesce vedi 780; se fallisce, controllo di "
           "attivazione (−2): se riesce vedi 341, altrimenti nessun evento.\n2. Sott’acqua: controllo di attivazione (−2): se riesce "
           "vedi 341, altrimenti nessun evento.",
    [EVENT, if_(SOTTO, [act(-2, [see("341")])], [pc(-2, [see("780")], [act(-2, [see("341")])])])])
par("671", "Colloca un segnalino Evento.\n1. In superficie: controllo di percezione (−1). Se riesce vedi 780; se fallisce, controllo di "
           "attivazione (−1): se riesce vedi 341, altrimenti nessun evento.\n2. Sott’acqua: controllo di attivazione (−1): se riesce "
           "vedi 341, altrimenti nessun evento.",
    [EVENT, if_(SOTTO, [act(-1, [see("341")])], [pc(-1, [see("780")], [act(-1, [see("341")])])])])
par("673", "1. In superficie: controllo di percezione (+2). Se riesce vedi 783; se fallisce, controllo di attivazione: se riesce vedi "
           "341, altrimenti, se s4 non è avvenuto, vedi 541.\n2. Sott’acqua: controllo di percezione (+1). Se riesce vedi 783; se "
           "fallisce, controllo di attivazione (−1): se riesce vedi 341, altrimenti, se s4 non è avvenuto, vedi 541.",
    [if_(SOTTO, [pc(1, [see("783")], [act(-1, [see("341")], [if_(NOT(S(4)), [see("541")])])])],
         [pc(2, [see("783")], [act(0, [see("341")], [if_(NOT(S(4)), [see("541")])])])])])
par("676", "Se il camion tedesco è attivo fora una gomma: controllo d’incidente, poi può andare solo piano (con una seconda gomma "
           "forata è immobilizzato e conta come distrutto). Solo una volta per missione. Altrimenti si tira un nuovo evento casuale.",
    [{"op": "ss_gomma_camion"}])
par("677", "1. In superficie: controllo di attivazione (+1). Se riesce vedi 341; se fallisce, controllo di percezione (+1): se riesce "
           "vedi 780, altrimenti vedi 542.\n2. Sott’acqua: controllo di percezione (+1). Se riesce vedi 780; se fallisce, controllo di "
           "attivazione (+1): se riesce vedi 341, altrimenti vedi 542.",
    [if_(SOTTO, [pc(1, [see("780")], [act(1, [see("341")], [see("542")])])], [act(1, [see("341")], [pc(1, [see("780")], [see("542")])])])])
par("678", "Controllo di percezione: se riesce vedi 783; se fallisce vedi 341.", [pc(0, [see("783")], [see("341")])])
par("696", "Se è sulla strada, nessun evento. Se è al piano superiore di U13, vedi 242.", [])
par("716", "Controllo di percezione: se riesce vedi 332; se fallisce vedi 430.", [pc(0, [see("332")], [see("430")])])
par("719", "Niente sbarco: si prosegue verso nord lungo la riga 1.", [])
par("780", "[s1, s4 e s5] Attiva la barca di guardia 60 in C7 e il tedesco 54 accovacciato in C9, nella reazione speciale A. Tira un "
           "dado: con un dispari le chiatte sono in D7, J7, M7, N5; con un pari in C6, I7, L7, N6. Vedi 237.",
    sighting(1, 4, 5) + [{"op": "ss_barca_guardia", "g": 60, "hex": "C7"}, activate([(54, "C9")], "crouching", reaction="A"),
                         {"op": "ss_chiatte", "dispari": ["D7", "J7", "M7", "N5"], "pari": ["C6", "I7", "L7", "N6"]}, see("237")])
par("787", "[s9] Il comandante sgancia i quattro sommozzatori, che entrano nella cala da E2, F2 e G2, mentre le due canoe proseguono "
           "verso nord per tagliare la strada ai rinforzi e attaccare il villaggio alle spalle. Le canoe non possono sbarcare nelle "
           "colonne A–N, poi si muovono liberamente. I sommozzatori restano negli esagoni d’acqua salvo diversa indicazione. Nelle "
           "Operazioni sommozzatori e canoe possono muoversi insieme, ma i sommozzatori non sono più aggrappati; nei Round ognuno "
           "muove per conto suo. I sommozzatori possono stare in superficie o sott’acqua.",
    sighting(9) + [{"op": "ss_sgancia_sub"}])
par("789", "Si passa alla Condizione 2 e si tolgono tutte le reazioni speciali A. La missione finisce quando (1) tutti gli americani "
           "sono usciti da A1 con tedeschi ancora attivi in mappa, oppure (2) tutti gli americani sono in acqua nelle righe 1 o 2, "
           "colonne A–G, e non ci sono tedeschi attivi. Nel caso 2 non si perdono PV per gli incapacitati; nel caso 1 si evitano "
           "facendoli uscire. I sommozzatori ora possono entrare in qualunque esagono: dall’acqua alla terra costa 2 PM (un’azione "
           "oltre una massicciata), con un cambio di postura gratuito. Un sommozzatore sale su una canoa con posto libero nello stesso "
           "esagono con un’azione. Un incapacitato può uscire nelle due caselle di porto di una canoa. Servono 20 PV per vincere.",
    [cond(2), {"op": "togli_reazioni", "r": ["A"]}, {"op": "ss_fine_789"}])
par("995", "Un tedesco ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Solo una volta per missione.",
    [{"op": "dissanguamento", "chiave": "995", "lato": "de"}])
par("996", "Un tedesco incapacitato, scelto a caso, muore per le ferite. Solo una volta per missione.",
    [{"op": "morte_incapacitato", "chiave": "996", "lato": "de"}])
par("997", "Un americano ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Solo una volta per missione.",
    [{"op": "dissanguamento", "chiave": "997", "lato": "us"}])
par("998", "Un americano incapacitato, scelto a caso, muore per le ferite. Solo una volta per missione.",
    [{"op": "morte_incapacitato", "chiave": "998", "lato": "us"}])

# ------------------------------------------------------------------ movimento (riferimenti rossi)
for pid, v, s_ in (("121", "U2", "U3"), ("122", "T2", "U3"), ("123", "P3", "P4"), ("124", "S3", "T3"), ("125", "O4", "P4"),
                   ("126", "R3", "S4"), ("127", "N3", "O5"), ("128", "Q4", "R4"), ("129", "M3", "N4"), ("424", "N7", "P7"),
                   ("717", "P4", "R4"), ("718", "O6", "P5")):
    mov(pid, f"Se si muove un veicolo, entra in {v}. Se si muove un soldato, entra in {s_}.",
        [if_(VEIC, [enter(v)], [enter(s_)])])
mov("714", "Se si muove un veicolo: nella Condizione 1 entra in R5, nella Condizione 2 in Q7. Se si muove un soldato, entra in Q6.",
    [if_(VEIC, [if_({"cond_in": [1]}, [enter("R5")], [enter("Q7")])], [enter("Q6")])])
mov("451", "Se si muove un veicolo, entra in M4. Se si muove un soldato e s2 è avvenuto, entra in L3; altrimenti in M4.",
    [if_(ALL(NOT(VEIC), S(2)), [enter("L3")], [enter("M4")])])
mov("459", "Se in H3 ci sono più tedeschi attivi che in H2, entra in H2; altrimenti in H3.",
    [if_({"ss_piu_tedeschi": ["H3", "H2"]}, [enter("H2")], [enter("H3")])])
mov("458", "Se si muove un soldato nella Condizione 1, entra in C9 e passa alla reazione speciale A. Altrimenti entra in B7.",
    [if_(ALL(NOT(VEIC), {"cond_in": [1]}), [enter("C9"), {"op": "g_reaction", "r": "A"}], [enter("B7")])])
mov("781", "Passa alla reazione speciale D.", [{"op": "g_reaction", "r": "D"}])
mov("788", "Entra in N2, scendendo in piedi dal camion se serve (1 PM).", [{"op": "ss_scende_camion"}, enter("N2")])
mov("675", "1. Se ci sono meno americani a sud della colonna M (compresa) che a nord, entra in N3.\n2. Altrimenti, se si muove un "
           "soldato, entra in M2; se si muove il camion, ogni occupante (al suo turno) scende in piedi in M3 spendendo 1 PM e toglie "
           "la reazione speciale T.",
    [if_({"ss_meno_a_sud": "M"}, [enter("N3")], [if_(VEIC, [{"op": "ss_scendono_tutti", "hex": "M3"}], [enter("M2")])])])
mov("931", "Se ci sono meno americani attivi a sud della colonna P (compresa) che a nord, entra in Q5; altrimenti in O6.",
    [if_({"ss_meno_a_sud": "P"}, [enter("Q5")], [enter("O6")])])


def chiatta(pid, it, chiatte, v_scende, v_entra, v_altrimenti, s_altrimenti, s_reazione="A", max_a_bordo=0, premessa=None):
    o = {"op": "ss_chiatta_mov", "chiatte": chiatte, "max": max_a_bordo, "scende": v_scende, "v_entra": v_entra,
         "v_altrimenti": v_altrimenti, "s_altrimenti": s_altrimenti, "s_reazione": s_reazione}
    mov(pid, it, (premessa or []) + [o])


chiatta("452", "Se s5 non è avvenuto, vedi subito 540. Se si muove il camion e in N5 c’è una chiatta attiva senza tedeschi a bordo, "
               "fa scendere in piedi un passeggero in O5 (a caso, o l’assistente) ed entra in O6; senza chiatta entra in O6. Se si "
               "muove un soldato e in N5 c’è una chiatta attiva senza tedeschi, sale sulla chiatta (2 PM) e passa alla reazione "
               "speciale B; altrimenti entra in P5 e passa alla reazione speciale A.",
        ["N5"], "O5", "O6", "O6", "P5", premessa=[if_(NOT(S(5)), [see("540")])])
chiatta("453", "Se si muove il camion e in N6 c’è una chiatta attiva senza tedeschi, fa scendere in piedi un passeggero in O7 ed entra "
               "in N7; altrimenti entra in N7. Se si muove un soldato e in N6 c’è una chiatta attiva senza tedeschi, ci sale (2 PM) e "
               "passa alla reazione B; altrimenti entra in P7 e passa alla reazione A.",
        ["N6"], "O7", "N7", "N7", "P7")
mov("454", "Condizione 1: se si muove il camion ed è attiva una chiatta in L7 o M7 senza tedeschi, fa scendere in piedi un passeggero in "
           "M8 ed entra in L8; un soldato sale sulla chiatta in L7 o M7 (2 PM, reazione B), altrimenti entra in M9 (reazione A). "
           "Condizione 2: il camion fa scendere un passeggero in M8 se c’è una chiatta libera ed entra in N7; un soldato sale sulla "
           "chiatta in L7 o M7 (reazione B), altrimenti entra in N7.",
    [if_({"cond_in": [1]},
         [{"op": "ss_chiatta_mov", "chiatte": ["M7", "L7"], "max": 0, "scende": "M8", "v_entra": "L8", "v_altrimenti": "L8",
           "s_altrimenti": "M9", "s_reazione": "A"}],
         [{"op": "ss_chiatta_mov", "chiatte": ["M7", "L7"], "max": 0, "scende": "M8", "v_entra": "N7", "v_altrimenti": "N7",
           "s_altrimenti": "N7", "s_reazione": ""}])])
mov("455", "Condizione 1: se si muove il camion ed è attiva una chiatta in J7 senza tedeschi, fa scendere in piedi un passeggero in J8 "
           "ed entra in I8; un soldato sale sulla chiatta in J7 (2 PM, reazione B), altrimenti entra in I9 (reazione A). "
           "Condizione 2: il camion entra in K8; un soldato sale sulla chiatta libera in J7 (reazione B), altrimenti entra in K8.",
    [if_({"cond_in": [1]},
         [{"op": "ss_chiatta_mov", "chiatte": ["J7"], "max": 0, "scende": "J8", "v_entra": "I8", "v_altrimenti": "I8",
           "s_altrimenti": "I9", "s_reazione": "A"}],
         [{"op": "ss_chiatta_mov", "chiatte": ["J7"], "max": 0, "scende": "", "v_entra": "K8", "v_altrimenti": "K8",
           "s_altrimenti": "K8", "s_reazione": ""}])])
mov("456", "Condizione 1: se si muove il camion ed è attiva una chiatta in I7 o J7 con al massimo un tedesco a bordo, fa scendere in "
           "piedi un passeggero in I8 ed entra in H8; un soldato ci sale (2 PM, reazione B), altrimenti entra in I9 (reazione A). "
           "Condizione 2: il camion fa scendere un passeggero in I8 se c’è una chiatta libera ed entra in J8; un soldato sale sulla "
           "chiatta libera (reazione B), altrimenti entra in J8.",
    [if_({"cond_in": [1]},
         [{"op": "ss_chiatta_mov", "chiatte": ["I7", "J7"], "max": 1, "scende": "I8", "v_entra": "H8", "v_altrimenti": "H8",
           "s_altrimenti": "I9", "s_reazione": "A"}],
         [{"op": "ss_chiatta_mov", "chiatte": ["I7", "J7"], "max": 0, "scende": "I8", "v_entra": "J8", "v_altrimenti": "J8",
           "s_altrimenti": "J8", "s_reazione": ""}])])
chiatta("457", "Se s4 non è avvenuto, vedi subito 541. Se si muove il camion e in D7 c’è una chiatta attiva senza tedeschi, fa scendere "
               "in piedi un passeggero in D8 ed entra in C8. Se si muove un soldato e in D7 c’è una chiatta attiva, ci sale (2 PM, "
               "reazione B); altrimenti entra in D9 (reazione A).",
        ["D7"], "D8", "C8", "C8", "D9", max_a_bordo=9, premessa=[if_(NOT(S(4)), [see("541")])])
chiatta("919", "Se si muove un soldato e in N5 c’è una chiatta attiva senza tedeschi, ci sale (2 PM, reazione B). Altrimenti entra in O5.",
        ["N5"], "", "O5", "O5", "O5", s_reazione="")
chiatta("920", "Se s5 non è avvenuto, vedi 540. Condizione 1: se si muove il camion e in N6 c’è una chiatta attiva senza tedeschi, fa "
               "scendere in piedi un passeggero in O6 ed entra in O7. Se si muove un soldato e in N6 c’è una chiatta libera, ci sale "
               "(2 PM, reazione B). Altrimenti entra in O5.",
        ["N6"], "O6", "O7", "O5", "O5", s_reazione="", premessa=[if_(NOT(S(5)), [see("540")])])
chiatta("926", "Se si muove il camion e in M7 c’è una chiatta attiva senza tedeschi, fa scendere in piedi un passeggero in N7 ed entra "
               "in M8. Se si muove un soldato e in M7 c’è una chiatta attiva, ci sale (2 PM, reazione B). Altrimenti entra in M8.",
        ["M7"], "N7", "M8", "M8", "M8", s_reazione="", max_a_bordo=9)
chiatta("930", "Se si muove il camion, entra in B5 facendo scendere in piedi un passeggero in B6 se in C6 c’è una chiatta attiva senza "
               "tedeschi. Se si muove un soldato e in C6 c’è una chiatta libera, ci sale (2 PM, reazione B). Altrimenti entra in B5.",
        ["C6"], "B6", "B5", "B5", "B5", s_reazione="")

# ------------------------------------------------------------------ azioni dei tedeschi propri della missione
AZ = {
 "233": "Il sommozzatore fa un controllo di percezione. Se riesce: riemerge se è sott’acqua e nuota verso il sommozzatore americano "
        "più vicino in vista; se non ne vede, nuota verso F4; in F4 non fa nulla. Se fallisce: resta come sta e nuota verso F4; in F4 "
        "non fa nulla.",
 "564": "Il sommozzatore fa un controllo di percezione. Se riesce: riemerge se serve e nuota verso il sommozzatore americano attivo più "
        "vicino in vista; se non ne vede, nuota verso K6; in K6, se vede un americano, gli spara con la pistola impermeabilizzata "
        "(inceppamento 25); altrimenti non fa nulla. Se fallisce: resta come sta e nuota verso K6; in K6 non fa nulla.",
 "672": "1. Con un sommozzatore americano attivo entro 2 esagoni, nuota verso il più vicino.\n2. Se è a 3 esagoni e ha una granata, "
        "riemerge e la lancia al sommozzatore più vicino a F2.\n3. Spara con la pistola all’americano attivo più vicino (inceppamento "
        "25), riemergendo prima se serve.\n4. Nuota verso F2.\n5. Non fa nulla.",
 "348": "1. Con un americano attivo nello stesso esagono, assalto per uccidere.\n2. Con un sommozzatore americano incapacitato nello "
        "stesso esagono e un americano attivo in un esagono adiacente, spende un’azione per strappargli l’equipaggiamento e lasciarlo "
        "cadere sul fondo.\n3. Con un americano attivo in un esagono adiacente, carica d’assalto per uccidere.",
 "343": "Sulla chiatta. 1. Con una granata e un sommozzatore americano attivo entro 3 esagoni, si accovaccia e la lancia al più vicino "
        "(−3 se non lo vede); poi prono se può. 2. Altrimenti si accovaccia e fa il miglior tiro al bersaglio visibile più vicino "
        "(prima i sommozzatori); poi prono se può. 3. Si accovaccia.",
 "344": "Sulla chiatta. 1. Se vede un sommozzatore americano, si accovaccia e spara al più vicino; poi prono se può. 2. Con una granata "
        "e un sommozzatore entro 3 esagoni non visibile, gliela lancia. 3. Si accovaccia e spara al bersaglio più facile. 4. Si accovaccia.",
 "345": "Sulla chiatta. 1. Con una granata e un bersaglio visibile, la lancia al più vicino (accovacciato fino a 3 esagoni, in piedi da "
        "4 a 6). 2. Si accovaccia e fa più tiri rapidi possibili. 3. Si accovaccia.",
 "347": "Sulla chiatta. 1. Con una granata e un bersaglio entro 3 esagoni, si accovaccia e la lancia al più vicino (−3 se non lo vede). "
        "2. Si accovaccia e fa il miglior tiro al bersaglio più facile. 3. Si accovaccia.",
 "565": "Autista del camion. Se il camion è stato colpito in questo Round, corre veloce e fa un tiro rapido con la pistola al bersaglio "
        "più facile; altrimenti avanza piano.",
 "566": "Sul camion. Se il camion è stato colpito in questo Round, fa il miglior tiro al bersaglio più vicino; altrimenti nulla.",
 "567": "Sul camion. Se il camion è stato colpito in questo Round, fa il miglior tiro al bersaglio più facile; altrimenti nulla.",
 "568": "Sul camion. Se il camion è stato colpito in questo Round, tira un dado: dispari, dà un turno al tedesco sul camion con "
        "l’abilità più alta; pari, fa più tiri rapidi possibili con la pistola mitragliatrice. Altrimenti nulla.",
 "569": "Toglie la reazione speciale T, scende in piedi dal camion (1 PM) e segue i paragrafi d’azione normali.",
 "782": "1. Se in N5 c’è una chiatta attiva senza tedeschi, toglie la reazione A, si alza ed entra in O5. 2. Se ce n’è una in N6, "
        "entra in O6. 3. Altrimenti, con il numero d’azione: 0–1: 801, 2–5: 800, 6–9: 808.",
 "784": "Se in M7 o L7 c’è una chiatta attiva senza tedeschi, toglie la reazione A, si alza ed entra in M8. Altrimenti, con il numero "
        "d’azione: 0–3: 801, 4–6: 808, 7–9: 856.",
 "785": "Se in J7 c’è una chiatta attiva senza tedeschi, toglie la reazione A, si alza ed entra in J8; se ce n’è una in I7, entra in I8. "
        "Altrimenti, con il numero d’azione: 0–3: 801, 4–6: 808, 7–9: 856.",
 "786": "Se in D7 c’è una chiatta attiva senza tedeschi, toglie la reazione A, si alza ed entra in D8; se ce n’è una in C6, entra in B8. "
        "Altrimenti, con il numero d’azione: 0–1: 856, 2: 840, 3–6: 810, 7–9: 802.",
 "823": "Se nell’esagono c’è un altro tedesco attivo, si sdraia prono. Altrimenti corre in un esagono scoperto o striscia in "
        "qualunque altro esagono.",
 "861": "Se c’è un tedesco attivo nello stesso esagono o in uno adiacente, si accovaccia e cede un turno al tedesco con meno turni "
        "(a parità, a quello con l’abilità più alta). Se tutti hanno due turni, o non ce ne sono, vedi 856.",
 "674": "Barca di guardia: mezzo piccolo allo scoperto, non ci si sale. Va piano (1 esagono per 1 punto equipaggio) o veloce (2 esagoni "
        "per 2 punti); sparare con il fucile o lanciare una granata costa 1 punto. Colpita: dispari, colpito l’equipaggio (tranne il "
        "panico, un uomo in meno; col mitra si continua a tirare; col bazooka il resto dell’equipaggio tira sulla riga Granata al "
        "chiuso); pari, colpita la barca (L: va solo piano; M o H: eliminata). Una granata dentro la barca la distrugge (−3 da fuori "
        "dell’esagono). Senza equipaggio la barca è eliminata.",
 "911": "Barca 60. Fuori da F5: miglior tiro a un americano nello stesso esagono o adiacente, granata al più vicino a 2–3 esagoni, va "
        "piano verso l’americano visibile più vicino; senza americani in vista va veloce verso F5. In F5: miglior tiro al più vicino, "
        "tiri rapidi al più facile, granata al più vicino (prima i sommozzatori).",
 "912": "Barca 60. Va veloce verso l’americano attivo visibile più vicino (prima i sommozzatori) e fa più tiri rapidi possibili; senza "
        "americani in vista va veloce verso F5 e spara al primo che vede. In F5 o con un americano nell’esagono: miglior tiro al più "
        "vicino, granata al secondo più vicino, tiri rapidi.",
 "913": "Barca 60. Fuori da F5: granata al più vicino fuori dall’esagono, va piano verso il più vicino in vista (o verso F5). In F5 o "
        "con un americano nell’esagono: più tiri rapidi possibili al più vicino.",
 "914": "Barca 60. Miglior tiro al più vicino, va veloce verso l’americano in vista più vicino (o piano verso F5), granata al più vicino "
        "fuori dall’esagono.",
 "915": "Barca 61, come 911 ma verso K6.",
 "916": "Barca 61, come 912 ma verso K6.",
 "917": "Barca 61, come 913 ma verso K6.",
 "918": "Barca 61, come 914 ma verso K6.",
}
for k, v in AZ.items():
    par(k, v, [], "azione")
