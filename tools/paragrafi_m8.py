# -*- coding: utf-8 -*-
"""Paragrafi della Missione 8 «Corsa verso la Sambre» (mappa A, nord in alto, lo Sherman americano, il ponte minato)."""
from paragrafi_m1 import pc, act, see, if_, S, NOT, ALL, sighting, activate, cond, P as P1
from paragrafi_m2 import P as P2
from paragrafi_m3 import P as P3
from paragrafi_m4 import P as P4, chain
from paragrafi_m5 import P as P5, dado
from paragrafi_m6 import P as P6
from paragrafi_m7 import P as P7

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def enter(h):
    return {"op": "g_enter", "hex": h}


def best(h, mod, dest):
    return {"op": "best_pc", "hex": h, "mod": mod, "ok": [see(dest)]}


def act_terreno(mod_si, mod_no, tipi, ok, ko=None):
    return {"op": "act_terreno", "si": mod_si, "no": mod_no, "tipi": tipi, "ok": ok, "ko": ko or []}


def mortaio(pid, esagoni):
    righe = "\n".join(f"{i}: esagono {h}" for i, h in enumerate(esagoni))
    par(pid, "Un colpo di mortaio tedesco! Tira un dado per l’esagono colpito:\n" + righe +
        "\nIn un esagono non di edificio metti un cratere; un edificio colpito diventa macerie. Tutti i soldati nell’esagono muoiono e i veicoli sono distrutti.",
        [{"op": "artiglieria_esagoni", "esagoni": esagoni}])


SHERMAN = {"sherman_in_mappa": True}
AUTO = {"op": "forza_consapevole"}

mortaio("208", ["L11", "K11", "J10", "I10", "H9", "G9", "F8", "E8", "D7", "C7"])
mortaio("508", ["L11", "K10", "I9", "G8", "E7", "C6", "A6", "K11", "J10", "I10"])
mortaio("659", ["B6", "L10", "K12", "I11", "G10", "E9", "C8", "A8", "L11", "H9"])
par("200", "Effettua un controllo di attivazione (+1). Se riesce, vedi 651.", [act(1, [see("651")])])
par("201", "[s5] Attiva i tedeschi 32 e 47 nell’esagono M10, accovacciati, con una mitragliatrice media pronta. Iniziano i Round. Passa alla Condizione 2.",
    sighting(5) + [activate([(32, "M10"), (47, "M10")], "crouching"), cond(2)])
par("202", "Tira un dado:\n0–4: controllo di attivazione; se riesce, vedi 355.\n5–7: nessun evento.\n8: controllo di percezione; se riesce, vedi 653.\n9: controllo di percezione; se riesce, vedi 502.",
    [dado((0, 4, [act(0, [see("355")])]), (5, 7, []), (8, 8, [pc(0, [see("653")])]), (9, 9, [pc(0, [see("502")])]))])
par("203", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 355;\n• se fallisce, vedi 503.", [act(1, [see("355")], [see("503")])])
par("205", "[s5] Attiva i tedeschi 32 e 47 nell’esagono M10, accovacciati, con una mitragliatrice media pronta. Iniziano i Round. Vantaggio americano. Il soldato che ha appena fatto il controllo di percezione è automaticamente consapevole; i consapevoli che non cadono nel panico ricevono 2 turni. Passa alla Condizione 2.",
    sighting(5) + [activate([(32, "M10"), (47, "M10")], "crouching", adv="us", us_two=True, aware=True), cond(2)])
par("206", "Il soldato nota un movimento tra gli alberi appena oltre il fiume, in M10.", [])
par("207", "Il soldato nota un luccichio di metallo tra gli alberi oltre il fiume, in K4.", [])
par("209", "Se c’è un carro americano sulla mappa, vedi 659. Altrimenti nessun evento.", [if_(SHERMAN, [see("659")])])
par("210", "Se un soldato americano vede l’esagono S12, vedi 363.", [if_({"see_hex": "S12"}, [see("363")])])
par("211", "Effettua un controllo di attivazione (+1 in terreno libero, −1 altrimenti):\n• se riesce, vedi 518;\n• se fallisce, vedi 511.",
    [act_terreno(1, -1, ["clear"], [see("518")], [see("511")])])
par("212", "[s6] Attiva il tedesco 14 nell’esagono K13, accovacciato. Iniziano i Round. Vantaggio tedesco. Passa alla Condizione 3.",
    sighting(6) + [activate([(14, "K13")], "crouching", adv="de"), cond(3)])
par("213", "Effettua un controllo di percezione (−1):\n• se riesce, vedi 366;\n• se fallisce, vedi 513.", [pc(-1, [see("366")], [see("513")])])
par("214", "Effettua un controllo di percezione:\n• se riesce, vedi 367;\n• se fallisce, vedi 514.", [pc(0, [see("367")], [see("514")])])
par("215", "[s3] Attiva il tedesco 56 nell’esagono K4, accovacciato. Iniziano i Round. Vantaggio americano. Il soldato che ha appena fatto il controllo di percezione è automaticamente consapevole; i consapevoli che non cadono nel panico ricevono 2 turni.",
    sighting(3) + [activate([(56, "K4")], "crouching", adv="us", us_two=True, aware=True)])
par("216", "• Se non ci sono stati né s5 né s4, vedi 353.\n• Se c’è stato s5 ma non s4, vedi 664.\n• Se non c’è stato s5 ma s4 sì, vedi 353.\n• Se ci sono stati s5 e s4, nessun evento.",
    chain((NOT(S(5)), [see("353")]), (NOT(S(4)), [see("664")])))
par("217", "Effettua un controllo di percezione (−1): se riesce, metti un segnalino Evento e vedi 660; se fallisce, metti un segnalino Evento e vedi 663.",
    [{"op": "event_marker"}, pc(-1, [see("660")], [see("663")])])
par("218", "Passa alla Condizione 3.", [cond(3)])
par("219", "[s8] Il soldato scopre che il fiume si può guadare in N18. Metti un segnalino Guado.", sighting(8) + [{"op": "guado", "hexes": ["N18"]}])
par("220", "Se vale una di queste: un carro americano è in questo esagono; un soldato americano qui è in vista di un tedesco attivo; non c’è stato s6 — vedi 373.",
    [if_({"m8_220": True}, [see("373")])])
par("221", "Il tuo soldato ha disinnescato le cariche del ponte. Guadagni 5 PV. Passa alla Condizione 5.",
    [{"op": "ponte_disinnescato"}, {"op": "vp", "n": 5, "why": "cariche del ponte disinnescate"}, cond(5)])
par("222", "Effettua un controllo di attivazione (−1 nel bosco, +2 altrimenti):\n• se riesce, vedi 213;\n• se fallisce, vedi 375.",
    [act_terreno(-1, 2, ["woods"], [see("213")], [see("375")])])
par("223", "[s4] Attiva il tedesco 45 nell’esagono T8, accovacciato. Iniziano i Round. Vantaggio americano.",
    sighting(4) + [activate([(45, "T8")], "crouching", adv="us")])
par("224", "Effettua un controllo di attivazione (+1). Se riesce, vedi 524.", [act(1, [see("524")])])
par("225", "Il soldato vede un detonatore con i fili che portano al ponte. Disinnescarlo costa un’azione nei Round (bottone «Disinnesca il detonatore»): poi vedi 221.",
    [{"op": "scelta_attiva", "par": "221", "testo": "Disinnesca il detonatore del ponte"}])
par("226", "Tira un dado:\n0–4: controllo di attivazione; se riesce, vedi 673.\n5–8: nessun evento.\n9: controllo di percezione (+1); se riesce, vedi 223.",
    [dado((0, 4, [act(0, [see("673")])]), (5, 8, []), (9, 9, [pc(1, [see("223")])]))])
par("227", "• Se si muove un tedesco con numero 12 o inferiore, entra in O17.\n• Se 13 o superiore, entra in P17.",
    [if_({"g_le": 12}, [enter("O17")], [enter("P17")])], "movimento")
par("228", "Attiva il tedesco 3 e/o l’11 in O16 (quelli tolti dalla mappa con un movimento evasivo). Iniziano i Round.",
    [{"op": "riattiva_evasi", "g": [3, 11], "hex": "O16"}])
par("353", "Effettua un controllo di attivazione. Se riesce, vedi 651.", [act(0, [see("651")])])
par("354", "[s5] Attiva i tedeschi 32 e 47 nell’esagono M10, accovacciati, con una mitragliatrice media. Iniziano i Round. Vantaggio tedesco. Entrambi ricevono 2 turni in questo Round. Passa alla Condizione 2.",
    sighting(5) + [activate([(32, "M10"), (47, "M10")], "crouching", adv="de", two=[32, 47]), cond(2)])
par("355", "[s2] Attiva il tedesco 3 in E13 e l’11 in F12, accovacciati. Iniziano i Round. Vantaggio tedesco. Entrambi ricevono 2 turni in questo Round. Passa alla Condizione 2.",
    sighting(2) + [activate([(3, "E13"), (11, "F12")], "crouching", adv="de", two=[3, 11]), cond(2)])
par("356", "Effettua un controllo di attivazione (−1). Se riesce, vedi 355.", [act(-1, [see("355")])])
par("357", "Effettua un controllo di attivazione (−1):\n• se riesce, vedi 355;\n• se fallisce, vedi 503.", [act(-1, [see("355")], [see("503")])])
par("358", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 651;\n• se fallisce, vedi 655.", [act(1, [see("651")], [see("655")])])
par("359", "Tira un dado:\n0–5: controllo di attivazione (+1); se riesce, vedi 652.\n6–8: nessun evento.\n9: controllo di percezione; se riesce, vedi 206.",
    [dado((0, 5, [act(1, [see("652")])]), (6, 8, []), (9, 9, [pc(0, [see("206")])]))])
par("360", "Il soldato crede di vedere un elmetto muoversi tra gli alberi oltre il fiume, in M7.", [])
par("361", "Se c’è un carro americano sulla mappa, vedi 508. Altrimenti nessun evento.", [if_(SHERMAN, [see("508")])])
par("362", "[s7] È arrivato lo Sherman! Usa la carta americana 04. Nelle Operazioni puoi farlo entrare subito in A6; nei Round dal Round successivo. Puoi anche ritardarne l’ingresso (bottone «Fai entrare lo Sherman in A6»).",
    sighting(7) + [{"op": "sherman_disponibile"}])
par("363", "[s0] Il soldato vede un blocco stradale di tronchi e rottami in S11 e S12. Metti i segnalini.",
    sighting(0) + [{"op": "blocco", "hexes": ["S11", "S12"]}])
par("364", "[s6] Attiva il tedesco 14 nell’esagono K13, accovacciato. Iniziano i Round. Vantaggio tedesco. Riceve 2 turni in questo Round. Passa alla Condizione 3.",
    sighting(6) + [activate([(14, "K13")], "crouching", adv="de", two=[14]), cond(3)])
par("365", "Effettua un controllo di percezione: se riesce, vedi 660; se fallisce, metti un segnalino Evento.",
    [pc(0, [see("660")], [{"op": "event_marker"}])])
par("366", "[s3] Attiva il tedesco 56 nell’esagono K4, accovacciato. Iniziano i Round.", sighting(3) + [activate([(56, "K4")], "crouching")])
par("367", "[s4] Attiva il tedesco 45 nell’esagono M6, accovacciato. Iniziano i Round.", sighting(4) + [activate([(45, "M6")], "crouching")])
par("368", "Tira un dado:\n0–4: controllo di attivazione; se riesce, vedi 214.\n5–8: nessun evento.\n9: controllo di percezione; se riesce, vedi 515.",
    [dado((0, 4, [act(0, [see("214")])]), (5, 8, []), (9, 9, [pc(0, [see("515")])]))])
par("369", "• Se non ci sono stati né s5 né s3, vedi 667.\n• Se c’è stato s5 ma non s3, vedi 665.\n• Se c’è stato s3 ma non s5, vedi 667.\n• Se ci sono stati entrambi, nessun evento.",
    chain((NOT(S(5)), [see("667")]), (NOT(S(3)), [see("665")])))
par("370", "Passa alla Condizione 3. Se non c’è stato s5, vedi 504.", [cond(3), if_(NOT(S(5)), [see("504")])])
par("371", "Tira un dado:\n0–4: controllo di attivazione; se riesce, vedi 218.\n5–8: nessun evento.\n9: controllo di percezione (+1); se riesce, vedi 662.",
    [dado((0, 4, [act(0, [see("218")])]), (5, 8, []), (9, 9, [pc(1, [see("662")])]))])
par("372", "Un soldato americano che vede S13 fa un controllo di percezione. Se riesce, vedi 519.", [best("S13", 0, "519")])
par("373", "Il ponte in M12 salta in aria. Chi è nell’esagono subisce i danni di un fucile automatico; chi sopravvive va in L11 o N12. Passa alla Condizione 4.",
    [{"op": "ponte_salta_m8"}, cond(4)])
par("374", "Effettua un controllo di percezione:\n• se riesce, vedi 221;\n• se fallisce, vedi 373.", [pc(0, [see("221")], [see("373")])])
par("375", "Effettua un controllo di percezione:\n• se riesce, vedi 215;\n• se fallisce, vedi 366.", [pc(0, [see("215")], [see("366")])])
par("376", "Effettua un controllo di attivazione (+2 in terreno libero, −1 altrimenti):\n• se riesce, vedi 523;\n• se fallisce, vedi 674.",
    [act_terreno(2, -1, ["clear"], [see("523")], [see("674")])])
par("377", "Tira un dado:\n0–5: controllo di attivazione; se riesce, vedi 524.\n6–8: nessun evento.\n9: controllo di percezione (+1); se riesce, vedi 675.",
    [dado((0, 5, [act(0, [see("524")])]), (6, 8, []), (9, 9, [pc(1, [see("675")])]))])
par("378", "Effettua un controllo di attivazione (+1). Se riesce, vedi 523.", [act(1, [see("523")])])
par("379", "Il soldato vede un mortaio tedesco abbandonato, senza munizioni.", [])
par("380", "Vai in S13 e togli a questo tedesco la reazione speciale B.", [enter("S13"), {"op": "g_reaction", "r": ""}], "movimento")
par("381", "Serve s6. Se il tedesco 14 è stato tolto dalla mappa con un movimento evasivo e un soldato americano vede S13, vedi 524.",
    [if_(ALL(S(6), {"evaded": 14}, {"see_hex": "S13"}), [see("524")])])
par("500", "Effettua un controllo di attivazione (+3). Se riesce, vedi 651.", [act(3, [see("651")])])
par("501", "Effettua un controllo di attivazione. Se riesce, vedi 652.", [act(0, [see("652")])])
par("502", "Attiva il tedesco 3 nell’esagono E13, in piedi. Iniziano i Round. Vantaggio americano. Il soldato che ha appena fatto il controllo di percezione è automaticamente consapevole.",
    [activate([(3, "E13")], "standing", adv="us", aware=True)])
par("503", "Il soldato fa un controllo di percezione:\n• se riesce, vedi 654;\n• se fallisce, vedi 655.", [pc(0, [see("654")], [see("655")])])
par("504", "Effettua un controllo di attivazione (+3):\n• se riesce, vedi 651;\n• se fallisce, vedi 655.", [act(3, [see("651")], [see("655")])])
par("505", "Effettua un controllo di attivazione:\n• se riesce, vedi 651;\n• se fallisce, passa alla Condizione 2.", [act(0, [see("651")], [cond(2)])])
par("506", "Tira un dado:\n0–5: controllo di attivazione; se riesce, vedi 651.\n6–8: nessun effetto.\n9: controllo di percezione (+2); se riesce, vedi 205.",
    [dado((0, 5, [act(0, [see("651")])]), (6, 8, []), (9, 9, [pc(2, [see("205")])]))])
par("507", "[s2] Attiva il tedesco 3 in E13 o l’11 in F12, quello che non è ancora stato attivato.",
    sighting(2) + [activate([(3, "E13"), (11, "F12")], "crouching")])
par("509", "Un soldato americano che vede J3 fa un controllo di percezione (−2). Se riesce, vedi 660.", [best("J3", -2, "660")])
par("510", "Tira un dado:\n0–5: controllo di attivazione (−1); se riesce, vedi 355.\n6–8: nessun evento.\n9: controllo di percezione; se riesce, vedi 654.",
    [dado((0, 5, [act(-1, [see("355")])]), (6, 8, []), (9, 9, [pc(0, [see("654")])]))])
par("511", "Effettua un controllo di percezione (−1):\n• se riesce, vedi 662;\n• se fallisce, vedi 212.", [pc(-1, [see("662")], [see("212")])])
par("512", "Passa alla Condizione 3. Se non c’è stato s1, vedi 660.", [cond(3), if_(NOT(S(1)), [see("660")])])
par("513", "[s3] Attiva il tedesco 56 nell’esagono K4, accovacciato. Iniziano i Round. Vantaggio tedesco. Riceve 2 turni in questo Round.",
    sighting(3) + [activate([(56, "K4")], "crouching", adv="de", two=[56])])
par("514", "[s4] Attiva il tedesco 45 nell’esagono M6, accovacciato. Iniziano i Round. Vantaggio tedesco. Riceve 2 turni in questo Round.",
    sighting(4) + [activate([(45, "M6")], "crouching", adv="de", two=[45])])
par("515", "[s4] Attiva il tedesco 45 nell’esagono M6, accovacciato. Iniziano i Round. Vantaggio americano. Il soldato che ha appena fatto il controllo di percezione è automaticamente consapevole; i consapevoli che non cadono nel panico ricevono 2 turni.",
    sighting(4) + [activate([(45, "M6")], "crouching", adv="us", us_two=True, aware=True)])
par("516", "Se c’è stato s3 e un soldato americano vede M6, vedi 664.", [if_(ALL(S(3), {"see_hex": "M6"}), [see("664")])])
par("517", "[s2] Attiva i tedeschi 3 e 11 nell’esagono F12, accovacciati. Iniziano i Round.",
    sighting(2) + [activate([(3, "F12"), (11, "F12")], "crouching")])
par("518", "Effettua un controllo di percezione:\n• se riesce, vedi 364;\n• se fallisce, vedi 218.", [pc(0, [see("364")], [see("218")])])
par("519", "Il soldato nota che il mortaio spara da appena dietro la cresta della collina, forse da X14.", [])
par("520", "[s0] Il soldato vede un blocco stradale di tronchi e rottami in S11 e S12: metti i segnalini. Effettua un controllo di percezione (+1): se riesce, vedi 671; altrimenti metti un segnalino Evento.",
    sighting(0) + [{"op": "blocco", "hexes": ["S11", "S12"]}, pc(1, [see("671")], [{"op": "event_marker"}])])
par("521", "Il soldato vede una sigaretta tedesca ancora accesa sul bordo di un tavolo in questa fattoria deserta. Sul pavimento ci sono alcuni bossoli.", [])
par("522", "Effettua un controllo di attivazione (+2):\n• se riesce, vedi 673;\n• se fallisce, vedi 223.", [act(2, [see("673")], [see("223")])])
par("523", "[s2] Attiva i tedeschi 3 e 11 nell’esagono O16, accovacciati. Iniziano i Round. Vantaggio tedesco.",
    sighting(2) + [activate([(3, "O16"), (11, "O16")], "crouching", adv="de")])
par("524", "[s6] Attiva il tedesco 14 nell’esagono S13, accovacciato. Iniziano i Round. Vantaggio tedesco.",
    sighting(6) + [activate([(14, "S13")], "crouching", adv="de")])
par("525", "Tira un dado:\n0–5: controllo di attivazione; se riesce, vedi 523.\n6–8: nessun effetto.\n9: controllo di percezione (+1); se riesce, vedi 674.",
    [dado((0, 5, [act(0, [see("523")])]), (6, 8, []), (9, 9, [pc(1, [see("674")])]))])
par("526", "I tuoi uomini sentono degli spruzzi nel fiume, verso O18.", [])
par("527", "Vai in T8 e togli a questo tedesco la reazione speciale D.", [enter("T8"), {"op": "g_reaction", "r": ""}], "movimento")
par("528", "Serve s4. Se il tedesco 45 è stato tolto dalla mappa con un movimento evasivo e un soldato americano vede T8, vedi 673.",
    [if_(ALL(S(4), {"evaded": 45}, {"see_hex": "T8"}), [see("673")])])
par("651", "Effettua un controllo di percezione:\n• se riesce, vedi 201;\n• se fallisce, vedi 354.", [pc(0, [see("201")], [see("354")])])
par("652", "Passa alla Condizione 2.", [cond(2)])
par("653", "Attiva il tedesco 11 nell’esagono F12, in piedi. Iniziano i Round. Vantaggio americano. Il soldato che ha appena fatto il controllo di percezione è automaticamente consapevole.",
    [activate([(11, "F12")], "standing", adv="us", aware=True)])
par("654", "[s2] Attiva il tedesco 3 in E13 e l’11 in F12, in piedi. Iniziano i Round. Vantaggio americano. Il soldato che ha appena fatto il controllo è automaticamente consapevole; i consapevoli che non cadono nel panico ricevono 2 turni. Passa alla Condizione 2.",
    sighting(2) + [activate([(3, "E13"), (11, "F12")], "standing", adv="us", us_two=True, aware=True), cond(2)])
par("655", "Effettua un controllo di percezione (−2):\n• se riesce, vedi 205;\n• se fallisce, vedi 201.", [pc(-2, [see("205")], [see("201")])])
par("656", "Tira un dado:\n0–3: controllo di attivazione; se riesce, vedi 652.\n4–8: nessun evento.\n9: controllo di percezione (+1); se riesce, vedi 206.",
    [dado((0, 3, [act(0, [see("652")])]), (4, 8, []), (9, 9, [pc(1, [see("206")])]))])
par("657", "Tira un dado:\n0–3: controllo di attivazione; se riesce, vedi 652.\n4–7: nessun evento.\n8: controllo di percezione (+1); se riesce, vedi 207.\n9: controllo di percezione (−1); se riesce, vedi 360.",
    [dado((0, 3, [act(0, [see("652")])]), (4, 7, []), (8, 8, [pc(1, [see("207")])]), (9, 9, [pc(-1, [see("360")])]))])
par("658", "Se c’è un carro americano sulla mappa, vedi 208. Altrimenti nessun evento.", [if_(SHERMAN, [see("208")])])
par("660", "[s1] Il soldato scopre che il fiume si può guadare in J3. Metti un segnalino Guado.", sighting(1) + [{"op": "guado", "hexes": ["J3"]}])
par("661", "Tira un dado:\n0–4: controllo di attivazione (−2); se riesce, vedi 355.\n5–8: nessun evento.\n9: controllo di percezione (−1); se riesce, vedi 654.",
    [dado((0, 4, [act(-2, [see("355")])]), (5, 8, []), (9, 9, [pc(-1, [see("654")])]))])
par("662", "[s6] Attiva il tedesco 14 nell’esagono K13, accovacciato. Iniziano i Round. Vantaggio americano. Il soldato che ha appena fatto il controllo di percezione è automaticamente consapevole. Passa alla Condizione 3.",
    sighting(6) + [activate([(14, "K13")], "crouching", adv="us", aware=True), cond(3)])
par("663", "Effettua un controllo di attivazione. Se riesce, vedi 213.", [act(0, [see("213")])])
par("664", "Effettua un controllo di attivazione. Se riesce, vedi 214.", [act(0, [see("214")])])
par("665", "Tira un dado:\n0–3: controllo di attivazione; se riesce, vedi 213.\n4–7: nessun evento.\n8–9: controllo di percezione; se riesce, vedi 215.",
    [dado((0, 3, [act(0, [see("213")])]), (4, 7, []), (8, 9, [pc(0, [see("215")])]))])
par("666", "• Se non ci sono stati né s5 né s3, vedi 353.\n• Se c’è stato s5 ma non s3, vedi 663.\n• Se c’è stato s3 ma non s5, vedi 500.\n• Se ci sono stati entrambi, nessun evento.",
    chain((ALL(NOT(S(5)), NOT(S(3))), [see("353")]), (NOT(S(3)), [see("663")]), (NOT(S(5)), [see("500")])))
par("667", "Tira un dado:\n0–4: controllo di attivazione (−1); se riesce, vedi 651.\n5–8: nessun evento.\n9: controllo di percezione; se riesce, vedi 205.",
    [dado((0, 4, [act(-1, [see("651")])]), (5, 8, []), (9, 9, [pc(0, [see("205")])]))])
par("668", "Tira un dado:\n0–4: controllo di attivazione (−2); se riesce, vedi 218.\n5–8: nessun evento.\n9: controllo di percezione; se riesce, vedi 662.",
    [dado((0, 4, [act(-2, [see("218")])]), (5, 8, []), (9, 9, [pc(0, [see("662")])]))])
par("669", "Un soldato americano che vede N18 fa un controllo di percezione (−1). Se riesce, vedi 219.", [best("N18", -1, "219")])
par("670", "Se i tedeschi 45 e 11 e altri due tedeschi sono stati catturati, incapacitati o uccisi, passa alla Condizione 5. Altrimenti nessun evento.",
    [if_({"m8_670": True}, [cond(5)])])
par("671", "Il soldato nota dei fili elettrici che corrono a terra verso il ponte. Tagliarli costa un’azione nei Round (bottone «Taglia i fili del ponte»): poi vedi 221.",
    [{"op": "scelta_attiva", "par": "221", "testo": "Taglia i fili del ponte"}])
par("672", "Effettua un controllo di percezione: se riesce, vedi 219; se fallisce, metti un segnalino Evento.",
    [pc(0, [see("219")], [{"op": "event_marker"}])])
par("673", "[s4] Attiva il tedesco 45 nell’esagono T8, in piedi. Iniziano i Round. Vantaggio tedesco. Riceve 2 turni nel prossimo Round.",
    sighting(4) + [activate([(45, "T8")], "standing", adv="de", two=[45])])
par("674", "[s2] Attiva i tedeschi 3 e 11 nell’esagono O16, in piedi. Iniziano i Round. Vantaggio americano.",
    sighting(2) + [activate([(3, "O16"), (11, "O16")], "standing", adv="us")])
par("675", "[s6] Attiva il tedesco 14 nell’esagono S13, in piedi. Iniziano i Round. Vantaggio americano.",
    sighting(6) + [activate([(14, "S13")], "standing", adv="us")])
par("676", "Effettua un controllo di attivazione (+1). Se riesce, vedi 673.", [act(1, [see("673")])])
par("677", "Vai in O16 e togli a questo tedesco la reazione speciale A. Passa alla Condizione 3.",
    [enter("O16"), {"op": "g_reaction", "r": ""}, cond(3)], "movimento")
par("678", "Serve s2. Se il tedesco 3 e/o l’11 sono stati tolti dalla mappa con un movimento evasivo e un soldato americano vede O16, vedi 228.",
    [if_(ALL(S(2), {"evaso_uno": [3, 11]}, {"see_hex": "O16"}), [see("228")])])

AZ = {
"507": None,
"841": "Se vedi tre o più bersagli attivi, esegui 800. Altrimenti esegui 815.",
"842": "Accovacciati e spara di rapido col fucile. Poi sdraiati prono.",
"843": "Se nel tuo esagono non c’è un tedesco attivo e vedi più di un americano attivo, arrenditi. Altrimenti esegui 815.",
"844": "Se nessun americano in vista è a est della colonna M, vai in N6 e metti in effetto la reazione speciale D.",
"926": "Accovacciati e spara di rapido. Poi vedi 507.",
"927": "Sdraiati prono, poi vedi 507.",
"928": "• Se nessun tedesco attivo è nel tuo esagono o accanto e non vedi americani attivi, muoviti il più rapidamente possibile e metti in effetto la reazione speciale A.\n• Altrimenti esegui 801.",
"929": "Se sei in un edificio, vedi 930. Altrimenti sdraiati prono.",
"930": "Accovacciati, poi:\n1. Se dalla porta nord non vedi americani attivi e il ponte è intatto, corri in L12 e metti in effetto la reazione speciale B.\n2. Se dalla finestra sud non vedi americani attivi, corri per L13 fino in K14 e metti in effetto la reazione speciale B.\n3. Esegui 802.",
"931": "Se vedi tre o più bersagli attivi, vai in N6. Se alla fine del Round sei fuori dalla vista degli americani, esci dalla mappa.",
"932": "• Se sei in un bosco, vedi 844.\n• Se sei in un edificio, vedi 802.",
}
for _k, _v in AZ.items():
    if _v:
        par(_k, _v, [], "azione")

for k in list(P):
    if k in P1 or k in P2 or k in P3 or k in P4 or k in P5 or k in P6 or k in P7:
        del P[k]
