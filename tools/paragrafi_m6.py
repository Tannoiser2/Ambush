# -*- coding: utf-8 -*-
"""Paragrafi della Missione 6 «Gita in canoa fino al Vallo occidentale» (mappa A, nord in alto, notte, canoe, bunker)."""
from paragrafi_m1 import pc, act, see, if_, S, NOT, ALL, sighting, activate, cond, P as P1
from paragrafi_m2 import P as P2
from paragrafi_m3 import P as P3
from paragrafi_m4 import P as P4, chain
from paragrafi_m5 import P as P5

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def enter(h):
    return {"op": "g_enter", "hex": h}


def reaz(r):
    return {"op": "g_reaction", "r": r}


def bunker(h, porta):
    return {"op": "bunker", "hex": h, "porta": porta}


EST = {"us_lato": "est"}
OVEST = {"us_lato": "ovest"}

par("561", "Metti un segnalino Evento. Effettua un controllo di percezione (−1). Se riesce, vedi 702.",
    [{"op": "event_marker"}, pc(-1, [see("702")])])
par("563", "Effettua un controllo di attivazione (−1):\n• se riesce, vedi 710;\n• se fallisce, vedi 751.", [act(-1, [see("710")], [see("751")])])
par("566", "Effettua un controllo di percezione (+1):\n• se riesce, vedi 713;\n• se fallisce, vedi 563.", [pc(1, [see("713")], [see("563")])])
par("570", "[s1] Nell’esagono L17 c’era un bunker tedesco, distrutto in pieno da una bomba da 500 libbre. Metti un cratere nell’esagono.",
    sighting(1) + [{"op": "cratere", "hex": "L17"}])
par("571", "Effettua un controllo di attivazione (+1). Se riesce, vedi 718.", [act(1, [see("718")])])
par("572", "Metti un segnalino Evento. Effettua un controllo di percezione (−1). Se riesce, vedi 721.",
    [{"op": "event_marker"}, pc(-1, [see("721")])])
par("574", "Effettua un controllo di attivazione (−1). Se riesce, vedi 725.", [act(-1, [see("725")])])
par("575", "Il tuo soldato vede un bunker mimetizzato nell’esagono S13. Puoi iniziare i Round andando al 884, oppure no: in qualsiasi momento potrai attaccare il bunker e attivarlo andando al 884 (bottone «Attacca il bunker in S13»).",
    [{"op": "scelta_attiva", "par": "884", "testo": "Attacca il bunker in S13"}])
par("578", "1. Se non c’è stato s2, vedi 737.\n2. Se ci sono stati s0 e s5, passa alla Condizione 4.\n3. Nessun evento.",
    chain((NOT(S(2)), [see("737")]), (ALL(S(0), S(5)), [cond(4)])))
par("580", "Serve s5. Se un soldato americano attivo è sulla riva est del fiume, vedi 784.", [if_(ALL(S(5), EST), [see("784")])])
par("581", "[s4] Attiva i tedeschi 27 e 28 nell’esagono A11, in piedi. Iniziano i Round. Vantaggio tedesco.",
    sighting(4) + [activate([(27, "A11"), (28, "A11")], "standing", adv="de")])
par("596", "1. Se un soldato americano attivo è sulla riva est del fiume, vedi 784.\n2. Se è sulla riva ovest, vedi 581.\n3. Nessun evento.",
    chain((EST, [see("784")]), (OVEST, [see("581")])))
par("597", "• Se non c’è stato s4, vedi 785.\n• Se c’è stato s4, vedi 894.", [if_(NOT(S(4)), [see("785")], [see("894")])])
par("702", "[s7] Nell’esagono E6 c’è uno Sherman distrutto: metti il segnaposto.", sighting(7) + [{"op": "landmark", "hex": "E6", "name": "sherman"}])
par("710", "[s3] Attiva il tedesco 86 nell’esagono K11, accovacciato. Iniziano i Round. Vantaggio tedesco. Passa alla Condizione 2.",
    sighting(3) + [activate([(86, "K11")], "crouching", adv="de"), cond(2)])
par("713", "Vedi la sagoma di una sentinella in piedi nell’esagono K11. Puoi iniziare i Round andando al 874, oppure proseguire in silenzio lungo il fiume restando nelle Operazioni (bottone «Attacca la sentinella in K11»).",
    [{"op": "scelta_attiva", "par": "874", "testo": "Attacca la sentinella in K11"}])
par("718", "[s2] Attiva il tedesco 60 nell’esagono Q10, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 60 riceve 2 turni in questo Round. Passa alla Condizione 2.",
    sighting(2) + [activate([(60, "Q10")], "crouching", adv="de", two=[60]), cond(2)])
par("719", "Effettua un controllo di percezione:\n• se riesce, vedi 755;\n• se fallisce, vedi 879.", [pc(0, [see("755")], [see("879")])])
par("721", "Il tuo soldato nota i segni di un campo minato da V7 a Y5.", [{"op": "linea_mine", "da": "V7", "a": "Y5"}])
par("723", "Effettua un controllo di percezione (+2):\n• se riesce, vedi 760;\n• se fallisce, vedi 759.", [pc(2, [see("760")], [see("759")])])
par("725", "[s0] Attiva i tedeschi 20 e 21, accovacciati, nell’esagono H15, dentro un bunker con la porta verso H16. Iniziano i Round. Vantaggio tedesco. Passa alla Condizione 3.",
    sighting(0) + [bunker("H15", "H16"), activate([(20, "H15"), (21, "H15")], "crouching", adv="de"), cond(3)])
par("727", "Effettua un controllo di attivazione (−1). Se riesce, vedi 729.", [act(-1, [see("729")])])
par("729", "[s0 e s3] Attiva i tedeschi 20 e 21 in H15, accovacciati dentro un bunker con la porta verso H16, e il tedesco 86 in K11, accovacciato. Iniziano i Round. Vantaggio tedesco. Passa alla Condizione 3.",
    sighting(0, 3) + [bunker("H15", "H16"), activate([(20, "H15"), (21, "H15"), (86, "K11")], "crouching", adv="de"), cond(3)])
par("730", "[s6, s0 e s3] Attiva il tedesco 86 in K11 e il 73 in E18, accovacciati, e i tedeschi 20 e 21 in H15, accovacciati dentro un bunker con la porta verso H16. Iniziano i Round. Vantaggio tedesco. Passa alla Condizione 3.",
    sighting(6, 0, 3) + [bunker("H15", "H16"), activate([(86, "K11"), (73, "E18"), (20, "H15"), (21, "H15")], "crouching", adv="de"), cond(3)])
par("731", "Effettua un controllo di percezione (+2):\n• se riesce, vedi 575;\n• se fallisce, controllo di attivazione (−1): se riesce, vedi 767.",
    [pc(2, [see("575")], [act(-1, [see("767")])])])
par("733", "• Se si muove un tedesco con numero 50 o superiore, entra in T14.\n• Se 49 o inferiore, entra in U14.",
    [if_({"g_ge": 50}, [enter("T14")], [enter("U14")])], "movimento")
par("734", "• Se un americano attivo è entro 4 esagoni da H15, entra in E13.\n• Altrimenti entra in F11.",
    [if_({"us_entro": ["H15", 4]}, [enter("E13")], [enter("F11")])], "movimento")
par("736", "• Se sei entrato qui da M12, entra in K11.\n• Se sei entrato da K11 o da L12, entra in M12.",
    [if_({"g_da": ["M12"]}, [enter("K11")], [enter("M12")])], "movimento")
par("737", "[s2] Attiva il tedesco 60 nell’esagono O14, accovacciato. Iniziano i Round.",
    sighting(2) + [activate([(60, "O14")], "crouching")])
par("739", "Serve s0. Se un soldato americano attivo è sulla riva ovest del fiume, vedi 581.", [if_(ALL(S(0), OVEST), [see("581")])])
par("740", "Togli le reazioni speciali R, T e V a tutti i tedeschi che le usano.", [{"op": "togli_reazioni", "r": ["R", "T", "V"]}])
par("742", "1. Se un soldato americano attivo è sulla riva est del fiume, vedi 597.\n2. Se è sulla riva ovest, vedi 893.\n3. Nessun evento.",
    chain((EST, [see("597")]), (OVEST, [see("893")])))
par("750", "Rapide! Per ogni canoa fa un controllo di percezione il soldato con la guida (DS) più alta a bordo: se riesce, nessun effetto; se fallisce, vedi 872.",
    [{"op": "rapide"}])
par("751", "Effettua un controllo di percezione (−1). Se riesce, vedi 874.", [pc(-1, [see("874")])])
par("752", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 710;\n• se fallisce, controllo di percezione (+1): se riesce, vedi 874.",
    [act(1, [see("710")], [pc(1, [see("874")])])])
par("753", "Vedi qualcosa che sembra un bunker nell’esagono L17.", [])
par("754", "[s2] Attiva il tedesco 60 nell’esagono Q10, accovacciato. Iniziano i Round. Vantaggio americano. Passa alla Condizione 2.",
    sighting(2) + [activate([(60, "Q10")], "crouching", adv="us"), cond(2)])
par("755", "[s2] Attiva il tedesco 60 nell’esagono X6, accovacciato. Iniziano i Round. Vantaggio americano. Passa alla Condizione 2.",
    sighting(2) + [activate([(60, "X6")], "crouching", adv="us"), cond(2)])
par("756", "[s2] Attiva il tedesco 60 nell’esagono X6, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 60 riceve 2 turni in questo Round. Passa alla Condizione 2.",
    sighting(2) + [activate([(60, "X6")], "crouching", adv="de", two=[60]), cond(2)])
par("757", "Metti un segnalino Evento. Effettua un controllo di percezione (−1). Se riesce, vedi 880.",
    [{"op": "event_marker"}, pc(-1, [see("880")])])
par("758", "Effettua un controllo di attivazione (−1):\n• se riesce, vedi 759;\n• se fallisce, vedi 723.", [act(-1, [see("759")], [see("723")])])
par("759", "[s6] Attiva il tedesco 73 nell’esagono E13, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 73 riceve 2 turni in questo Round. Passa alla Condizione 2.",
    sighting(6) + [activate([(73, "E13")], "crouching", adv="de", two=[73]), cond(2)])
par("760", "[s6] Attiva il tedesco 73 nell’esagono E13, accovacciato. Iniziano i Round. Vantaggio americano. Passa alla Condizione 2.",
    sighting(6) + [activate([(73, "E13")], "crouching", adv="us"), cond(2)])
par("761", "[s0] Attiva i tedeschi 20 e 21, accovacciati, in H15, dentro un bunker con la porta verso H16. Iniziano i Round. Vantaggio americano. Tutti i soldati americani che vedono H15 sono automaticamente consapevoli; i consapevoli che non cadono nel panico ricevono 2 turni. Passa alla Condizione 3.",
    sighting(0) + [bunker("H15", "H16"), activate([(20, "H15"), (21, "H15")], "crouching", adv="us", us_two=True),
                   {"op": "consapevoli_vede", "hex": "H15"}, cond(3)])
par("762", "1. Se non ci sono stati né s0 né s3, vedi 727.\n2. Se c’è stato s3, vedi 574.\n3. Se c’è stato s0, vedi 752.\n4. Se ci sono stati s0 e s3, nessun evento.",
    chain((ALL(NOT(S(0)), NOT(S(3))), [see("727")]), (ALL(S(3), NOT(S(0))), [see("574")]), (ALL(S(0), NOT(S(3))), [see("752")])))
par("763", "Si esegue la prima voce valida: 1. né s6, né s0, né s3: vedi 730; 2. né s6 né s3: 764; 3. né s0 né s3: 727; 4. né s6 né s0: 765; 5. non s0: 574; 6. non s3: 752; 7. non s6: 760; 8. altrimenti nessun evento.",
    chain((ALL(NOT(S(6)), NOT(S(0)), NOT(S(3))), [see("730")]), (ALL(NOT(S(6)), NOT(S(3))), [see("764")]),
          (ALL(NOT(S(0)), NOT(S(3))), [see("727")]), (ALL(NOT(S(6)), NOT(S(0))), [see("765")]),
          (NOT(S(0)), [see("574")]), (NOT(S(3)), [see("752")]), (NOT(S(6)), [see("760")])))
par("764", "[s6 e s3] Attiva il tedesco 86 in K11 e il 73 in E13, accovacciati. Iniziano i Round. Vantaggio tedesco. I tedeschi 73 e 86 ricevono 2 turni in questo Round. Passa alla Condizione 2.",
    sighting(6, 3) + [activate([(86, "K11"), (73, "E13")], "crouching", adv="de", two=[73, 86]), cond(2)])
par("765", "[s0 e s6] Attiva il tedesco 73 in E13, accovacciato, e i tedeschi 20 e 21 in H15, dentro un bunker con la porta verso H16. Iniziano i Round. Vantaggio tedesco. Passa alla Condizione 3.",
    sighting(0, 6) + [bunker("H15", "H16"), activate([(73, "E13"), (20, "H15"), (21, "H15")], "crouching", adv="de"), cond(3)])
par("766", "• Se il bunker è intatto, metti in effetto per questo tedesco la reazione speciale R: entra nel bunker. Se non c’è stato s0, vedi 725.\n• Se il bunker è distrutto, reazione speciale V.",
    [if_({"bunker_intatto": "H15"}, [reaz("R"), {"op": "entra_bunker", "hex": "H15"}, if_(NOT(S(0)), [see("725")])], [reaz("V")])], "movimento")
par("767", "[s5] Attiva i tedeschi 65 e 66, accovacciati, in S13, dentro un bunker con la porta verso T13. Iniziano i Round. Vantaggio tedesco. Passa alla Condizione 3.",
    sighting(5) + [bunker("S13", "T13"), activate([(65, "S13"), (66, "S13")], "crouching", adv="de"), cond(3)])
par("768", "Effettua un controllo di attivazione (−1):\n• se riesce, vedi 884;\n• se fallisce, controllo di percezione (+2): se riesce, vedi 575.",
    [act(-1, [see("884")], [pc(2, [see("575")])])])
par("771", "• Se il bunker è intatto, reazione speciale R per questo tedesco: entra nel bunker. Se non c’è stato s5, vedi 767.\n• Se il bunker è distrutto, reazione speciale V.",
    [if_({"bunker_intatto": "S13"}, [reaz("R"), {"op": "entra_bunker", "hex": "S13"}, if_(NOT(S(5)), [see("767")])], [reaz("V")])], "movimento")
par("772", "Metti in effetto per questo soldato la reazione speciale T.", [reaz("T")], "movimento")
par("773", "• Se sei appena entrato qui e vedi un americano attivo, reazione speciale X.\n• Se la reazione X è stata tolta o non vedi americani attivi, entra nell’esagono a nord-est.",
    [if_({"g_vede_us": True}, [reaz("X")], [{"op": "g_enter_dir", "dir": 1}])], "movimento")
par("774", "• Se si muove un tedesco con numero 50 o superiore, entra in Q11.\n• Se 49 o inferiore, entra in P10.",
    [if_({"g_ge": 50}, [enter("Q11")], [enter("P10")])], "movimento")
par("775", "Metti in effetto per questo tedesco la reazione speciale V.", [reaz("V")], "movimento")
par("776", "• Se un americano attivo vede S13, entra in S13.\n• Altrimenti entra in T12.",
    [if_({"see_hex": "S13"}, [enter("S13")], [enter("T12")])], "movimento")
par("778", "1. Se un americano attivo è sulla strada da N12 a Y8 o a sud di essa, entra in O13.\n2. Se è a nord di quella strada, entra in N11.\n3. Se non ci sono americani attivi sulla riva est, entra in N12.",
    [if_(NOT(EST), [enter("N12")], [if_({"us_strada": ["N12", "sud"]}, [enter("O13")], [enter("N11")])])], "movimento")
par("779", "• Se sei entrato qui da N12, entra in L11.\n• Se sei entrato da L11, entra in N12.",
    [if_({"g_da": ["N12"]}, [enter("L11")], [enter("N12")])], "movimento")
par("780", "• Se c’è un americano attivo sulla riva ovest, entra in K10.\n• Altrimenti entra in L11.",
    [if_(OVEST, [enter("K10")], [enter("L11")])], "movimento")
par("781", "1. Se un americano attivo è sulla strada da A6 a L11 o a sud di essa, entra in C8.\n2. Altrimenti entra in D7.",
    [if_({"us_strada": ["A6", "sud"]}, [enter("C8")], [enter("D7")])], "movimento")
par("782", "• Se un americano attivo vede H15, entra in H15.\n• Altrimenti entra in I7.",
    [if_({"see_hex": "H15"}, [enter("H15")], [enter("I7")])], "movimento")
par("783", "• Se nessun americano attivo è sulla strada da N12 a Y8 o a nord di essa, entra in P4.\n• Altrimenti entra in P3.",
    [if_({"us_strada": ["N12", "nord"]}, [enter("P3")], [enter("P4")])], "movimento")
par("784", "[s4] Attiva i tedeschi 27 e 28 nell’esagono S19, in piedi. Iniziano i Round. Vantaggio tedesco.",
    sighting(4) + [activate([(27, "S19"), (28, "S19")], "standing", adv="de")])
par("785", "[s4 e s8] Attiva i tedeschi 27, 28, 38 e 39 nell’esagono S19, in piedi. Iniziano i Round. Vantaggio tedesco.",
    sighting(4, 8) + [activate([(27, "S19"), (28, "S19"), (38, "S19"), (39, "S19")], "standing", adv="de")])
par("786", "[s8] Attiva i tedeschi 38 e 39 nell’esagono A11, in piedi. Iniziano i Round. Vantaggio tedesco.",
    sighting(8) + [activate([(38, "A11"), (39, "A11")], "standing", adv="de")])
par("872", "La canoa sta per rovesciarsi! Il soldato con la guida più alta fa un controllo d’incidente: se riesce, la controlla; se fallisce, la canoa si capovolge e affonda con l’equipaggiamento che trasportava (non quello personale). I soldati finiscono proni in un esagono di terra adiacente e si fa un controllo di paragrafo.",
    [])
par("874", "[s3] Attiva il tedesco 86 nell’esagono K11, in piedi. Iniziano i Round. Vantaggio americano. Tutti i soldati americani che vedono K11 sono automaticamente consapevoli. Passa alla Condizione 2.",
    sighting(3) + [activate([(86, "K11")], "standing", adv="us"), {"op": "consapevoli_vede", "hex": "K11"}, cond(2)])
par("876", "Campo minato! Esegui la procedura del campo minato. Se esplode una mina, passa alla Condizione 2.",
    [{"op": "minefield"}, if_(NOT({"no_mine_blast": True}), [cond(2)])])
par("877", "Metti un segnalino Evento. Effettua un controllo di percezione (+1):\n• se riesce, vedi 570;\n• se fallisce, vedi 753.",
    [{"op": "event_marker"}, pc(1, [see("570")], [see("753")])])
par("878", "Effettua un controllo di percezione:\n• se riesce, vedi 754;\n• se fallisce, vedi 571.", [pc(0, [see("754")], [see("571")])])
par("879", "Effettua un controllo di attivazione (+1). Se riesce, vedi 756.", [act(1, [see("756")])])
par("880", "Il tuo soldato nota i segni di un campo minato da O19 a S9.", [{"op": "linea_mine", "da": "O19", "a": "S9"}])
par("881", "Effettua un controllo di attivazione (−1):\n• se riesce, vedi 725;\n• se fallisce, controllo di percezione: se riesce, vedi 761.",
    [act(-1, [see("725")], [pc(0, [see("761")])])])
par("882", "Metti un segnalino Evento. Effettua un controllo di percezione (+1). Se riesce, vedi 761.",
    [{"op": "event_marker"}, pc(1, [see("761")])])
par("883", "1. Se non ci sono stati né s6 né s0, vedi 765.\n2. Se c’è stato s0, vedi 723.\n3. Se c’è stato s6, vedi 725.\n4. Se ci sono stati s6 e s0, nessun evento.",
    chain((ALL(NOT(S(6)), NOT(S(0))), [see("765")]), (ALL(S(0), NOT(S(6))), [see("723")]), (ALL(S(6), NOT(S(0))), [see("725")])))
par("884", "[s5] Attiva i tedeschi 65 e 66, in piedi, in S13, dentro un bunker con la porta verso T13. Iniziano i Round. Vantaggio americano. Tutti i soldati americani che vedono S13 sono automaticamente consapevoli; i consapevoli che non cadono nel panico ricevono 2 turni. Passa alla Condizione 3.",
    sighting(5) + [bunker("S13", "T13"), activate([(65, "S13"), (66, "S13")], "standing", adv="us", us_two=True),
                   {"op": "consapevoli_vede", "hex": "S13"}, cond(3)])
par("885", "Metti in effetto per questo tedesco la reazione speciale Y.", [reaz("Y")], "movimento")
par("887", "• Se vedi un americano attivo, entra in K12.\n• Altrimenti entra in L11.",
    [if_({"g_vede_us": True}, [enter("K12")], [enter("L11")])], "movimento")
par("888", "• Se sei entrato qui da O12, entra in M12.\n• Se sei entrato da M12, entra in O12.",
    [if_({"g_da": ["O12"]}, [enter("M12")], [enter("O12")])], "movimento")
par("889", "1. Se un americano attivo è sulla strada da A6 a L11 o a nord di essa, entra in G7.\n2. Se è a sud di quella strada, entra in F7.\n3. Se non ci sono americani attivi sulla riva ovest, entra in G9.",
    [if_(NOT(OVEST), [enter("G9")], [if_({"us_strada": ["A6", "nord"]}, [enter("G7")], [enter("F7")])])], "movimento")
par("890", "• Appena entrato qui: se il bunker è intatto, reazione speciale R; se è distrutto, reazione speciale V.\n• Se la reazione R o V è stata tolta, entra in H16.",
    [if_({"bunker_intatto": "@hex"}, [reaz("R")], [if_({"bunker_qui": True}, [reaz("V")], [enter("H16")])])], "movimento")
par("891", "• Se nessun americano attivo è sulla strada da N12 a Y8 o a nord di essa, entra in Q6.\n• Altrimenti entra in R6.",
    [if_({"us_strada": ["N12", "nord"]}, [enter("R6")], [enter("Q6")])], "movimento")
par("892", "Togli le reazioni speciali X e Y a tutti i tedeschi che le usano.", [{"op": "togli_reazioni", "r": ["X", "Y"]}])
par("893", "• Se non c’è stato s4, vedi 895.\n• Se c’è stato s4, vedi 786.", [if_(NOT(S(4)), [see("895")], [see("786")])])
par("894", "[s8] Attiva i tedeschi 38 e 39 nell’esagono S19, in piedi. Iniziano i Round. Vantaggio tedesco.",
    sighting(8) + [activate([(38, "S19"), (39, "S19")], "standing", adv="de")])
par("895", "[s4 e s8] Attiva i tedeschi 27, 28, 38 e 39 nell’esagono A11, in piedi. Iniziano i Round. Vantaggio tedesco.",
    sighting(4, 8) + [activate([(27, "A11"), (28, "A11"), (38, "A11"), (39, "A11")], "standing", adv="de")])
par("896", "1. Se un soldato americano attivo è sulla riva ovest del fiume, vedi 893.\n2. Se è sulla riva est, vedi 597.\n3. Nessun evento.",
    chain((OVEST, [see("893")]), (EST, [see("597")])))
par("897", "Se un soldato americano attivo vede l’esagono E6, vedi 899.", [if_({"see_hex": "E6"}, [see("899")])])
par("899", "[s7] Nell’esagono E6 c’è uno Sherman distrutto: metti il segnaposto.", sighting(7) + [{"op": "landmark", "hex": "E6", "name": "sherman"}])

AZ = {
"732": "• Se uno dei due mitraglieri tedeschi è inattivo, aiuta a sparare con la mitragliatrice: esegui 815.\n• Se sono inattivi entrambi, o nessuno dei due, esegui 802 con la tua arma.",
"770": "• Se c’è un bersaglio entro 3 esagoni, alzati e lancia una granata nell’esagono più vicino con più americani attivi entro 3 esagoni dal bunker.\n• Se non c’è un bersaglio entro 3 esagoni o non hai granate, alzati e spara con la tua arma al bersaglio più vicino.",
}
for _k, _v in AZ.items():
    par(_k, _v, [], "azione")

for k in list(P):
    if k in P1 or k in P2 or k in P3 or k in P4 or k in P5:
        del P[k]
