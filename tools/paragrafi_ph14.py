# -*- coding: utf-8 -*-
"""Purple Heart – Missione 14 «Ricognizione in forze» (mappa C, in alto è ovest; a sud di Caen, 22 luglio 1944).

La squadra, su due jeep, deve raggiungere l’incrocio J8 e ricongiungersi con la squadra 2 della compagnia Baker.
Testo inglese: tools/paragrafi_ph_programma.json, tools/paragrafi_ph_en.json e il database del programma.
"""
from paragrafi_m1 import pc, act, see, die, if_, S, NOT, sighting, activate, cond, EVENT

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def mov(pid, it, ops):
    par(pid, it, ops, "movimento")


def az(pid, it):
    par(pid, it, [], "azione")


def enter(h):
    return {"op": "g_enter", "hex": h}


# ------------------------------------------------------------------ Condizione 1: verso l’incrocio
par("618", "1. Se leggi questo paragrafo per la prima volta, la radio gracchia: «Che diavolo state aspettando? Raggiungete J8 di corsa!».\n"
           "2. La seconda volta, il comandante minaccia di degradare il sergente.\n3. La terza volta: se non vinci la missione il sergente "
           "torna a casa caporale e tutta la squadra fa quattro settimane di corvé. Muoversi!", [{"op": "radio_618"}])
par("539", "Campo minato! Si esegue la procedura del campo minato.", [{"op": "minefield"}])
par("581", "Trappola esplosiva! Si esegue la procedura delle trappole.", [{"op": "boobytrap"}])
par("317", "[s2] Il soldato vede uno Sherman distrutto in Q15.", sighting(2) + [{"op": "relitto", "hex": "Q15", "nome": "Sherman distrutto"}])
par("325", "[s2] Il soldato vede uno Sherman distrutto in N7.", sighting(2) + [{"op": "relitto", "hex": "N7", "nome": "Sherman distrutto"}])
par("307", "[s3] Il soldato vede un bunker tedesco distrutto in X3.", sighting(3) + [{"op": "relitto", "hex": "X3", "nome": "Bunker distrutto"}])
par("300", "[s9] Il grande edificio che il soldato vede è il linificio Pierre-Marie, abbandonato dall’inizio dell’occupazione.", sighting(9))
par("331", "[s8] Il soldato vede una scena terribile: la squadra 2 è stata massacrata! Ci sono caduti americani in L9, J8, K9 e L8, con un "
           "camion americano distrutto in L8; in J8 ci sono macerie. Potrebbero esserci dei superstiti. Presto!",
    sighting(8) + [{"op": "relitto", "hex": "L8", "nome": "Camion distrutto"}, {"op": "macerie", "hex": "J8"}])
par("340", "Il soldato di questo esagono con il PC più alto fa un controllo di percezione:\n• se riesce, vedi 348;\n• se fallisce, vedi 355.",
    [pc(0, [see("348")], [see("355")])])
par("684", "Il soldato di questo esagono con il PC più alto fa un controllo di percezione:\n• se riesce, vedi 690;\n• se fallisce, vedi 355.",
    [pc(0, [see("690")], [see("355")])])
RADIO = [if_({"radio": True}, [see("362")], [see("368")]), cond(2)]
par("348", "Il soldato si accorge che i corpi in questo esagono sono stati minati e disinnesca la trappola! Vedi 541. Se la radio è "
           "presidiata chiama il comando e vedi 362; altrimenti vedi 368. Passa alla Condizione 2.", [see("541")] + RADIO)
par("690", "Il soldato si accorge che il corpo in questo esagono è stato minato e disinnesca la trappola! Vedi 562. Se la radio è "
           "presidiata chiama il comando e vedi 362; altrimenti vedi 368. Passa alla Condizione 2.", [see("562")] + RADIO)
par("355", "I caduti in questo esagono sono morti e i corpi sono minati! Si esegue la procedura delle trappole. Se la radio è presidiata "
           "vedi 362, altrimenti 368. Passa alla Condizione 2.", [{"op": "boobytrap"}] + RADIO)
par("541", "Due dei caduti in questo esagono sono ancora vivi! Al posto del segnalino entrano i soldati americani J e K, incapacitati "
           "(senza carta). Guadagni 2 PV a fine missione per ciascuno che esce dalla mappa con la squadra; ne perdi 2 per ciascuno che "
           "muore o resta in mappa. Ci sono due M-1 con quattro caricatori in tutto e una granata. Una volta sola.",
    [{"op": "superstiti", "ids": ["J", "K"]},
     {"op": "bottino", "hex": None, "oggetti": [{"arma": "sar"}, {"arma": "sar"}, {"mun": "sar", "n": 4}, {"mun": "granata", "n": 1}]}])
par("562", "Il caduto in questo esagono è ancora vivo! Al posto del segnalino entra il soldato americano J, incapacitato (senza carta). "
           "Guadagni 2 PV a fine missione se esce dalla mappa con la squadra; ne perdi 2 se muore o resta in mappa. Ha un M-1 con due "
           "caricatori e una granata. Una volta sola.",
    [{"op": "superstiti", "ids": ["J"]},
     {"op": "bottino", "hex": None, "oggetti": [{"arma": "sar"}, {"mun": "sar", "n": 2}, {"mun": "granata", "n": 1}]}])
FINE = ("Ti servono 20 PV per vincere. Oltre ai PV delle attivazioni ricevi 2 PV per ogni soldato americano che esce dal bordo nord tra "
        "Y1 e Y19. La missione finisce appena non ci sono più soldati americani attivi in mappa. Portando fuori gli incapacitati con la "
        "squadra si evitano i PV persi per loro.")
par("362", "Ripiegate! C’è una forte attività tedesca nel settore. " + FINE, [{"op": "ripiegamento_14"}])
par("368", "Ripiegate! Siete caduti in un’imboscata. " + FINE, [{"op": "ripiegamento_14"}])

# ------------------------------------------------------------------ Condizione 2: l’artiglieria
par("390", "Passa alla Condizione 3.", [cond(3)])
par("378", "[s7] Un colpo d’artiglieria tedesca cade in S9: il ponte è distrutto! Chi è nell’esagono muore, i mezzi sono distrutti.",
    sighting(7) + [{"op": "artiglieria_esagoni", "esagoni": ["S9"]}])
par("555", "Metti un segnalino Evento. Un tiro d’artiglieria tedesca! Tira i dadi percentuali e segui il diagramma della dispersione "
           "dell’artiglieria (pagina 31 del libretto) con bersaglio K9: 00–09 K9, 10–39 uno dei sei esagoni vicini, 40–99 il secondo "
           "anello. Cratere, o macerie se colpisce un edificio; chi è nell’esagono muore, i mezzi sono distrutti.",
    [EVENT, {"op": "artiglieria_dispersione", "hex": "K9"}])
par("383", "Un tiro d’artiglieria tedesca! Colonna: due dadi più 2; riga: due dadi (per esempio 8 e poi 18 danno J18). Cratere, o macerie "
           "se colpisce un edificio; chi è nell’esagono muore (anche i tedeschi), i mezzi sono distrutti.", [{"op": "artiglieria_383"}])
par("544", "Un tiro d’artiglieria tedesca! Tira un dado: 0 I5, 1 S11, 2 O14, 3 F4, 4 P7, 5 U13, 6 H15, 7 P3, 8 Q12, 9 U5. Cratere, o "
           "macerie su un edificio; chi è nell’esagono muore, i mezzi sono distrutti.",
    [{"op": "artiglieria_esagoni", "esagoni": ["I5", "S11", "O14", "F4", "P7", "U13", "H15", "P3", "Q12", "U5"]}])
par("592", "Un tiro d’artiglieria tedesca! Tira un dado: 0 O6, 1 L10, 2 N8, 3 L13, 4 O12, 5 Q14, 6 Q10, 7 I11, 8 J8, 9 S7. Cratere, o "
           "macerie su un edificio; chi è nell’esagono muore, i mezzi sono distrutti.",
    [{"op": "artiglieria_esagoni", "esagoni": ["O6", "L10", "N8", "L13", "O12", "Q14", "Q10", "I11", "J8", "S7"]}])

# ------------------------------------------------------------------ Condizione 3: il contrattacco
par("398", "Effettua un controllo di attivazione:\n• se riesce, vedi 408;\n• se fallisce, vedi 418.", [act(0, [see("408")], [see("418")])])
par("408", "[s1] Attiva i tedeschi 17 e 35 in U19, accovacciati. Iniziano i Round, vantaggio tedesco; i tedeschi 17 e 35 ricevono 2 turni "
           "in questo Round. Passa alla Condizione 3.",
    sighting(1) + [activate([(17, "U19"), (35, "U19")], "crouching", adv="de", two=[17, 35]), cond(3)])
par("418", "Effettua un controllo di percezione:\n• se riesce, vedi 424;\n• se fallisce, vedi 430.", [pc(0, [see("424")], [see("430")])])
par("424", "[s1] Attiva i tedeschi 17 e 35 in U19, accovacciati. Iniziano i Round, vantaggio americano: il soldato che ha fatto il "
           "controllo è consapevole e i consapevoli che non vanno nel panico ricevono 2 turni. Passa alla Condizione 3.",
    sighting(1) + [activate([(17, "U19"), (35, "U19")], "crouching", adv="us", us_two=True, aware=True), cond(3)])
par("430", "[s1] Attiva i tedeschi 17 e 35 in U19, accovacciati. Iniziano i Round. Passa alla Condizione 3.",
    sighting(1) + [activate([(17, "U19"), (35, "U19")], "crouching"), cond(3)])


def evento_c3(pid, ordine):
    passi = {"5": ("438", 5), "4": ("445", 4), "0": ("453", 0)}
    testo = "1. Se non ci sono tedeschi attivi in mappa o s6 non è avvenuto, vedi 582.\n"
    ops = [{"op": "if", "t": {"tedeschi_o_s6": True}, "then": [], "else": [see("582")]}]
    catena = [see("575")]
    for i, k in enumerate(reversed(ordine)):
        p_, s_ = passi[k]
        catena = [if_(NOT(S(s_)), [see(p_)], catena)]
    for i, k in enumerate(ordine):
        p_, s_ = passi[k]
        testo += "%d. Se s%d non è avvenuto, vedi %s.\n" % (i + 2, s_, p_)
    testo += "%d. Vedi 575." % (len(ordine) + 2)
    ops[0]["then"] = catena
    par(pid, testo, ops)


evento_c3("462", ["5", "4", "0"])
evento_c3("467", ["4", "0", "5"])
evento_c3("476", ["0", "4", "5"])
par("582", "[s6] I soldati avvertono un silenzio improvviso. «Troppo silenzio», dice uno. Uno stormo di uccelli vola verso sud. Si "
           "accendono le sigarette.", sighting(6))
par("438", "[s5] Attiva i tedeschi 40, 41 e 42 in L19, in piedi. Iniziano i Round, vantaggio tedesco; questi tedeschi ricevono 2 turni.",
    sighting(5) + [activate([(40, "L19"), (41, "L19"), (42, "L19")], "standing", adv="de", two=[40, 41, 42])])
par("445", "[s4] Attiva il tedesco 43 (Panzer IV) in Q19, accovacciato. Iniziano i Round, vantaggio tedesco; il tedesco 43 riceve 2 turni.",
    sighting(4) + [activate([(43, "Q19")], "crouching", adv="de", two=[43])])
par("453", "[s0] Attiva i tedeschi 44 e 45 in H19, in piedi. Iniziano i Round, vantaggio tedesco; questi tedeschi ricevono 2 turni.",
    sighting(0) + [activate([(44, "H19"), (45, "H19")], "standing", adv="de", two=[44, 45])])
par("575", "Tira un dado:\n0–1: vedi 447.\n2–3: vedi 443.\n4–5: vedi 569.\n6: vedi 404.\n7: vedi 485.\n8: vedi 461.\n9: vedi 623.\n"
           "Se l’evento è già avvenuto e può avvenire una volta sola, nessun evento.",
    [die((0, 1, [see("447")]), (2, 3, [see("443")]), (4, 5, [see("569")]), (6, 6, [see("404")]), (7, 7, [see("485")]),
         (8, 8, [see("461")]), (9, 9, [see("623")]))])
par("569", "Una jeep americana fora una gomma (a caso se più d’una). Un soldato attivo nell’esagono della jeep la cambia: due controlli "
           "degli eventi nelle Operazioni, dieci azioni nei Round. Una volta sola.", [{"op": "jeep_tire"}])

# ------------------------------------------------------------------ movimenti e reazioni
par("499", "Mette in atto la reazione speciale L per questo soldato.", [{"op": "g_reaction", "r": "L"}], "movimento")
mov("520", "• Se non vede bersagli attivi, entra in R15.\n• Altrimenti mette in atto la reazione speciale L.",
    [if_({"g_vede_us": True}, [{"op": "g_reaction", "r": "L"}], [enter("R15")])])
for pid, si, no in (("492", "T15", "U15"), ("597", "M18", "O18"), ("610", "J13", "J12")):
    mov(pid, f"• Se si muove un mezzo, entra in {si}.\n• Altrimenti entra in {no}.",
        [if_({"vehicle_moving": True}, [enter(si)], [enter(no)])])

# ------------------------------------------------------------------ azioni dei tedeschi
az("590", "1. Con una granata e un bersaglio entro tre esagoni, si accovaccia e la lancia al più vicino; poi prono se può.\n2. Con una "
          "granata e un bersaglio tra 4 e 6 esagoni, si alza e la lancia al più vicino; poi prono se può.\n3. Altrimenti tira un dado: "
          "0–4 esegue 815, 5–9 esegue 840.")
az("712", "• Se c’è un tedesco attivo nello stesso esagono o in uno adiacente, si accovaccia e gli cede un turno (a chi ne ha meno; a "
          "parità, al più abile); se tutti hanno 2 turni cade prono.\n• Altrimenti esegue 801.")
az("750", "• Con una granata e un bersaglio a tiro, si alza e la lancia al più vicino; poi prono se può.\n• Altrimenti non fa nulla.")
for pid, it in (("900", "Con 3 o più bersagli in vista, o se il mezzo è stato bersagliato, chiude i portelli (se già chiusi vedi 901). Con 1 o 2 "
                        "bersagli vedi 903. Senza bersagli apre i portelli (se già aperti vedi 903)."),
                ("901", "Tiro mirato con la mitragliatrice di scafo al più vicino; cannone contro un mezzo americano o un bersaglio in un "
                        "edificio (altrimenti lo carica); con il cannone carico e senza bersagli, tiro mirato con la coassiale al secondo."),
                ("902", "Con bersagli in vista chiude i portelli (se già chiusi vedi 900); senza bersagli vedi 906."),
                ("903", "Avanza lento; cannone (o lo carica); con il cannone carico e senza bersagli tiro rapido con la coassiale al secondo; "
                        "tiro rapido con la mitragliatrice di scafo al più vicino."),
                ("905", "Con 3 o più bersagli chiude i portelli (se già chiusi vedi 900); con 1 bersaglio vedi 910; senza bersagli apre (se "
                        "già aperti vedi 906)."),
                ("906", "Avanza veloce; tiro rapido con la mitragliatrice di scafo al più vicino; carica il cannone."),
                ("907", "Con 3 o più bersagli chiude i portelli (se già chiusi vedi 910); con 1 o 2 vedi 903; senza bersagli apre (se già "
                        "aperti vedi 903)."),
                ("908", "Tiro mirato con la mitragliatrice di scafo al più vicino."),
                ("909", "Se è a est del fiume e ancora aperto, vedi 911; altrimenti vedi 900."),
                ("910", "Tiro mirato con la mitragliatrice di scafo al più vicino; cannone (o lo carica); con il cannone carico e senza "
                        "bersagli, tiro mirato con la coassiale al secondo."),
                ("911", "Avanza veloce; cannone (o lo carica); con il cannone carico e senza bersagli, tiro mirato con la mitragliatrice di "
                        "scafo al più facile."),
                ("921", "Con 3 o più bersagli, o se bersagliato, chiude i portelli (se già chiusi vedi 925); con 1 o 2 vedi 927; senza "
                        "bersagli apre (se già aperti vedi 929)."),
                ("923", "Avanza veloce; tiro rapido con la coassiale al più vicino; carica il cannone; tiro rapido con la mitragliatrice di "
                        "scafo al secondo."),
                ("925", "Avanza lento; tiro rapido con la mitragliatrice di scafo al più vicino; cannone (o lo carica)."),
                ("927", "Tiro mirato con la mitragliatrice di scafo al più vicino; cannone (o lo carica); con il cannone carico e senza "
                        "bersagli, tiro mirato con la coassiale al secondo."),
                ("929", "Avanza veloce.")):
    az(pid, it)
