# -*- coding: utf-8 -*-
"""Move Out! – Missione 9 «Le prime luci dell’alba» (mappa A, Aquisgrana, 11 settembre 1944).

Notte sulla Linea Sigfrido: razzi illuminanti, sentinelle, filo spinato, bunker, il Jagdpanther immobilizzato,
l’alba, la colonna corazzata americana e il contrattacco con i Panzerfaust.
"""
from paragrafi_m1 import pc, act, see, if_, S, NOT, sighting, cond, die, activate, ALL

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def mov(pid, it, ops):
    par(pid, it, ops, "movimento")


def enter(h):
    return {"op": "g_enter", "hex": h}


# ------------------------------------------------------------------ razzi illuminanti (Condizioni 1–2)
def razzo(pid, tab, poi):
    par(pid, "Metti un segnalino Evento. Un razzo illuminante tedesco! Un dado decide dove cade: "
             + ", ".join(f"{i}: {h}" for i, h in enumerate(tab)) + ". Illumina quell’esagono e i sei intorno. "
             f"Se nessun soldato è illuminato non succede nulla; altrimenti ogni soldato illuminato fa un controllo di "
             f"percezione: se riesce si butta prono, se fallisce resta com’è. Poi vedi {poi}.",
        [{"op": "event_marker"}, {"op": "razzo", "tab": tab, "poi": poi}])


def nascosto(pid, soglia, gittata, arma, ws, nomi):
    par(pid, f"Tira un dado: 0–{soglia} un tedesco nascosto spara di rapido a un soldato illuminato scelto a caso "
             f"(i Round non cominciano): gittata {nomi[0]}, {nomi[1]}, abilità {ws:+d}. "
             f"{soglia + 1}–9 come sopra, ma tiro mirato. Si toglie il razzo e si passa alla Condizione 2.",
        [{"op": "fuoco_nascosto", "soglia": soglia, "gittata": gittata, "arma": arma, "ws": ws}, cond(2)])


razzo("400", ["B8", "A13", "A13", "B17", "B17", "C11", "C11", "C15", "C15", "E11"], "405")
razzo("408", ["F18", "G16", "G16", "H13", "H13", "J12", "J12", "J15", "J15", "J18"], "410")
razzo("413", ["F2", "F4", "F4", "J6", "J6", "H3", "H3", "I6", "I6", "I8"], "417")
razzo("419", ["A6", "B2", "B2", "B4", "B4", "D7", "D7", "E7", "E7", "B6"], "418")
nascosto("405", 6, "media", "bolt", 0, ("media", "fucile"))
nascosto("410", 8, "corta", "bolt", 1, ("corta", "fucile"))
nascosto("417", 5, "corta", "bolt", 0, ("corta", "fucile"))
nascosto("418", 6, "lunga", "mp", 1, ("lunga", "pistola mitragliatrice"))


# ------------------------------------------------------------------ le sentinelle 20, 40 e 41 (Condizione 3)
def trio(pid, hexes, adv, testo_extra="", two=False, aware=False, us_two=False):
    coppie = [(20, hexes[0]), (40, hexes[1]), (41, hexes[2])]
    nomi = ", ".join(f"il tedesco {g} in {h}" for g, h in coppie)
    vant = {"de": " Vantaggio tedesco.", "us": " Vantaggio americano.", None: ""}[adv]
    par(pid, f"[s0] Attiva {nomi}, accovacciati. Iniziano i Round.{vant}{testo_extra} Si passa alla Condizione 3.",
        sighting(0) + [activate(coppie, "crouching", adv=adv, two=[20, 40, 41] if two else [], us_two=us_two, aware=aware), cond(3)])


def gruppo(base, hexes, a, b, c, d, soglia, codici):
    """Paragrafo col dado: 0–soglia attivazione (a riesce, b fallisce), poi percezione (c riesce, d fallisce)."""
    par(base, f"Tira un dado. 0–{soglia}: controllo di attivazione, se riesce vedi {a}, se fallisce vedi {b}. "
              f"{soglia + 1}–9: controllo di percezione, se riesce vedi {c}, se fallisce vedi {d}.",
        [die([0, soglia, [act(0, [see(a)], [see(b)])]], [soglia + 1, 9, [pc(0, [see(c)], [see(d)])]])])
    pc_b, ok_b, ko_b = codici
    par(pc_b, f"Controllo di percezione: se riesce vedi {ok_b}, se fallisce vedi {ko_b}.", [pc(0, [see(ok_b)], [see(ko_b)])])


gruppo("420", None, "427", "430", "438", "437", 4, ("430", "432", "437"))
trio("427", ["O4", "N4", "P3"], "de", " I tedeschi 20, 40 e 41 ricevono 2 turni.", two=True)
trio("432", ["O4", "N4", "P3"], "us", " Il soldato che ha fatto il controllo è consapevole.", aware=True)
trio("437", ["O4", "N4", "P3"], "de")
trio("438", ["O4", "N4", "P3"], "us", " I soldati consapevoli ricevono 2 turni.", us_two=True)
trio("440", ["M5", "M6", "N4"], "de")
trio("443", ["M5", "M6", "M7"], "de")
gruppo("445", None, "448", "451", "458", "455", 6, ("451", "453", "455"))
trio("448", ["M8", "M7", "M6"], "de", " I tedeschi 20, 40 e 41 ricevono 2 turni.", two=True)
trio("453", ["M8", "M7", "M6"], "us", " Il soldato che ha fatto il controllo è consapevole.", aware=True)
trio("455", ["M8", "M7", "M6"], "de")
trio("458", ["M8", "M7", "M6"], "us", " I soldati consapevoli ricevono 2 turni.", us_two=True)
trio("459", ["M10", "M8", "N11"], "de")
trio("462", ["N10", "M10", "N11"], "de")
trio("464", ["O12", "N11", "O14"], "de")
gruppo("467", None, "470", "472", "480", "478", 5, ("472", "475", "478"))
trio("470", ["O16", "O17", "O15"], "de", " I tedeschi 20, 40 e 41 ricevono 2 turni.", two=True)
trio("475", ["O16", "O17", "O15"], "us", " Il soldato che ha fatto il controllo è consapevole.", aware=True)
trio("478", ["O16", "O17", "O15"], "de")
trio("480", ["O16", "O17", "O15"], "us", " I soldati consapevoli ricevono 2 turni.", us_two=True)
gruppo("481", None, "483", "486", "495", "492", 5, ("486", "488", "492"))
trio("483", ["P17", "P19", "O17"], "de", " I tedeschi 20, 40 e 41 ricevono 2 turni.", two=True)
trio("488", ["P17", "P19", "O17"], "us", " Il soldato che ha fatto il controllo è consapevole.", aware=True)
trio("492", ["P17", "P19", "O17"], "de")
trio("495", ["P17", "P19", "O17"], "us", " I soldati consapevoli che non sono nel panico ricevono 2 turni.", us_two=True)

# ------------------------------------------------------------------ filo spinato, case pericolanti, tedesco 21
FILO = " Nelle Operazioni il filo si attraversa normalmente. Nei Round entrare costa 1 PM in più e ci si deve buttare proni; " \
       "uscendo si tira un dado: con 0 il soldato è ferito, resta prono e perde i turni del Round. Non ostacola i tedeschi; " \
       "una carica da demolizione che esplode nell’esagono lo toglie."
par("497", "[s5] Il soldato vede una fila di filo spinato da K5 a K9." + FILO,
    sighting(5) + [{"op": "filo", "hex": ["K5", "K6", "K7", "K8", "K9"]}])
par("600", "[s6] Il soldato vede una fila di filo spinato da M14 a M19." + FILO,
    sighting(6) + [{"op": "filo", "hex": ["M14", "M15", "M16", "M17", "M18", "M19"]}])
par("604", "[s6] Il soldato vede una fila di filo spinato in N6, O6, P5, Q5, R4 e S4." + FILO,
    sighting(6) + [{"op": "filo", "hex": ["N6", "O6", "P5", "Q5", "R4", "S4"]}])
par("601", "Per i bombardamenti a tappeto le fondamenta di questa casa sono debolissime. Ogni soldato nell’edificio fa subito "
    "un controllo di percezione: chi riesce torna nell’esagono da cui è entrato; chi fallisce vede il tetto crollare e tira "
    "per i danni come da pistola. Ogni esagono dell’edificio diventa macerie e i superstiti restano proni sulle macerie. "
    "Una volta sola per missione.", [{"op": "crollo"}])
for pid, h in [("606", "R5"), ("608", "O7"), ("611", "S7"), ("613", "X7")]:
    par(pid, f"[s4] Attiva il tedesco 21 in {h}, accovacciato. Iniziano i Round.", sighting(4) + [activate([(21, h)], "crouching")])


# ------------------------------------------------------------------ bunker e Jagdpanther
def bunker50(pid, adv, extra="", aware=False, us_two=False, two=None, con12=False, s9=False):
    ss = [7, 9] if s9 else [7]
    coppie = [(50, "S17"), (51, "S17")] + ([(12, "U16")] if con12 else [])
    testo = ("[s7 e s9] " if s9 else "[s7] ") + "Attiva i tedeschi 50 e 51 in S17, accovacciati dentro un bunker con la porta verso T17." \
        + (" Attiva il Jagdpanther (tedesco 12) in U16, rivolto verso T15." if con12 else "") + " Iniziano i Round." \
        + {"de": " Vantaggio tedesco.", "us": " Vantaggio americano.", None: ""}[adv] + extra
    ops = sighting(*ss) + [{"op": "bunker", "hex": "S17", "porta": "T17"},
                           activate(coppie, "crouching", adv=adv, two=two or [], us_two=us_two, aware=aware)]
    if con12:
        ops.append({"op": "fronte", "g": 12, "verso": "T15"})
    par(pid, testo, ops)


def bunker52(pid, adv, extra="", aware=False, us_two=False, two=None):
    par(pid, "[s8] Attiva i tedeschi 52 e 53 in W15, accovacciati dentro un bunker con la porta verso W16. Iniziano i Round."
        + {"de": " Vantaggio tedesco.", "us": " Vantaggio americano.", None: ""}[adv] + extra,
        sighting(8) + [{"op": "bunker", "hex": "W15", "porta": "W16"},
                       activate([(52, "W15"), (53, "W15")], "crouching", adv=adv, two=two or [], us_two=us_two, aware=aware)])


gruppo("615", None, "620", "624", "629", "627", 5, ("624", "625", "627"))
bunker50("620", "de", " Il tedesco 50 riceve 2 turni.", two=[50])
bunker50("625", "us", " Il soldato che ha fatto il controllo è consapevole.", aware=True)
bunker50("627", "de")
bunker50("629", "us", " I soldati consapevoli che non sono nel panico ricevono 2 turni.", us_two=True)
gruppo("631", None, "633", "635", "642", "639", 6, ("635", "637", "639"))
bunker50("633", "de", " I tedeschi 50 e 12 ricevono 2 turni.", two=[50, 12], con12=True, s9=True)
bunker50("637", "us", " Il soldato che ha fatto il controllo è consapevole.", aware=True, con12=True, s9=True)
bunker50("639", "de", con12=True, s9=True)
bunker50("642", "us", " I soldati consapevoli che non sono nel panico ricevono 2 turni.", us_two=True, con12=True, s9=True)
bunker50("655", "de", " I tedeschi 12 e 50 ricevono 2 turni.", two=[50, 12], con12=True, s9=True)
bunker50("664", None, con12=True, s9=True)
gruppo("644", None, "646", "648", "653", "650", 5, ("648", "649", "650"))
bunker52("646", "de", " Il tedesco 52 riceve 2 turni.", two=[52])
bunker52("649", "us", " Il soldato che ha fatto il controllo è consapevole.", aware=True)
bunker52("650", "de")
bunker52("653", "us", " I soldati consapevoli che non sono nel panico ricevono 2 turni.", us_two=True)
bunker52("660", "de", " I tedeschi 52 e 53 ricevono 2 turni.", two=[52, 53])
bunker52("665", None)
par("657", "Il soldato con la percezione più alta fa un controllo di percezione: se riesce, vedi 658.", [pc(0, [see("658")])])
par("658", "[s3] Il soldato nota uno strano bagliore in direzione di U16.", sighting(3))
par("662", "Campo minato! Si applica la procedura del campo minato.", [{"op": "minefield"}])
par("668", "[s2] Il soldato vede uno squarcio nel fianco sinistro del Jagdpanther! Dentro si vedono i due uomini "
    "dell’equipaggio che caricano e sparano. Lo squarcio vale come un’apertura per il tiro e per le granate; l’equipaggio è "
    "accovacciato. Se un membro dell’equipaggio viene colpito, l’equipaggio si arrende e il carro è fuori uso.",
    sighting(2) + [{"op": "squarcio"}])
for pid, adv, testo in [("936", "de", " Vantaggio tedesco. Il tedesco 12 riceve 2 turni."),
                        ("939", "us", " Vantaggio americano. Chi vede U16 è consapevole e riceve 2 turni."),
                        ("941", None, "")]:
    par(pid, f"[s9] Attiva il Jagdpanther (tedesco 12) in U16, rivolto verso T15. Iniziano i Round.{testo}",
        sighting(9) + [activate([(12, "U16")], "crouching", adv=adv, two=[12] if adv == "de" else [],
                                us_two=adv == "us"), {"op": "fronte", "g": 12, "verso": "T15"}]
        + ([{"op": "consapevoli_vede", "hex": "U16"}] if adv == "us" else []))
gruppo("937", None, "936", "938", "939", "941", 4, ("938", "939", "941"))

# ------------------------------------------------------------------ alba, colonna americana, contrattacco
par("870", "Se uno degli avvistamenti 7, 8 o 9 è avvenuto, vedi 874; altrimenti nessun evento.",
    [if_({"any_s": [7, 8, 9]}, [see("874")])])
par("872", "Nelle Operazioni vedi 874; nei Round nessun evento.", [if_({"in_round": True}, [], [see("874")])])
par("874", "L’alba! La visibilità sale a dieci esagoni. Si passa alla Condizione 4.", [{"op": "visibilita", "n": 10}, cond(4)])
par("876", "Nei Round vedi 878; nelle Operazioni nessun evento.", [if_({"in_round": True}, [see("878")])])
par("878", "Un americano con iniziativa 3 o meno, scelto a caso, va nel panico e cade prono: perde i turni di questo Round. "
    "Una volta sola per missione.", [{"op": "panico_mo"}])
par("880", "Se il soldato che porta la radio è in bosco, cespugli o macerie, inciampa e cade prono. Un dado: con 0 la radio è "
    "distrutta; altrimenti il soldato tira per i danni come da pistola. Una volta sola per missione.", [{"op": "radio_inciampa"}])
par("883", "Pieno giorno: il sole sorge e la visibilità torna piena per il resto della partita. Si passa alla Condizione 5.",
    [{"op": "visibilita", "n": 0}, cond(5)])
par("885", "Se la radio è presidiata e funziona, il comando di divisione chiede se la colonna può avanzare: puoi chiamarla adesso "
    "o quando vuoi (vedi 887). Se la radio non funziona o non è presidiata, vedi 889.",
    [if_({"radio": True}, [{"op": "scelta_attiva", "par": "887", "testo": "Chiama la colonna corazzata (paragrafo 887)"}],
         [see("889")])])
par("887", "La colonna americana entra in A6! Si passa alla Condizione 6 e il sole sorge: visibilità piena. (Nel gioco da "
    "tavolo Sherman e jeep si muovono con le loro carte; qui li comandi tu: lo Sherman è Z, la jeep ha l’autista J e il "
    "mitragliere K.)", [{"op": "colonna", "hex": "A6"}, {"op": "visibilita", "n": 0}, cond(6)])
par("889", "La colonna americana entra in A6! Si passa alla Condizione 6. Questo evento sostituisce ogni altro riferimento "
    "alla colonna: non si può più rimandare.", [{"op": "colonna", "hex": "A6"}, cond(6)])
par("890", "Tira due dadi: con 9 o meno vedi 892; altrimenti nessun evento.", [{"op": "due_dadi", "max": 9, "p": "892"}])
par("892", "Un contrattacco tedesco! Attiva i tedeschi 30, 31, 32 e 33 in Q19, in piedi. Si continua coi Round, vantaggio "
    "tedesco; ricevono 2 turni in questo Round.",
    [activate([(30, "Q19"), (31, "Q19"), (32, "Q19"), (33, "Q19")], "standing", adv="de", two=[30, 31, 32, 33])])
par("894", "Se almeno due degli avvistamenti 7, 8 e 9 sono avvenuti, vedi 883; altrimenti nessun evento.",
    [if_({"almeno_s": [2, 7, 8, 9]}, [see("883")])])
par("461", "Un tedesco incapacitato, scelto a caso, muore per le ferite. Una volta sola per missione.",
    [{"op": "morte_incapacitato", "lato": "de", "chiave": "mo461"}])
par("485", "Un tedesco ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Una volta sola per missione.",
    [{"op": "dissanguamento", "lato": "de", "chiave": "mo485"}])
par("623", "Un americano ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Una volta sola per missione.",
    [{"op": "dissanguamento", "lato": "us", "chiave": "mo623"}])
mov("672", "Il tedesco 30 entra in P19, il 31 in P18, il 32 in Q18, il 33 in R18.",
    [if_({"g_num": 30}, [enter("P19")], [if_({"g_num": 31}, [enter("P18")], [if_({"g_num": 32}, [enter("Q18")], [enter("R18")])])])])

# ------------------------------------------------------------------ azioni dei tedeschi (scripts/motore/tedeschi_mo.gd)
for n, t in {
    "803": "Se non vede bersagli per il buio ma c’è un americano attivo entro sei esagoni, si alza e lancia una granata (−3 "
           "perché il bersaglio non è in vista); poi prono se può. Se ha un bersaglio in vista e una granata, si alza e la lancia; "
           "poi prono se può. Se ha un bersaglio in vista ma niente granate, vedi 801.",
    "804": "Con un solo bersaglio in vista si accovaccia e fa il miglior tiro con la mitragliatrice; con due o più vedi 805; senza "
           "bersagli non fa nulla.",
    "805": "Con un bersaglio entro tre esagoni si accovaccia e lancia una granata nell’esagono con più americani, poi prono se può. "
           "Con un bersaglio entro cinque esagoni si alza e spara di rapido a quanti più bersagli può, poi prono se può. "
           "Altrimenti vedi 815.",
    "806": "Se vede un mezzo americano attivo, prepara il Panzerbüchse e spara allo Sherman, poi alla jeep. Altrimenti vedi 805.",
    "807": "Se vede un mezzo americano attivo, prepara il Panzerbüchse e spara allo Sherman, poi alla jeep. Altrimenti vedi 815.",
    "809": "Se vede un mezzo americano attivo, prepara il Panzerbüchse e spara allo Sherman, poi alla jeep. Altrimenti vedi 810.",
    "810": "Con un americano attivo entro cinque esagoni si alza e fa il miglior tiro al più vicino, poi prono se può. "
           "Altrimenti vedi 815.",
    "811": "Con un americano attivo entro sei esagoni si alza e lancia una granata (esagono a caso se più d’uno), poi prono se può. "
           "Altrimenti si butta prono.",
    "813": "Se il tedesco 50 è attivo non fa nulla; altrimenti si accovaccia e lancia una granata in un esagono adiacente al bunker.",
    "816": "Ignora la reazione di autoconservazione: nuovo numero d’azione sulla colonna che userebbe altrimenti.",
    "818": "Se il tedesco 52 è attivo non fa nulla; altrimenti si accovaccia e lancia una granata in un esagono adiacente al bunker.",
    "820": "Se il tedesco 50 non è più attivo si arrende; altrimenti non fa nulla.",
    "821": "Se il tedesco 52 non è più attivo si arrende; se non ci sono altri tedeschi attivi nello stesso esagono o accanto si butta "
           "prono; altrimenti non fa nulla.",
    "823": "Se ha il Panzerfaust e un mezzo americano è entro tre esagoni, si accovaccia e spara allo Sherman, poi alla jeep; poi prono "
           "se può. Se il mezzo è in vista ma più lontano, vedi 801. Altrimenti corre verso J13 e vedi 868.",
    "825": "Come 823, ma corre verso N13.", "826": "Come 823, ma corre verso S12.", "827": "Come 823, ma corre verso T12.",
    "901": "Se vede un mezzo americano attivo carica il cannone e spara allo Sherman, poi alla jeep; altrimenti vedi 902.",
    "902": "Se ha un bersaglio in vista fa il miglior tiro con la mitragliatrice di scafo al più facile; altrimenti nulla.",
    "903": "Se vede un mezzo americano attivo carica il cannone e spara allo Sherman, poi alla jeep; altrimenti vedi 904.",
    "904": "Se quattro o più americani attivi sono nel suo esagono, l’equipaggio si arrende; altrimenti vedi 902.",
    "932": "Se due o più americani attivi sono nell’esagono si arrende; altrimenti si alza e fa il miglior tiro al più vicino, poi "
           "prono se può.",
    "933": "Con un bersaglio entro tre esagoni si alza e lancia una granata nell’esagono con più americani (entro tre esagoni dal "
           "bunker); altrimenti si alza e spara con l’arma personale al più vicino.",
}.items():
    # 823–827 compaiono anche come riferimenti di movimento della carta: le eseguono le azioni di Move Out!
    par(n, t, [{"op": "azione_tedesca", "n": int(n)}] if n in ("823", "825", "826", "827") else [], "azione")
