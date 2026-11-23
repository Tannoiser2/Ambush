# -*- coding: utf-8 -*-
"""Move Out! – Missione 12 «Per la cruna dell’ago» (mappa A poi mappa B, dintorni di Parigi, 16 agosto 1944).

Condizione 1 (mappa A): la squadra cerca Claude, partigiano francese, che la porta alla chiatta in M12.
Dalla Condizione 2 (mappa B): il villaggio, la sentinella, il faro sul campanile, la galleria e i prigionieri.
"""
from paragrafi_m1 import pc, act, see, if_, S, NOT, sighting, cond, die, activate

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def mov(pid, it, ops):
    par(pid, it, ops, "movimento")


def enter(h):
    return {"op": "g_enter", "hex": h}


def flag(k):
    return {"op": "nota", "chiave": k}


SE_C4 = [if_({"cond_in": [4]}, [cond(5)])]
# I mitraglieri 18 e 19 sono al piano superiore del campanile di S13.
PIANO = {k: [{"op": "al_piano", "g": [18, 19]}] for k in ("651", "652", "898")}
TESTO_C4 = " Se si è nella Condizione 4 si passa alla 5; nella 3 si resta nella 3."


def sentinella(base, h, posizione, primo):
    """Le terne della sentinella SS (tedesco 11): vantaggio americano / tedesco / nessuno."""
    us, de, no = base
    par(us, f"[s3] Attiva il tedesco 11 in {h}, {posizione}. Iniziano i Round con vantaggio americano: chi lo vede è "
            "consapevole e riceve 2 turni in questo Round. Si passa alla Condizione 3.",
        sighting(3) + [activate([(11, h)], primo, adv="us", us_two=True, aware=True), cond(3)])
    par(de, f"[s3] Attiva il tedesco 11 in {h}, {posizione}. Iniziano i Round con vantaggio tedesco. Si passa alla Condizione 3.",
        sighting(3) + [activate([(11, h)], primo, adv="de"), cond(3)])
    par(no, f"[s3] Attiva il tedesco 11 in {h}, {posizione}. Iniziano i Round. Si passa alla Condizione 3.",
        sighting(3) + [activate([(11, h)], primo), cond(3)])


def dado_sentinella(pid, soglia, us, pc_ko, de, no):
    par(pid, f"Tira un dado. 0–{soglia}: controllo di percezione, se riesce vedi {us}, se fallisce vedi {pc_ko}. "
             f"{soglia + 1}–9: controllo di attivazione, se riesce vedi {de}, se fallisce vedi {no}.",
        [die([0, soglia, [pc(0, [see(us)], [see(pc_ko)])]], [soglia + 1, 9, [act(0, [see(de)], [see(no)])]])])


def att_doppia(pid, de, us_, s, gs, h, testo):
    par(pid, f"Tira un dado: 0–5 vedi {de}; 6–9 vedi {us_}.", [die([0, 5, [see(de)]], [6, 9, [see(us_)]])])
    coppie = [(g, h) for g in gs]
    par(de, f"[s{s}] Attiva {testo} in {h}, accovacciat{'i' if len(gs) > 1 else 'o'}. Iniziano i Round con vantaggio tedesco." + TESTO_C4,
        sighting(s) + [activate(coppie, "crouching", adv="de")] + PIANO.get(de, []) + SE_C4)
    par(us_, f"[s{s}] Attiva {testo} in {h}, accovacciat{'i' if len(gs) > 1 else 'o'}. Iniziano i Round con vantaggio americano: "
             "i soldati consapevoli ricevono 2 turni in questo Round." + TESTO_C4,
        sighting(s) + [activate(coppie, "crouching", adv="us", us_two=True)] + PIANO.get(us_, []) + SE_C4)


# ------------------------------------------------------------------ Condizione 1, mappa A
par("402", "Controllo di percezione: se riesce, vedi 407.", [pc(0, [see("407")])])
par("407", "[s0] Il soldato sente una radio che suona verso sud.", sighting(0))
par("415", "[s1] Il soldato vede una luce nell’edificio in T8.", sighting(1))
par("436", "Il soldato vede una piccola baracca di una stanza: due sedie, un tavolo e un letto. Una radio suona.", [])
par("429", "Il soldato vede una luce lampeggiare in P11 e sente sussurrare con accento francese: «Psst! Di qua. Non sparate.» "
    "Da ora si ignorano gli altri rimandi a questo paragrafo.",
    [if_({"flag": "mo429"}, [], [flag("mo429")])])
par("433", "[s2] Un partigiano francese contatta la squadra in P11: è Claude (carta americana 06). Sa dove sono i compagni "
    "scomparsi e lo dirà appena avrà una sigaretta americana. Dopo una lunga boccata racconta che sono tenuti in un piccolo "
    "villaggio a sud: la zona è minata e non ci si arriva via terra. Ha una chiatta nascosta in M12 e conosce la strada. "
    "Quando un soldato entra in M12, vedi 442. Claude è bravo coi coltelli e fa parte della squadra fino alla fine; "
    "se viene ucciso o incapacitato e resta in mappa perdi 2 PV come per gli altri.",
    sighting(2) + [{"op": "claude", "hex": "P11"}])
par("442", "In M12 c’è la chiatta (vale come una canoa da dieci posti, con tutto l’equipaggiamento: si affonda solo con una "
    "penetrazione pesante). Claude mette il timone controcorrente e la squadra ai remi. Seguite il fiume finché la chiatta "
    "esce da O19: allora vedi 465.", [{"op": "chiatta", "hex": "M12"}])
par("446", "Tra lo sciabordio dei remi, la squadra sente in lontananza voci tedesche.", [])
par("465", "Si passa alla Condizione 2: si toglie la mappa A e si prende la mappa B, nord in alto; il corso d’acqua è lo stesso "
    "fiume. La chiatta entra in A6. La missione finisce nelle Condizioni 3, 4 o 5 quando l’ultimo americano attivo esce dal "
    "bordo ovest, tra A1 e A19.", [{"op": "chiatta_mappa_b", "hex": "A6"}, cond(2)])
par("934", "Campo minato! Si applica la procedura del campo minato. Nella Condizione 2 si passa alla 3; nella 4 alla 5.",
    [{"op": "minefield"}, if_({"cond_in": [2]}, [cond(3)], [if_({"cond_in": [4]}, [cond(5)])])])

# ------------------------------------------------------------------ la sentinella SS (tedesco 11)
par("473", "Controllo di percezione: se riesce vedi 474, se fallisce vedi 482.", [pc(0, [see("474")], [see("482")])])
par("474", "Il soldato vede la sagoma di una sentinella tedesca in K9 e la squadra apre il fuoco per prima: vedi 479. "
    "(Nel gioco da tavolo potresti anche proseguire di nascosto.)", [see("479")])
par("479", "[s3] Attiva il tedesco 11 in K9, in piedi. Iniziano i Round con vantaggio americano: tutti gli americani sono "
    "consapevoli e ricevono 2 turni in questo Round. Si passa alla Condizione 3.",
    sighting(3) + [activate([(11, "K9")], "standing", adv="us", us_two=True, aware=True), {"op": "tutti_consapevoli"}, cond(3)])
par("482", "Controllo di attivazione: se riesce, vedi 484; altrimenti nessun evento.", [act(0, [see("484")])])
par("484", "[s3] Attiva il tedesco 11 in K9, in piedi. Iniziano i Round con vantaggio tedesco. Claude è consapevole nel Round 1. "
    "Si passa alla Condizione 3.", sighting(3) + [activate([(11, "K9")], "standing", adv="de"), cond(3)])
dado_sentinella("490", 5, "491", "493", "494", "496")
dado_sentinella("498", 4, "491", "493", "494", "496")
par("493", "Controllo di attivazione: se riesce vedi 494, se fallisce vedi 496.", [act(0, [see("494")], [see("496")])])
sentinella(("491", "494", "496"), "K7", "accovacciato", "crouching")
dado_sentinella("499", 5, "602", "603", "605", "607")
par("603", "Controllo di attivazione: se riesce vedi 605, se fallisce vedi 607.", [act(0, [see("605")], [see("607")])])
sentinella(("602", "605", "607"), "L5", "accovacciato", "crouching")
dado_sentinella("609", 5, "610", "412", "612", "614")
par("412", "Controllo di attivazione: se riesce vedi 612, se fallisce vedi 614.", [act(0, [see("612")], [see("614")])])
sentinella(("610", "612", "614"), "O5", "accovacciato", "crouching")
dado_sentinella("616", 5, "617", "618", "619", "622")
par("618", "Controllo di attivazione: se riesce vedi 619, se fallisce vedi 622.", [act(0, [see("619")], [see("622")])])
sentinella(("617", "619", "622"), "J13", "accovacciato", "crouching")
dado_sentinella("626", 4, "628", "630", "632", "634")
par("630", "Controllo di attivazione: se riesce vedi 632, se fallisce vedi 634.", [act(0, [see("632")], [see("634")])])
sentinella(("628", "632", "634"), "L12", "accovacciato", "crouching")
dado_sentinella("636", 4, "638", "640", "641", "643")
par("640", "Controllo di attivazione: se riesce vedi 641, se fallisce vedi 643.", [act(0, [see("641")], [see("643")])])
sentinella(("638", "641", "643"), "K15", "accovacciato", "crouching")

# ------------------------------------------------------------------ il villaggio
att_doppia("647", "651", "652", 5, [18, 19], "S13", "i mitraglieri 18 e 19 (al primo piano)")
att_doppia("654", "656", "659", 9, [56], "S9", "il tedesco 56")
att_doppia("661", "663", "666", 7, [55], "R7", "l’ufficiale SS 55")
att_doppia("667", "669", "670", 6, [54], "P9", "il tedesco 54")
att_doppia("671", "673", "675", 4, [57], "P5", "il tedesco 57")
att_doppia("677", "679", "681", 8, [17], "L10", "il tedesco 17")
par("682", "Se Claude e almeno un altro americano attivo sono in questo esagono, vedi 487; altrimenti si passa alla Condizione 3.",
    [if_({"claude_qui": True}, [see("487")], [cond(3)])])
par("487", "Si passa alla Condizione 4. Claude rivela che sotto questo ponte comincia una galleria che va dritta fino a R7, "
    "scavata dalla Resistenza durante l’occupazione: i tedeschi non ne sanno nulla. Si entra solo da sotto il ponte in G13 "
    "(un punto movimento in più per entrare o uscire); in galleria si leggono solo i paragrafi segnati con la T e nessun "
    "tedesco può vedere chi ci cammina.", [cond(4), {"op": "galleria"}])
par("976", "Se il soldato è nella galleria vedi 683; altrimenti si ignora.", [if_({"in_galleria": True}, [see("683")])])
par("977", "Se il soldato è nella galleria vedi 685; altrimenti vedi 661.", [if_({"in_galleria": True}, [see("685")], [see("661")])])
par("683", "Qui una botola si apre sul pianterreno: i soldati possono salire (senza controllo del paragrafo all’uscita) o "
    "proseguire nella galleria. Salire o scendere costa un punto movimento.", [{"op": "botola", "hex": "N9"}])
par("685", "La galleria finisce qui, sotto un’altra botola che dà sul pianterreno. Salire o scendere costa un punto movimento; "
    "si può salire o tornare indietro. Se si sale e l’avvistamento 7 non è avvenuto, vedi subito 687.",
    [{"op": "botola", "hex": "R7"}])
par("687", "Tira un dado: 0–4 vedi 689; 5–9 vedi 690.", [die([0, 4, [see("689")]], [5, 9, [see("690")]])])
par("689", "[s7] Sorprendete un generale delle SS nel sonno! Attiva il tedesco 55 in R7, prono. Iniziano i Round con vantaggio "
    "americano: chi è nella stanza col generale è consapevole e ha 2 turni. Si passa alla Condizione 5.",
    sighting(7) + [activate([(55, "R7")], "prone", adv="us", us_two=True, aware=True), cond(5)])
par("690", "[s7] Attiva il tedesco 55 in R7, in piedi. Iniziano i Round con vantaggio tedesco e il 55 riceve 2 turni; chi è nella "
    "stanza col generale è consapevole. Si passa alla Condizione 5.",
    sighting(7) + [activate([(55, "R7")], "standing", adv="de", two=[55]), cond(5)])
par("692", "Avete trovato i compagni! Sono legati e imbavagliati sul pavimento, torturati. Mettili in questo esagono, proni e "
    "feriti. Nei Round serve un’azione per slegare ciascuno; nelle Operazioni possono muoversi subito. Nei Round, chi viene "
    "slegato è consapevole e riceve un turno.", [{"op": "prigionieri_trovati"}])

# ------------------------------------------------------------------ eventi
par("694", "1. Se l’avvistamento 3 non è avvenuto vedi 696. 2. Se non è avvenuto il 4 vedi 698. 3. Se non è avvenuto il 9 vedi "
    "699. 4. Se non è avvenuto il 6 vedi 896. 5. Se non è avvenuto il 5 vedi 898. 6. Se non è avvenuto l’8 vedi 940. "
    "7. Se non è avvenuto il 7 vedi 942. 8. Nessun evento.",
    [if_(NOT(S(3)), [see("696")], [if_(NOT(S(4)), [see("698")], [if_(NOT(S(9)), [see("699")], [if_(NOT(S(6)), [see("896")],
     [if_(NOT(S(5)), [see("898")], [if_(NOT(S(8)), [see("940")], [if_(NOT(S(7)), [see("942")], [])])])])])])])])
for pid, s, gs, h, st in [("696", 3, [11], "K7", "standing"), ("698", 4, [57], "P5", "crouching"), ("699", 9, [56], "S9", "crouching"),
                          ("896", 6, [54], "P9", "crouching"), ("898", 5, [18, 19], "S13", "crouching"),
                          ("940", 8, [17], "L10", "crouching"), ("942", 7, [55], "R7", "crouching")]:
    nomi = " e ".join(f"il tedesco {g}" for g in gs)
    par(pid, f"[s{s}] Attiva {nomi} in {h}, {'in piedi' if st == 'standing' else 'accovacciat' + ('i' if len(gs) > 1 else 'o')}. "
             "Iniziano i Round.", sighting(s) + [activate([(g, h) for g in gs], st)] + PIANO.get(pid, []))
for pid, tab in [("944", ["A1", "D1", "H1", "L1", "P1", "T1", "X1", "Y4", "Y8", "Y12"]),
                 ("945", ["Y16", "X18", "T19", "P19", "L19", "H19", "D19", "A18", "A14", "A10"]),
                 ("946", ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9", "A11"])]:
    par(pid, "Un faro! Una fotoelettrica tedesca al primo piano di S13 spazza la zona. Un dado decide dove punta: "
             + ", ".join(f"{i}: {h}" for i, h in enumerate(tab)) + ". Poi vedi 948.", [{"op": "faro", "da": "S13", "tab": tab}])
par("948", "Si traccia una linea dritta da S13 all’esagono puntato: ogni esagono della linea in vista dal primo piano di S13 è "
    "illuminato per un momento. Se un americano è nella luce, si passa subito dalla Condizione 2 alla 3 (o dalla 4 alla 5) e "
    "la mitragliatrice spara un tiro rapido (abilità 0) al bersaglio illuminato più vicino.", [])
par("947", "Un partigiano nascosto spara a un tedesco scelto a caso in un esagono aperto: tiro rapido, gittata media, pistola, "
    "abilità −2.", [{"op": "partigiano"}])
par("949", "Se in questo Round si è sparato, vedi 694; altrimenti nessun evento.", [if_({"spari": True}, [see("694")])])
par("485", "Un tedesco ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Una volta sola per missione.",
    [{"op": "dissanguamento", "lato": "de", "chiave": "mo485"}])
par("623", "Un americano ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Una volta sola per missione.",
    [{"op": "dissanguamento", "lato": "us", "chiave": "mo623"}])

# ------------------------------------------------------------------ movimenti e azioni dei tedeschi
for pid, a, b, soglia in [("953", "L11", "L10", 6), ("955", "L7", "L6", 4), ("961", "R7", "Q9", 4), ("963", "J11", "K13", 5)]:
    mov(pid, f"Tira un dado: 0–{soglia} entra in {a}; {soglia + 1}–9 entra in {b}.",
        [die([0, soglia, [enter(a)]], [soglia + 1, 9, [enter(b)]])])
par("967", "Mette in vigore la reazione speciale L per questo tedesco (togliendo quella che aveva).", [{"op": "g_reaction", "r": "L"}], "azione")
par("969", "Se non ha bersagli attivi in vista lascia la mitragliatrice al suo posto, scende al pianterreno e mette in vigore la "
    "reazione speciale A.", [if_({"g_vede_almeno": 1}, [], [{"op": "g_reaction", "r": "A"}, {"op": "g_pianterreno"}])], "azione")
