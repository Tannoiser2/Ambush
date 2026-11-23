# -*- coding: utf-8 -*-
"""Paragrafi della Missione 3 «Un freddo mattino in Belgio» (mappa B, nebbia, niente livelli di attivazione).

Testo inglese da tools/paragrafi_en.json, controllato sulle scansioni per 017, 031 (tabelle del dado) e 250.
"""
from paragrafi_m1 import pc, act, see, die, if_, S, NOT, ALL, sighting, activate, cond, EVENT, P as P1
from paragrafi_m2 import P as P2

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def vp(n, why):
    return {"op": "vp", "n": n, "why": why}


def enter(h):
    return {"op": "g_enter", "hex": h}


def reaz(r):
    return {"op": "g_reaction", "r": r}


def artiglieria(pid, esagoni):
    righe = "\n".join(f"{i}: esagono {h}" for i, h in enumerate(esagoni))
    par(pid, "Un tiro d’artiglieria tedesco! Tira un dado per l’esagono colpito:\n" + righe +
        "\nIn un esagono non di edificio metti un cratere; un edificio colpito diventa macerie. Tutti i soldati nell’esagono colpito muoiono e i veicoli sono distrutti.",
        [{"op": "artiglieria_esagoni", "esagoni": esagoni}])


artiglieria("017", ["O6", "N8", "L10", "L13", "O12", "Q14", "Q10", "I11", "J8", "S7"])
artiglieria("031", ["I5", "S11", "O14", "F4", "P7", "U13", "H15", "P8", "Q12", "U5"])
par("014", "Una jeep americana fora una gomma (se ce n’è più d’una, si sceglie a caso). Un soldato americano attivo nell’esagono della jeep può montare la ruota di scorta: nelle Operazioni costa due controlli Evento, nei Round 10 azioni (due soldati possono dividersele). Se succede una seconda volta alla stessa jeep, la ruota di scorta non c’è più.",
    [{"op": "jeep_tire"}])
par("019", "[s2] Un razzo di segnalazione esplode in cielo.", sighting(2))
par("021", "[s3] Una nebbia fitta scende sul campo di battaglia. La visibilità si riduce a 3 esagoni e il costo in punti movimento dei veicoli aumenta di 1 in ogni tipo di terreno. La nebbia resta finché un paragrafo non la toglie.",
    sighting(3) + [{"op": "vista", "n": 3, "veicoli": 1}])
par("022", "[s4] Serve s3. La nebbia fitta si dirada: torna il tempo del briefing (visibilità 6 esagoni).",
    [if_(S(3), sighting(4) + [{"op": "vista", "n": 6, "veicoli": 0}])])
par("084", "[s7] Attiva il tedesco 93 nell’esagono N9, accovacciato. Iniziano i Round. Vantaggio tedesco.",
    sighting(7) + [activate([(93, "N9")], "crouching", adv="de")])


def seq(hexes, mod, dest, nessuno):
    return {"op": "pc_sequenza", "mod": mod, "passi": [[h, [see(dest)]] for h in hexes], "nessuno": nessuno}


par("121", "Ogni soldato americano che vede l’esagono Y12 fa un controllo di percezione (−1): se almeno uno riesce, vedi 250.\nSe falliscono tutti, fanno il controllo i soldati che vedono X12; poi W13; poi V13 (se uno riesce, vedi 250).\nSe falliscono anche per V13, o se non si fa nessun controllo, vedi 157.",
    [seq(["Y12", "X12", "W13", "V13"], -1, "250", [see("157")])])
par("143", "Se la radio è presidiata, vedi 178.", [if_({"radio": True}, [see("178")])])
par("145", "Ogni soldato entro 8 esagoni da C4 fa un controllo di percezione (−1). Se almeno uno riesce, vedi 255.",
    [{"op": "pc_entro", "hex": "C4", "dist": 8, "mod": -1, "any": [see("255")]}])
par("146", "• Se si muove il tedesco 35 o il 41, entra in U13 e metti in effetto per lui la reazione speciale R.\n• Se si muove il tedesco 52, entra nell’esagono U14.",
    [if_({"g_is": [35, 41]}, [enter("U13"), reaz("R")], [if_({"g_is": [52]}, [enter("U14")])])], "movimento")
par("157", "Attiva i tedeschi 35, 41 e 52 nell’esagono V13, accovacciati. Attiva il tedesco 55 in A5. Iniziano i Round. Vantaggio tedesco. I tedeschi 35, 41 e 52 ricevono due turni in questo Round, il 55 uno solo. Per il rumore del 55 tutti i soldati americani, ovunque siano, possono fare il controllo di consapevolezza nel primo Round. Passa alla Condizione 2.",
    [activate([(35, "V13"), (41, "V13"), (52, "V13"), (55, "A5")], "crouching", adv="de", two=[35, 41, 52]),
     {"op": "consapevolezza_libera"}, cond(2)])
par("178", "[s1] Il comando di battaglione comunica che è in corso un’offensiva tedesca: abbandonate le posizioni! Ritardate il nemico a vostra discrezione. Ricevi 2 PV per ogni soldato americano attivo che esce tra A13 e A19 compresi; non perdi PV per gli incapacitati portati fuori da quegli esagoni. Ricevi PV per la distruzione dei ponti: ponte di legno 2 PV, ponte di pietra 4 PV, entrambi 10 PV (vedi il paragrafo 1000). La missione termina quando non ci sono più soldati americani attivi sulla mappa.",
    sighting(1) + [{"op": "offensiva"}])
par("250", "Attiva i tedeschi 35, 41 e 52 nell’esagono che si stava controllando, in piedi (accovacciati se in V13). Attiva il tedesco 55 in A5, in piedi. Iniziano i Round. Vantaggio americano. Il soldato americano che ha appena superato il controllo di percezione è automaticamente consapevole. Tutti i soldati americani consapevoli che non cadono nel panico ricevono 2 turni in questo Round. Passa alla Condizione 2.",
    [if_({"indicato": "V13"}, [activate([(35, "@indicato"), (41, "@indicato"), (52, "@indicato")], "crouching", adv="us", us_two=True, aware=True)],
         [activate([(35, "@indicato"), (41, "@indicato"), (52, "@indicato")], "standing", adv="us", us_two=True, aware=True)]),
     activate([(55, "A5")], "standing", adv="us"), cond(2)])
par("251", "Se il ponte in G13 è intatto e nessun tedesco è entrato e uscito da G13, entra in G13. Altrimenti:\n• se si muove un tedesco con numero 52 o inferiore, entra in H13;\n• se si muove un tedesco con numero 53 o superiore e il ponte è intatto, entra in G13;\n• se si muove un tedesco con numero 53 o superiore e il ponte è distrutto, entra in I12.",
    [if_({"bridge_ok": "G13"}, [enter("G13")],
         [if_({"g_le": 52}, [enter("H13")], [if_({"bridge_intact": "G13"}, [enter("G13")], [enter("I12")])])])], "movimento")
par("252", "Serve s2: vedi 121. Altrimenti nessun evento.", [if_(S(2), [see("121")])])
par("253", "Se il soldato vede l’esagono Y12, fa un controllo di percezione (+2):\n• se riesce, vedi 250;\n• se fallisce, vedi 157.",
    [if_({"see_hex": "Y12"}, [{"op": "indica", "hex": "Y12"}, pc(2, [see("250")], [see("157")])])])
par("254", "Metti in effetto per questo tedesco la reazione speciale T. Tira un nuovo numero d’azione tedesca e applica a questo tedesco l’azione indicata.",
    [reaz("T"), {"op": "g_reroll"}], "movimento")
par("255", "Il soldato sente il cingolare di un mezzo corazzato diretto verso l’esagono d’ingresso A5.", [])
par("256", "• Se si muove un soldato tedesco (non un veicolo) e il ponte di questo esagono non è stato controllato per le cariche, lo controlla: servono quattro turni, che possono dividersi tutti i tedeschi mandati a questo paragrafo, anche non di seguito. Chi controlla il ponte, se bersagliato, è accovacciato in terreno scoperto.\n• Se si muove un veicolo, o il ponte è già stato controllato: entra in H13 se il tedesco ha numero 52 o inferiore, in F14 se 53 o superiore.",
    [if_(ALL(NOT({"vehicle_moving": True}), NOT({"bridge_checked": "@hex"})), [{"op": "controlla_ponte"}],
         [if_({"g_le": 52}, [enter("H13")], [enter("F14")])])], "movimento")
par("257", "Ogni soldato americano in un esagono scoperto o di strada che vede l’esagono Y12 fa un controllo di percezione (−2):\n• se almeno uno riesce, vai al 262;\n• se falliscono tutti, vai al 020;\n• se non si fa nessun controllo, nessun evento.",
    [{"op": "group_pc", "hex": "Y12", "mod": -2, "solo_aperto": True, "any": [see("262")], "all_fail": [see("020")]}])
par("258", "Se il tedesco 55 si è mosso di quattro o più esagoni nel Round precedente, ha perso un cingolo: non si muove più per il resto della missione, ma esegue le azioni che non richiedono movimento.",
    [{"op": "cingolo_55"}])
par("259", "Ogni soldato americano che vede l’esagono J1 fa un controllo di percezione (−1): se almeno uno riesce, vedi 264. Se falliscono tutti, si continua con K2, K3 e L3, nell’ordine: al primo successo vedi 264. Se falliscono tutti, vedi 269.",
    [seq(["J1", "K2", "K3", "L3"], -1, "264", [see("269")])])
par("260", "• Se si muove un veicolo e il ponte in G14 è intatto, entra in G14; se il ponte è distrutto, entra in H12.\n• Se si muove un soldato con numero 52 o inferiore e il ponte in G14 è intatto e nessun tedesco vi è entrato e uscito, entra in G14. Se il ponte in G14 è distrutto ma quello in G13 è intatto e nessun tedesco vi è entrato e uscito, entra in H12. Altrimenti entra in I14.\n• Se si muove un soldato con numero 53 o superiore e il ponte in G14 è intatto, entra in G14. Se G14 è distrutto ma G13 è intatto, entra in H12. Se sono distrutti entrambi, entra in H14.",
    [if_({"vehicle_moving": True}, [if_({"bridge_intact": "G14"}, [enter("G14")], [enter("H12")])],
         [if_({"g_le": 52},
              [if_({"bridge_ok": "G14"}, [enter("G14")], [if_(ALL(NOT({"bridge_intact": "G14"}), {"bridge_ok": "G13"}), [enter("H12")], [enter("I14")])])],
              [if_({"bridge_intact": "G14"}, [enter("G14")], [if_({"bridge_intact": "G13"}, [enter("H12")], [enter("H14")])])])])], "movimento")
par("261", "• Se si muove un soldato tedesco (non un veicolo) e il ponte di questo esagono non è stato controllato per le cariche, lo controlla: servono quattro turni, che possono dividersi tutti i tedeschi mandati a questo paragrafo, anche non di seguito. Chi controlla il ponte, se bersagliato, è accovacciato in terreno scoperto.\n• Se si muove un veicolo, o il ponte è già stato controllato: entra in H12 se il tedesco ha numero 52 o inferiore, in F13 se 53 o superiore.",
    [if_(ALL(NOT({"vehicle_moving": True}), NOT({"bridge_checked": "@hex"})), [{"op": "controlla_ponte"}],
         [if_({"g_le": 52}, [enter("H12")], [enter("F13")])])], "movimento")
par("262", "Il soldato nota un movimento nell’esagono Y12.", [])
par("263", "Non ricevi PV per l’uscita di questo soldato e non ne perdi se è ucciso o incapacitato: era un agente tedesco travestito da soldato americano.",
    [{"op": "staffetta_spia"}])
par("264", "Attiva i tedeschi 61, 64 e 72 nell’esagono che si stava controllando, in piedi (accovacciati se in L3). Attiva i tedeschi 90, 91 e 92 in A5, in piedi. Iniziano i Round. Vantaggio americano. Il soldato americano che ha appena superato il controllo di percezione è automaticamente consapevole. Tutti i soldati americani consapevoli che non cadono nel panico ricevono 2 turni in questo Round. Passa alla Condizione 3.",
    [if_({"indicato": "L3"}, [activate([(61, "@indicato"), (64, "@indicato"), (72, "@indicato")], "crouching", adv="us", us_two=True, aware=True)],
         [activate([(61, "@indicato"), (64, "@indicato"), (72, "@indicato")], "standing", adv="us", us_two=True, aware=True)]),
     activate([(90, "A5"), (91, "A5"), (92, "A5")], "standing", adv="us"), cond(3)])
par("265", "Se sei al piano superiore, scendi al piano inferiore. Se sei al piano inferiore e c’è un soldato americano attivo al piano superiore, sali. Se sei al piano inferiore e non c’è nessun americano al piano superiore, entra in S14.",
    [{"op": "scala_tedesco", "altrimenti": "S14"}], "movimento")
par("266", "Una staffetta del comando di battaglione entra in gioco in A17 (carta americana 01). Puoi usarla come vuoi e conta per la tua squadra ai fini dei PV, ma cerca un comandante di squadra. Se i Round sono in corso, la staffetta è automaticamente consapevole.",
    [{"op": "staffetta", "carta": 1}])
par("267", "Ogni soldato americano in un esagono scoperto o di strada che vede l’esagono J1 fa un controllo di percezione (−2):\n• se almeno uno riesce, vedi 272;\n• se falliscono tutti, vedi 020;\n• se non si fa nessun controllo, nessun evento.",
    [{"op": "group_pc", "hex": "J1", "mod": -2, "solo_aperto": True, "any": [see("272")], "all_fail": [see("020")]}])
par("268", "• Se è un veicolo tedesco, entra in I7.\n• Se è un soldato tedesco, entra in H7.",
    [if_({"vehicle_moving": True}, [enter("I7")], [enter("H7")])], "movimento")
par("269", "Attiva i tedeschi 61, 64 e 72 in L3 e i tedeschi 90, 91 e 92 in A5, tutti in piedi. Iniziano i Round. Vantaggio tedesco. I tedeschi 61, 64 e 72 ricevono due turni in questo Round (90, 91 e 92 tirano normalmente). Passa alla Condizione 3.",
    [activate([(61, "L3"), (64, "L3"), (72, "L3"), (90, "A5"), (91, "A5"), (92, "A5")], "standing", adv="de", two=[61, 64, 72]), cond(3)])
par("270", "Entra in S15 e togli a questo tedesco la reazione speciale R: le sue azioni tornano a dipendere dalla Condizione in vigore. Se gli restano punti movimento, continua a muoversi finché non li ha spesi.",
    [enter("S15"), reaz("")], "movimento")
par("271", "Una staffetta del comando di battaglione entra in gioco in A17 (carta americana 08). Puoi usarla come vuoi, ma cerca di raggiungere un comandante di squadra. Se i Round sono in corso, la staffetta è automaticamente consapevole.",
    [{"op": "staffetta", "carta": 8}])
par("272", "Il soldato nota un movimento nell’esagono J1.", [])
par("273", "• Se il ponte in G13 è distrutto, entra in I9.\n• Se il ponte è intatto, entra in H10.",
    [if_({"bridge_intact": "G13"}, [enter("H10")], [enter("I9")])], "movimento")
par("274", "Ogni soldato americano che vede l’esagono R3 fa un controllo di percezione (+1):\n• se almeno uno riesce, vedi 279;\n• se falliscono tutti, o non si fa nessun controllo, vedi 284.",
    [{"op": "group_pc", "hex": "R3", "mod": 1, "any": [see("279")], "all_fail": [see("284")], "nessuno": [see("284")]}])
par("275", "• Se i ponti in G14 e G13 sono distrutti entrambi, oppure un ponte è intatto e almeno un tedesco è entrato e uscito da quel ponte, metti in effetto per questo tedesco la reazione speciale D, tira un nuovo numero d’azione e applica l’azione indicata.\n• Altrimenti entra in I14.",
    [if_(ALL(NOT({"bridge_ok": "G13"}), NOT({"bridge_ok": "G14"})), [reaz("D"), {"op": "g_reroll"}], [enter("I14")])], "movimento")
par("276", "I tuoi soldati capiscono che la staffetta è una quinta colonna tedesca che cerca di ingannare la squadra. Scoperto, il nazista grida «Heil Hitler!» e si uccide. Guadagni 2 PV.",
    [{"op": "staffetta_smascherata"}, vp(2, "spia smascherata")])
par("277", "Ogni soldato americano in un esagono scoperto o di strada che vede l’esagono T2 fa un controllo di percezione (−2):\n• se almeno uno riesce, vedi 282;\n• se falliscono tutti, vedi 020;\n• se non si fa nessun controllo, nessun evento.",
    [{"op": "group_pc", "hex": "T2", "mod": -2, "solo_aperto": True, "any": [see("282")], "all_fail": [see("020")]}])
par("278", "• Se si muove un tedesco con numero 90 o superiore, entra in F12.\n• Se si muove un tedesco con numero 89 o inferiore, entra in F14.",
    [if_({"g_ge": 90}, [enter("F12")], [enter("F14")])], "movimento")
par("279", "Attiva i tedeschi 82, 85 e 89 nell’esagono R8, accovacciati. Iniziano i Round. Vantaggio americano. Il soldato americano che ha appena superato il controllo di percezione è automaticamente consapevole. Tutti i soldati americani consapevoli che non cadono nel panico ricevono 2 turni in questo Round. Passa alla Condizione 4.",
    [activate([(82, "R8"), (85, "R8"), (89, "R8")], "crouching", adv="us", us_two=True, aware=True), cond(4)])
par("280", "• Se il ponte in G13 o in G14 è intatto e nessun tedesco è ancora entrato e uscito da quel ponte, entra in H13.\n• Altrimenti entra in J13.",
    [if_({"any_bridge_ok": ["G13", "G14"]}, [enter("H13")], [enter("J13")])], "movimento")
par("281", "Il comando di battaglione comunica che una pattuglia tedesca si dirige verso il villaggio, nei pressi dell’esagono Y16.", [])
par("282", "Il soldato nota un movimento nell’esagono T2.", [])
par("283", "• Se si muove un tedesco con numero 90 o superiore, entra in I9.\n• Se si muove un tedesco con numero 89 o inferiore, entra in J9.",
    [if_({"g_ge": 90}, [enter("I9")], [enter("J9")])], "movimento")
par("284", "Attiva i tedeschi 82, 85 e 89 nell’esagono R3, accovacciati. Iniziano i Round. Vantaggio tedesco. Tutti i tedeschi appena attivati ricevono 2 turni in questo Round. Passa alla Condizione 4.",
    [activate([(82, "R3"), (85, "R3"), (89, "R3")], "crouching", adv="de", two=[82, 85, 89]), cond(4)])
par("285", "Metti in effetto per questo veicolo la reazione speciale B.", [reaz("B")], "movimento")
par("286", "• Se si muove un tedesco con numero 54 o superiore, entra in K14.\n• Se si muove un tedesco con numero 53 o inferiore, entra in J13.",
    [if_({"g_ge": 54}, [enter("K14")], [enter("J13")])], "movimento")
par("287", "Metti in effetto per questo tedesco la reazione speciale X.", [reaz("X")], "movimento")
par("631", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 084;\n• se fallisce, vedi 633.", [act(1, [see("084")], [see("633")])])
par("633", "[s7] Attiva il tedesco 93 nell’esagono N9, accovacciato. Iniziano i Round. Vantaggio americano.",
    sighting(7) + [activate([(93, "N9")], "crouching", adv="us")])

# I paragrafi già scritti per le missioni 1 e 2 non vengono sovrascritti.
for k in list(P):
    if k in P1 or k in P2:
        del P[k]

A = {
"812": "1. Se c’è un soldato americano attivo nel tuo esagono, assaltalo per uccidere.\n2. Se sei adiacente a un soldato americano attivo oltre un lato attraversabile e hai una granata, accovacciati e lanciala. Eccezione: se nel tuo esagono c’è un altro tedesco attivo, esegui invece una carica d’assalto per uccidere.\n3. Se vedi un bersaglio attivo e nel suo esagono non ci sono tedeschi, accovacciati ed esegui il miglior tiro.\n4. Muoviti e spara di rapido se durante il movimento compaiono bersagli attivi.",
"834": "• Se sei in un esagono con un veicolo tedesco attivo, accovacciati ed esegui il miglior tiro contro il bersaglio più facile. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito.\n• Altrimenti vedi 808.",
"858": "• Se non vedi bersagli, accovacciati.\n• Se sei in un edificio e 1 o 2 bersagli sono in vista o negli esagoni adiacenti, alzati ed esegui il miglior tiro contro il bersaglio più facile. Sdraiati prono se ti resta il cambio di postura gratuito.\n• Se non sei in un edificio e vedi 1 o 2 bersagli, accovacciati ed esegui il miglior tiro contro il più facile. Sdraiati prono se ti resta il cambio di postura gratuito.\n• Se vedi tre o più bersagli attivi, sdraiati prono.",
"860": "• Se sei in un edificio, alzati e spara di rapido al maggior numero possibile di bersagli, cominciando dal più vicino e poi dal più facile. Sdraiati prono se ti resta il cambio di postura gratuito.\n• Se non sei in un edificio, accovacciati e spara di rapido al maggior numero possibile di bersagli, cominciando dal più vicino e poi dal più facile.",
"862": "• Se non vedi bersagli attivi, muoviti il più rapidamente possibile.\n• Se vedi un bersaglio attivo e sei in un esagono scoperto, muoviti il più rapidamente possibile e alla fine sdraiati prono (spendendo un punto movimento, se necessario).\n• Se vedi un bersaglio attivo e non sei in un esagono scoperto, accovacciati ed esegui il miglior tiro contro il bersaglio più facile.",
"863": "• Se non vedi bersagli attivi, muoviti il più rapidamente possibile.\n• Se vedi un bersaglio attivo e sei in un esagono scoperto, muoviti il più rapidamente possibile e sdraiati prono nel primo esagono non scoperto in cui entri (o nell’ultimo, spendendo un punto movimento se necessario).\n• Se vedi un bersaglio attivo e non sei in un esagono scoperto, esegui 869.",
"864": "• Se non vedi bersagli attivi, muoviti il più rapidamente possibile.\n• Se vedi un bersaglio attivo, alzati e spara un tiro rapido al più vicino; poi muoviti il più rapidamente possibile spendendo fino a metà dei tuoi punti movimento (per difetto). Sdraiati prono se ti resta il cambio di postura gratuito.",
"869": "• Se hai una granata e un soldato americano attivo è entro tre esagoni, alzati e lanciala. Sdraiati prono se ti resta il cambio di postura gratuito.\n• Altrimenti esegui 801.",
"060": "1. Se il ponte in G14 è intatto e nessun tedesco attivo è in G14 o adiacente, vedi 565.\n2. Se il ponte in G13 è intatto e nessun tedesco attivo è in G13 o adiacente, vedi 565.\n3. Se sono saltati entrambi i ponti, o ci sono tedeschi in entrambi gli esagoni o adiacenti, vedi 858.",
"716": "• Se i tedeschi 63 e 83 sono inattivi, arrenditi.\n• Se sono attivi o non sono ancora stati attivati, esegui 802.",
"911": "• Se sei nell’esagono J13, vedi 824.\n• Altrimenti vedi 803.",
"912": "• Se sei nell’esagono E11 o K7, vedi 824.\n• Altrimenti vedi 803.",
}
par("565", "Il tedesco aziona un interruttore segreto e il ponte salta. Chi è nell’esagono del ponte muore; chi è in un esagono adiacente subisce i danni di una granata all’aperto.", [])
for _k, _v in A.items():
    if _k not in P1 and _k not in P2:
        par(_k, _v, [], "azione")

C = {
"811": "• Se vedi un bersaglio attivo, arrenditi.\n• Altrimenti sdraiati prono.",
"827": "Guida il veicolo veloce.",
"840": "Non fare nulla.",
"900": "Guida piano. Spara col cannone se c’è un bersaglio attivo in un edificio o un veicolo americano attivo in vista; altrimenti carica il cannone. Se il cannone è carico e non c’è un bersaglio da cannone, spara di rapido con la mitragliatrice coassiale al secondo bersaglio più vicino. Spara di rapido con la mitragliatrice di prua al bersaglio più vicino.",
"901": "• Se vedi uno o più bersagli attivi, vedi 910.\n• Altrimenti vedi 906.",
"902": "• Se vedi bersagli attivi, chiudi i portelli (se sono già chiusi, vedi 900).\n• Altrimenti apri i portelli (se sono già aperti, vedi 906).",
"903": "• Se l’abilità di guida (DS) è 6 o più, guida veloce e carica il cannone se non è carico.\n• Altrimenti guida piano e carica il cannone se non è carico.",
"904": "Spara di rapido con la mitragliatrice di prua al bersaglio più vicino. Spara col cannone se c’è un bersaglio attivo in un edificio o un veicolo americano attivo in vista; altrimenti carica il cannone.",
"905": "• Se vedi 2 o più bersagli attivi, chiudi i portelli (se sono già chiusi, vedi 900).\n• Se ne vedi uno, vedi 910.\n• Se non ne vedi, apri i portelli (se sono già aperti, vedi 906).",
"906": "Guida veloce. Spara di rapido con la mitragliatrice di prua al bersaglio più vicino. Carica il cannone se non è carico.",
"907": "• Se vedi 3 o più bersagli attivi, chiudi i portelli (se sono già chiusi, vedi 910).\n• Se ne vedi 1 o 2, vedi 900.\n• Se non ne vedi, apri i portelli (se sono già aperti, vedi 900).",
"908": "Tiro mirato con la mitragliatrice di prua al bersaglio più vicino.",
"909": "• Se vedi bersagli attivi, chiudi i portelli (se sono già chiusi, vedi 904).\n• Altrimenti vedi 827.",
"910": "Tiro mirato con la mitragliatrice di prua al bersaglio più vicino. Spara col cannone a un bersaglio attivo in un edificio o a un veicolo americano attivo in vista; altrimenti carica il cannone. Se il cannone è carico e non c’è un bersaglio da cannone, tiro mirato con la coassiale al secondo bersaglio più vicino.",
"921": "Guida piano. Spara di rapido con la mitragliatrice al bersaglio più vicino. Spara col cannone se c’è un bersaglio attivo in un edificio o un veicolo americano attivo in vista; altrimenti carica il cannone.",
"922": "Guida veloce. Spara di rapido con la mitragliatrice al bersaglio più vicino. Carica il cannone se non è carico.",
"923": "• Se vedi 2 o più bersagli attivi, chiudi i portelli (se sono già chiusi, vedi 921).\n• Se ne vedi uno, vedi 924.\n• Se non ne vedi, apri i portelli (se sono già aperti, vedi 922).",
"924": "Tiro mirato con la mitragliatrice al bersaglio più vicino. Spara col cannone a un bersaglio attivo in un edificio o a un veicolo americano attivo in vista; altrimenti carica il cannone.",
"925": "• Se vedi bersagli attivi, chiudi i portelli (se sono già chiusi, vedi 921).\n• Altrimenti apri i portelli (se sono già aperti, vedi 922).",
}
for _k, _v in C.items():
    if _k not in P1 and _k not in P2:
        par(_k, _v, [], "azione")
