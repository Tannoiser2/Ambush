# -*- coding: utf-8 -*-
"""Paragrafi della Missione 5 «Operazione Borseggio» (mappa B, nord in alto, fiume con guadi, base dei V-2).

Testo inglese da tools/paragrafi_en.json, completato sulle scansioni (091, 096, 487).
"""
from paragrafi_m1 import pc, act, see, if_, S, NOT, ALL, sighting, activate, cond, P as P1
from paragrafi_m2 import P as P2
from paragrafi_m3 import P as P3
from paragrafi_m4 import P as P4, chain, dado_pari

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def enter(h):
    return {"op": "g_enter", "hex": h}


def reaz(r):
    return {"op": "g_reaction", "r": r}


def dado(*fasce):
    return {"op": "die", "b": [[a, b, ops] for a, b, ops in fasce]}


def guado(*hexes):
    return {"op": "guado", "hexes": list(hexes)}


def inst(nome, pv, hexx="@hex", p=""):
    return {"op": "installazione", "hex": hexx, "nome": nome, "pv": pv, "par": p}


def reaz_gruppo(nums, r, no_auto=True):
    return {"op": "reazione_gruppo", "g": nums, "r": r, "no_auto": no_auto}


INATTIVI_SCIENZIATI = {"inattivi": [24, 42]}
SCIENZIATO_ATTIVO = {"attivo_uno": [24, 42]}

par("032", "Tira un dado:\n0–4: controllo di attivazione; se riesce, vedi 617.\n5–7: controllo di attivazione (−3); se riesce, vedi 617.\n8–9: controllo di percezione; se riesce, vedi 640.",
    [dado((0, 4, [act(0, [see("617")])]), (5, 7, [act(-3, [see("617")])]), (8, 9, [pc(0, [see("640")])]))])
par("033", "Metti un segnalino Evento. Effettua un controllo di percezione. Se riesce, vedi 038.",
    [{"op": "event_marker"}, pc(0, [see("038")])])
par("036", "Se un soldato americano attivo vede l’esagono S6, vedi 635.", [if_({"see_hex": "S6"}, [see("635")])])
par("037", "• Se i tedeschi 24 e 42 sono inattivi, entra in T15.\n• Se non c’è stato s0, segna s0: attiva i tedeschi 24 e 42 accovacciati in S14; reazione speciale Q per i tedeschi 13, 24 e 42, senza colonna di autoconservazione.\n• Se c’è già stato s0 e il 24 o il 42 sono attivi, reazione speciale Q per 13, 24 e 42, senza autoconservazione.",
    [if_(INATTIVI_SCIENZIATI, [enter("T15")],
         [if_(NOT(S(0)), sighting(0) + [activate([(24, "S14"), (42, "S14")], "crouching"), reaz_gruppo([13, 24, 42], "Q")],
              [if_(SCIENZIATO_ATTIVO, [reaz_gruppo([13, 24, 42], "Q")])])])], "movimento")
par("038", "Il soldato sente uno scatto metallico, come l’otturatore di un fucile, nell’esagono S9.", [])
par("039", "Il soldato sente una radio nell’esagono J13.", [])
par("041", "Il soldato vede un guado nell’esagono N16.", [guado("N16")])
par("042", "[s5] Attiva il tedesco 36 nell’esagono N9, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 36 riceve 2 turni in questo Round.",
    sighting(5) + [activate([(36, "N9")], "crouching", adv="de", two=[36])])
par("043", "Effettua un controllo di percezione (−1):\n• se riesce, vedi 634;\n• se fallisce, vedi 482.", [pc(-1, [see("634")], [see("482")])])
par("044", "Il soldato vede un guado nell’esagono G7.", [guado("G7")])
par("045", "Un soldato scelto a caso, adiacente a un esagono di ruscello, ci cade dentro. Tira un dado: pari, riesce a uscire e torna nel suo esagono illeso; dispari, la corrente lo trascina via e annega, perdendo tutto. Succede una sola volta per missione.",
    [{"op": "caduta_fiume"}])
par("046", "[s3 e s6] Attiva il tedesco 40 in O6 e il tedesco 7 in P5, accovacciati. Iniziano i Round. Vantaggio tedesco. I tedeschi 40 e 7 ricevono 2 turni in questo Round.",
    sighting(3, 6) + [activate([(40, "O6"), (7, "P5")], "crouching", adv="de", two=[40, 7])])
par("048", "Metti un segnalino Evento. Effettua un controllo di percezione. Se riesce, vedi 648.",
    [{"op": "event_marker"}, pc(0, [see("648")])])
par("049", "[s9] Nell’esagono I4 c’è un mucchio di bombole di gas vuote e altri rifiuti. Metti un segnaposto.",
    sighting(9) + [{"op": "landmark", "hex": "I4", "name": "rifiuti"}])
par("061", "1. Se non ci sono stati né s3 né s7, vedi 471.\n2. Se c’è stato s7, vedi 482.\n3. Se c’è stato s3, vedi 464.\n4. Se ci sono stati s3 e s7, nessun evento.",
    chain((ALL(NOT(S(3)), NOT(S(7))), [see("471")]), (ALL(S(7), NOT(S(3))), [see("482")]), (ALL(S(3), NOT(S(7))), [see("464")])))
par("062", "Campo minato! Esegui la procedura del campo minato. Se una mina esplode ed è in vigore la Condizione 1, passa alla Condizione 2.",
    [{"op": "minefield"}, if_(ALL(NOT({"no_mine_blast": True}), {"cond_in": [1]}), [cond(2)])])
par("070", "[s3] Attiva il tedesco 40 nell’esagono O6, accovacciato. Iniziano i Round. Vantaggio americano. Tutti i soldati americani che non cadono nel panico ricevono 2 turni in questo Round.",
    sighting(3) + [activate([(40, "O6")], "crouching", adv="us", us_two=True), {"op": "tutti_due_turni"}])
par("071", "[s4] Nell’esagono c’è una grande antenna mimetizzata: metti un segnaposto. Distruggerla vale 2 PV: lancia una carica da demolizione nel suo esagono.",
    sighting(4) + [inst("antenna", 2)])
par("072", "Un soldato americano incapacitato, scelto a caso, muore per le ferite. Succede una sola volta per missione.",
    [{"op": "morte_incapacitato", "lato": "us", "chiave": "072"}])
par("074", "Tira un dado:\n0–4: controllo di attivazione; se riesce, vedi 636.\n5–8: nessun effetto.\n9: controllo di percezione (−1); se riesce, vedi 618.",
    [dado((0, 4, [act(0, [see("636")])]), (5, 8, []), (9, 9, [pc(-1, [see("618")])]))])
par("075", "Il soldato trova a terra un pacchetto di sigarette tedesche.", [])
par("076", "Metti un segnalino Evento. Effettua un controllo di percezione (+1). Se riesce, vedi 626.",
    [{"op": "event_marker"}, pc(1, [see("626")])])
par("080", "[s1] Il soldato vede un’antenna radar sul tetto dell’edificio in K7. Metti un segnaposto.",
    sighting(1) + [{"op": "landmark", "hex": "K7", "name": "radar"}])
par("090", "Achtung! Minen-feld! I cartelli segnalano un campo minato negli esagoni a nord e a nord-ovest della tua posizione: metti i segnaposto.",
    [{"op": "avviso_mine", "dirs": [0, 5]}])
par("091", "Tira un dado:\n0–2: controllo di attivazione; se riesce, vedi 617.\n3–6: controllo di attivazione (−2); se riesce, vedi 617.\n7–9: controllo di percezione; se riesce, vedi 096; se fallisce, vai al 039.",
    [dado((0, 2, [act(0, [see("617")])]), (3, 6, [act(-2, [see("617")])]), (7, 9, [pc(0, [see("096")], [see("039")])]))])
par("092", "Serve s5: passa alla Condizione 2.", [if_(S(5), [cond(2)])])
par("094", "1. Se non ci sono stati né s3 né s6, vedi 046.\n2. Se c’è stato s3, vedi 478.\n3. Se c’è stato s6, vedi 643.\n4. Se ci sono stati s3 e s6, nessun evento.",
    chain((ALL(NOT(S(3)), NOT(S(6))), [see("046")]), (ALL(S(3), NOT(S(6))), [see("478")]), (ALL(S(6), NOT(S(3))), [see("643")])))
par("095", "Serve s6: passa alla Condizione 4.", [if_(S(6), [cond(4)])])
par("096", "[s5] Attiva il tedesco 36 nell’esagono J13, in piedi. Iniziano i Round. Vantaggio americano. Tutti i soldati americani che vedono J13 sono automaticamente consapevoli. Tutti i soldati consapevoli che non cadono nel panico ricevono 2 turni in questo Round.",
    sighting(5) + [activate([(36, "J13")], "standing", adv="us", us_two=True), {"op": "consapevoli_vede", "hex": "J13"}])
par("108", "Il ruscello qui è impraticabile: il soldato non può entrare nell’esagono.", [])
par("117", "Esagono di guado. Metti un segnaposto.", [guado("@hex")])
par("458", "[s5] Attiva il tedesco 36 nell’esagono N9, accovacciato. Iniziano i Round. Vantaggio americano. Tutti i soldati americani consapevoli che non cadono nel panico ricevono 2 turni in questo Round.",
    sighting(5) + [activate([(36, "N9")], "crouching", adv="us", us_two=True)])
par("461", "Un tedesco incapacitato, scelto a caso, muore per le ferite. Succede una sola volta per missione.",
    [{"op": "morte_incapacitato", "lato": "de", "chiave": "461"}])
par("462", "• Se il soldato è sul ponte, vedi 647.\n• Se è sotto il ponte, vedi 108.", [see("647")])
par("463", "Passa alla Condizione 3.", [cond(3)])
par("464", "Tira un dado:\n0–4: controllo di attivazione (+1); se riesce, vedi 636.\n5–8: controllo di attivazione; se riesce, vedi 636.\n9: controllo di percezione; se riesce vedi 477, altrimenti vedi 636.",
    [dado((0, 4, [act(1, [see("636")])]), (5, 8, [act(0, [see("636")])]), (9, 9, [pc(0, [see("477")], [see("636")])]))])
par("465", "Se un soldato americano attivo vede l’esagono N5, passa alla Condizione 2.", [if_({"see_hex": "N5"}, [cond(2)])])
par("466", "Se un soldato americano vede l’esagono K7, vedi 080.", [if_({"see_hex": "K7"}, [see("080")])])
par("471", "[s3 e s7] Attiva il tedesco 40 in S9, accovacciato, e il tedesco 12 al piano superiore dell’edificio in S13, accovacciato. Iniziano i Round. Vantaggio tedesco. I tedeschi 12 e 40 ricevono 2 turni in questo Round.",
    sighting(3, 7) + [activate([(40, "S9"), (12, "S13")], "crouching", adv="de", two=[12, 40])])
par("472", "[s3] Attiva il tedesco 40 nell’esagono S9, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 40 riceve 2 turni in questo Round.",
    sighting(3) + [activate([(40, "S9")], "crouching", adv="de", two=[40])])
par("473", "Il soldato vede un guado nell’esagono F10.", [guado("F10")])
par("475", "Il soldato americano con la percezione più alta che vede l’esagono I4 fa un controllo di percezione. Se riesce, vedi 049.",
    [{"op": "best_pc", "hex": "I4", "mod": 0, "ok": [see("049")]}])
par("477", "[s7] Attiva il tedesco 12 al piano superiore dell’edificio in S13, accovacciato. Iniziano i Round. Vantaggio tedesco.",
    sighting(7) + [activate([(12, "S13")], "crouching", adv="de")])
par("478", "[s6] Attiva il tedesco 7 nell’esagono P5, in piedi. Iniziano i Round. Vantaggio americano.",
    sighting(6) + [activate([(7, "P5")], "standing", adv="us")])
par("479", "• Se c’è stato s0, vedi 487.\n• Altrimenti segna s0: attiva i tedeschi 24 e 42 in S14, accovacciati. Iniziano i Round. Vantaggio americano. Tutti i soldati americani attivi che vedono S14 sono automaticamente consapevoli; i consapevoli che non cadono nel panico ricevono 2 turni. Vedi 487.",
    [if_(S(0), [see("487")], sighting(0) + [activate([(24, "S14"), (42, "S14")], "crouching", adv="us", us_two=True),
                                          {"op": "consapevoli_vede", "hex": "S14"}, see("487")])])
par("480", "Il soldato vede un guado nell’esagono B5.", [guado("B5")])
par("481", "Tira un dado:\n0–3: controllo di attivazione; se riesce, vedi 042.\n4–6: controllo di attivazione (−1); se riesce, vedi 042.\n7–9: controllo di percezione; se riesce, vedi 458.",
    [dado((0, 3, [act(0, [see("042")])]), (4, 6, [act(-1, [see("042")])]), (7, 9, [pc(0, [see("458")])]))])
par("482", "Effettua un controllo di attivazione:\n• se riesce, vedi 472;\n• se fallisce, controllo di percezione: se riesce, vedi 634.",
    [act(0, [see("472")], [pc(0, [see("634")])])])
par("483", "[s6] Attiva il tedesco 7 nell’esagono P5, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 7 riceve 2 turni in questo Round.",
    sighting(6) + [activate([(7, "P5")], "crouching", adv="de", two=[7])])
par("484", "Il soldato è entrato in una stazione radar. Metti un segnalino Evento ed effettua un controllo di percezione: se riesce, vedi 133. Inoltre distruggere la stazione radar vale 2 PV: lancia una carica da demolizione nel suo esagono.",
    [{"op": "event_marker"}, inst("radar", 2), pc(0, [see("133")])])
par("485", "Un tedesco ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Succede una sola volta per missione.",
    [{"op": "dissanguamento", "lato": "de", "chiave": "485"}])
par("486", "Effettua un controllo di percezione (−1):\n• se riesce, vedi 070;\n• se fallisce, vedi 493.", [pc(-1, [see("070")], [see("493")])])
par("487", "Nell’esagono S13, nascosto nella chiesa, c’è un razzo V-2: metti il segnaposto. Distruggerlo vale 2 PV: lancia una carica da demolizione nel suo esagono e leggi il paragrafo 639.",
    [inst("v2", 2, "S13", "639")])
par("491", "Metti un segnalino Evento. Effettua un controllo di percezione:\n• se riesce, vedi 049;\n• se fallisce, vedi 638.",
    [{"op": "event_marker"}, pc(0, [see("049")], [see("638")])])
par("492", "[s3] Attiva il tedesco 40 nell’esagono S9, accovacciato. Iniziano i Round.",
    sighting(3) + [activate([(40, "S9")], "crouching")])
par("493", "Effettua un controllo di attivazione (−1):\n• se riesce, vedi 643;\n• se fallisce, controllo di percezione (−1): se riesce, vedi 070.",
    [act(-1, [see("643")], [pc(-1, [see("070")])])])
par("494", "Serve s3: passa alla Condizione 3.", [if_(S(3), [cond(3)])])
par("495", "Tira un dado:\n0–2: controllo di attivazione; se riesce, vedi 483.\n3–8: controllo di attivazione (−1); se riesce, vedi 483.\n9: controllo di percezione; se riesce, vedi 478.",
    [dado((0, 2, [act(0, [see("483")])]), (3, 8, [act(-1, [see("483")])]), (9, 9, [pc(0, [see("478")])]))])
par("617", "[s5] Attiva il tedesco 36 nell’esagono J13, accovacciato. Iniziano i Round. Vantaggio tedesco.",
    sighting(5) + [activate([(36, "J13")], "crouching", adv="de")])
par("618", "Il soldato vede un’ombra muoversi nel campanile della chiesa in S13.", [])
par("619", "• Se non c’è stato s7, vedi 477, poi vedi 487.\n• Se c’è stato s7, vedi 479.",
    [if_(NOT(S(7)), [see("477"), see("487")], [see("479")])])
par("621", "1. Se non ci sono stati né s3 né s5, vedi 644.\n2. Se c’è stato s5, vedi 643.\n3. Se c’è stato s3, vedi 042.\n4. Se ci sono stati s3 e s5, nessun evento.",
    chain((ALL(NOT(S(3)), NOT(S(5))), [see("644")]), (ALL(S(5), NOT(S(3))), [see("643")]), (ALL(S(3), NOT(S(5))), [see("042")])))
par("622", "Metti un segnalino Evento. Effettua un controllo di percezione (+1). Se riesce, vedi 041.",
    [{"op": "event_marker"}, pc(1, [see("041")])])
par("623", "Un soldato americano ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Succede una sola volta per missione.",
    [{"op": "dissanguamento", "lato": "us", "chiave": "623"}])
par("626", "Il soldato vede due guadi, negli esagoni T17 e V17.", [guado("T17", "V17")])
par("629", "Effettua un controllo di attivazione:\n• se riesce, vedi 617;\n• se fallisce, controllo di percezione: se riesce, vedi 096.",
    [act(0, [see("617")], [pc(0, [see("096")])])])
par("634", "[s3] Attiva il tedesco 40 nell’esagono S9, accovacciato. Iniziano i Round. Vantaggio americano.",
    sighting(3) + [activate([(40, "S9")], "crouching", adv="us")])
par("635", "[s8] Nell’esagono S6 c’è una torre a traliccio di metallo su una piattaforma di cemento: metti il segnaposto della rampa. Distruggerla vale 2 PV: lancia una carica da demolizione nel suo esagono.",
    sighting(8) + [inst("rampa", 2, "S6")])
par("636", "[s7] Attiva il tedesco 12 al piano superiore dell’edificio in S13, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 12 riceve automaticamente 2 turni in questo Round.",
    sighting(7) + [activate([(12, "S13")], "crouching", adv="de", two=[12])])
par("638", "Il soldato vede un luccichio d’acciaio nell’esagono I4.", [])
par("639", "Quando la carica esplode, esplode anche il razzo: una gigantesca palla di fuoco erutta dal campanile come il Vesuvio. Tutti i soldati in S13 muoiono; S13 e S14 diventano macerie. Chi è entro 2 esagoni da S13 subisce i danni di una granata all’aperto; nei Round, chi è entro 3 esagoni cade nel panico.",
    [{"op": "esplosione_v2"}])
par("640", "Il soldato vede un movimento nell’edificio in J13.", [])
par("641", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 643;\n• se fallisce, controllo di percezione (−1): se riesce, vedi 070.",
    [act(1, [see("643")], [pc(-1, [see("070")])])])
par("643", "[s3] Attiva il tedesco 40 nell’esagono O6, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 40 riceve automaticamente 2 turni in questo Round.",
    sighting(3) + [activate([(40, "O6")], "crouching", adv="de", two=[40])])
par("644", "[s3 e s5] Attiva il tedesco 40 in O6 e il tedesco 36 in N9, accovacciati. Tira un dado: pari, vantaggio americano; dispari, vantaggio tedesco.",
    sighting(3, 5) + [dado_pari([activate([(40, "O6"), (36, "N9")], "crouching", adv="us")],
                                [activate([(40, "O6"), (36, "N9")], "crouching", adv="de")])])
par("645", "Un soldato americano scelto a caso, in un esagono di terreno accidentato, cade. Fa un controllo di percezione: se riesce è illeso; se fallisce, subisce i danni di un colpo di pistola. Succede una sola volta per missione.",
    [{"op": "caduta_accidentato"}])
par("646", "Achtung! Minen-feld! I cartelli segnalano un campo minato nell’esagono a nord-est della tua posizione: metti il segnaposto.",
    [{"op": "avviso_mine", "dirs": [1]}])
par("647", "Il soldato vede un guado nell’esagono G12.", [guado("G12")])
par("648", "[s4] Il soldato vede una grande torre d’antenna nell’esagono X10.", sighting(4) + [inst("antenna", 2, "X10")])
par("650", "Tira un dado:\n0–2: controllo di attivazione; se riesce, vedi 617.\n3–6: controllo di attivazione (−2); se riesce, vedi 617.\n7–9: controllo di percezione; se riesce, vedi 640.",
    [dado((0, 2, [act(0, [see("617")])]), (3, 6, [act(-2, [see("617")])]), (7, 9, [pc(0, [see("640")])]))])
par("973", "Vedi 037.", [see("037")], "movimento")
par("978", "• Se i tedeschi 24 e 42 sono inattivi, entra in R14.\n• Se non c’è stato s0, segna s0: attiva i tedeschi 24 e 42 accovacciati in S14; reazione speciale Q per i tedeschi 13, 24 e 42, senza autoconservazione.\n• Se c’è già stato s0 e il 24 o il 42 sono attivi, reazione speciale Q per 13, 24 e 42, senza autoconservazione.",
    [if_(INATTIVI_SCIENZIATI, [enter("R14")],
         [if_(NOT(S(0)), sighting(0) + [activate([(24, "S14"), (42, "S14")], "crouching"), reaz_gruppo([13, 24, 42], "Q")],
              [if_(SCIENZIATO_ATTIVO, [reaz_gruppo([13, 24, 42], "Q")])])])], "movimento")
par("983", "Vedi 984.", [see("984")], "movimento")
par("984", "• Se il tedesco 7 è inattivo, entra in P7.\n• Se non c’è stato s6, segna s6: attiva il tedesco 7 accovacciato in P5; reazione speciale X per i tedeschi 7 e 13, senza autoconservazione.\n• Se c’è già stato s6 e il 7 è attivo, reazione speciale X per i tedeschi 7 e 13, senza autoconservazione.",
    [if_({"inattivi": [7]}, [enter("P7")],
         [if_(NOT(S(6)), sighting(6) + [activate([(7, "P5")], "crouching"), reaz_gruppo([7, 13], "X")],
              [if_({"attivo_uno": [7]}, [reaz_gruppo([7, 13], "X")])])])], "movimento")
par("986", "Vedi 978.", [see("978")], "movimento")
par("992", "[s2] Un’auto comando tedesca piomba sulla scena! Attiva il tedesco 13 in Y8. Iniziano i Round.",
    sighting(2) + [activate([(13, "Y8")], "crouching")])
par("996", "[s2] Un’auto comando tedesca piomba sulla scena! Attiva il tedesco 13 in Y16. Iniziano i Round.",
    sighting(2) + [activate([(13, "Y16")], "crouching")])
par("999", "• Se dalla porta vedi un americano attivo, metti in effetto la reazione speciale A ed entra in J12.\n• Altrimenti metti in effetto la reazione speciale A ed entra in J14.",
    [reaz("A"), if_({"g_vede_us": True}, [enter("J12")], [enter("J14")])], "movimento")
AZ = {
"034": "• Se il tedesco 7 è inattivo, togli la reazione speciale X e tira di nuovo sulla colonna delle Condizioni 3–4, eseguendo subito l’azione.\n• Se il 7 è attivo ma non è sull’auto, esegui 825.\n• Se il 7 è attivo e sull’auto, reazione speciale C per i tedeschi 7 e 13 e tira di nuovo: entra in P7 (se l’auto è entrata in Y8) o in Q6 (se è entrata in Y16).",
"459": "• Se i tedeschi 24 e 42 sono inattivi, togli la reazione speciale Q e tira di nuovo sulla colonna delle Condizioni 3–4.\n• Se uno dei due è attivo ma non è sull’auto, esegui 825.\n• Se sono sull’auto o inattivi, reazione speciale C per il tedesco 13 e tira di nuovo: entra in T15 (auto entrata in Y8) o in R14 (entrata in Y16).",
"630": "1. Se sei in S14 e l’auto comando non è fuori uso, accovacciati e striscia in S15.\n2. Se sei in S15 e l’auto non è fuori uso, sali sull’auto.\n3. Se sei sull’auto e l’autista è attivo, passa.\n4. Se sei sull’auto e l’autista è inattivo, prendi il suo posto e guida.\n5. Altrimenti accovacciati.",
"642": "• Se vedi un americano attivo, guida veloce.\n• Altrimenti guida piano.",
"649": "• Se sei su un veicolo attivo con l’autista attivo, esegui 832.\n• Se l’autista è inattivo, prendi il suo posto e guida.\n• Se il veicolo è fuori uso, reazione speciale U e tira di nuovo per questa azione.",
"972": "1. Se sei in P5 e l’auto comando non è fuori uso, accovacciati e striscia in P6.\n2. Se sei in P6, sali sull’auto.\n3. Se sei sull’auto e l’autista è attivo, reazione speciale C per i tedeschi 7 e 13 e tira di nuovo: l’auto entra in P7.\n4. Se l’autista è inattivo, il 7 guida l’auto.\n5. Altrimenti esegui 832.",
"974": "Metti in effetto la reazione speciale B e sdraiati prono se ti resta il cambio di postura gratuito o un punto movimento.",
"977": "L’ufficiale usa la radio. Passa alla Condizione 3.",
"993": "• Se è in vigore la Condizione 1 o 2, vedi 977.\n• Se è in vigore la Condizione 3 o 4, vedi 839.",
}
for _k, _v in AZ.items():
    par(_k, _v, [], "azione")

for k in list(P):
    if k in P1 or k in P2 or k in P3 or k in P4:
        del P[k]
