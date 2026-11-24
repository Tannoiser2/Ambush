# -*- coding: utf-8 -*-
"""Purple Heart – Missione 17 «Sul filo del rasoio» (mappe B + E, in alto è ovest; Germania occidentale, 15 marzo 1945).

La squadra raggiunge la Mosella e deve far saltare i tre ponti (legno G11, pietra J11 e R10) per chiudere la sacca.
Testo inglese: tools/paragrafi_ph_programma.json, tools/paragrafi_ph_en.json e il database del programma.
"""
from paragrafi_m1 import pc, act, see, die, if_, S, NOT, ALL, sighting, activate, cond, EVENT

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def mov(pid, it, ops):
    par(pid, it, ops, "movimento")


def az(pid, it):
    par(pid, it, [], "azione")


def enter(h):
    return {"op": "g_enter", "hex": h}


def attiva_check(pid, ok, ko):
    par(pid, f"Effettua un controllo di attivazione:\n• se riesce, vedi {ok};\n• se fallisce, vedi {ko}.", [act(0, [see(ok)], [see(ko)])])


def pc_check(pid, ok, ko):
    par(pid, f"Effettua un controllo di percezione:\n• se riesce, vedi {ok};\n• se fallisce, vedi {ko}.", [pc(0, [see(ok)], [see(ko)])])


# ------------------------------------------------------------------ attivazioni
attiva_check("377", "387", "394")
pc_check("394", "400", "409")
par("387", "[s0] Attiva i tedeschi 22 e 23 in E11, accovacciati. Iniziano i Round, vantaggio tedesco; il tedesco 22 riceve 2 turni.",
    sighting(0) + [activate([(22, "E11"), (23, "E11")], "crouching", adv="de", two=[22])])
par("400", "[s0] Attiva i tedeschi 22 e 23 in E11, accovacciati. Iniziano i Round, vantaggio americano; i consapevoli che non vanno nel "
           "panico ricevono 2 turni.", sighting(0) + [activate([(22, "E11"), (23, "E11")], "crouching", adv="us", us_two=True)])
par("409", "[s0] Attiva i tedeschi 22 e 23 in E11, accovacciati. Iniziano i Round.", sighting(0) + [activate([(22, "E11"), (23, "E11")], "crouching")])
attiva_check("417", "423", "429")
pc_check("429", "437", "444")
par("423", "[s3] Attiva i tedeschi 55 e 56 in O12, accovacciati. Iniziano i Round, vantaggio tedesco; ricevono 2 turni. Passa alla "
           "Condizione 2.", sighting(3) + [activate([(55, "O12"), (56, "O12")], "crouching", adv="de", two=[55, 56]), cond(2)])
par("437", "[s3] Attiva i tedeschi 55 e 56 in O12, accovacciati. Iniziano i Round, vantaggio americano; i consapevoli che non vanno nel "
           "panico ricevono 2 turni. Passa alla Condizione 2.",
    sighting(3) + [activate([(55, "O12"), (56, "O12")], "crouching", adv="us", us_two=True), cond(2)])
par("444", "[s3] Attiva i tedeschi 55 e 56 in O12, accovacciati. Iniziano i Round. Passa alla Condizione 2.",
    sighting(3) + [activate([(55, "O12"), (56, "O12")], "crouching"), cond(2)])
attiva_check("335", "337", "346")
pc_check("346", "356", "367")
par("337", "[s5] Attiva il tedesco 50 (cecchino) in X14, accovacciato. Iniziano i Round, vantaggio tedesco; riceve 2 turni.",
    sighting(5) + [activate([(50, "X14")], "crouching", adv="de", two=[50])])
par("356", "[s5] Attiva il tedesco 50 (cecchino) in X14, accovacciato. Iniziano i Round, vantaggio americano; i "
           "consapevoli che non vanno nel panico ricevono 2 turni.",
    sighting(5) + [activate([(50, "X14")], "crouching", adv="us", us_two=True)])
par("367", "[s5] Attiva il tedesco 50 (cecchino) in X14, accovacciato. Iniziano i Round.",
    sighting(5) + [activate([(50, "X14")], "crouching")])
attiva_check("514", "523", "570")
pc_check("570", "529", "535")
par("523", "[s0] Attiva i tedeschi 22 e 23 in I13, accovacciati. Iniziano i Round, vantaggio tedesco.",
    sighting(0) + [activate([(22, "I13"), (23, "I13")], "crouching", adv="de")])
par("529", "[s0] Attiva i tedeschi 22 e 23 in I13, accovacciati. Iniziano i Round, vantaggio americano; i consapevoli che non vanno nel "
           "panico ricevono 2 turni.", sighting(0) + [activate([(22, "I13"), (23, "I13")], "crouching", adv="us", us_two=True)])
par("535", "[s0] Attiva i tedeschi 22 e 23 in I13, accovacciati. Iniziano i Round.", sighting(0) + [activate([(22, "I13"), (23, "I13")], "crouching")])

# ------------------------------------------------------------------ il treno
par("455", "• Se s1 non è avvenuto, vedi 463.\n• Se s1 è avvenuto, vedi 486.", [if_(NOT(S(1)), [see("463")], [see("486")])])
par("463", "Ogni soldato fa subito un controllo di percezione:\n• se almeno uno riesce, vedi 471;\n• se falliscono tutti, vedi 486.",
    [{"op": "pc_tutti", "ok": [see("471")], "ko": [see("486")]}])
par("471", "[s1] Il soldato sente un treno che arriva da nord. All’inizio del prossimo Round, al posto del controllo degli eventi casuali, "
           "vedi 486. Se sei nelle Operazioni iniziano subito i Round (anche senza tedeschi in mappa) e 486 si legge all’inizio del "
           "secondo Round.", sighting(1) + [{"op": "treno_in_arrivo"}])
par("486", "[s8] Un treno tedesco entra in Y5! Iniziano i Round, vantaggio tedesco. Vedi 493. Appena il treno esce dalla mappa o deraglia, "
           "passa alla Condizione 3; si resta nei Round finché il treno è in mappa.", sighting(8) + [{"op": "treno"}])
par("493", "Il treno: locomotiva, tre vagoni merci e una cisterna (in ordine casuale dietro la locomotiva). Avanza di 6 esagoni di binario "
           "per turno, due turni per Round (qui: 12 esagoni all’inizio di ogni Round). Non si sale sul treno. Un vagone che entra "
           "nell’esagono di un soldato attivo: controllo di percezione, se riesce si sposta in un esagono vicino, altrimenti muore. Vedi 497 "
           "per farlo deragliare.", [])
par("497", "Il treno deraglia se entra nel ponte di legno G11 distrutto (vedi 506). In questa versione i binari non si possono far "
           "saltare e il treno non si può distruggere a colpi di bazooka.", [])
par("506", "Deragliamento: locomotiva e vagoni si rovesciano dove si trovano (in questa versione senza la procedura di scivolamento). "
           "Passa alla Condizione 3 e torna alle Operazioni se non ci sono tedeschi attivi. Un soldato americano attivo che entra in un "
           "vagone merci rovesciato: vedi 595.", [])
par("595", "[s9] I tesori del Louvre! I vagoni contengono centinaia di casse marcate Picasso, Rembrandt, Michelangelo. Guadagni 10 PV per "
           "aver salvato il patrimonio della Francia!", [{"op": "louvre"}])

# ------------------------------------------------------------------ Condizione 2–4: eventi
par("645", "Un soldato americano a caso in un esagono di terreno accidentato cade: controllo di percezione; se fallisce, danni come da un "
           "colpo di pistola. Una volta sola.", [{"op": "caduta_accidentato"}])
par("543", "1. Se s2 non è avvenuto, vedi 551.\n2. Se s4 non è avvenuto, vedi 559.\n3. Se s6 non è avvenuto, vedi 566.\n4. Vedi 577.",
    [if_(NOT(S(2)), [see("551")], [if_(NOT(S(4)), [see("559")], [if_(NOT(S(6)), [see("566")], [see("577")])])])])
par("551", "[s2] Attiva il tedesco 24 in B9, accovacciato in un cratere (metti il segnalino). Iniziano i Round, vantaggio tedesco; riceve "
           "2 turni.", sighting(2) + [{"op": "cratere_hex", "hex": "B9"}, activate([(24, "B9")], "crouching", adv="de", two=[24])])
par("559", "[s4] Attiva i tedeschi 48 e 49 su una motocicletta in W1. Iniziano i Round, vantaggio tedesco; ricevono 2 turni.",
    sighting(4) + [{"op": "colonna_ph", "mezzi": [["moto", 48, [49]]], "hex": "W1", "two": [48, 49], "reazione": ""}])
par("566", "[s6] Attiva i tedeschi 52 e 53 su un’auto comando in W1. Iniziano i Round, vantaggio tedesco; ricevono 2 turni. Il tedesco 53 "
           "è un corriere delle SS con una borsa sigillata.",
    sighting(6) + [{"op": "colonna_ph", "mezzi": [["auto_comando", 52, [53]]], "hex": "W1", "two": [52, 53], "reazione": ""}])
par("577", "• Se tutti i ponti sono distrutti, vedi 587.\n• Altrimenti vedi 639.", [if_({"ponti_distrutti": True}, [see("587")], [see("639")])])
par("587", "Passa alla Condizione 4.", [cond(4)])
par("639", "Tira un dado:\n0–1: vedi 447.\n2–3: vedi 443.\n4–5: vedi 485.\n6: vedi 461.\n7: vedi 623.\n8–9: nessun evento.",
    [die((0, 1, [see("447")]), (2, 3, [see("443")]), (4, 5, [see("485")]), (6, 6, [see("461")]), (7, 7, [see("623")]), (8, 9, []))])
par("706", "Da ora in poi, durante i Round, non si fanno più controlli dei paragrafi. Tornando alle Operazioni si controllano normalmente.",
    [{"op": "niente_controlli_round"}])
par("701", "• Se tutti gli 8 soldati americani sono attivi e i ponti sono saltati, vedi 707.\n• Altrimenti vedi 641.",
    [if_({"tutti_attivi_ponti": True}, [see("707")], [see("641")])])
par("707", "Tutti i tedeschi rimasti si arrendono! Guadagni 5 PV per il lavoro ben fatto. La missione finisce subito.", [{"op": "resa_generale"}])
par("652", "I documenti rivelano le formule segrete per produrre carburante sintetico. Guadagni 5 PV.",
    [{"op": "vp", "n": 5, "why": "documenti della borsa sigillata"}])
par("585", "Il Jagdpanther sembra solo parzialmente fuori uso (in questa versione non si può usare).", [])

# ------------------------------------------------------------------ movimenti
mov("369", "• Se si muove un mezzo, entra in R12.\n• Altrimenti entra in R10.", [if_({"vehicle_moving": True}, [enter("R12")], [enter("R10")])])
mov("603", "• Se si muovono i tedeschi 48 e 49, entra in V5.\n• Altrimenti entra in U5.", [if_({"vehicle_moving": True}, [enter("V5")], [enter("U5")])])
mov("611", "• Se un ponte è ancora intatto, si ferma e mette la reazione speciale A per i tedeschi 48 e 49.\n• Se tutti i ponti sono distrutti, "
           "entra in W9 e passa alla Condizione 4 alla fine del Round.",
    [if_({"ponti_distrutti": True}, [enter("W9"), cond(4)], [{"op": "reazione_nums", "nums": [48, 49], "r": "A"}, {"op": "ferma_g"}])])
mov("676", "Passa alla Condizione 4.", [cond(4)])
mov("686", "• Se il ponte in R10 è intatto, entra in R9.\n• Altrimenti entra in Q9.", [if_({"ponte_ok": "R10"}, [enter("R9")], [enter("Q9")])])
mov("693", "• Se il ponte in J11 è intatto, entra in J11.\n• Altrimenti entra in I10.", [if_({"ponte_ok": "J11"}, [enter("J11")], [enter("I10")])])
mov("697", "• Se il ponte in G11 è intatto, entra in H10.\n• Altrimenti entra in I9 e passa alla Condizione 4.",
    [if_({"ponte_ok": "G11"}, [enter("H10")], [enter("I9"), cond(4)])])
mov("738", "Scende al pianterreno ed entra in W14.", [{"op": "g_pianterreno"}, enter("W14")])
mov("748", "• Se il ponte in R10 è minato (o lo si sta minando), entra in R11.\n• Se il ponte è saltato, reazione speciale Q.\n• Altrimenti "
           "toglie la reazione speciale L.",
    [if_({"ponte_minato": "R10"}, [enter("R11")], [if_({"ponte_ok": "R10"}, [{"op": "g_reaction", "r": ""}], [{"op": "g_reaction", "r": "Q"}])])])
mov("756", "• Se si muove un mezzo, entra in R11.\n• Altrimenti vedi 759.", [if_({"vehicle_moving": True}, [enter("R11")], [see("759")])])
mov("759", "Il tedesco sul ponte: se le cariche sono innescate e non ci sono americani nell’esagono, ne getta via una (il ponte non è più "
           "minato); se ci sono americani, li assalta. Altrimenti entra in Q10, toglie la reazione L e mette la reazione Q.",
    [{"op": "tedesco_sotto_ponte"}])

# ------------------------------------------------------------------ azioni dei tedeschi (Purple Heart)
AZ = {
    "341": "• Se il tedesco 52 è attivo, esegue 801.\n• Altrimenti vedi 913.",
    "343": "• Se il tedesco 52 è attivo, esegue 825.\n• Altrimenti vedi 913.",
    "350": "• A est del fiume esegue 840.\n• A ovest del fiume esegue 825.",
    "358": "• A est del fiume esegue 840.\n• A ovest del fiume esegue 808.",
    "363": "• A est del fiume esegue 840.\n• A ovest del fiume esegue 801.",
    "624": "Motociclista: fuori dal mezzo passa alla reazione C; con la moto fuori uso scende, cade prono e passa alla reazione C. Prima "
           "dell’auto comando (s6) fa il miglior tiro al più facile; poi, finché l’auto non ha passato il fiume, spara a chi è su un ponte "
           "o accanto (altrimenti dado: 0–3 801, 4–6 829, 7–9 840); quando l’auto è passata, il 48 corre in U9 e il 49 esegue 802.",
    "627": "Come 624 ma con il bersaglio più vicino; senza bersagli sul ponte dado: 0–3 825, 4–6 802, 7 840, 8–9 818; quando l’auto è "
           "passata, il 48 corre in U9 e il 49 non fa nulla.",
    "659": "Prima di s6 tira un dado: 0–4 808, 5–7 829, 8–9 801. Poi, finché l’auto comando non ha passato il fiume, spara a chi è su un "
           "ponte o accanto (altrimenti dado: 0–3 801, 4–6 829, 7–9 840). Quando è passata: toglie la reazione C, esegue 868 verso U9 e "
           "al turno seguente passa alla reazione B.",
    "661": "• Se un ponte è intatto, tira un dado: 0–1 862, 2–3 863, 4–5 864, 6–7 865, 8 866, 9 840.\n• Se tutti i ponti sono saltati, "
           "vedi 820.",
    "710": "Miglior tiro a chi è su un ponte o accanto (il più vicino), poi prono se può; altrimenti esegue 801.",
    "715": "Miglior tiro a chi è su un ponte o accanto (il più vicino), poi prono se può; altrimenti esegue 825.",
    "721": "Miglior tiro a chi è su un ponte o accanto (il più vicino), poi prono se può; altrimenti esegue 808.",
    "731": "Mette la reazione speciale L e ritira il numero d’azione.",
    "761": "Con la mitragliatrice: miglior tiro a chi è su un ponte o accanto, poi prono se può; altrimenti miglior tiro al più facile "
           "con l’arma personale.",
    "769": "Con la mitragliatrice: miglior tiro a chi è su un ponte o accanto; altrimenti miglior tiro al più vicino; poi prono se può.",
    "771": "Con la mitragliatrice: miglior tiro a chi è su un ponte o accanto; altrimenti tiri rapidi al più vicino e al secondo; poi "
           "prono se può. Senza bersagli si accovaccia.",
    "780": "• Entro 8 esagoni da un altro tedesco attivo esegue 869.\n• Altrimenti cade prono.",
    "783": "• Entro 6 esagoni da un altro tedesco attivo si accovaccia e fa il miglior tiro al più vicino.\n• Altrimenti cade prono.",
    "785": "• Entro 3 esagoni da un altro tedesco attivo esegue 829.\n• Altrimenti cade prono.",
    "804": "• Se vede un altro tedesco attivo, tiri rapidi a quanti più bersagli può.\n• Altrimenti cade prono.",
    "834": "• Nell’esagono di un mezzo tedesco attivo si accovaccia e fa il miglior tiro al più facile, poi prono se può.\n• Altrimenti "
           "vedi 803.",
    "846": "• Con 3 o più bersagli in vista cade prono.\n• Con 2 bersagli esegue 815.\n• Con 1 bersaglio si alza e fa il miglior tiro "
           "con l’arma personale, poi prono se può.",
    "848": "1. Con una granata e un bersaglio entro 3 esagoni si accovaccia e la lancia; poi prono se può.\n2. Con una granata e un "
           "bersaglio tra 4 e 6 esagoni si alza e la lancia; poi prono se può.\n3. Altrimenti cade prono.",
    "852": "• Con uno o due bersagli in vista si alza e spara di rapido a ciascuno.\n• Altrimenti cade prono.",
    "855": "• A est del fiume esegue 840.\n• A ovest tira un dado: 0–2 802, 3–5 840, 6–7 869, 8–9 801.",
    "872": "• Mezzo fuori uso: scende, cade prono e passa alla reazione L.\n• Mai bersagliato: guida lento.\n• Bersagliato: guida veloce "
           "e tiro rapido al più vicino con il mitra.",
    "876": "• Mezzo fuori uso: scende, cade prono e passa alla reazione L.\n• Mai bersagliato: guida lento.\n• Bersagliato: guida veloce "
           "e tiro rapido al più vicino con la pistola.",
    "881": "• A est del fiume guida lento.\n• A ovest del fiume guida veloce.",
    "886": "Guida lento e spara un tiro rapido al più vicino con il mitra.",
    "889": "• Se il tedesco 53 è fuori combattimento nell’esagono, prende la borsa sigillata.\n• Altrimenti esegue 864.",
    "893": "• Se il tedesco 53 è fuori combattimento nell’esagono, prende la borsa sigillata.\n• Altrimenti esegue 865.",
    "898": "• Se il tedesco 53 è fuori combattimento nell’esagono, prende la borsa sigillata.\n• Altrimenti esegue 866.",
    "913": "• Se il mezzo è intatto, reazione speciale D.\n• Se è fuori uso, reazione speciale L.",
    "916": "Passa al posto di guida (o, se c’è già, guida veloce); tiro rapido con la pistola al più vicino.",
    "918": "Passa al posto di guida (o, se c’è già, guida veloce); tiro rapido con la pistola al più vicino.",
    "919": "• Se il tedesco 52 è attivo non fa nulla.\n• Altrimenti vedi 913.",
}
for k, v in AZ.items():
    az(k, v)
