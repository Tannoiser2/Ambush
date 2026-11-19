# -*- coding: utf-8 -*-
"""Paragrafi della Missione 2 «Avanzata su Chasoul» (mappa B).

Testo inglese da tools/paragrafi_en.json (OCR del libretto, controllato sulle scansioni quando
era troncato: 101, 148, 168, 169, 173). Per ogni paragrafo raggiungibile dalle carte Condizione
della missione 2 o dalle carte dei tedeschi che vi compaiono: testo italiano e script «ops».
I paragrafi già scritti per la missione 1 (001, 007, 010, 011, 012, 013, 020, 023, 192, 337) restano quelli.
"""
from paragrafi_m1 import pc, act, see, die, if_, S, NOT, ALL, sighting, activate, cond, EVENT, P as P1

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def vp(n, why):
    return {"op": "vp", "n": n, "why": why}


def reaction(g, r):
    return {"op": "g_reaction_num", "g": g, "r": r}


def indica(h):
    return {"op": "indica", "hex": h}


AWARE = {"op": "forza_consapevole"}
UNAWARE = {"op": "forza_inconsapevole"}

# ---------------------------------------------------------------- 0xx
par("000", "[s4] Il relitto abbandonato di un Panzer IV. Sembra messo lì apposta, come blocco stradale. Colloca un segnaposto. Solo Missione 2: se s2 non è avvenuto, vai al 148.",
    sighting(4) + [{"op": "landmark", "name": "carro", "hex": "@hex"}, if_(ALL({"mission": 2}, NOT(S(2))), [see("148")])])
par("002", "[s9] Il soldato vede un barile d’acqua piovana che riflette il sole.", sighting(9))
par("003", "[s9] Il soldato vede un cavallo morto in un canalone.", sighting(9))
par("004", "[s7] Il soldato vede un passero che svolazza nella stanza.", sighting(7))
par("005", "[s6] Il soldato vede un paio di occhiali da bambino rotti.", sighting(6))
par("006", "Il soldato trova una valigetta con i piani segreti dei prossimi movimenti delle truppe tedesche. Al comando di battaglione saranno ben contenti di averli. Ottieni 3 PV.",
    [vp(3, "piani segreti tedeschi")])
par("008", "Un caccia tedesco Me-109 compie un mitragliamento. Ottieni 1 PV. Tira un dado per la rotta: 0 colonna C; 1 colonna F; 2 colonna I; 3 colonna L; 4 colonna Q; 5 colonna U; 6 in diagonale da A9 a V19; 7 da A4 a Y16; 8 da C1 a Y12; 9 da A15 a Y3.\nOgni soldato americano che vede un esagono della rotta fa un controllo di percezione: chi riesce può sparare subito un tiro rapido all’aereo (gratuito: non consuma turni e non fa iniziare i Round). Al tiro si aggiungono 10 esagoni di distanza per la quota; l’aereo è un veicolo piccolo in terreno scoperto e cade in fiamme fuori mappa con una penetrazione leggera o migliore.\nPoi ogni soldato americano in un esagono scoperto, di strada o di macchia, sulla rotta o adiacente, è colpito come da una mitragliatrice pesante, se l’aereo non è stato abbattuto. Solo Missione 2: se il Me-109 è abbattuto, passa alla Condizione 6.",
    [vp(1, "passaggio del Me-109"), {"op": "strafe"}])
par("009", "Passa alla Condizione 4.", [cond(4)])
par("015", "I tuoi soldati vedono una formazione di B-17 diretta verso il cuore della Germania.", [])
par("016", "Trappola esplosiva! Esegui la procedura della trappola esplosiva.", [{"op": "boobytrap"}])

# ---------------------------------------------------------------- 1xx
par("100", "Tira un dado:\n0–8: nessun effetto. Colloca un segnalino Evento.\n9: effettua un controllo di percezione (−2). Se riesce, vedi 150.",
    [die((0, 8, [EVENT]), (9, 9, [pc(-2, [see("150")])]))])
par("101", "Effettua un controllo di percezione. Se riesce, vedi 111.", [pc(0, [see("111")])])
par("102", "Tira un dado:\n0–8: nessun effetto. Colloca un segnalino Evento.\n9: il soldato può fare un controllo di percezione (−3). Se riesce, vedi 159.",
    [die((0, 8, [EVENT]), (9, 9, [pc(-3, [see("159")])]))])
par("103", "Tira un dado:\n0–8: nessun effetto. Colloca un segnalino Evento.\n9: il soldato può fare un controllo di percezione (−1). Se riesce, vedi 165.",
    [die((0, 8, [EVENT]), (9, 9, [pc(-1, [see("165")])]))])
par("104", "Il soldato nota tracce fresche di pneumatici sulla strada sterrata, dirette verso l’esagono J14.", [])
par("105", "Tira un dado:\n0–2: effettua un controllo di attivazione (+3). Se riesce, vedi 160.\n3–8: effettua un controllo di attivazione (−2). Se riesce, vedi 155.\n9: il soldato può fare un controllo di percezione. Se riesce, vedi 150.",
    [die((0, 2, [act(3, [see("160")])]), (3, 8, [act(-2, [see("155")])]), (9, 9, [pc(0, [see("150")])]))])
par("106", "Tira un dado:\n0–8: nessun effetto. Colloca un segnalino Evento.\n9: il soldato può fare un controllo di percezione (−8). Se riesce, vedi 150.",
    [die((0, 8, [EVENT]), (9, 9, [pc(-8, [see("150")])]))])
par("107", "Tira un dado:\n0–1: effettua un controllo di attivazione (+3). Se riesce, vedi 020.\n2–8: effettua un controllo di attivazione (−2). Se riesce, vedi 155.\n9: il soldato può fare un controllo di percezione. Se riesce, vai al 150.",
    [die((0, 1, [act(3, [see("020")])]), (2, 8, [act(-2, [see("155")])]), (9, 9, [pc(0, [see("150")])]))])
par("109", "Tira un dado:\n0–8: nessun effetto. Colloca un segnalino Evento.\n9: il soldato può fare un controllo di percezione (−1). Se riesce, vedi 159.",
    [die((0, 8, [EVENT]), (9, 9, [pc(-1, [see("159")])]))])
par("110", "Tira un dado:\n0–8: nessun effetto. Colloca un segnalino Evento.\n9: il soldato può fare un controllo di percezione. Se riesce, vedi 150.",
    [die((0, 8, [EVENT]), (9, 9, [pc(0, [see("150")])]))])
par("111", "Il soldato nota tracce fresche di pneumatici sulla strada sterrata, dirette verso l’esagono J14.", [])
par("112", "Tira un dado:\n0–2: effettua un controllo di attivazione (+2). Se riesce, vedi 137.\n3–8: effettua un controllo di attivazione (−2). Se riesce, vedi 148.\n9: il soldato può fare un controllo di percezione. Se riesce, vedi 159.",
    [die((0, 2, [act(2, [see("137")])]), (3, 8, [act(-2, [see("148")])]), (9, 9, [pc(0, [see("159")])]))])
par("113", "Tira un dado:\n0–8: nessun effetto. Colloca un segnalino Evento.\n9: il soldato può fare un controllo di percezione (−1). Se riesce, vedi 165.",
    [die((0, 8, [EVENT]), (9, 9, [pc(-1, [see("165")])]))])
par("114", "Il soldato sente voci tedesche nell’esagono N12.", [])
par("115", "• Se il soldato è sul ponte, vai al 125.\n• Se il soldato è sotto il ponte, tira un dado:\n0–3: effettua un controllo di attivazione (+1). Se riesce, vedi 160.\n4–8: effettua un controllo di attivazione (−2). Se riesce, vedi 155.\n9: il soldato può fare un controllo di percezione. Se riesce, vedi 150.",
    [if_({"on_bridge": True}, [see("125")],
         [die((0, 3, [act(1, [see("160")])]), (4, 8, [act(-2, [see("155")])]), (9, 9, [pc(0, [see("150")])]))])])
par("116", "Tira un dado:\n0–2: effettua un controllo di attivazione (+3). Se riesce, vedi 020.\n3–8: effettua un controllo di attivazione (−2). Se riesce, vedi 148.\n9: il soldato può fare un controllo di percezione. Se riesce, vedi 159.",
    [die((0, 2, [act(3, [see("020")])]), (3, 8, [act(-2, [see("148")])]), (9, 9, [pc(0, [see("159")])]))])
par("118", "Tira un dado:\n0: effettua un controllo di attivazione (+3). Se riesce, vedi 137 e metti in effetto per questo tedesco la reazione speciale A.\n1–8: effettua un controllo di attivazione (−2). Se riesce, vedi 148 e metti in effetto la reazione speciale A.\n9: il soldato può fare un controllo di percezione. Se riesce, vedi 159 e metti in effetto la reazione speciale A.",
    [die((0, 0, [act(3, [see("137"), reaction(2, "A")])]), (1, 8, [act(-2, [see("148"), reaction(2, "A")])]),
         (9, 9, [pc(0, [see("159"), reaction(2, "A")])]))])
par("119", "Effettua un controllo di attivazione:\n• se riesce, vedi 154;\n• se fallisce, effettua un controllo di percezione. Se riesce, vedi 114.",
    [act(0, [see("154")], [pc(0, [see("114")])])])
par("120", "Tira un dado:\n0–8: nessun effetto. Colloca un segnalino Evento.\n9: se il soldato non è prono, effettua un controllo di percezione. Se riesce, vedi 150.",
    [die((0, 8, [EVENT]), (9, 9, [if_({"not_prone": True}, [pc(0, [see("150")])])]))])
par("122", "Il soldato nota un luccichio metallico nell’esagono V8.", [])
par("123", "Tira un dado:\n0: effettua un controllo di attivazione. Se riesce, vedi 137 e metti in effetto per questo tedesco la reazione speciale A.\n1–8: effettua un controllo di attivazione (−4). Se riesce, vedi 148 e metti in effetto la reazione speciale A.\n9: effettua un controllo di percezione (−2). Se riesce, vedi 159 e metti in effetto la reazione speciale A.",
    [die((0, 0, [act(0, [see("137"), reaction(2, "A")])]), (1, 8, [act(-4, [see("148"), reaction(2, "A")])]),
         (9, 9, [pc(-2, [see("159"), reaction(2, "A")])]))])
par("124", "[s3] Una mitragliatrice leggera apre il fuoco dall’esagono N12. Colloca i tedeschi 5 e 49 nell’esagono, accovacciati. Iniziano i Round. Vantaggio americano. Il soldato americano che ha appena superato il controllo di percezione è automaticamente consapevole. Tutti i soldati americani consapevoli che non cadono nel panico ricevono 2 turni nel primo Round.",
    sighting(3) + [activate([(5, "N12"), (49, "N12")], "crouching", adv="us", us_two=True, aware=True)])
par("125", "Tira un dado:\n0–3: effettua un controllo di attivazione (+3). Se riesce, vedi 020.\n4–8: effettua un controllo di attivazione (−2). Se riesce, vedi 155.\n9: effettua un controllo di percezione. Se riesce, vedi 150.",
    [die((0, 3, [act(3, [see("020")])]), (4, 8, [act(-2, [see("155")])]), (9, 9, [pc(0, [see("150")])]))])
par("126", "Serve s1. Se un soldato vede l’esagono K7, effettua un controllo di attivazione:\n• se riesce, vedi 137;\n• se fallisce, o se nessuno vede K7, ripeti lo stesso controllo per l’esagono G4: se riesce, vedi 167.\nSe fallisce anche questo, o nessuno vede nessuno dei due esagoni, nessun effetto.",
    [if_(S(1), [if_({"see_hex": "K7"}, [act(0, [see("137")], [if_({"see_hex": "G4"}, [act(0, [see("167")])])])],
                    [if_({"see_hex": "G4"}, [act(0, [see("167")])])])])])
par("127", "Tira un dado:\n0–8: nessun effetto. Colloca un segnalino Evento.\n9: se il soldato non è prono, effettua un controllo di percezione (−2). Se riesce, vedi 159.",
    [die((0, 8, [EVENT]), (9, 9, [if_({"not_prone": True}, [pc(-2, [see("159")])])]))])
par("128", "Un veicolo tedesco parte dall’esagono N12. Attiva il tedesco 19 nell’esagono. Iniziano i Round. Passa alla Condizione 5.",
    [{"op": "activate_vehicle", "g": 19, "hex": "N12"}, cond(5)])
par("129", "• Se la Condizione 5 è in effetto ora o lo è mai stata, vedi 171.\n• Se la Condizione 5 non è mai stata in effetto, vedi 139.",
    [if_({"cond_seen": 5}, [see("171")], [see("139")])])
par("130", "Tira un dado:\n0–2: effettua un controllo di attivazione (+1). Se riesce, vedi 160.\n3–8: effettua un controllo di attivazione (−2). Se riesce, vedi 155.\n9: effettua un controllo di percezione. Se riesce, vedi 150.",
    [die((0, 2, [act(1, [see("160")])]), (3, 8, [act(-2, [see("155")])]), (9, 9, [pc(0, [see("150")])]))])
par("131", "Un’arma tedesca che ha sparato nel Round precedente è senza munizioni. Se hanno sparato più armi, si sceglie a caso. Eccezione: una mitragliatrice in gioco può restare senza munizioni solo dalla Condizione 5 in poi.",
    [{"op": "ammo_out", "mg_da_condizione": 5}])
par("132", "Effettua un controllo di attivazione (+8):\n• se riesce, vedi 134;\n• se fallisce, effettua un controllo di percezione. Se riesce, vedi 122.",
    [act(8, [see("134")], [pc(0, [see("122")])])])
par("134", "Effettua un controllo di percezione (−2):\n• se riesce, vedi 170: il soldato è automaticamente consapevole nel Round che segue;\n• se fallisce, vedi 151: il soldato è automaticamente inconsapevole nel Round che segue.",
    [pc(-2, [AWARE, see("170")], [UNAWARE, see("151")])])
par("135", "Tira un dado:\n0–1: effettua un controllo di attivazione. Se riesce, vedi 160.\n2–8: effettua un controllo di attivazione (−2). Se riesce, vedi 155.\n9: effettua un controllo di percezione. Se riesce, vedi 150.",
    [die((0, 1, [act(0, [see("160")])]), (2, 8, [act(-2, [see("155")])]), (9, 9, [pc(0, [see("150")])]))])
par("136", "Effettua un controllo di attivazione (−1):\n• se riesce, vedi 154;\n• se fallisce, effettua un controllo di percezione. Se riesce, vedi 165.",
    [act(-1, [see("154")], [pc(0, [see("165")])])])
par("137", "[s2] Attivato un cecchino tedesco in K7. Colloca il tedesco 2 nell’esagono, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 2 riceve 2 turni in questo Round.",
    sighting(2) + [activate([(2, "K7")], "crouching", adv="de", two=[2])])
par("138", "Serve s2. Se un soldato americano vede l’esagono J13, effettua un controllo di attivazione: se riesce, vedi 160.\nSe fallisce, o nessuno vede J13, ripeti il controllo per l’esagono G13: se riesce, vedi 172. Altrimenti ripetilo per O5: se riesce, vedi 172. Altrimenti per L2: se riesce, vedi 172.\nSe tutti falliscono, o nessuno vede questi esagoni, nessun effetto.",
    [if_(S(2), [{"op": "catena", "passi": [["J13", [see("160")]], ["G13", [indica("G13"), see("172")]],
                                           ["O5", [indica("O5"), see("172")]], ["L2", [indica("L2"), see("172")]]]}])])
par("139", "• Se s3 è avvenuto e nell’esagono non ci sono tedeschi attivi, vedi 173.\n• Se s3 è avvenuto e nell’esagono ci sono tedeschi attivi, leggi il 173 quando nell’esagono restano attivi solo i tuoi soldati (annotalo sulla scheda della squadra).\n• Se s3 non è avvenuto, vedi 124.",
    [if_(S(3), [if_({"g_in_hex": True}, [{"op": "note_par", "p": "173"}], [see("173")])], [see("124")])])
par("140", "• Se s1 è avvenuto, effettua un controllo di percezione. Se riesce, vedi 104.\n• Se s1 non è avvenuto, vedi 105.",
    [if_(S(1), [pc(0, [see("104")])], [see("105")])])
par("141", "Effettua un controllo di attivazione (+3):\n• se riesce, vedi 154;\n• se fallisce, effettua un controllo di percezione. Se riesce, vedi 165.",
    [act(3, [see("154")], [pc(0, [see("165")])])])
par("142", "Effettua un controllo di attivazione (+2):\n• se riesce, vedi 134;\n• se fallisce, effettua un controllo di percezione. Se riesce, vedi 122.",
    [act(2, [see("134")], [pc(0, [see("122")])])])
par("144", "Un ricognitore tedesco Storch sorvola la zona. Effettua un controllo di attivazione (+2). Se riesce, passa alla Condizione 2.",
    [act(2, [cond(2)])])
par("147", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 154;\n• se fallisce, effettua un controllo di percezione. Se riesce, vedi 114.",
    [act(1, [see("154")], [pc(0, [see("114")])])])
par("148", "[s2] Attiva il tedesco 2 nell’esagono K7, accovacciato. Iniziano i Round. Vantaggio tedesco.",
    sighting(2) + [activate([(2, "K7")], "crouching", adv="de")])
par("149", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 134;\n• se fallisce, effettua un controllo di percezione. Se riesce, vedi 122.",
    [act(1, [see("134")], [pc(0, [see("122")])])])
par("150", "[s1] Noti il luccichio della canna di un fucile in J13. Attiva il tedesco 10 in J13, in piedi. Iniziano i Round. Vantaggio americano. Il soldato americano che ha appena superato il controllo di percezione è automaticamente consapevole. Tutti i soldati americani consapevoli che non cadono nel panico ricevono 2 turni in questo Round.",
    sighting(1) + [activate([(10, "J13")], "standing", adv="us", us_two=True, aware=True)])
par("151", "[s5] Attiva i tedeschi 26, 37 e 50 nell’esagono V8, tutti accovacciati. Iniziano i Round. I tedeschi in V8 ricevono 2 turni in questo Round.",
    sighting(5) + [activate([(26, "V8"), (37, "V8"), (50, "V8")], "crouching", two=[26, 37, 50])])
par("152", "Campo minato! Esegui la procedura del campo minato. Se nessuna mina è esplosa e s3 non è ancora avvenuto, vedi 169.",
    [{"op": "minefield"}, if_(ALL({"no_mine_blast": True}, NOT(S(3))), [see("169")])])
par("153", "Tira un dado:\n0–1: effettua un controllo di attivazione (+3). Se riesce, vedi 023.\n2–8: effettua un controllo di attivazione (−1). Se riesce, vedi 148.\n9: effettua un controllo di percezione. Se riesce, vedi 159.",
    [die((0, 1, [act(3, [see("023")])]), (2, 8, [act(-1, [see("148")])]), (9, 9, [pc(0, [see("159")])]))])
par("154", "Effettua un controllo di percezione (−1):\n• se riesce, vedi 124;\n• se fallisce, vedi 164. Il soldato è inconsapevole nel Round che segue.",
    [pc(-1, [see("124")], [UNAWARE, see("164")])])
par("155", "[s1] Attiva il tedesco 10 nell’esagono J13, accovacciato. Iniziano i Round.",
    sighting(1) + [activate([(10, "J13")], "crouching")])
par("156", "[s4] Il soldato vede un Panzer IV distrutto nell’esagono L6. Colloca il segnaposto del carro distrutto.",
    sighting(4) + [{"op": "landmark", "name": "carro", "hex": "L6"}])
par("158", "• Se s2 è avvenuto, effettua un controllo di attivazione. Se riesce, vedi 175.\n• Se s2 non è avvenuto, vedi 123.",
    [if_(S(2), [act(0, [see("175")])], [see("123")])])
par("159", "[s2] Noti un elmetto che si muove nell’esagono K7. Attiva il tedesco 2 in K7, in piedi. Iniziano i Round. Vantaggio americano. Il soldato americano che ha appena superato il controllo di percezione è automaticamente consapevole. Tutti i soldati americani consapevoli che non cadono nel panico ricevono 2 turni in questo Round.",
    sighting(2) + [activate([(2, "K7")], "standing", adv="us", us_two=True, aware=True)])
par("160", "[s1] Attiva il tedesco 10 nell’esagono J13, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 10 riceve 2 turni in questo Round.",
    sighting(1) + [activate([(10, "J13")], "crouching", adv="de", two=[10])])
par("161", "Servono s1 e s2. Passa alla Condizione 3.", [if_(ALL(S(1), S(2)), [cond(3)])])
par("162", "Effettua un controllo di attivazione:\n• se riesce, vedi 134;\n• se fallisce, effettua un controllo di percezione. Se riesce, vedi 122.",
    [act(0, [see("134")], [pc(0, [see("122")])])])
par("163", "Se si muove un veicolo, entra nell’esagono O12. Se si muove un soldato, entra nell’esagono N18.",
    [if_({"vehicle_moving": True}, [{"op": "g_enter", "hex": "O12"}], [{"op": "g_enter", "hex": "N18"}])], "movimento")
par("164", "[s3] Una mitragliatrice leggera apre il fuoco. Attiva i tedeschi 5 e 49 nell’esagono N12, accovacciati. Iniziano i Round. Vantaggio tedesco. I tedeschi 5 e 49 ricevono 2 turni in questo Round.",
    sighting(3) + [activate([(5, "N12"), (49, "N12")], "crouching", adv="de", two=[5, 49])])
par("165", "Il soldato nota una rete mimetica nell’esagono N12.", [])
par("166", "• Se è in effetto la Condizione 1, 2, 3 o 4, muoviti in L14.\n• Se è in effetto la Condizione 5 o 6, muoviti in L15.",
    [if_({"cond_in": [1, 2, 3, 4]}, [{"op": "g_enter", "hex": "L14"}], [{"op": "g_enter", "hex": "L15"}])], "movimento")
par("167", "[s2] Attiva il tedesco 2 nell’esagono G4, accovacciato. Iniziano i Round. Il tedesco 2 riceve 2 turni in questo Round. Dopo il primo tiro metti in effetto la reazione speciale B per tutte le sue azioni.",
    sighting(2) + [activate([(2, "G4")], "crouching", two=[2], reaction="B")])
par("168", "Effettua un controllo di percezione. Se riesce, vedi 015.", [pc(0, [see("015")])])
par("169", "Effettua un controllo di percezione. Se riesce, vedi 114.", [pc(0, [see("114")])])
par("170", "[s5] Attiva i tedeschi 26, 37 e 50 nell’esagono V8, accovacciati. Iniziano i Round. Vantaggio americano. Tutti i soldati americani consapevoli che non cadono nel panico ricevono 2 turni in questo Round.",
    sighting(5) + [activate([(26, "V8"), (37, "V8"), (50, "V8")], "crouching", adv="us", us_two=True)])
par("171", "Il soldato trova un bunker nascosto. È deserto. In un bidone della spazzatura la cenere ancora calda fa pensare che qualcuno abbia bruciato dei documenti.",
    [{"op": "landmark", "name": "bunker", "hex": "@hex"}])
par("172", "[s1] Un cecchino apre il fuoco dall’esagono che ha provocato l’attivazione. Attiva lì il tedesco 10, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 10 riceve 2 turni in questo Round. Dopo il primo tiro metti in effetto per lui la reazione speciale D.",
    sighting(1) + [activate([(10, "@indicato")], "crouching", adv="de", two=[10], reaction="D")])
par("173", "Il soldato trova una Kübelwagen all’ingresso del bunker nascosto. Un ufficiale tedesco e il suo aiutante stanno caricando in fretta i loro effetti personali. Sorpresi, si arrendono (le loro armi sono sulla carta del tedesco 19). Come indicato sulla carta, la cattura dell’ufficiale vale 3 PV. Interrogato, l’ufficiale parla: effettua un controllo Evento, poi vedi 177. Se vuoi perquisire l’auto, effettua un controllo Evento, poi vai al 006.",
    [{"op": "kubel_surrender"}])
par("174", "Nessun evento.", [])
par("175", "Il soldato trova un ragazzino francese spaventato in una piccola cantina. Racconta di aver visto soldati tedeschi in un boschetto lì vicino (intorno all’esagono N12).", [])
par("176", "Se il tedesco 10 è stato rimosso dal gioco con un movimento evasivo e un soldato americano attivo vede l’esagono M12, attiva il tedesco in quell’esagono, accovacciato. Iniziano i Round. Dopo il primo tiro metti in effetto per il tedesco 10 la reazione speciale D.",
    [if_(ALL({"evaded": 10}, {"see_hex": "M12"}), [activate([(10, "M12")], "crouching", reaction="D")])])
par("177", "L’ufficiale catturato rivela che nell’esagono S14 c’è una trappola esplosiva. Quando un soldato americano entra in quell’esagono, aggiungi 3 alla sua percezione per il controllo.",
    [{"op": "nota", "chiave": "trappola_S14"}])

# ---------------------------------------------------------------- 3xx
def miglior_pc(pid, h, mod, dest):
    segno = "" if mod == 0 else (" (%+d)" % mod).replace("-", "−")
    par(pid, f"Il soldato americano con il PC più alto che vede l’esagono {h} deve fare un controllo di percezione{segno}. Se riesce, vedi {dest}.",
        [{"op": "best_pc", "hex": h, "mod": mod, "ok": [see(dest)]}])


def rientro(pid, g, h, r):
    par(pid, f"Se il tedesco {g} è già stato rimosso una volta dal gioco con un movimento evasivo e un soldato americano attivo vede l’esagono {h}, attiva il tedesco in quell’esagono, accovacciato. Iniziano i Round. Dopo il primo tiro usa per lui la reazione speciale {r} in tutte le azioni.",
        [if_(ALL({"evaded": g}, {"see_hex": h}), [activate([(g, h)], "crouching", reaction=r)])])


miglior_pc("300", "D12", 0, "003")
rientro("301", 2, "U8", "B")
miglior_pc("302", "R8", -2, "013")
miglior_pc("303", "L9", -1, "013")
par("304", "Rinforzi! Una jeep con una mitragliatrice media montata e un autista entra in A17 o in A5 (a tua scelta). L’autista è il soldato americano 2. L’autista può usare la mitragliatrice se la jeep è ferma; altrimenti uno o due dei tuoi soldati devono salire sulla jeep per usarla. Se i Round sono in corso, la jeep entra quando riprendono le Operazioni. Questo evento può avvenire una sola volta.",
    [{"op": "jeep_reinforcement", "hexes": ["A5", "A17"]}])
rientro("305", 10, "P14", "D")
miglior_pc("306", "P15", -1, "010")
miglior_pc("307", "W11", 0, "007")
rientro("308", 2, "Q3", "B")
miglior_pc("309", "O5", 0, "002")
rientro("320", 2, "T3", "B")
miglior_pc("321", "Q10", 0, "004")
rientro("322", 10, "M16", "D")
par("323", "In alto, un caccia P-51 ingaggia un Me-109 e lo abbatte. Passa alla Condizione 6.", [cond(6)])

# ---------------------------------------------------------------- azioni tedesche nuove
A = {
"806": "Corri in un esagono scoperto, striscia in qualsiasi altro tipo di esagono. Fermati e sdraiati prono se ti resta il cambio di postura gratuito e sei fuori dalla vista dei soldati americani attivi. Se alla fine del Round sei fuori dalla vista degli americani, rimuovi il tedesco dalla mappa.",
"807": "• Se vedi un bersaglio attivo, accovacciati ed esegui il miglior tiro contro il bersaglio più facile. Dopo l’azione sdraiati prono se ti resta il cambio di postura gratuito.\n• Se non vedi bersagli attivi, corri in un esagono scoperto o striscia in qualsiasi altro tipo di esagono. Dopo l’azione sdraiati prono se ti resta il cambio di postura gratuito.",
"810": "1. Se sei entro 2 esagoni da un soldato (nemico o amico) ucciso o incapacitato e non sei in vista di un bersaglio attivo, corri fino a lui e prendi la sua arma; poi torna nell’esagono di partenza.\n2. Se sei in vista di un bersaglio attivo, accovacciati ed esegui il miglior tiro.\n3. Accovacciati.",
"814": "Guida il veicolo lentamente.",
"817": "1. Se un soldato americano è in un esagono adiacente e hai una granata, vedi 818.\n2. Se non vedi bersagli attivi, accovacciati.\n3. Se vedi un bersaglio, accovacciati ed esegui il miglior tiro contro il bersaglio più vicino.\n4. Se sei senza munizioni ma hai granate, vedi 818.\n5. Se sei senza munizioni e granate e vedi un bersaglio attivo, arrenditi.",
"818": "Accovacciati, poi lancia una granata al bersaglio più vicino. Dopo il lancio sdraiati prono se ti resta il cambio di postura gratuito. Se non c’è un bersaglio, o il più vicino è nel tuo stesso esagono, accovacciati.",
"819": "• Se hai una granata e un bersaglio è a tiro, lancia la granata al bersaglio più vicino. Dopo il lancio sdraiati prono se ti resta il cambio di postura gratuito.\n• Se non hai granate o nessun bersaglio è a tiro, corri in un esagono scoperto o striscia in qualsiasi altro tipo di esagono.",
"820": "1. Se non vedi bersagli attivi, corri in un esagono scoperto o striscia in qualsiasi altro tipo di esagono.\n2. Se vedi un bersaglio attivo e sei in un esagono con un altro tedesco attivo, o adiacente a uno, sdraiati prono.\n3. Arrenditi.",
"821": "• Se sei in vista di un bersaglio attivo, sdraiati prono.\n• Se non vedi bersagli attivi, corri in un esagono scoperto o interno, striscia in qualsiasi altro tipo di esagono.",
"822": "• Se c’è un tedesco attivo nello stesso esagono o in uno adiacente, accovacciati e cedi un turno al tedesco con meno turni. A parità, a quello con l’abilità con le armi più alta. Se tutti hanno due turni, vedi 801.\n• Se non ci sono tedeschi attivi nello stesso esagono o in uno adiacente, corri in un esagono scoperto o striscia in qualsiasi altro tipo di esagono.",
"826": "• Se il veicolo è stato bersagliato, guidalo veloce.\n• Se non è mai stato bersagliato, guidalo lentamente.",
"828": "Guida il veicolo veloce.",
"867": "• Se non vedi bersagli attivi, muoviti il più rapidamente possibile.\n• Se vedi un bersaglio attivo, muoviti il più rapidamente possibile e sdraiati prono nel primo esagono non scoperto in cui entri (spendendo un punto movimento, se necessario); se non entri in nessun esagono non scoperto, sdraiati prono nell’ultimo.",
"950": "• Se il tedesco 2 è attivo, vedi 802.\n• Se il tedesco 2 non è attivo e un bersaglio attivo è in vista dalla porta sud, accovacciati ed esegui un tiro rapido contro il bersaglio più vicino da quella parte.\n• Altrimenti corri fino all’esagono K15 e sdraiati prono; se ci riesci, metti in effetto la reazione speciale K.",
"951": "• Se nessun soldato americano attivo vede il tedesco 10, rimuovilo dalla mappa.\n• Altrimenti striscia di un esagono e sdraiati prono, se ti resta il cambio di postura gratuito. Eccezione: nell’esagono N13 sdraiati prono e basta.",
"952": "• Se il tedesco non ha ancora sparato né è stato bersagliato, vedi 806.\n• Se è stato bersagliato, vedi 953.",
"953": "• Se vedi un bersaglio attivo, accovacciati ed esegui il miglior tiro. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito. Se sei in K7, hanno la precedenza i bersagli visibili dalla finestra est.\n• Se non vedi bersagli attivi, vedi 806.",
"954": "Accovacciati ed esegui il miglior tiro. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito. Se un bersaglio è in vista dalla finestra est, metti in effetto per questo tedesco la reazione speciale A.",
"955": "• Se il tedesco è stato bersagliato da più di 2 soldati americani o ha subito un attacco con granate, metti in effetto la reazione speciale A e ritira subito per questa azione, eseguendo la nuova istruzione.\n• Altrimenti vedi 801.",
"956": "• Se il tedesco 10 è attivo, vedi 802.\n• Se il tedesco 10 è inattivo, metti in effetto la reazione speciale A e ritira subito per questa azione, eseguendo la nuova istruzione.",
"957": "• Se un bersaglio è in vista dalla porta, accovacciati ed esegui il miglior tiro.\n• Se nessun bersaglio è in vista dalla porta, corri in un esagono scoperto o striscia in qualsiasi altro tipo di esagono. Metti in effetto per questo tedesco la reazione speciale D.",
"958": "• Se un bersaglio è in vista dalla porta, accovacciati ed esegui il miglior tiro.\n• Altrimenti corri fino all’esagono L6, sdraiati prono e metti in effetto la reazione speciale B.",
"959": "• Se un bersaglio attivo è entro 3 esagoni, accovacciati ed esegui il miglior tiro con la Luger. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito.\n• Altrimenti vedi 815.",
"960": "• Se il tedesco 49 è ucciso o incapacitato e non vedi bersagli attivi, striscia e metti in effetto la reazione speciale E.\n• Altrimenti sdraiati prono.",
"961": "• Se il tedesco 5 è ucciso o incapacitato e non vedi bersagli attivi, striscia e metti in effetto la reazione speciale F.\n• Altrimenti sdraiati prono.",
"962": "• Se il tedesco 49 è ucciso o incapacitato e vedi almeno un bersaglio attivo, arrenditi.\n• Altrimenti esegui 815.",
"963": "Corri in un esagono scoperto o striscia in qualsiasi altro tipo di esagono. Se il movimento parte da K7, metti in effetto la reazione speciale A; altrimenti la reazione speciale B.",
"964": "Corri in un esagono scoperto o striscia in qualsiasi altro tipo di esagono. Se il movimento parte da J13, metti in effetto la reazione speciale K; altrimenti la reazione speciale D.",
"966": "• Se sei nell’esagono N12, vedi 815.\n• Altrimenti vedi 813.",
"967": "• Se sei nell’esagono N12, vedi 815.\n• Altrimenti vedi 820.",
"968": "• Se sei nell’esagono N12, vedi 815.\n• Altrimenti vedi 818.",
"969": "• Se un bersaglio attivo è entro 7 esagoni, accovacciati ed esegui il miglior tiro. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito.\n• Altrimenti vedi 822.",
"970": "• Se il tedesco 37 o il 50 è ucciso, incapacitato o non è in questo esagono, striscia.\n• Altrimenti esegui 801.",
}
for k, v in A.items():
    par(k, v, [], "azione")

# I paragrafi condivisi con la missione 1 non vengono sovrascritti.
for k in list(P):
    if k in P1:
        del P[k]
