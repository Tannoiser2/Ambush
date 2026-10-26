# -*- coding: utf-8 -*-
"""Paragrafi della Missione 1 «Sangue a Saint-Michaux».

Testo inglese verificato riga per riga sulle scansioni originali del Paragraph
Book (pagine 2, 5, 6, 7, 8, 9, 12, 15, 16, 18). Per ogni paragrafo raggiungibile
dalle carte Condizione o dalle carte dei tedeschi della missione 1 qui c'è:
  - il testo italiano (traduzione rivista),
  - lo script «ops» eseguito dal motore.

Vocabolario delle ops: vedi scripts/motore/paragrafi.gd.
"""

# ---------------------------------------------------------------- helper
def pc(mod=0, ok=None, ko=None):
    return {"op": "check", "kind": "pc", "mod": mod, "ok": ok or [], "ko": ko or []}

def act(mod=0, ok=None, ko=None):
    return {"op": "check", "kind": "act", "mod": mod, "ok": ok or [], "ko": ko or []}

def see(p):
    return {"op": "goto", "p": p}

def die(*branches):
    return {"op": "die", "b": [[lo, hi, ops] for lo, hi, ops in branches]}

def if_(test, then, other=None):
    return {"op": "if", "t": test, "then": then, "else": other or []}

def S(n):
    return {"s": n}

def NOT(t):
    return {"not": t}

def ALL(*t):
    return {"all": list(t)}

def sighting(*ns):
    return [{"op": "sighting", "s": n} for n in ns]

def activate(germans, stance, adv=None, two=None, us_two=False, aware=False, reaction=None, rounds=True):
    return {"op": "activate", "g": [[g, h] for g, h in germans], "stance": stance, "adv": adv,
            "two": two or [], "us_two": us_two, "aware": aware, "reaction": reaction, "rounds": rounds}

def cond(n):
    return {"op": "condition", "n": n}

EVENT = {"op": "event_marker"}
NOEV = {"op": "nothing"}

P = {}

def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}

# ---------------------------------------------------------------- 0xx
par("001", "Campo minato! Esegui la procedura del campo minato.",
    [{"op": "minefield"}])
par("007", "Dev’essere stato il vento.", [])
par("010", "Falso allarme.", [])
par("011", "Possibile colpo d’artiglieria casuale. Tira i dadi percentuali leggendo la cifra più bassa come «decine» e la più alta come «unità» (non si dichiara prima quale dado indica le decine). Se il risultato è 25 o meno, tira di nuovo leggendo i dadi nello stesso modo. Se il secondo risultato è 19 o meno, i due risultati insieme danno le coordinate dell’esagono colpito: per esempio 13 e 18 indicano l’esagono 1318, cioè M18. Colloca un segnalino Cratere nell’esagono colpito; se è un edificio, colloca invece un segnalino Macerie. Tutti i soldati nell’esagono muoiono e i veicoli sono distrutti. Se uno dei due tiri supera i limiti indicati, il colpo cade fuori mappa: i tuoi soldati sentono un’esplosione lontana.",
    [{"op": "artillery"}])
par("012", "Se un soldato americano porta una granata, una granata esplode accidentalmente. Determina a caso a quale soldato appartiene. Solo il soldato che porta la granata difettosa effettua un controllo di percezione:\n• se lo supera, può gettare la granata in un esagono adiacente non occupato, dove esplode senza danni;\n• se lo fallisce, lui e tutti gli altri soldati nel suo esagono sono colpiti dall’esplosione. Il soldato con la granata si considera al chiuso, ovunque si trovi. Nessun altro soldato nel suo esagono può effettuare un controllo di percezione per questa esplosione.",
    [{"op": "grenade_accident"}])
par("013", "È soltanto la tua immaginazione.", [])
par("018", "Un’arma tedesca usata nel Round precedente ha finito le munizioni. Se nel Round precedente hanno sparato più armi tedesche, determina a caso quale.",
    [{"op": "ammo_out"}])
par("020", "Un soldato è bersaglio di un tiratore nascosto; i Round non iniziano. Risolvi un tiro con queste caratteristiche:\n• mirato\n• gittata corta\n• fucile a otturatore con ottica\n• abilità con le armi 0",
    [{"op": "sniper"}])
par("023", "Un soldato è bersaglio di un tiratore nascosto (i Round non iniziano). Risolvi un tiro con queste caratteristiche:\n• mirato\n• gittata corta\n• fucile a otturatore con ottica\n• abilità con le armi 0",
    [{"op": "sniper"}])
par("024", "Colloca un segnalino Evento. Effettua un controllo di percezione (−1). Se riesce, vedi 013.",
    [EVENT, pc(-1, [see("013")])])
par("025", "Colloca un segnalino Evento. Effettua un controllo di percezione (−1). Se riesce, vedi 007.",
    [EVENT, pc(-1, [see("007")])])
par("026", "Il soldato con la percezione più alta tra quelli che vedono l’esagono U9 deve effettuare un controllo di percezione. Se riesce, vedi 007.",
    [{"op": "best_pc", "hex": "U9", "mod": 0, "ok": [see("007")]}])
par("027", "Qualsiasi soldato tedesco rimosso dal gioco con un movimento evasivo non può rientrare in gioco per il resto della missione. Questa istruzione prevale su ogni successivo riferimento contrario dei paragrafi.",
    [{"op": "no_reentry"}])
par("028", "Il soldato con la percezione più alta tra quelli che vedono l’esagono O12 deve effettuare un controllo di percezione. Se riesce, vedi 010.",
    [{"op": "best_pc", "hex": "O12", "mod": 0, "ok": [see("010")]}])
par("029", "Se l’evento è stato provocato da un soldato entrato in un esagono di bosco o accidentato, ha spaventato un nido di uccelli, che si alzano in volo.",
    [{"op": "birds"}])
par("030", "Il soldato con la percezione più alta tra quelli che vedono l’esagono D17 deve effettuare un controllo di percezione. Se riesce, vedi 013.",
    [{"op": "best_pc", "hex": "D17", "mod": 0, "ok": [see("013")]}])

# ---------------------------------------------------------------- 17x-19x
par("179", "Effettua un controllo di attivazione (+2):\n• se riesce, vedi 288;\n• se fallisce, vedi 310.",
    [act(2, [see("288")], [see("310")])])
par("180", "[s1] Attiva i tedeschi 9 e 15 nell’esagono K13, accovacciati. Iniziano i Round. Vantaggio tedesco. I tedeschi appena attivati ricevono 2 turni in questo Round. Passa alla Condizione 3.",
    sighting(1) + [activate([(9, "K13"), (15, "K13")], "crouching", adv="de", two=[9, 15]), cond(3)])
par("181", "Tira un dado:\n0–5: effettua un controllo di attivazione (+3). Se riesce, vedi 020.\n6–8: nessun effetto.\n9: effettua un controllo di percezione (−1). Se riesce, vedi 289.",
    [die((0, 5, [act(3, [see("020")])]), (6, 8, []), (9, 9, [pc(-1, [see("289")])]))])
par("182", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 291;\n• se fallisce, vedi 313.",
    [act(1, [see("291")], [see("313")])])
par("183", "[s2] Attiva il tedesco 25 nell’esagono M7, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 25 riceve 2 turni in questo Round. Passa alla Condizione 3.",
    sighting(2) + [activate([(25, "M7")], "crouching", adv="de", two=[25]), cond(3)])
par("184", "Tira un dado:\n0–4: se s2 non è avvenuto, effettua un controllo di attivazione (+3). Se riesce, vedi 020.\n5–8: se s3 non è avvenuto, effettua un controllo di percezione. Se riesce, vedi 293.\n9: se s2 non è avvenuto, effettua un controllo di percezione. Se riesce, vedi 289.",
    [die((0, 4, [if_(NOT(S(2)), [act(3, [see("020")])])]),
         (5, 8, [if_(NOT(S(3)), [pc(0, [see("293")])])]),
         (9, 9, [if_(NOT(S(2)), [pc(0, [see("289")])])]))])
par("185", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 294;\n• se fallisce, effettua un controllo di percezione. Se riesce, vedi 316.",
    [act(1, [see("294")], [pc(0, [see("316")])])])
par("186", "Tira un dado:\n0–2: effettua un controllo di attivazione. Se riesce, vedi 288.\n3–8: nessun effetto.\n9: effettua un controllo di percezione (−1). Se riesce, vedi 289.",
    [die((0, 2, [act(0, [see("288")])]), (3, 8, []), (9, 9, [pc(-1, [see("289")])]))])
par("187", "[s2, s5 e s6] Attiva il tedesco 34 nell’esagono M5, il tedesco 25 nell’esagono M7 e il tedesco 53 nell’esagono O4, tutti e tre accovacciati. Iniziano i Round. Vantaggio americano. Passa alla Condizione 3.",
    sighting(2, 5, 6) + [activate([(34, "M5"), (25, "M7"), (53, "O4")], "crouching", adv="us"), cond(3)])
par("188", "Effettua un controllo di percezione:\n• se riesce, vedi 333;\n• se fallisce, vedi 297.",
    [pc(0, [see("333")], [see("297")])])
par("189", "Effettua un controllo di attivazione (+2):\n• se riesce, vedi 334;\n• se fallisce, effettua un controllo di percezione (−2). Se riesce, vedi 298.",
    [act(2, [see("334")], [pc(-2, [see("298")])])])
par("190", "Effettua un controllo di attivazione (+2):\n• se riesce, vedi 324;\n• se fallisce, effettua un controllo di percezione (−2). Se riesce, vedi 289.",
    [act(2, [see("324")], [pc(-2, [see("289")])])])
par("191", "Tira un dado:\n0–3: effettua un controllo di attivazione. Se riesce, vedi 288.\n4–8: se s3 non è avvenuto, effettua un controllo di percezione (−1). Se riesce, vedi 293.\n9: effettua un controllo di percezione. Se riesce, vedi 289.",
    [die((0, 3, [act(0, [see("288")])]),
         (4, 8, [if_(NOT(S(3)), [pc(-1, [see("293")])])]),
         (9, 9, [pc(0, [see("289")])]))])
par("192", "Tira un dado:\n0–5: effettua un controllo di attivazione (+2). Se riesce, vedi 337.\n6–8: nessun effetto.\n9: effettua un controllo di percezione (−2). Se riesce, vedi 602.",
    [die((0, 5, [act(2, [see("337")])]), (6, 8, []), (9, 9, [pc(-2, [see("602")])]))])
par("193", "Tira un dado:\n0–3: effettua un controllo di attivazione (+1). Se riesce, vedi 338.\n4–8: nessun effetto.\n9: effettua un controllo di percezione (−1). Se riesce, vedi 602.",
    [die((0, 3, [act(1, [see("338")])]), (4, 8, []), (9, 9, [pc(-1, [see("602")])]))])
par("194", "Effettua un controllo di percezione:\n• se riesce, vedi 602;\n• se fallisce, vedi 338.",
    [pc(0, [see("602")], [see("338")])])
par("195", "• Se il soldato è sul ponte, vedi 190.\n• Se il soldato è sotto il ponte, vedi 186.",
    [if_({"on_bridge": True}, [see("190")], [see("186")])])
par("196", "Tira un dado:\n0–4: effettua un controllo di attivazione (+2). Se riesce, vedi 291.\n5–8: se s8 non è avvenuto, effettua un controllo di percezione. Se riesce, vedi 342; se fallisce, colloca un segnalino Evento.\n9: effettua un controllo di percezione. Se riesce, vedi 312.",
    [die((0, 4, [act(2, [see("291")])]),
         (5, 8, [if_(NOT(S(8)), [pc(0, [see("342")], [EVENT])])]),
         (9, 9, [pc(0, [see("312")])]))])
par("197", "[s7] Attiva i tedeschi 1 e 81 nell’esagono indicato, accovacciati. Iniziano i Round. Vantaggio tedesco. Ciascun tedesco riceve 2 turni in questo Round.",
    sighting(7) + [activate([(1, "@indicato"), (81, "@indicato")], "crouching", adv="de", two=[1, 81])])
par("198", "1. Se s5 e s6 sono avvenuti, nessun evento.\n2. Se s5 è avvenuto, vedi 318.\n3. Se s6 è avvenuto, vedi 603.\n4. Se s5 e s6 non sono avvenuti, vedi 189.",
    [if_(ALL(S(5), S(6)), [], [if_(S(5), [see("318")], [if_(S(6), [see("603")], [see("189")])])])])
par("199", "1. Se s2 e s6 sono avvenuti, nessun evento.\n2. Se s2 è avvenuto, vedi 318.\n3. Se s6 è avvenuto, vedi 335.\n4. Se s2 e s6 non sono avvenuti, vedi 318.",
    [if_(ALL(S(2), S(6)), [], [if_(S(2), [see("318")], [if_(S(6), [see("335")], [see("318")])])])])

# ---------------------------------------------------------------- 28x-29x
par("288", "Effettua un controllo di percezione (−2):\n• se riesce, vedi 324;\n• se fallisce, vedi 180.",
    [pc(-2, [see("324")], [see("180")])])
par("289", "[s1] Attiva i tedeschi 9 e 15 nell’esagono K13, in piedi. Iniziano i Round. Vantaggio americano. Il soldato americano che ha appena superato il controllo di percezione è automaticamente consapevole. Tutti i soldati americani consapevoli che non cadono nel panico ricevono 2 turni in questo Round. Passa alla Condizione 3.",
    sighting(1) + [activate([(9, "K13"), (15, "K13")], "standing", adv="us", us_two=True, aware=True), cond(3)])
par("290", "Effettua un controllo di attivazione (+2):\n• se riesce, vedi 297;\n• se fallisce, effettua un controllo di percezione (−2). Se riesce, vedi 333.",
    [act(2, [see("297")], [pc(-2, [see("333")])])])
par("291", "Effettua un controllo di percezione (−2):\n• se riesce, vedi 327;\n• se fallisce, vedi 183.",
    [pc(-2, [see("327")], [see("183")])])
par("292", "• Se s3 è avvenuto, vedi 314.\n• Se s3 non è avvenuto, colloca un segnalino Evento, poi effettua un controllo di percezione (−1). Se riesce, vedi 314.",
    [if_(S(3), [see("314")], [EVENT, pc(-1, [see("314")])])])
par("293", "Il soldato nota una figura in tuta da combattimento americana distesa accanto a un albero nell’esagono G10.", [])
par("294", "[s2 e s5] Attiva il tedesco 25 nell’esagono M7 e il tedesco 34 nell’esagono M5, in piedi. Iniziano i Round. Vantaggio tedesco. Passa alla Condizione 3.",
    sighting(2, 5) + [activate([(25, "M7"), (34, "M5")], "standing", adv="de"), cond(3)])
par("295", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 183;\n• se fallisce, effettua un controllo di percezione (−2). Se riesce, vedi 312.",
    [act(1, [see("183")], [pc(-2, [see("312")])])])
par("296", "• Se s5 è avvenuto, vedi 182.\n• Se s5 non è avvenuto, effettua un controllo di attivazione. Se riesce, vedi 294; se fallisce, vedi 316.",
    [if_(S(5), [see("182")], [act(0, [see("294")], [see("316")])])])
par("297", "[s6] Attiva il tedesco 53 nell’esagono O4, accovacciato. Iniziano i Round. Vantaggio tedesco. Passa alla Condizione 2.",
    sighting(6) + [activate([(53, "O4")], "crouching", adv="de"), cond(2)])
par("298", "[s5 e s6] Attiva il tedesco 34 nell’esagono M5 e il tedesco 53 nell’esagono O4, accovacciati. Iniziano i Round. Vantaggio americano. Passa alla Condizione 2.",
    sighting(5, 6) + [activate([(34, "M5"), (53, "O4")], "crouching", adv="us"), cond(2)])
par("299", "Tira un dado:\n0–3: effettua un controllo di attivazione (+1). Se riesce, vedi 288.\n4–8: nessun effetto.\n9: effettua un controllo di percezione. Se riesce, vedi 289.",
    [die((0, 3, [act(1, [see("288")])]), (4, 8, []), (9, 9, [pc(0, [see("289")])]))])

# ---------------------------------------------------------------- 31x-35x
par("310", "Effettua un controllo di percezione:\n• se riesce, vedi 289;\n• se fallisce, vedi 324.",
    [pc(0, [see("289")], [see("324")])])
par("311", "Tira un dado:\n0–3: effettua un controllo di attivazione (+2). Se riesce, vedi 023.\n4–8: nessun effetto.\n9: effettua un controllo di percezione (−1). Se riesce, vedi 312.",
    [die((0, 3, [act(2, [see("023")])]), (4, 8, []), (9, 9, [pc(-1, [see("312")])]))])
par("312", "[s2] Attiva il tedesco 25 nell’esagono M7, in piedi. Iniziano i Round. Vantaggio americano. Il soldato americano che ha appena superato il controllo di percezione è automaticamente consapevole. Tutti i soldati americani consapevoli che non cadono nel panico ricevono 2 turni in questo Round. Passa alla Condizione 3.",
    sighting(2) + [activate([(25, "M7")], "standing", adv="us", us_two=True, aware=True), cond(3)])
par("313", "Effettua un controllo di percezione:\n• se riesce, vedi 312;\n• se fallisce, vedi 327.",
    [pc(0, [see("312")], [see("327")])])
par("314", "[s4] Il soldato nota un riflesso metallico e trova in questo esagono un mitra intatto. È scarico.",
    sighting(4) + [{"op": "place_smg"}])
par("315", "Tira un dado:\n0–8: nessun effetto. Colloca un segnalino Evento.\n9: effettua un controllo di percezione (−2). Se riesce, vedi 312.",
    [die((0, 8, [EVENT]), (9, 9, [pc(-2, [see("312")])]))])
par("316", "[s2 e s5] Attiva il tedesco 25 nell’esagono M7 e il tedesco 34 nell’esagono M5, accovacciati. Iniziano i Round. Vantaggio americano. Passa alla Condizione 3. Se un soldato americano ha appena superato un controllo di percezione per arrivare a questo paragrafo, è automaticamente consapevole.",
    sighting(2, 5) + [activate([(25, "M7"), (34, "M5")], "crouching", adv="us", aware=True), cond(3)])
par("317", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 331;\n• se fallisce, vedi 187.",
    [act(1, [see("331")], [see("187")])])
par("318", "Effettua un controllo di attivazione (+1):\n• se riesce, vedi 332;\n• se fallisce, vedi 188.",
    [act(1, [see("332")], [see("188")])])
par("319", "[s6] Attiva il tedesco 53 nell’esagono O4, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 53 riceve 2 turni in questo Round. Passa alla Condizione 2.",
    sighting(6) + [activate([(53, "O4")], "crouching", adv="de", two=[53]), cond(2)])
par("324", "[s1] Attiva i tedeschi 9 e 15 nell’esagono K13, accovacciati. Iniziano i Round. Vantaggio tedesco. Passa alla Condizione 3.",
    sighting(1) + [activate([(9, "K13"), (15, "K13")], "crouching", adv="de"), cond(3)])
par("325", "Tira un dado:\n0–3: effettua un controllo di attivazione (+2). Se riesce, vedi 023.\n4–8: nessun effetto.\n9: effettua un controllo di percezione (−2). Se riesce, vedi 289.",
    [die((0, 3, [act(2, [see("023")])]), (4, 8, []), (9, 9, [pc(-2, [see("289")])]))])
par("326", "Tira un dado:\n0–3: effettua un controllo di attivazione (+1). Se riesce, vedi 297.\n4–8: nessun effetto.\n9: effettua un controllo di percezione (+2). Se riesce, vedi 333.",
    [die((0, 3, [act(1, [see("297")])]), (4, 8, []), (9, 9, [pc(2, [see("333")])]))])
par("327", "[s2] Attiva il tedesco 25 nell’esagono M7, accovacciato. Iniziano i Round. Vantaggio tedesco. Passa alla Condizione 3.",
    sighting(2) + [activate([(25, "M7")], "crouching", adv="de"), cond(3)])
par("328", "[s3] Il soldato trova un uomo incapacitato della squadra caduta nell’imboscata stamattina. Ha due caricatori per mitra e una granata. Riesce a parlare: dice di aver perso il suo mitra una ventina di metri più avanti (nell’esagono I11). Colloca il soldato americano K nell’esagono G10 (non ha una carta). Se porti quest’uomo al sicuro (in un edificio o fuori dalla mappa, secondo il modo in cui termina la missione) ed è vivo alla fine della missione, ottieni 3 PV.",
    sighting(3) + [{"op": "place_k"}])
par("329", "Colloca un segnalino Evento. Effettua un controllo di percezione (−2). Se riesce, vedi 007.",
    [EVENT, pc(-2, [see("007")])])
par("330", "Effettua un controllo di attivazione (+3):\n• se riesce, vedi 294;\n• se fallisce, effettua un controllo di percezione. Se riesce, vedi 316.",
    [act(3, [see("294")], [pc(0, [see("316")])])])
par("331", "[s2, s5 e s6] Attiva il tedesco 25 nell’esagono M7, il tedesco 34 nell’esagono M5 e il tedesco 53 nell’esagono O4, tutti e tre accovacciati. Iniziano i Round. Vantaggio tedesco. Il tedesco 34 riceve 2 turni in questo Round (gli altri tirano normalmente). Passa alla Condizione 2.",
    sighting(2, 5, 6) + [activate([(25, "M7"), (34, "M5"), (53, "O4")], "crouching", adv="de", two=[34]), cond(2)])
par("332", "Effettua un controllo di percezione (−2):\n• se riesce, vedi 297;\n• se fallisce, vedi 319.",
    [pc(-2, [see("297")], [see("319")])])
par("333", "[s6] Attiva il tedesco 53 nell’esagono O4, in piedi. Iniziano i Round. Vantaggio americano. Il soldato che ha appena superato il controllo di percezione è automaticamente consapevole. Tutti i soldati americani consapevoli che non cadono nel panico ricevono 2 turni in questo Round. Passa alla Condizione 2.",
    sighting(6) + [activate([(53, "O4")], "standing", adv="us", us_two=True, aware=True), cond(2)])
par("334", "[s5 e s6] Attiva il tedesco 34 nell’esagono M5 e il tedesco 53 nell’esagono O4, accovacciati. Iniziano i Round. Vantaggio tedesco. Passa alla Condizione 2.",
    sighting(5, 6) + [activate([(34, "M5"), (53, "O4")], "crouching", adv="de"), cond(2)])
par("335", "Effettua un controllo di attivazione (+3):\n• se riesce, vedi 183;\n• se fallisce, effettua un controllo di percezione (−2). Se riesce, vedi 312.",
    [act(3, [see("183")], [pc(-2, [see("312")])])])
par("336", "Effettua un controllo di attivazione (+1):\n• se riesce e s5 è avvenuto, vedi 183;\n• se riesce e s5 non è avvenuto, vedi 294;\n• se fallisce, effettua un controllo di percezione (−2). Se riesce e s5 è avvenuto, vedi 312; se riesce e s5 non è avvenuto, vedi 316.",
    [act(1, [if_(S(5), [see("183")], [see("294")])],
         [pc(-2, [if_(S(5), [see("312")], [see("316")])])])])
par("337", "[s5] Attiva il tedesco 34 nell’esagono M5, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 34 riceve 2 turni in questo Round.",
    sighting(5) + [activate([(34, "M5")], "crouching", adv="de", two=[34])])
par("338", "[s5] Attiva il tedesco 34 nell’esagono M5, accovacciato. Iniziano i Round. Vantaggio tedesco.",
    sighting(5) + [activate([(34, "M5")], "crouching", adv="de")])
par("339", "Effettua un controllo di percezione:\n• se riesce, vedi 342;\n• se fallisce, colloca un segnalino Evento.",
    [pc(0, [see("342")], [EVENT])])
par("340", "Effettua un controllo di attivazione:\n• se riesce, vedi 291;\n• se fallisce, vedi 313.",
    [act(0, [see("291")], [see("313")])])
par("341", "Ogni soldato che vede l’esagono R2 deve effettuare un controllo di percezione (−2):\n• se almeno uno riesce, vedi 606;\n• se falliscono tutti, vedi 197;\n• se non si effettua alcun controllo, nessun evento.",
    [{"op": "group_pc", "hex": "R2", "mod": -2, "any": [see("606")], "all_fail": [see("197")]}])
par("342", "[s8] Il soldato nota i segni rivelatori di una striscia di mine che corre ad arco dall’esagono Q9 all’esagono V6.",
    sighting(8) + [{"op": "mine_hint"}])
par("343", "1. Se s2 e s5 sono avvenuti, nessun evento.\n2. Se s2 è avvenuto, vedi 603.\n3. Se s5 è avvenuto, vedi 182.\n4. Se s5 e s2 non sono avvenuti, vedi 330.",
    [if_(ALL(S(2), S(5)), [], [if_(S(2), [see("603")], [if_(S(5), [see("182")], [see("330")])])])])
par("344", "1. Se s2 e s5 sono avvenuti, nessun evento.\n2. Se s2 è avvenuto, vedi 192.\n3. Se s5 è avvenuto, vedi 335.\n4. Se s5 e s2 non sono avvenuti, vedi 330.",
    [if_(ALL(S(2), S(5)), [], [if_(S(2), [see("192")], [if_(S(5), [see("335")], [see("330")])])])])
par("345", "Campo minato! Esegui la procedura del campo minato. Poi, se s6 non è avvenuto, effettua un controllo di attivazione (+1). Se riesce, vedi 297.",
    [{"op": "minefield"}, if_(NOT(S(6)), [act(1, [see("297")])])])
par("346", "Se il tedesco 34 è già stato rimosso una volta dal gioco con un movimento evasivo, vedi 611.",
    [if_({"evaded": 34}, [see("611")])])
par("347", "Se un soldato americano vede l’esagono T8, attiva il tedesco 25 in quell’esagono, accovacciato. Iniziano i Round. Metti in vigore la reazione speciale B per il tedesco 25.",
    [if_({"see_hex": "T8"}, [activate([(25, "T8")], "crouching", reaction="B")])])
par("348", "Lontano, a est del campo di battaglia, i tuoi soldati vedono dei Typhoon in picchiata sulle posizioni tedesche. Le raffiche della contraerea circondano gli aerei britannici.", [])
par("349", "[s0] Il soldato vede un pilota ferito nell’abitacolo. Il pilota grida: «Ehi, amico! Sta per saltare in aria; mi dai una mano?». Se si sposta un montante dell’ala accartocciato, il pilota potrà strisciare fuori dai rottami. Durante i Round, un soldato non ferito deve spendere 2 azioni per liberarlo. Durante le Operazioni, a un soldato non ferito basta dichiarare l’intenzione ed effettuare un controllo Evento. Se il pilota viene liberato, vedi 454.",
    sighting(0) + [{"op": "pilot_found"}])
par("350", "• Se è visibile un soldato americano attivo a est della colonna O, entra nell’esagono N16.\n• Altrimenti entra nell’esagono P16.",
    [if_({"us_visible_east_of": "O"}, [{"op": "g_enter", "hex": "N16"}], [{"op": "g_enter", "hex": "P16"}])], "movimento")
par("351", "[s5] Attiva il tedesco 34 nell’esagono M6, accovacciato. Iniziano i Round.",
    sighting(5) + [activate([(34, "M6")], "crouching")])
par("352", "Entra nell’esagono Q11 e metti in vigore la reazione speciale A per questo tedesco.",
    [{"op": "g_enter", "hex": "Q11"}, {"op": "g_reaction", "r": "A"}], "movimento")

# ---------------------------------------------------------------- 45x
par("450", "Ogni soldato americano che vede l’esagono M10 deve effettuare un controllo di percezione (−2):\n• se almeno uno riesce, vedi 606;\n• se falliscono tutti, vedi 197;\n• se non si effettua alcun controllo, nessun evento.",
    [{"op": "group_pc", "hex": "M10", "mod": -2, "any": [see("606")], "all_fail": [see("197")]}])
par("451", "Se il tedesco 53 è già stato rimosso una volta dal gioco con un movimento evasivo, vedi 452.",
    [if_({"evaded": 53}, [see("452")])])
par("452", "Se un soldato americano attivo vede l’esagono T8, attiva il tedesco 53 in quell’esagono, accovacciato. Metti in vigore la reazione speciale B per il tedesco 53.",
    [if_({"see_hex": "T8"}, [activate([(53, "T8")], "crouching", reaction="B")])])
par("453", "[s9] Avvolto dal fumo, un caccia britannico Typhoon compie un atterraggio di fortuna nell’esagono R15. Colloca in quell’esagono un segnalino di riferimento con l’aereo fumante. Tutti i soldati presenti nell’esagono al momento dell’impatto muoiono. Se un soldato americano entra in R15 mentre il segnalino è presente, vedi 349. Annota questo paragrafo sulla scheda della squadra.",
    sighting(9) + [{"op": "typhoon_crash"}])
par("454", "Ottieni 2 PV. Il pilota combatterà con la tua squadra: usa la carta del soldato americano 05 per le sue caratteristiche. Non perdi PV se in seguito diventa incapacitato o muore. Ottieni altri 2 PV se è attivo alla fine della missione.",
    [{"op": "pilot_joins"}])
par("455", "Ogni soldato americano che vede l’esagono M5 deve effettuare un controllo di percezione (−2):\n• se almeno uno riesce, vedi 602;\n• se falliscono tutti, vedi 338;\n• se non si effettua alcun controllo, nessun evento.",
    [{"op": "group_pc", "hex": "M5", "mod": -2, "any": [see("602")], "all_fail": [see("338")]}])
par("456", "Effettua un controllo di attivazione (−1):\n• se riesce, vedi 337;\n• se fallisce, vedi 194.",
    [act(-1, [see("337")], [see("194")])])
par("457", "Entra nell’esagono X7 e metti in vigore la reazione speciale A per questo tedesco.",
    [{"op": "g_enter", "hex": "X7"}, {"op": "g_reaction", "r": "A"}], "movimento")

# ---------------------------------------------------------------- 60x-61x
par("600", "Effettua un controllo di percezione:\n• se riesce, vedi 293;\n• se fallisce, colloca un segnalino Evento.",
    [pc(0, [see("293")], [EVENT])])
par("601", "Effettua un controllo di attivazione (+3):\n• se riesce e s5 è avvenuto, vedi 183;\n• se riesce e s5 non è avvenuto, vedi 294;\n• se fallisce, effettua un controllo di percezione (−2). Se riesce e s5 è avvenuto, vedi 312; se riesce e s5 non è avvenuto, vedi 316.",
    [act(3, [if_(S(5), [see("183")], [see("294")])],
         [pc(-2, [if_(S(5), [see("312")], [see("316")])])])])
par("602", "[s5] Attiva il tedesco 34 nell’esagono M5, in piedi. Iniziano i Round. Vantaggio americano. Il soldato americano che ha appena superato il controllo di percezione è automaticamente consapevole in questo Round.",
    sighting(5) + [activate([(34, "M5")], "standing", adv="us", aware=True)])
par("603", "Effettua un controllo di attivazione (+2):\n• se riesce, vedi 337;\n• se fallisce, vedi 194.",
    [act(2, [see("337")], [see("194")])])
par("604", "Effettua un controllo di percezione (−2):\n• se riesce, vedi 342;\n• se fallisce, colloca un segnalino Evento.",
    [pc(-2, [see("342")], [EVENT])])
par("605", "Campo minato! Esegui la procedura del campo minato. Poi, se s2 non è avvenuto, effettua un controllo di attivazione (+1):\n• se riesce, vedi 291;\n• se fallisce, vedi 313.",
    [{"op": "minefield"}, if_(NOT(S(2)), [act(1, [see("291")], [see("313")])])])
par("606", "[s7] Attiva i tedeschi 1 e 81 nell’esagono indicato, in piedi. Iniziano i Round. Vantaggio americano. Il soldato americano che ha appena superato il controllo di percezione è automaticamente consapevole.",
    sighting(7) + [activate([(1, "@indicato"), (81, "@indicato")], "standing", adv="us", aware=True)])
par("607", "Tira un dado:\n0–3: effettua un controllo di attivazione. Se riesce, vedi 291.\n4–8: nessun effetto.\n9: effettua un controllo di percezione (−2). Se riesce, vedi 312.",
    [die((0, 3, [act(0, [see("291")])]), (4, 8, []), (9, 9, [pc(-2, [see("312")])]))])
par("608", "1. Se s2 e s6 sono avvenuti, nessun evento.\n2. Se s2 è avvenuto, vedi 290 se il soldato è in terreno scoperto; altrimenti vedi 326.\n3. Se s6 è avvenuto, vedi 182.\n4. Se s2 e s6 non sono avvenuti, vedi 182.",
    [if_(ALL(S(2), S(6)), [], [if_(S(2), [if_({"in_clear": True}, [see("290")], [see("326")])],
                                    [if_(S(6), [see("182")], [see("182")])])])])
par("609", "1. Se s5 e s6 sono avvenuti, nessun evento.\n2. Se s5 è avvenuto, vedi 290.\n3. Se s6 è avvenuto, vedi 192.\n4. Se s5 e s6 non sono avvenuti, vedi 189.",
    [if_(ALL(S(5), S(6)), [], [if_(S(5), [see("290")], [if_(S(6), [see("192")], [see("189")])])])])
par("610", "Se il tedesco 25 è già stato rimosso una volta dal gioco con un movimento evasivo, vedi 347.",
    [if_({"evaded": 25}, [see("347")])])
par("611", "Se un soldato americano attivo vede l’esagono T8, attiva il tedesco 34 in quell’esagono, accovacciato. Iniziano i Round. Metti in vigore la reazione speciale B per il tedesco 34. Passa alla Condizione 4.",
    [if_({"see_hex": "T8"}, [activate([(34, "T8")], "crouching", reaction="B"), cond(4)])])
par("612", "Se un soldato americano attivo vede l’esagono Q11, attiva i tedeschi 1 e 81 in quell’esagono, accovacciati. Iniziano i Round. Metti in vigore la reazione speciale A per entrambi. Se nessun americano vede Q11, ma qualcuno vede l’esagono X7, attiva invece questi tedeschi lì.",
    [if_({"see_hex": "Q11"}, [activate([(1, "Q11"), (81, "Q11")], "crouching", reaction="A")],
         [if_({"see_hex": "X7"}, [activate([(1, "X7"), (81, "X7")], "crouching", reaction="A")])])])
par("613", "[s0] Richiede s9. Le fiamme divampano dall’esagono R15: il Typhoon abbattuto brucia rapidamente fino a ridursi in cenere. Tutti i soldati in R15 in questo momento muoiono. Rimuovi il segnalino dall’esagono.",
    [if_(S(9), sighting(0) + [{"op": "typhoon_burn"}])])
par("614", "• Se dalla porta è visibile un soldato americano attivo, entra nell’esagono M14.\n• Se dalla porta non è visibile alcun soldato americano attivo, entra nell’esagono L14.",
    [if_({"us_visible_from": "L14"}, [{"op": "g_enter", "hex": "M14"}], [{"op": "g_enter", "hex": "L14"}])], "movimento")
par("615", "[s5] Attiva il tedesco 34 nell’esagono N4, accovacciato. Iniziano i Round.",
    sighting(5) + [activate([(34, "N4")], "crouching")])
par("616", "Entra nell’esagono T8 e metti in vigore la reazione speciale B per questo tedesco.",
    [{"op": "g_enter", "hex": "T8"}, {"op": "g_reaction", "r": "B"}], "movimento")

# ---------------------------------------------------------------- azioni tedesche
# Il comportamento è eseguito da scripts/motore/tedeschi.gd; qui solo testo.
A = {
"800": "Sdraiati prono.",
"801": "Accovacciati, poi esegui il miglior tiro contro il bersaglio più facile. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito.",
"802": "Accovacciati, poi esegui il miglior tiro contro il bersaglio più vicino. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito.",
"803": "• Se c’è un bersaglio attivo visibile e il tedesco non è in un esagono scoperto, accovacciati ed esegui il miglior tiro contro il bersaglio più facile. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito.\n• Se c’è un bersaglio attivo visibile e il tedesco è in un esagono scoperto, muoviti il più rapidamente possibile.\n• Se non è visibile alcun bersaglio attivo, corri in un esagono scoperto o striscia in qualsiasi altro tipo di esagono.",
"804": "• Se sei fuori dalla vista degli americani, rimuovi il tedesco dalla mappa.\n• Se sei in vista degli americani e un bersaglio è entro 3 esagoni, accovacciati ed esegui il miglior tiro. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito.\n• Se sei in vista degli americani e nessun bersaglio è entro 3 esagoni, sdraiati prono.",
"805": "• Se sei fuori dalla vista degli americani, rimuovi il tedesco dalla mappa.\n• Se sei in vista degli americani e un bersaglio è entro 4 esagoni, arrenditi.\n• Se sei in vista degli americani e nessun bersaglio è entro 4 esagoni, sdraiati prono.",
"808": "• Se non vedi alcun bersaglio attivo, accovacciati.\n• Se vedi 1 o 2 bersagli attivi, accovacciati ed esegui il miglior tiro contro il bersaglio più facile. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito.\n• Se vedi tre o più bersagli attivi, sdraiati prono.",
"809": "Muoviti il più rapidamente possibile; alla fine del movimento sdraiati prono (spendendo un punto movimento, se necessario).",
"813": "• Se sono visibili più di 2 bersagli attivi, arrenditi.\n• Altrimenti vedi 802.",
"815": "Accovacciati, poi spara con la mitragliatrice o assisti chi la usa. Esegui il miglior tiro contro un bersaglio attivo entro 3 esagoni; altrimenti tiro mirato contro il bersaglio più facile. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito. Se la mitragliatrice è senza munizioni, usa la seconda arma.",
"816": "Ignora la reazione di autoconservazione. Tira un nuovo numero d’azione tedesca e consulta la colonna d’azione che si applicherebbe altrimenti a questo soldato.",
"824": "Accovacciati, poi esegui il miglior tiro contro il bersaglio più facile. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito. Eccezione: se questo bersaglio è già stato colpito da un tiro in questo Round ed è visibile un altro bersaglio, spara invece al secondo.",
"825": "Accovacciati ed esegui un tiro rapido contro il maggior numero possibile di bersagli, cominciando dal più vicino e poi dal più facile.",
"829": "• Se è visibile un solo bersaglio attivo, accovacciati ed esegui il miglior tiro. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito.\n• Altrimenti sdraiati prono.",
"830": "• Se sei in un esagono scoperto, muoviti il più rapidamente possibile.\n• Se sei in un altro tipo di esagono, o se durante il movimento entri in un altro tipo di esagono, sdraiati prono.",
"831": "• Se c’è un tedesco attivo nello stesso esagono o in uno adiacente, accovacciati e cedi un turno al tedesco con meno turni. Se più tedeschi idonei hanno lo stesso numero di turni, cedilo a quello con l’abilità con le armi più alta. Se tutti i tedeschi idonei hanno due turni, vedi 801.\n• Se non ci sono altri tedeschi attivi nello stesso esagono o in uno adiacente, sdraiati prono.",
"832": "• Se c’è un tedesco attivo nello stesso esagono o in uno adiacente, accovacciati e cedi un turno al tedesco con meno turni. Se più tedeschi idonei hanno lo stesso numero di turni, cedilo a quello con l’abilità con le armi più alta. Se tutti i tedeschi idonei hanno due turni, vedi 801.\n• Se non ci sono altri tedeschi attivi nello stesso esagono o in uno adiacente, vedi 801.",
"833": "1. Se c’è un soldato americano attivo nell’esagono, assaltalo per uccidere.\n2. Se sei adiacente a un soldato americano attivo attraverso un lato attraversabile e hai una granata, accovacciati e lanciala. Eccezione: se c’è un tedesco attivo nell’esagono americano, esegui invece un assalto in carica per uccidere.\n3. Se è visibile un bersaglio attivo, accovacciati ed esegui il miglior tiro.\n4. Sdraiati prono.",
"835": "• Se c’è un tedesco attivo entro due esagoni, cedi un turno al tedesco con meno turni. Se più tedeschi idonei hanno lo stesso numero di turni, cedilo a quello più vicino a un soldato americano attivo (poi all’abilità con le armi più alta). Se tutti i tedeschi idonei hanno due turni, vedi 801.\n• Se non ci sono altri tedeschi attivi entro due esagoni, esegui 801.",
"836": "• Se sei fuori dalla vista degli americani, rimuovi il tedesco dalla mappa.\n• Se sei in vista degli americani e in terreno scoperto, muoviti il più rapidamente possibile. Dopo il movimento sdraiati prono se ti resta il cambio di postura gratuito.\n• Se sei in vista degli americani e non in terreno scoperto, accovacciati ed esegui il miglior tiro. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito.",
"837": "• Se sei fuori dalla vista degli americani, rimuovi il tedesco dalla mappa.\n• Se sei in vista degli americani, muoviti il più rapidamente possibile. Sdraiati prono nel primo esagono non scoperto in cui entri.",
"838": "Corri in un esagono scoperto, striscia in qualsiasi altro tipo di esagono. Fermati e sdraiati prono se entri in un esagono non edificio fuori dalla vista degli americani. Se alla fine del Round sei fuori dalla vista degli americani, rimuovi il tedesco dalla mappa.",
"839": "• Se c’è un soldato americano attivo nell’esagono, assaltalo per uccidere.\n• Se non c’è alcun bersaglio attivo nell’esagono, accovacciati ed esegui il miglior tiro contro il bersaglio più vicino.",
"913": "1. Se un soldato americano attivo occupa l’esagono T8, vedi 802.\n2. Se 3 o più soldati tedeschi sono stati uccisi, resi incapacitati o catturati, striscia nell’esagono N5. Passa alla Condizione 4.\n3. Vedi 802.",
"914": "1. Se un soldato americano attivo occupa l’esagono T8, vedi 802.\n2. Se 3 o più soldati americani sono in vista, striscia nell’esagono N5. Passa alla Condizione 4.\n3. Vedi 802.",
"915": "• Se è in vista un soldato americano attivo, vedi 801.\n• Altrimenti vedi 830.",
"916": "• Se sei in un esagono di edificio o di bosco, vedi 802.\n• Altrimenti vedi 830.",
"917": "• Se sei in un esagono di edificio, vedi 801.\n• Altrimenti vedi 803.",
"918": "• Se sei nell’esagono di attivazione, vedi 801.\n• Altrimenti vedi 836.",
"919": "• Se sei nell’esagono di attivazione, vedi 802.\n• Altrimenti vedi 837.",
"920": "• Se sei nell’esagono di attivazione, vedi 802.\n• Altrimenti vedi 809.",
"965": "• Se un bersaglio attivo è entro 5 esagoni, accovacciati, poi esegui il miglior tiro con la Luger contro il bersaglio più vicino. Dopo il tiro sdraiati prono se ti resta il cambio di postura gratuito.\n• Se nessun bersaglio è entro 5 esagoni, sdraiati prono.",
"971": "• Se non ci sono bersagli attivi nell’esagono, sdraiati prono.\n• Se nell’esagono ci sono uno o due bersagli attivi, assaltali per uccidere.\n• Se nell’esagono ci sono tre o più bersagli attivi, arrenditi.",
}
for k, v in A.items():
    par(k, v, [], "azione")
