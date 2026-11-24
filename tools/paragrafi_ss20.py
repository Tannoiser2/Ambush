# -*- coding: utf-8 -*-
"""Silver Star – Missione 20 «Facile come bere un bicchier d’acqua» (Easy as Apple Pie; mappa F, Natale 1943 presso Cassino).

Un convoglio (tre camion e una jeep con mitragliatrice media) porta il pranzo caldo di Natale alla compagnia, che dovrebbe
presidiare una galleria fra le montagne. Testo inglese: tools/paragrafi_ss_en.json. Operazioni «ss_*»: scripts/motore/missioni_ss.gd.
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


def pari_dispari(lista_dispari, lista_pari):
    return [die(*[(i, i, lista_dispari if i % 2 else lista_pari) for i in range(10)])]


# ------------------------------------------------------------------ controlli ed eventi
par("100", "Campo minato! Esegui la procedura del campo minato.", [{"op": "minefield"}])
par("658", "Campo minato! Esegui la procedura del campo minato.", [{"op": "minefield"}])
par("102", "In questo esagono c’è un blocco stradale con una trappola esplosiva. Esegui la procedura della trappola: se esplode, per "
           "sgombrare il blocco basta un’azione. Se s0 non è avvenuto vedi 351; se s1 non è avvenuto vedi 681; se s2 non è avvenuto "
           "vedi 461.",
    [{"op": "ss_blocco", "hex": "@", "trappola": True}, if_(NOT(S(0)), [see("351")]), if_(NOT(S(1)), [see("681")]),
     if_(NOT(S(2)), [see("461")])])
par("103", "Colloca un segnalino Evento. Controllo di percezione (−1): se riesce vedi 579; altrimenti nessun evento.",
    [EVENT, pc(-1, [see("579")])])
par("104", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 579; altrimenti nessun evento.",
    [EVENT, pc(0, [see("579")])])
par("105", "Se non è ancora avvenuto nessun avvistamento, vedi 118. Se ne è avvenuto almeno uno, nessun evento (e da allora si ignora "
           "questo paragrafo).",
    [if_({"ss_nessun_avvistamento": True}, [see("118")])])
par("107", "Controllo di attivazione (+1): se riesce vedi 461; altrimenti nessun evento.", [act(1, [see("461")])])
par("108", "Controllo di attivazione: se riesce vedi 460; altrimenti nessun evento.", [act(0, [see("460")])])
par("110", "[s1] Attiva i tedeschi 16 e 17 accovacciati in L3. Iniziano i Round, vantaggio tedesco. Gli americani consapevoli che non "
           "vanno in panico ricevono 2 turni in questo Round.",
    sighting(1) + [activate([(16, "L3"), (17, "L3")], "crouching", adv="de", us_two=True)])
par("111", "[s1] Attiva i tedeschi 16 e 17 accovacciati in L3. Iniziano i Round, vantaggio tedesco. I tedeschi 16 e 17 ricevono 2 "
           "turni in questo Round.",
    sighting(1) + [activate([(16, "L3"), (17, "L3")], "crouching", adv="de", two=[16, 17])])
par("112", "Controllo di percezione: se riesce vedi 113. Se fallisce e s5 non è avvenuto, controllo di attivazione: se riesce vedi "
           "220; altrimenti nessun evento.",
    [pc(0, [see("113")], [if_(NOT(S(5)), [act(0, [see("220")])])])])
par("119", "Colloca un segnalino Evento. Controllo di percezione (−1): se riesce vedi 113. Se fallisce e s5 non è avvenuto, controllo "
           "di attivazione (−1): se riesce vedi 220; altrimenti nessun evento.",
    [EVENT, pc(-1, [see("113")], [if_(NOT(S(5)), [act(-1, [see("220")])])])])
BLOCCO = ("Si guadagna 1 PV quando il blocco è sgombrato. Nelle Operazioni basta un soldato nell’esagono e si fanno due controlli "
          "Evento. Nei Round lo si sgombra: 1) lanciando una carica da demolizione nell’esagono; 2) con una penetrazione pesante del "
          "bazooka (+2 per colpire); 3) spendendo 3 azioni (anche divise fra più soldati) con almeno un soldato accovacciato o in "
          "piedi nell’esagono, che lì è in copertura; 4) sfondandolo con un camion lanciato veloce, che deve entrare e uscire "
          "dall’esagono nello stesso turno facendo due controlli d’incidente: se ne fallisce uno il camion si ferma distrutto nel "
          "blocco e chi è a bordo tira sulla riga del fucile semiautomatico. La jeep è troppo leggera per sfondare.")
par("113", "[s0] C’è un blocco stradale in I5 (segnalino). " + BLOCCO, sighting(0) + [{"op": "ss_blocco", "hex": "I5"}])
par("351", "[s0] C’è un blocco stradale in K6 (segnalino). " + BLOCCO, sighting(0) + [{"op": "ss_blocco", "hex": "K6"}])
par("118", "1. Se leggi questo paragrafo per la prima volta: cosa ci fate qui a girovagare? Sarà solo il pranzo per la compagnia, ma "
           "lo vogliono ancora caldo.\n2. Se lo leggi per la seconda volta: muovetevi, prima che il sergente diventi caporale.\n3. Dalla "
           "terza volta in poi: perdi 1 PV ogni volta.",
    [{"op": "ss_girovagare"}])
par("130", "1. Se s1 non è avvenuto, vedi 469.\n2. Se s0 non è avvenuto, vedi 240.\n3. Se s2 non è avvenuto, vedi 108.\n4. Nessun evento.",
    [if_(NOT(S(1)), [see("469")], [if_(NOT(S(0)), [see("240")], [if_(NOT(S(2)), [see("108")])])])])
par("131", "1. Se s0 non è avvenuto, vedi 351.\n2. Se s1 non è avvenuto, vedi 468.\n3. Se s2 non è avvenuto, vedi 107.\n4. Nessun evento.",
    [if_(NOT(S(0)), [see("351")], [if_(NOT(S(1)), [see("468")], [if_(NOT(S(2)), [see("107")])])])])
par("133", "Il soldato con la percezione più alta fa un controllo di percezione: se riesce vedi 353 (ma 359 se il dado è esattamente "
           "uguale alla sua percezione); se fallisce vedi 136.",
    [{"op": "ss_pc_esatto", "ok": "353", "esatto": "359", "ko": "136"}])
par("134", "Colloca un segnalino Evento. Controllo di percezione (−1): se riesce vedi 248; altrimenti nessun evento.",
    [EVENT, pc(-1, [see("248")])])
par("135", "1. Se s2 non è avvenuto, tira un dado: dispari vedi 461, pari vedi 460.\n2. Se s1 non è avvenuto, tira un dado: dispari "
           "vedi 680, pari vedi 681.\n3. Colloca un segnalino Evento: nessun evento.",
    [if_(NOT(S(2)), pari_dispari([see("461")], [see("460")]), [if_(NOT(S(1)), pari_dispari([see("680")], [see("681")]), [EVENT])])])
par("136", "Controllo di attivazione: se riesce vedi 249; altrimenti vedi 353.", [act(0, [see("249")], [see("353")])])
par("137", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 248 con vantaggio americano. Se fallisce, controllo di "
           "attivazione: se riesce vedi 248 con vantaggio tedesco; altrimenti nessun evento.",
    [EVENT, pc(0, [see("248"), {"op": "ss_vantaggio", "lato": "us"}], [act(0, [see("248"), {"op": "ss_vantaggio", "lato": "de"}])])])
par("138", "Controllo di percezione (+1): se riesce vedi 248 con vantaggio americano. Se fallisce, controllo di attivazione (+1): se "
           "riesce vedi 248 con vantaggio tedesco; altrimenti vedi 248.",
    [pc(1, [see("248"), {"op": "ss_vantaggio", "lato": "us"}], [act(1, [see("248"), {"op": "ss_vantaggio", "lato": "de"}], [see("248")])])])
par("220", "[s5] Tira un dado e rimetti in mappa, accovacciati, i tedeschi rimossi fra questi: 18 (dispari E3, pari H7); 19 e 20 "
           "(dispari H7, pari E3); 48 (dispari K3, pari H1); 49 (dispari K9, pari I8); 50 (D2). Chi aveva finito le munizioni è "
           "rifornito; chi ha usato granate tira un dado: 0–4 nessuna, 5–7 una, 8–9 due (mai più di quante ne aveva all’inizio).",
    sighting(5) + [{"op": "ss_riattiva", "dispari": {"18": "E3", "19": "H7", "20": "H7", "48": "K3", "49": "K9", "50": "D2"},
                    "pari": {"18": "H7", "19": "E3", "20": "E3", "48": "H1", "49": "I8", "50": "D2"}}])
par("240", "Controllo di percezione: se riesce vedi 351; altrimenti nessun evento.", [pc(0, [see("351")])])
par("242", "Trappola esplosiva! Esegui la procedura della trappola esplosiva.", [{"op": "boobytrap"}])
par("245", "Qui c’è un imbocco della galleria stradale che attraversa la montagna da W7 a W9. Nella galleria si pagano i costi della "
           "strada; chi la percorre è nascosto (segnalino prono rovesciato). Per la vista i lati W6/W7 e W9/W10 contano come porte; "
           "per il buio, da W6 o W10 si vede un solo esagono dentro la galleria, mentre da W7 o W9 si vede fuori senza limiti. Un mezzo "
           "che va veloce in galleria e deve fare un controllo d’incidente (anche per il fuoco) applica il 465. In galleria valgono i "
           "paragrafi con la T davanti; quelli senza T sono per chi passa sopra la galleria.",
    [{"op": "ss_galleria"}])
par("465", "Nello spazio stretto della galleria l’incidente si risolve normalmente, ma si toglie 2 al dado dei danni. Se due mezzi si "
           "scontrano o restano fuori uso nello stesso esagono della galleria, per aprire un varco servono 6 azioni nei Round o 2 "
           "controlli Evento nelle Operazioni; poi uno dei due mezzi (a scelta) si sposta di un esagono verso l’imbocco da cui è entrato.",
    [])
par("248", "[s4] Nido di mitragliatrici! Attiva i tedeschi 19 e 20 accovacciati: con un dispari in P15, con un pari in O14. Iniziano i "
           "Round.",
    sighting(4) + pari_dispari([activate([(19, "P15"), (20, "P15")], "crouching")], [activate([(19, "O14"), (20, "O14")], "crouching")]))
PAVIMENTO = ("Il pavimento del piano superiore sopra la strada conta come un muro di legno per il fuoco; se il bazooka lo colpisce da "
             "sotto, chi è al piano di sotto tira i danni come dietro un muro colpito dal bazooka (riga del fucile semiautomatico).")
par("249", "[s3] Attiva il tedesco 18 in piedi al piano superiore di U13. Iniziano i Round, vantaggio tedesco. " + PAVIMENTO,
    sighting(3) + [activate([(18, "U13")], "standing", adv="de"), {"op": "ss_piano", "g": 18}])
par("353", "[s3] Attiva il tedesco 18 in piedi al piano superiore di U13. Iniziano i Round, vantaggio americano. " + PAVIMENTO,
    sighting(3) + [activate([(18, "U13")], "standing", adv="us"), {"op": "ss_piano", "g": 18}])
par("359", "[s3] Attiva il tedesco 18 in piedi al piano superiore di U13. Iniziano i Round, vantaggio tedesco; l’americano che ha "
           "superato il controllo riceve 2 turni in questo Round. " + PAVIMENTO,
    sighting(3) + [activate([(18, "U13")], "standing", adv="de", us_two=True), {"op": "ss_piano", "g": 18}])
par("300", "Nota sui carri negli edifici e sul filo spinato (non usata in questa missione).", [])
par("334", "Campo minato! Esegui la procedura del campo minato.\n1. Se superi il controllo di percezione e nessuna mina esplode: se s1 "
           "non è avvenuto vedi 681; se s6 non è avvenuto vedi 651; se entrambi sono avvenuti, nessun evento.\n2. Se fallisci il "
           "controllo e il soldato subisce la mina ma resta attivo: se s1 non è avvenuto vedi 680; se s6 non è avvenuto vedi 790; "
           "altrimenti nessun evento.\n3. Se il soldato è reso inattivo dalla mina, nessun altro evento.",
    [{"op": "minefield"},
     if_({"no_mine_blast": True}, [if_(NOT(S(1)), [see("681")], [if_(NOT(S(6)), [see("651")])])],
         [if_({"ss_vittima_mina_attiva": True}, [if_(NOT(S(1)), [see("680")], [if_(NOT(S(6)), [see("790")])])])])])
par("335", "Se si muove un mezzo entrato qui direttamente da F4, vedi 641. Se s2 non è avvenuto, vedi 130. Altrimenti nessun evento.",
    [if_(ALL(VEIC, {"ss_entrato_da": "F4"}), [see("641")]), if_(NOT(S(2)), [see("130")])])
par("336", "Se si muove un mezzo entrato qui direttamente da G4, vedi 641. Altrimenti nessun evento.",
    [if_(ALL(VEIC, {"ss_entrato_da": "G4"}), [see("641")])])
par("641", "Tagliare le curve si paga! Controllo d’incidente immediato.", [{"op": "ss_incidente"}])
par("350", "Controllo di percezione (+2): se riesce vedi 351. Se fallisce e s1 non è avvenuto, controllo di attivazione (+1): se "
           "riesce vedi 680; altrimenti nessun evento.",
    [pc(2, [see("351")], [if_(NOT(S(1)), [act(1, [see("680")])])])])
par("T358", "Quando l’ultimo mezzo americano attivo entra in W7, vedi 464. Se un mezzo che non è ancora entrato in W7 diventa inattivo e "
            "tutti gli altri ci sono già entrati, vedi subito 464.",
    [{"op": "ss_galleria_358"}])
par("390", "[s1] Attiva i tedeschi 74 e 75 accovacciati in K10. Iniziano i Round, vantaggio tedesco.", [])
par("460", "[s2] Attiva il tedesco 50 accovacciato in D2, il 48 in piedi in J1 e il 49 in piedi in I8. Iniziano i Round, vantaggio "
           "tedesco.",
    sighting(2) + [activate([(50, "D2")], "crouching", adv="de"), activate([(48, "J1"), (49, "I8")], "standing", adv="de")])
par("461", "[s2] Attiva il tedesco 48 in piedi in I1, il 49 accovacciato in H7 e il 50 accovacciato in D2. Iniziano i Round, vantaggio "
           "americano.",
    sighting(2) + [activate([(48, "I1")], "standing", adv="us"), activate([(49, "H7"), (50, "D2")], "crouching", adv="us")])
par("464", "Togli dalla mappa i tedeschi 16, 17, 48, 49 e 50 ancora attivi: 1 PV per ciascuno.",
    [{"op": "ss_rimuovi_bonus", "g": [16, 17, 48, 49, 50]}])
par("468", "Controllo di attivazione (+1): se riesce vedi 680; altrimenti vedi 681.", [act(1, [see("680")], [see("681")])])
par("469", "Controllo di attivazione: se riesce vedi 680; altrimenti nessun evento.", [act(0, [see("680")])])
par("528", "Controllo di percezione: se riesce vedi 648; altrimenti vedi 460.", [pc(0, [see("648")], [see("460")])])
par("532", "Controllo di percezione: se riesce vedi 461; altrimenti vedi 649.", [pc(0, [see("461")], [see("649")])])
par("534", "Controllo di percezione: se riesce vedi 681; altrimenti vedi 680.", [pc(0, [see("681")], [see("680")])])
par("535", "Controllo di percezione: se riesce vedi 652; altrimenti vedi 653.", [pc(0, [see("652")], [see("653")])])
par("536", "Controllo di percezione: se riesce vedi 654; altrimenti vedi 655.", [pc(0, [see("654")], [see("655")])])
par("537", "Se s2 non è avvenuto, tira un dado: dispari vedi 656, pari vedi 657. Se s2 è avvenuto e s6 no, vedi 790. Se sono avvenuti "
           "entrambi, colloca un segnalino Evento: nessun evento.",
    [if_(NOT(S(2)), pari_dispari([see("656")], [see("657")]), [if_(NOT(S(6)), [see("790")], [EVENT])])])
par("570", "Se s0 e s1 sono avvenuti entrambi, colloca un segnalino Evento: nessun evento. Altrimenti controllo di percezione (+2): se "
           "riesce, vedi 351 se s0 non è avvenuto, altrimenti 681 se s1 non è avvenuto. Se fallisce e s1 non è avvenuto, controllo di "
           "attivazione: se riesce vedi 680.",
    [if_(ALL(S(0), S(1)), [EVENT], [pc(2, [if_(NOT(S(0)), [see("351")], [if_(NOT(S(1)), [see("681")])])],
                                       [if_(NOT(S(1)), [act(0, [see("680")])])])])])
par("578", "Colloca un segnalino Evento. Controllo di attivazione (−1): se riesce vedi 790; altrimenti nessun evento.",
    [EVENT, act(-1, [see("790")])])
par("579", "[s7] Il soldato nota un movimento sul livello 4, verso S10 e R9.", sighting(7))
par("601", "Il ponte distrutto in questo esagono è impraticabile: si torna nell’esagono da cui si è entrati. Nei Round, un mezzo fa un "
           "controllo d’incidente (se lo supera torna indietro senza costo e continua, altrimenti torna indietro e il turno finisce); un "
           "soldato fa un controllo di percezione (se lo supera torna indietro senza costo, altrimenti torna indietro, cade prono e il "
           "turno finisce).",
    [{"op": "ss_ponte_rotto"}])
par("630", "Controllo di percezione: se riesce vedi 461; altrimenti vedi 460.", [pc(0, [see("461")], [see("460")])])
par("648", "[s2] Attiva il tedesco 48 in piedi in I8, il 49 in piedi in J1 e il 50 accovacciato in D2. Iniziano i Round, vantaggio "
           "americano.",
    sighting(2) + [activate([(48, "I8"), (49, "J1")], "standing", adv="us"), activate([(50, "D2")], "crouching", adv="us")])
par("649", "[s2] Attiva il tedesco 48 in piedi in I1, il 49 in piedi in H7 e il 50 accovacciato in D2. Iniziano i Round, vantaggio "
           "tedesco.",
    sighting(2) + [activate([(48, "I1"), (49, "H7")], "standing", adv="de"), activate([(50, "D2")], "crouching", adv="de")])
par("651", "[s6] Attiva la squadra del mortaio (tedesco 47) in S10. Iniziano i Round, vantaggio americano. Vedi 791 per il mortaio.",
    sighting(6) + [{"op": "ss_mortaio", "hex": "S10", "adv": "us"}])
par("790", "[s6] Attiva la squadra del mortaio (tedesco 47) in S10. Iniziano i Round, vantaggio tedesco. Vedi 791 per il mortaio.",
    sighting(6) + [{"op": "ss_mortaio", "hex": "S10", "adv": "de"}])
par("791", "Il mortaio (segnalino 791) si attiva con il colpo pronto, con i tre serventi accovacciati nell’esagono. Gittata minima 7 "
           "esagoni (esclusi); in un turno si può sparare un colpo e prepararne un altro. L’abilità del servente non conta; gli "
           "americani non possono usarlo. Prima si controlla il colpo a vuoto (05), poi il bersaglio: il mezzo visibile più vicino a "
           "S10 a 7 o più esagoni; altrimenti l’esagono visibile con più americani; altrimenti un esagono a caso. Il punto d’impatto "
           "si sposta col diagramma A (B se si ripete il tiro sul segnalino o a 2 esagoni da lui). Danni: allo scoperto, su strada o "
           "in copertura riga Granata al chiuso; in un edificio riga Granata all’aperto (con ucciso crolla un lato e tutti tirano sulla "
           "riga del fucile semiautomatico); su un mezzo riga Granata all’aperto: con incapacitato o ucciso il mezzo è fuori uso e chi "
           "è a bordo tira sulla riga della carabina, altrimenti tira sulla riga della pistola.",
    [])
par("652", "[s4] Avete sorpreso una squadra di mitraglieri tedeschi! Attiva i tedeschi 19 e 20 accovacciati in O14. Iniziano i Round, "
           "vantaggio americano.", sighting(4) + [activate([(19, "O14"), (20, "O14")], "crouching", adv="us")])
par("653", "[s4] Nido di mitragliatrici! Attiva i tedeschi 19 e 20 accovacciati in O14. Iniziano i Round, vantaggio tedesco.",
    sighting(4) + [activate([(19, "O14"), (20, "O14")], "crouching", adv="de")])
par("654", "[s4] Avete sorpreso una squadra di mitraglieri tedeschi! Attiva i tedeschi 19 e 20 accovacciati in P15. Iniziano i Round, "
           "vantaggio americano.", sighting(4) + [activate([(19, "P15"), (20, "P15")], "crouching", adv="us")])
par("655", "[s4] Nido di mitragliatrici! Attiva i tedeschi 19 e 20 accovacciati in P15. Iniziano i Round, vantaggio tedesco.",
    sighting(4) + [activate([(19, "P15"), (20, "P15")], "crouching", adv="de")])
par("656", "[s2] Attiva accovacciati il tedesco 48 in F14, il 49 in J17 e il 50 in G19. Iniziano i Round; controllo di percezione: se "
           "riesce vantaggio americano, altrimenti tedesco.",
    sighting(2) + [activate([(48, "F14"), (49, "J17"), (50, "G19")], "crouching", adv="pc")])
par("657", "[s2] Attiva accovacciati il tedesco 48 in I18, il 49 in E15 e il 50 in E19. Iniziano i Round; controllo di percezione: se "
           "riesce vantaggio americano, altrimenti tedesco.",
    sighting(2) + [activate([(48, "I18"), (49, "E15"), (50, "E19")], "crouching", adv="pc")])
par("792", "[s2] Con un numero d’azione tedesco dispari attiva accovacciati il tedesco 48 in F14, il 49 in J17 e il 50 in G19; con un "
           "pari il 48 in I18, il 49 in E15 e il 50 in E19. Iniziano i Round.",
    sighting(2) + [if_(DISPARI, [activate([(48, "F14"), (49, "J17"), (50, "G19")], "crouching")],
                       [activate([(48, "I18"), (49, "E15"), (50, "E19")], "crouching")])])
par("680", "[s1] Attiva i tedeschi 16 e 17 accovacciati in Q9. Iniziano i Round, vantaggio tedesco.",
    sighting(1) + [activate([(16, "Q9"), (17, "Q9")], "crouching", adv="de")])
par("681", "[s1] Attiva i tedeschi 16 e 17 accovacciati in Q9. Iniziano i Round, vantaggio americano.",
    sighting(1) + [activate([(16, "Q9"), (17, "Q9")], "crouching", adv="us")])
par("793", "[s1] Attiva i tedeschi 16 e 17 accovacciati in L3. Iniziano i Round, vantaggio americano. Gli americani consapevoli che non "
           "vanno in panico ricevono 2 turni; chi ha superato il controllo di percezione è consapevole.",
    sighting(1) + [activate([(16, "L3"), (17, "L3")], "crouching", adv="us", us_two=True, aware=True)])
par("796", "Colloca un segnalino Evento. Controllo di attivazione (+1): se riesce vedi 111. Se fallisce, controllo di percezione (+1): se "
           "riesce vedi 110; altrimenti nessun evento.",
    [EVENT, act(1, [see("111")], [pc(1, [see("110")])])])
par("797", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 793. Se fallisce, controllo di attivazione: se riesce "
           "vedi 110; altrimenti nessun evento.",
    [EVENT, pc(0, [see("793")], [act(0, [see("110")])])])
par("798", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 793. Se fallisce, controllo di attivazione (−1): se "
           "riesce vedi 110; altrimenti nessun evento.",
    [EVENT, pc(0, [see("793")], [act(-1, [see("110")])])])
FINE = ("Si evita di perdere PV per i feriti gravi e i morti portandoli fuori. Servono 6 PV per vincere. Chi esce dalla mappa, uomo o "
        "mezzo, non può tornare.")
par("683", "La missione finisce quando tutti i mezzi americani attivi sono usciti da A8 e tutti i soldati attivi da A7–A9. " + FINE +
           " Se s1 non è avvenuto, vedi subito 110.",
    [{"op": "ss_fine_20", "mezzi": ["A8"], "soldati": ["A7", "A8", "A9"]}, if_(NOT(S(1)), [see("110")])])
par("685", "Si passa alla Condizione 2. [s5] Tira un dado e rimetti in mappa, accovacciati, i tedeschi rimossi fra questi: 16 e 17 "
           "(dispari K19, pari G19), 48 (dispari I13, pari H13), 49 (dispari G14, pari F13), 50 (dispari A19, pari E19); 16, 17 e 50 "
           "nella reazione speciale D. Munizioni rifornite, granate come al 220. Iniziano i Round. Se tutti questi tedeschi sono fuori "
           "combattimento e s6 non è avvenuto, vedi subito 790; se qualcuno torna in mappa e s6 non è avvenuto, all’inizio del prossimo "
           "Round leggi 790 al posto del controllo Evento. Se s4 non è avvenuto, vedi 248. La missione finisce nella Condizione 2 "
           "quando tutti gli americani attivi sono usciti (i mezzi da B19, i soldati da A19–C19). " + FINE,
    [cond(2)] + sighting(5) + [{"op": "ss_riattiva", "reazione": {"16": "D", "17": "D", "50": "D"},
                                "dispari": {"16": "K19", "17": "K19", "48": "I13", "49": "G14", "50": "A19"},
                                "pari": {"16": "G19", "17": "G19", "48": "H13", "49": "F13", "50": "E19"}, "round": True},
                               {"op": "ss_dopo_685"}, if_(NOT(S(4)), [see("248")]),
                               {"op": "ss_fine_20", "mezzi": ["B19"], "soldati": ["A19", "B19", "C19"]}])
par("713", "Il resto della compagnia dovrebbe essere nella zona fra W6 e W10. Portate là il pranzo, il più in fretta possibile.", [])
par("T794", "[s8] Ormai avreste dovuto vedere qualche segno della compagnia: l’avanzata deve andare meglio del previsto. Il sergente "
            "decide di proseguire lungo la strada finché non la trova. I tedeschi ancora attivi in mappa vengono tolti appena non "
            "hanno più la vista su un mezzo americano attivo. Si guadagna 1 PV per ogni servente del mortaio ancora attivo quando il "
            "tedesco 47 viene tolto per questo paragrafo.",
    sighting(8) + [{"op": "ss_794"}])
par("795", "Quando l’ultimo americano attivo è a est della colonna L (compresa) e a nord della riga 14 (compresa), togli il tedesco 47 "
           "dalla mappa: 1 PV per ogni tedesco ancora attivo in quel momento.",
    [{"op": "ss_nota_795"}])
par("799", "Si passa alla Condizione 3.", [cond(3)])
par("990", "Se un camion è fuori uso per il fuoco o per un incidente, vedi 932. Altrimenti nessun evento.",
    [if_({"ss_camion_fuori_uso": True}, [see("932")])])
par("932", "La benzina che esce dal serbatoio squarciato prende fuoco e il camion (a caso, se più d’uno) esplode: al suo posto resta un "
           "cratere. Chi è a bordo tira sulla riga Carica al chiuso (non prono); chi è su un altro mezzo nello stesso esagono sulla riga "
           "Carica all’aperto (prono); chi è a piedi nell’esagono sulla riga Carica all’aperto nella sua postura. Un altro mezzo "
           "nell’esagono tira sulla riga Carica all’aperto: con ucciso o incapacitato è fuori uso.",
    [{"op": "ss_camion_esplode"}])
par("991", "Se in mappa c’è una trappola esplosiva che non è esplosa quando è stata scoperta, una (a caso) non era del tutto disinnescata "
           "ed esplode ora: chi è nell’esagono tira sulla riga Granata al chiuso nella sua postura. Solo una volta per missione.",
    [{"op": "ss_trappola_ritardata"}])
par("992", "Un’arma tedesca usata nel Round precedente finisce le munizioni (a caso se più d’una); vale anche per il mortaio. Può "
           "capitare più volte.", [{"op": "ammo_out"}])
par("993", "Un soldato americano non prono, a caso, in un esagono che non sia strada né scoperto, cade: controllo di percezione; se "
           "riesce non si fa nulla ma cade prono, altrimenti tira i danni come colpito da una pistola. Solo una volta per missione.",
    [{"op": "ss_caduta"}])
par("995", "Un tedesco ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Solo una volta per missione.",
    [{"op": "dissanguamento", "chiave": "995", "lato": "de"}])
par("996", "Un tedesco incapacitato, scelto a caso, muore per le ferite. Solo una volta per missione.",
    [{"op": "morte_incapacitato", "chiave": "996", "lato": "de"}])
par("997", "Un americano ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Solo una volta per missione.",
    [{"op": "dissanguamento", "chiave": "997", "lato": "us"}])
par("998", "Un americano incapacitato, scelto a caso, muore per le ferite. Solo una volta per missione.",
    [{"op": "morte_incapacitato", "chiave": "998", "lato": "us"}])
par("999", "Un mezzo attivo (a caso) fora una gomma: controllo d’incidente, poi va solo piano. Con una seconda foratura nei Round resta "
           "fermo finché non si spendono 5 azioni per cambiare la ruota (nelle Operazioni nessun effetto). Solo una volta per missione.",
    [{"op": "ss_gomma_convoglio"}])

# ------------------------------------------------------------------ movimento dei tedeschi (riferimenti rossi)
mov("198", "Se si muove un soldato, entra in P4; se si muove un mezzo, in R4.", [if_(VEIC, [enter("R4")], [enter("P4")])])
mov("243", "Se è al piano superiore di T12, scende al piano terra. Se è al piano terra di T12 e vede un americano, entra in S13; "
           "altrimenti in T13.",
    [if_({"ss_al_piano": True}, [{"op": "ss_scendi_piano"}], [if_({"g_vede_us": True}, [enter("S13")], [enter("T13")])])])
mov("244", "Se c’è un americano attivo entro 3 esagoni, entra in J15; altrimenti in J14.",
    [if_({"ss_us_entro": 3}, [enter("J15")], [enter("J14")])])
mov("246", "Se vede un americano, entra in N15; altrimenti in M15.", [if_({"g_vede_us": True}, [enter("N15")], [enter("M15")])])
mov("247", "Se vede un americano, entra in P13; altrimenti in P14.", [if_({"g_vede_us": True}, [enter("P13")], [enter("P14")])])
mov("333", "Toglie la reazione speciale M. Se vede un bersaglio attivo, esegue il paragrafo della colonna D per il numero d’azione "
           "attuale (senza passare alla reazione D); altrimenti si accovaccia.",
    [{"op": "ss_333"}])
mov("354", "Se c’è un americano attivo entro 3 esagoni, entra in I16; altrimenti in H15.",
    [if_({"ss_us_entro": 3}, [enter("I16")], [enter("H15")])])
mov("355", "Con un numero d’azione dispari entra in L15, con un pari in L16.", [if_(DISPARI, [enter("L15")], [enter("L16")])])
mov("356", "Se ci sono più americani attivi sulla strada e a sud di essa che a nord, entra in F16; altrimenti in F15.",
    [if_({"ss_us_sud_strada": True}, [enter("F16")], [enter("F15")])])
mov("357", "Se c’è un americano attivo entro 3 esagoni, entra in H16; altrimenti in G16.",
    [if_({"ss_us_entro": 3}, [enter("H16")], [enter("G16")])])
mov("463", "Se né il 16 né il 17 sono attivi in M13, entra in N14; altrimenti in O16.",
    [if_({"ss_g_attivi_in": [[16, 17], "M13"]}, [enter("O16")], [enter("N14")])])
mov("571", "Se si muove il 19 o il 20, entra in N13; altrimenti in N14.", [if_({"g_num": [19, 20]}, [enter("N13")], [enter("N14")])])
mov("572", "Se vede un americano: con un numero d’azione dispari entra in O14, con un pari in P15. Altrimenti entra in O15.",
    [if_({"g_vede_us": True}, [if_(DISPARI, [enter("O14")], [enter("P15")])], [enter("O15")])])
mov("573", "Se vede un americano, entra in Q16; altrimenti in Q15.", [if_({"g_vede_us": True}, [enter("Q16")], [enter("Q15")])])
mov("682", "Se c’è un americano attivo entro 3 esagoni, entra in M16; altrimenti in M15.",
    [if_({"ss_us_entro": 3}, [enter("M16")], [enter("M15")])])
mov("684", "Se non vede americani, entra in R15; altrimenti in R16.", [if_({"g_vede_us": True}, [enter("R16")], [enter("R15")])])
mov("686", "Se è al piano superiore di V13, scende al piano terra; se è al piano terra, entra in V14.",
    [if_({"ss_al_piano": True}, [{"op": "ss_scendi_piano"}], [enter("V14")])])
mov("687", "Con un numero d’azione dispari entra in D17, con un pari in E18.", [if_(DISPARI, [enter("D17")], [enter("E18")])])
mov("688", "Passa alla reazione speciale D.", [{"op": "g_reaction", "r": "D"}])
mov("689", "Con un numero d’azione dispari entra in T12, con un pari in V13.", [if_(DISPARI, [enter("T12")], [enter("V13")])])
mov("712", "Al piano terra nessun evento; al piano superiore vedi 133.", [if_({"ss_al_piano_us": True}, [see("133")])])
mov("431", "Se vede un bersaglio attivo, vedi 352. Se non ne vede e tutti i mezzi americani attivi sono passati per W10, esce dalla "
           "mappa. Altrimenti si sdraia prono; se a fine turno non vede nessun mezzo americano attivo, esce dalla mappa.",
    [{"op": "ss_431", "varco": "W10", "bonus": 0}])
mov("531", "Se vede un bersaglio attivo, vedi 352. Se non ne vede e tutti i mezzi americani attivi sono passati per W6, esce dalla mappa "
           "(1 PV). Altrimenti si sdraia prono; se a fine turno non vede nessun mezzo americano attivo, esce dalla mappa (1 PV).",
    [{"op": "ss_431", "varco": "W6", "bonus": 1}])

# ------------------------------------------------------------------ azioni dei tedeschi (codice in tedeschi_ss.gd)
PRIO = " Prima i mezzi, poi i soldati."
AZ = {
 "352": "1. Se vede un mezzo americano attivo e ha una granata, si accovaccia (fino a 3 esagoni) o si alza (da 4 a 6) e la lancia al "
        "mezzo visibile più vicino; poi prono se può. 2. Se vede un mezzo ma non ha granate o è fuori portata, si accovaccia e fa il "
        "miglior tiro al mezzo più vicino. 3. Se vede un soldato, si accovaccia e fa il miglior tiro al più vicino. 4. Se non vede "
        "bersagli, si muove il più in fretta possibile e fa un tiro rapido al primo bersaglio che compare.",
 "106": "Come il 352, ma con un soldato in vista spara al bersaglio più facile e, se non vede nessuno, fa il miglior tiro al primo "
        "mezzo o soldato che compare.",
 "114": "Come il 352, ma con un soldato in vista spara al bersaglio più facile; se non vede nessuno si muove il più in fretta possibile.",
 "115": "1. In U13, con una granata e un mezzo americano nell’esagono sotto, si sporge dalla finestra e la lascia cadere sul mezzo. 2. "
        "Con una granata e un mezzo in un esagono adiacente, si accovaccia e la lancia al mezzo più vicino al bordo est. 3. Senza "
        "granate, miglior tiro al bersaglio più vicino fuori dal suo esagono. 4. Senza americani in vista né entro 3 esagoni, esce "
        "dalla mappa. 5. Si accovaccia.",
 "241": "Come il 115, ma la granata va al mezzo più vicino al bordo ovest e, senza americani in vista né entro 3 esagoni, passa alla "
        "reazione speciale M.",
 "132": "Se vede un americano attivo, con il numero d’azione: 0–3: 815, 4: 840, 5–6: 841, 7–9: 770. Altrimenti: nella Condizione 1 si "
        "accovaccia, nella 2 si muove il più in fretta possibile, nella 3 esce dalla mappa." + PRIO,
 "139": "Se non vede americani, si muove il più in fretta possibile. Altrimenti, con il numero d’azione: 0–1: 815, 2: 840, 3–6: 770, "
        "7–9: 841." + PRIO,
 "462": "1. Se non vede bersagli e tutti gli americani sono a est della colonna N, esce dalla mappa (1 PV). 2. Se non vede bersagli ma ci "
        "sono americani nella colonna N o a ovest: granata al più vicino entro 3 esagoni (accovacciato) o da 4 a 6 (in piedi), −3 perché "
        "non lo vede; altrimenti si accovaccia. 3. Se vede un bersaglio, con il numero d’azione: 0–3: 802, 4–6: 808, 7–8: 824, 9: 800." + PRIO,
 "466": "1. In Q9 senza americani in vista, si alza, entra in R8, si accovaccia e fa il miglior tiro al bersaglio più facile. 2. Senza "
        "americani in vista e con tutti i mezzi americani passati per W6, esce dalla mappa (1 PV). 3. Con il numero d’azione: 0: 843, "
        "1–3: 841, 4–6: 815, 7–9: 770." + PRIO,
 "467": "1. In Q9 senza americani in vista, si alza, entra in R8, si accovaccia e fa il miglior tiro al bersaglio più vicino. 2. Senza "
        "americani in vista e con tutti i mezzi americani passati per W6, esce dalla mappa (1 PV). 3. Con il numero d’azione: 0–3: 841, "
        "4: 843, 5–8: 815, 9: 770." + PRIO,
 "549": "Squadra del mortaio. 1. Con un americano attivo nello stesso esagono, assalto per uccidere. 2. Con un americano in un esagono "
        "adiacente, miglior tiro al bersaglio più facile. 3. Con una granata e un bersaglio a 2–3 esagoni, granata nell’esagono con più "
        "americani. 4. Con una granata e un bersaglio visibile a 4–6 esagoni, si alza e la lancia. 5. Senza granate e con un bersaglio "
        "visibile a 4–6 esagoni, miglior tiro al più vicino. 6. Altrimenti, con il numero d’azione: 0–2: L 502, Q 503, T 504; 3–5: L 503, "
        "Q 504, T 502; 6–9: L 504, Q 502, T 503.",
 "502": "1. Se non c’è un colpo pronto, si accovaccia e lo prepara. 2. Se il colpo è pronto e il mortaio non ha ancora sparato in questo "
        "turno, si accovaccia e spara. 3. Si accovaccia.",
 "503": "1. Se il mortaio ha sparato in questo turno e il colpo non è ancora stato preparato, lo prepara. 2. Se il colpo è pronto e il "
        "mortaio non ha sparato, spara. 3. Si sdraia prono.",
 "504": "1. Se il colpo è pronto e il mortaio non ha sparato in questo turno, spara. 2. Se non c’è un colpo pronto, lo prepara. 3. Si "
        "sdraia prono.",
}
for k, v in AZ.items():
    par(k, v, [], "azione")
