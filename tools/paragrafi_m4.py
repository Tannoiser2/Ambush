# -*- coding: utf-8 -*-
"""Paragrafi della Missione 4 «Lancio notturno nel D-Day» (mappa B, nord in alto, notte, lancio col paracadute).

Testo inglese da tools/paragrafi_en.json, completato sulle scansioni (079, 498, 593, 738).
"""
from paragrafi_m1 import pc, act, see, if_, S, NOT, ALL, sighting, activate, cond, P as P1
from paragrafi_m2 import P as P2
from paragrafi_m3 import P as P3

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def enter(h):
    return {"op": "g_enter", "hex": h}


def reaz(r):
    return {"op": "g_reaction", "r": r}


def vista(hexes, dest):
    """«Se un americano attivo vede uno di questi esagoni, vedi …»: il primo visto e non occupato diventa l’indicato."""
    return {"op": "lista_vista", "hexes": hexes, "ok": [see(dest)]}


def adv_pc(g):
    return {"op": "adv_pc", "g": g}


def chain(*items, last=None):
    """Elenco numerato: si esegue la prima voce la cui condizione è vera."""
    out = last or []
    for test, then in reversed(items):
        out = [if_(test, then, out)]
    return out


def dado_pari(pari, dispari):
    return {"op": "die", "b": [[0, 0, pari], [1, 1, dispari], [2, 2, pari], [3, 3, dispari], [4, 4, pari],
                               [5, 5, dispari], [6, 6, pari], [7, 7, dispari], [8, 8, pari], [9, 9, dispari]]}


par("040", "Il soldato è bersagliato da un tedesco invisibile (i Round non iniziano). Quando tutti sono atterrati si passa alla Condizione 3 invece che alla 2. Si risolve un tiro rapido a lunga gittata con un fucile a otturatore, abilità 0; il paracadutista conta come accovacciato in terreno scoperto.",
    [{"op": "tiro_invisibile"}])
par("047", "[s4] Attiva il tedesco 51 nell’esagono J13, accovacciato. Iniziano i Round. Vantaggio tedesco.",
    sighting(4) + [activate([(51, "J13")], "crouching", adv="de")])
par("051", "Se un soldato americano attivo vede uno di questi esagoni, vai al 582: 1. D17; 2. L10; 3. L12; 4. G10.",
    [vista(["D17", "L10", "L12", "G10"], "582")])
par("057", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 555;\n• se fallisce, vedi 625.", [act(1, [see("555")], [see("625")])])
par("063", "Effettua un controllo di percezione (−1). Se riesce, vedi 633.", [pc(-1, [see("633")])])
par("065", "Effettua un controllo di percezione (+1):\n• se riesce, vedi 744;\n• se fallisce, vedi 586.", [pc(1, [see("744")], [see("586")])])
par("066", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 496;\n• se fallisce, vedi 568.", [act(1, [see("496")], [see("568")])])
par("069", "[s2] Attiva il tedesco 6 al piano superiore dell’esagono S13, accovacciato. Iniziano i Round. Vantaggio americano. Tutti i soldati americani che vedono S13 sono automaticamente consapevoli.",
    sighting(2) + [activate([(6, "S13")], "crouching", adv="us"), {"op": "consapevoli_vede", "hex": "S13"}, {"op": "al_piano", "g": [6]}])
par("073", "[s8] Attiva il tedesco 62 nel primo esagono dell’elenco visto dagli americani e non occupato da un americano attivo. Iniziano i Round. Vantaggio tedesco.",
    sighting(8) + [activate([(62, "@indicato")], "crouching", adv="de")])
par("077", "1. Se non c’è stato s5, vedi 497.\n2. Se non c’è stato s7, vedi 631.\n3. Se non c’è stato s8, vedi 988.\n4. Se non c’è stato s2, vedi 069.\n5. Passa alla Condizione 4.",
    chain((NOT(S(5)), [see("497")]), (NOT(S(7)), [see("631")]), (NOT(S(8)), [see("988")]), (NOT(S(2)), [see("069")]), last=[cond(4)]))
par("079", "1. Se non ci sono stati né s5 né s7, vedi 579.\n2. Se c’è stato s5, vedi 631.\n3. Se c’è stato s7, vedi 497.\n4. Se ci sono stati s5 e s7, nessun evento.",
    chain((ALL(NOT(S(5)), NOT(S(7))), [see("579")]), (ALL(S(5), NOT(S(7))), [see("631")]), (ALL(S(7), NOT(S(5))), [see("497")])))
par("081", "1. Se il ponte in G14 è intatto, entra in F14.\n2. Se il ponte in G13 è intatto, entra in F13.\n3. Se sono saltati entrambi, entra in F14.",
    [if_({"bridge_intact": "G14"}, [enter("F14")], [if_({"bridge_intact": "G13"}, [enter("F13")], [enter("F14")])])], "movimento")
par("083", "1. Se non c’è stato s1, vedi 573.\n2. Se non c’è stato s2, vedi 069.\n3. Se non c’è stato s3, vedi 559.\n4. Se non c’è stato s8, tira un dado: pari 988, dispari 738.\n5. Nessun evento.",
    chain((NOT(S(1)), [see("573")]), (NOT(S(2)), [see("069")]), (NOT(S(3)), [see("559")]), (NOT(S(8)), [dado_pari([see("988")], [see("738")])])))
par("086", "Un razzo illuminante! Tira un dado per la colonna (1 = A … 9 = I, 0 = J) e un altro, più 10, per la riga. Il razzo illumina l’esagono colpito e tutti quelli entro 3 esagoni: chi ha una linea di vista libera li vede anche oltre i 5 esagoni della notte.",
    [{"op": "razzo_illuminante"}])
par("087", "• Se c’è stato s5, vedi 006.\n• Altrimenti vedi 637.", [if_(S(5), [see("006")], [see("637")])])
par("088", "Metti un segnalino Evento. Effettua un controllo di percezione (−2). Se riesce, vedi 741.",
    [{"op": "event_marker"}, pc(-2, [see("741")])])
par("089", "Se un soldato americano attivo vede l’esagono S9, vedi 589.", [if_({"see_hex": "S9"}, [see("589")])])
par("097", "• Se il soldato americano 06 non è ancora entrato, entra in A5, accovacciato: è l’unico sopravvissuto dell’aliante schiantato fuori mappa.\n• Se è già entrato, nessun effetto.",
    [{"op": "sopravvissuto_aliante"}])
par("098", "[s8] Attiva il tedesco 62 nel primo esagono dell’elenco visto dagli americani e non occupato da un americano attivo. Iniziano i Round. Vantaggio tedesco.",
    sighting(8) + [activate([(62, "@indicato")], "crouching", adv="de")])
par("099", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 586;\n• se fallisce, effettua un controllo di percezione (+1): se riesce, vedi 744.",
    [act(1, [see("586")], [pc(1, [see("744")])])])
par("133", "Il soldato trova documenti importanti. Guadagni 1 PV (nella Missione 5 vale solo se li porta fuori mappa).", [{"op": "documenti", "n": 1}])
par("460", "Serve s7: passa alla Condizione 3.", [if_(S(7), [cond(3)])])
par("467", "Se si muove un soldato (non la cassa), tira un dado: 0–8 nessun effetto; 9 vedi 040.",
    [{"op": "die", "b": [[0, 8, []], [9, 9, [see("040")]]]}])
par("468", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 047;\n• se fallisce, vedi 551.", [act(1, [see("047")], [see("551")])])
par("469", "Il soldato sente la voce sensuale di Marlene Dietrich che canta «Lili Marleen»: viene dall’edificio accanto.", [])
par("474", "• Se si muove un veicolo, entra in L4.\n• Se si muove un soldato, metti in effetto per lui la reazione speciale J. Se non c’è stato s0, segna s0 e metti in questo esagono il segnaposto della Kübelwagen.",
    [if_({"vehicle_moving": True}, [enter("L4")],
         [reaz("J"), if_(NOT(S(0)), sighting(0) + [{"op": "landmark", "hex": "@hex", "name": "kubelwagen"}])])], "movimento")
par("476", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 560;\n• se fallisce, vedi 488.", [act(1, [see("560")], [see("488")])])
par("488", "Effettua un controllo di percezione (+1):\n• se riesce, vedi 703;\n• se fallisce, vedi 560.", [pc(1, [see("703")], [see("560")])])
par("489", "• Se il ponte in G14 è saltato, entra in F15.\n• Altrimenti entra in G14.",
    [if_({"bridge_intact": "G14"}, [enter("G14")], [enter("F15")])], "movimento")
par("496", "[s2] Attiva il tedesco 6 al piano superiore dell’esagono S13, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 6 riceve 2 turni in questo Round.",
    sighting(2) + [activate([(6, "S13")], "crouching", adv="de", two=[6]), {"op": "al_piano", "g": [6]}])
par("497", "Effettua un controllo di attivazione:\n• se riesce, vedi 590;\n• se fallisce, vedi 637.", [act(0, [see("590")], [see("637")])])
par("498", "Effettua un controllo di percezione. Se riesce, vedi 133.", [pc(0, [see("133")])])
par("551", "Effettua un controllo di percezione (−1):\n• se riesce, vedi 620;\n• se fallisce, vedi 701.", [pc(-1, [see("620")], [see("701")])])
par("555", "[s3] Attiva il tedesco 16 nell’esagono G5, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 16 riceve 2 turni in questo Round.",
    sighting(3) + [activate([(16, "G5")], "crouching", adv="de", two=[16])])
par("556", "Artiglieria! Tira un dado per la colonna (1 = A … 9 = I, 0 = J) e un altro, più 10, per la riga. Nell’esagono colpito metti un cratere: tutti i soldati presenti, anche tedeschi, muoiono.",
    [{"op": "artiglieria_dadi"}])
par("559", "[s3] Attiva il tedesco 16 nell’esagono G5, accovacciato. Iniziano i Round. Vantaggio americano. Tutti i soldati americani che vedono G5 sono automaticamente consapevoli.",
    sighting(3) + [activate([(16, "G5")], "crouching", adv="us"), {"op": "consapevoli_vede", "hex": "G5"}])
par("560", "[s1] Attiva il tedesco 17 nell’esagono U5, accovacciato. Iniziano i Round. Vantaggio tedesco.",
    sighting(1) + [activate([(17, "U5")], "crouching", adv="de")])
par("564", "• Se il ponte in G13 è saltato, entra in F14.\n• Altrimenti entra in G13.",
    [if_({"bridge_intact": "G13"}, [enter("G13")], [enter("F14")])], "movimento")
par("567", "Metti in effetto per questo tedesco la reazione speciale F.", [reaz("F")], "movimento")
par("568", "Effettua un controllo di percezione (−1):\n• se riesce, vedi 069;\n• se fallisce, vedi 496.", [pc(-1, [see("069")], [see("496")])])
par("569", "[s1] Attiva il tedesco 17 nell’esagono O6, accovacciato. Iniziano i Round.",
    sighting(1) + [activate([(17, "O6")], "crouching")])
par("573", "Effettua un controllo di attivazione (+1). Se riesce, vedi 569.", [act(1, [see("569")])])
par("576", "• Se si muove un tedesco con numero 50 o superiore, entra in M10.\n• Se 49 o inferiore, entra in N10.",
    [if_({"g_ge": 50}, [enter("M10")], [enter("N10")])], "movimento")
par("579", "Effettua un controllo di attivazione (+1): se riesce, vedi 583. Se fallisce, effettua un controllo di percezione (−1): se riesce, vedi 632.",
    [act(1, [see("583")], [pc(-1, [see("632")])])])
par("582", "[s9] Attiva il tedesco 84 nel primo esagono dell’elenco visto dagli americani e non occupato da un americano attivo. Iniziano i Round. Vantaggio tedesco.",
    sighting(9) + [activate([(84, "@indicato")], "crouching", adv="de")])
par("583", "[s5 e s7] Attiva i tedeschi 63 e 83 nell’esagono M6, accovacciati, e il tedesco 93 in N9, accovacciato. Iniziano i Round. Vantaggio tedesco.",
    sighting(5, 7) + [activate([(63, "M6"), (83, "M6"), (93, "N9")], "crouching", adv="de")])
par("584", "Il soldato americano con la percezione più alta che vede S13 fa un controllo di percezione. Se riesce, vedi 980.",
    [{"op": "best_pc", "hex": "S13", "mod": 0, "ok": [see("980")]}])
par("585", "Effettua un controllo di percezione:\n• se riesce, vedi 633;\n• se fallisce, vedi 084.", [pc(0, [see("633")], [see("084")])])
par("586", "[s2] Attiva il tedesco 6 nell’esagono V15, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 6 riceve 2 turni in questo Round.",
    sighting(2) + [activate([(6, "V15")], "crouching", adv="de", two=[6])])
par("587", "Effettua un controllo di percezione (+1):\n• se riesce, vedi 744;\n• se fallisce, vedi 099.", [pc(1, [see("744")], [see("099")])])
par("588", "Se sono già stati attivati dei tedeschi, passa alla Condizione 3.", [if_({"tedeschi_attivati": True}, [cond(3)])])
par("589", "[s1] Attiva il tedesco 17 nell’esagono S9, accovacciato. Iniziano i Round. Se è in vigore la Condizione 2, passa alla 3; se la 3, passa alla 4. Il tedesco 17 fa un controllo di percezione: se riesce, vantaggio tedesco; altrimenti vantaggio americano. Tutti i soldati americani attivi che vedono S9 sono automaticamente consapevoli.",
    sighting(1) + [adv_pc(17), activate([(17, "S9")], "crouching", adv="pc"), {"op": "consapevoli_vede", "hex": "S9"},
                   if_({"cond_in": [2]}, [cond(3)], [if_({"cond_in": [3]}, [cond(4)])])])
par("590", "[s5] Attiva i tedeschi 63 e 83 nell’esagono M6, accovacciati. Iniziano i Round. Vantaggio tedesco.",
    sighting(5) + [activate([(63, "M6"), (83, "M6")], "crouching", adv="de")])
par("591", "[s2] Attiva il tedesco 6 nell’esagono L14, accovacciato. Il tedesco 6 fa un controllo di percezione: se riesce, vantaggio tedesco; altrimenti vantaggio americano.",
    sighting(2) + [adv_pc(6), activate([(6, "L14")], "crouching", adv="pc")])
par("592", "• Se non vedi americani attivi, entra in Q14.\n• Se ne vedi, entra in Q15.",
    [if_({"g_vede_us": True}, [enter("Q15")], [enter("Q14")])], "movimento")
par("593", "1. Se non ci sono stati né s5 né s7, vedi 632.\n2. Se non c’è stato s5, vedi 637.\n3. Se non c’è stato s7, vedi 633.\n4. Se ci sono stati s5 e s7, passa alla Condizione 4.",
    chain((ALL(NOT(S(5)), NOT(S(7))), [see("632")]), (NOT(S(5)), [see("637")]), (NOT(S(7)), [see("633")]), last=[cond(4)]))
par("595", "Serve s6: vedi 097.", [if_(S(6), [see("097")])])
par("599", "Se un soldato americano attivo vede uno di questi esagoni, vedi 582: 1. K15; 2. G17; 3. E11; 4. B12.",
    [vista(["K15", "G17", "E11", "B12"], "582")])
par("620", "[s4] Attiva il tedesco 51 nell’esagono J13, in piedi. Iniziano i Round. Vantaggio americano. Tutti i soldati americani consapevoli che non cadono nel panico ricevono 2 turni in questo Round.",
    sighting(4) + [activate([(51, "J13")], "standing", adv="us", us_two=True)])
par("624", "Metti in effetto per questo tedesco la reazione speciale X, per il resto della missione salvo diversa indicazione. Si usa comunque la colonna di autoconservazione quando un americano è adiacente o nello stesso esagono; se quella colonna rimanda alla Condizione, si torna alla reazione X.",
    [reaz("X")], "movimento")
par("625", "Effettua un controllo di percezione (+1):\n• se riesce, vedi 559;\n• se fallisce, vedi 555.", [pc(1, [see("559")], [see("555")])])
par("627", "Effettua un controllo di attivazione (−2):\n• se riesce, vedi 496;\n• se fallisce, vedi 568.", [act(-2, [see("496")], [see("568")])])
par("628", "• Se si muove un veicolo, entra in F5.\n• Se si muove un tedesco con numero 49 o inferiore, entra in H6.\n• Se 50 o superiore, entra in F5.",
    [if_({"vehicle_moving": True}, [enter("F5")], [if_({"g_le": 49}, [enter("H6")], [enter("F5")])])], "movimento")
par("632", "[s5 e s7] Attiva i tedeschi 63 e 83 nell’esagono M6, accovacciati, e il tedesco 93 in N9, accovacciato. Iniziano i Round. Vantaggio americano.",
    sighting(5, 7) + [activate([(63, "M6"), (83, "M6"), (93, "N9")], "crouching", adv="us")])
par("637", "[s5] Attiva i tedeschi 63 e 83 nell’esagono M6, accovacciati. Iniziano i Round. Vantaggio americano.",
    sighting(5) + [activate([(63, "M6"), (83, "M6")], "crouching", adv="us")])
par("701", "Effettua un controllo di attivazione (−1). Se riesce, vedi 047.", [act(-1, [see("047")])])
par("703", "[s1] Attiva il tedesco 17 nell’esagono U5, accovacciato. Iniziano i Round. Vantaggio americano.",
    sighting(1) + [activate([(17, "U5")], "crouching", adv="us")])
par("707", "Metti in effetto per questo tedesco la reazione speciale Y: ignora l’autoconservazione finché è in vigore. Inoltre, se è in vigore la Condizione 2 o 3, passa alla Condizione 4.",
    [reaz("Y"), {"op": "no_autoconservazione"}, if_({"cond_in": [2, 3]}, [cond(4)])], "movimento")
par("720", "• Se si muove un veicolo, entra in G6.\n• Se si muove un tedesco con numero 49 o inferiore, entra in I7.\n• Se 50 o superiore, entra in G6.",
    [if_({"vehicle_moving": True}, [enter("G6")], [if_({"g_le": 49}, [enter("I7")], [enter("G6")])])], "movimento")
par("724", "Il razzo illuminante si spegne: togli un razzo dalla mappa (a caso, se ce n’è più d’uno).", [{"op": "spegni_razzo"}])
par("738", "Se un soldato americano attivo vede uno di questi esagoni, vedi 098: 1. G10; 2. L12; 3. L10; 4. D17.",
    [vista(["G10", "L12", "L10", "D17"], "098")])
par("741", "[s0] Il soldato vede una Kübelwagen mimetizzata nell’esagono M4. Metti un segnaposto.",
    sighting(0) + [{"op": "landmark", "hex": "M4", "name": "kubelwagen"}])
par("743", "Effettua un controllo di percezione:\n• se riesce, vedi 637;\n• se fallisce, vedi 497.", [pc(0, [see("637")], [see("497")])])
par("744", "[s2] Attiva il tedesco 6 nell’esagono V15, in piedi. Iniziano i Round. Vantaggio americano. Tutti i soldati americani che vedono V15 sono automaticamente consapevoli.",
    sighting(2) + [activate([(6, "V15")], "standing", adv="us"), {"op": "consapevoli_vede", "hex": "V15"}])
par("745", "[s6] Un aliante americano passa basso da est a ovest. I tuoi soldati lo vedono sparire e, pochi secondi dopo, sentono lo schianto mentre scivola nel bosco fuori mappa.", sighting(6))
par("746", "[s3] Attiva il tedesco 16 nell’esagono G5, accovacciato. Iniziano i Round. Passa alla Condizione 3.",
    sighting(3) + [activate([(16, "G5")], "crouching"), cond(3)])
par("747", "[s2] Attiva il tedesco 6 nell’esagono J15, accovacciato. Il tedesco 6 fa un controllo di percezione: se riesce, vantaggio tedesco; altrimenti vantaggio americano.",
    sighting(2) + [adv_pc(6), activate([(6, "J15")], "crouching", adv="pc")])
par("748", "• Se non vedi americani attivi, entra in O7.\n• Se ne vedi, entra in P5.",
    [if_({"g_vede_us": True}, [enter("P5")], [enter("O7")])], "movimento")
par("749", "Il soldato americano con la percezione più alta che vede S13 fa un controllo di percezione. Se riesce, vedi 069.",
    [{"op": "best_pc", "hex": "S13", "mod": 0, "ok": [see("069")]}])
par("886", "1. Se non c’è stato s6, vedi 745.\n2. Se non c’è stato s8, tira un dado: pari 988, dispari 738.\n3. Se non c’è stato s9, tira un dado: pari 051, dispari 599.\n4. Se c’è stato s6, vedi 097.\n5. Nessun evento.",
    chain((NOT(S(6)), [see("745")]), (NOT(S(8)), [dado_pari([see("988")], [see("738")])]),
          (NOT(S(9)), [dado_pari([see("051")], [see("599")])]), (S(6), [see("097")])))
par("933", "• Se vedi un americano attivo, entra in U4.\n• Altrimenti entra in T5.",
    [if_({"g_vede_us": True}, [enter("U4")], [enter("T5")])], "movimento")
par("976", "• Se vedi un americano attivo, entra in J9.\n• Altrimenti entra in H9.",
    [if_({"g_vede_us": True}, [enter("J9")], [enter("H9")])], "movimento")
par("979", "Se nessun soldato americano attivo vede l’esagono G5, vedi 746.", [if_(NOT({"see_hex": "G5"}), [see("746")])])
par("980", "Il soldato si è sbagliato: non vede niente.", [])
par("981", "Serve s5: passa alla Condizione 3.", [if_(S(5), [cond(3)])])
par("985", "Un soldato americano incapacitato nel lancio, scelto a caso, muore per le ferite. Succede una sola volta per missione.",
    [{"op": "morte_lancio"}])
par("987", "1. Se un americano attivo vede L14 e L14 non è occupato da americani, vedi 591.\n2. Se un americano attivo vede J15 e J15 non è occupato da americani, vedi 747.\n3. Nessun effetto.",
    chain((ALL({"see_hex": "L14"}, NOT({"us_in": "L14"})), [see("591")]), (ALL({"see_hex": "J15"}, NOT({"us_in": "J15"})), [see("747")])))
par("988", "Se un soldato americano attivo vede uno di questi esagoni, vedi 073: 1. B12; 2. E11; 3. G17; 4. K15.",
    [vista(["B12", "E11", "G17", "K15"], "073")])

par("056", "Esci dalla mappa. Passa alla Condizione 6.", [{"op": "g_exit"}, cond(6)], "movimento")
par("594", "1. Se non ci sono stati né s5 né s7, vedi 632.\n2. Se non c’è stato s5, vedi 637.\n3. Se non c’è stato s7, vedi 633.\n4. Se i tedeschi 63 e 83 sono inattivi, passa alla Condizione 5.\n5. Nessun evento.",
    chain((ALL(NOT(S(5)), NOT(S(7))), [see("632")]), (NOT(S(5)), [see("637")]), (NOT(S(7)), [see("633")]), ({"inattivi": [63, 83]}, [cond(5)])))
par("717", "1. Se non ci sono stati né s5 né s7, vedi 579.\n2. Se non c’è stato s1, vedi 569.\n3. Se non c’è stato s7, vedi 631.\n4. Se non c’è stato s5, vedi 497.\n5. Se ci sono stati s1, s5 e s7, nessun evento.",
    chain((ALL(NOT(S(5)), NOT(S(7))), [see("579")]), (NOT(S(1)), [see("569")]), (NOT(S(7)), [see("631")]), (NOT(S(5)), [see("497")])))
par("870", "1. Se non c’è stato s1, vedi 573.\n2. Se non c’è stato s2, vedi 069.\n3. Se non c’è stato s3, vedi 559.\n4. Se non c’è stato s8, tira un dado: pari 988, dispari 738.\n5. Se i tedeschi 63 e 83 sono inattivi, passa alla Condizione 5.\n6. Nessun evento.",
    chain((NOT(S(1)), [see("573")]), (NOT(S(2)), [see("069")]), (NOT(S(3)), [see("559")]), (NOT(S(8)), [dado_pari([see("988")], [see("738")])]),
          ({"inattivi": [63, 83]}, [cond(5)])))

AZ = {
"050": "Passa alla Condizione 4, poi vedi 868.",
"055": "• Se il veicolo è attivo, guidalo veloce.\n• Altrimenti metti in effetto la reazione speciale U e tira di nuovo per questa azione, eseguendola subito.",
"470": "1. Se la Kübelwagen è fuori uso o controllata dagli americani, metti in effetto la reazione speciale U ed entra in L4 come primo esagono di movimento.\n2. Se non sei sulla Kübelwagen, sali a bordo.\n3. Se sei a bordo e i tedeschi 63 e 83 sono entrambi attivi e a bordo, reazione speciale Q per entrambi e tira di nuovo per questa azione.\n4. Se il 63 è a bordo e l’83 è inattivo, reazione speciale T per il 63 e tira di nuovo.\n5. Se l’83 è a bordo e il 63 è inattivo, reazione speciale Q per l’83 e tira di nuovo.\n6. Accovacciati e spara di rapido al maggior numero possibile di bersagli, dal più vicino e poi dal più facile.",
"554": "• Se sei su un veicolo attivo e l’autista è attivo, esegui il miglior tiro contro il bersaglio più facile.\n• Se l’autista è inattivo, metti in effetto la reazione speciale T, ma in questo turno non agisci.\n• Se il veicolo è fuori uso, reazione speciale U e tira di nuovo per questa azione.",
"708": "• Se è in vigore la Condizione 4, 5 o 6, togli la reazione speciale F e torna alla Condizione in vigore.\n• Se è in vigore la Condizione 3, vedi 802.",
"711": "• Se nel tuo esagono ci sono 2 o più americani attivi, arrenditi.\n• Altrimenti alzati ed esegui il miglior tiro contro il bersaglio più vicino. Sdraiati prono se ti resta il cambio di postura gratuito.",
"712": "• Se un tedesco attivo è nel tuo esagono o in uno adiacente, accovacciati e cedi un turno al tedesco con meno turni (a parità, a quello con l’abilità più alta). Se tutti hanno già due turni, sdraiati prono.\n• Altrimenti esegui 801.",
"856": "• Se sei in un edificio, alzati ed esegui il miglior tiro contro il bersaglio più facile; altrimenti accovacciati e fai lo stesso. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito.",
"857": "• Se sei in un edificio, alzati ed esegui il miglior tiro contro il bersaglio più vicino; altrimenti accovacciati e fai lo stesso. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito.",
"859": "• Se nel tuo esagono c’è un americano attivo, assaltalo per uccidere.\n• Altrimenti, se sei in un edificio, alzati ed esegui il miglior tiro contro il più vicino (poi prono se ti resta il cambio gratuito); fuori da un edificio accovacciati e fai lo stesso.",
"865": "• Se non vedi bersagli attivi, muoviti il più rapidamente possibile.\n• Se ne vedi 1 o 2, accovacciati ed esegui il miglior tiro contro il più vicino.\n• Se ne vedi 3 o più, sdraiati prono.",
"866": "• Se non vedi bersagli attivi, muoviti il più rapidamente possibile.\n• Se ne vedi 1 o 2, muoviti il più rapidamente possibile e sdraiati prono nel primo esagono non scoperto (o nell’ultimo).\n• Se ne vedi 3 o più, accovacciati e spara di rapido al maggior numero possibile di bersagli.",
"868": "Muoviti il più rapidamente possibile. Alla fine sdraiati prono se ti resta il cambio di postura gratuito e vedi un americano attivo.",
}
for _k, _v in AZ.items():
    par(_k, _v, [], "azione")

for k in list(P):
    if k in P1 or k in P2 or k in P3:
        del P[k]
