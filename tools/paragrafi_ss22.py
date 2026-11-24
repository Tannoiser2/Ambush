# -*- coding: utf-8 -*-
"""Silver Star – Missione 22 «Un altro ponte di troppo?» (Another Bridge Too Far?; mappa F con mezza G, in alto è est;
gennaio 1944, a nord-ovest di Montecassino).

La squadra, con un semicingolato e una jeep, cerca un ponte intatto per i carri. Testo inglese: tools/paragrafi_ss_en.json.
Operazioni «ss22_*»: scripts/motore/missione22_ss.gd.
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
NESSUNO = [{"op": "nothing"}]


def pari_dispari(d, pr):
    return [die(*[(i, i, d if i % 2 else pr) for i in range(10)])]


def sold_veic(pid, h_sold, h_veic):
    mov(pid, f"Se si muove un soldato entra in {h_sold}; se si muove un mezzo entra in {h_veic}.",
        [if_(VEIC, [enter(h_veic)], [enter(h_sold)])])


# ------------------------------------------------------------------ galleria W7–W9 (come nella Missione 20)
par("245", "Qui c’è l’ingresso di una galleria stradale fra le montagne, da W7 a W9: dentro si paga il costo della strada. Gli "
           "ingressi W6/W7 e W9/W10 contano come porte per la vista; per il buio da W6 o W10 si vede un solo esagono dentro. I "
           "paragrafi con la T valgono per chi si muove nella galleria, gli altri per chi passa sopra.", [{"op": "ss_galleria"}])
mov("150", "Il tedesco entra nella galleria ed entra in W7.", [enter("W7")])
mov("159", "Se si muove un mezzo entra in W8. Se si muove un soldato esce dalla galleria ed entra in W10.",
    [if_(VEIC, [enter("W8")], [enter("W10")])])
mov("188", "Il mezzo entra nella galleria ed entra in W9.", [enter("W9")])
mov("263", "Il tedesco esce dalla galleria ed entra in W6.", [enter("W6")])
mov("264", "Sopra la galleria entra in X7; dentro, un soldato entra in W9 e un mezzo in W7.",
    [if_(VEIC, [enter("W7")], [enter("X7")])])
par("465", "Nella galleria gli incidenti sono più gravi: −2 al dado dei danni. Due mezzi fermi nello stesso esagono la bloccano "
           "(6 azioni o 2 controlli Evento per sgombrarla).", [])
par("T375", "Trappola esplosiva! Esegui la procedura della trappola esplosiva.", [{"op": "boobytrap"}])

# ------------------------------------------------------------------ movimento (riferimenti rossi)
sold_veic("185", "L12", "M14")
sold_veic("186", "W13", "V12")
sold_veic("187", "X10", "W10")
sold_veic("189", "X6", "W5")
sold_veic("195", "L9", "M10")
sold_veic("196", "O8", "O7")
sold_veic("197", "P4", "Q5")
sold_veic("198", "P4", "R4")
sold_veic("199", "T6", "U6")
sold_veic("203", "K13", "L12")
sold_veic("205", "G16", "G15")
sold_veic("764", "M16", "O16")
sold_veic("765", "N17", "O18")
mov("183", "Se si muove un soldato e il numero d’azione è dispari entra in S14; altrimenti in T14.",
    [if_(ALL(NOT(VEIC), DISPARI), [enter("S14")], [enter("T14")])])
mov("184", "Se c’è un americano nelle colonne da O in poi e nelle righe da 10 in poi entra in O11; altrimenti in P11.",
    [if_({"ss22_us_nord_est": True}, [enter("O11")], [enter("P11")])])
mov("193", "Con un numero d’azione dispari entra in U8, altrimenti in S7.", [if_(DISPARI, [enter("U8")], [enter("S7")])])
mov("206", "Se si muove il 28 o il 46 entra in K9; altrimenti in J9.", [if_({"g_is": [28, 46]}, [enter("K9")], [enter("J9")])])
mov("207", "Con un numero d’azione dispari entra in N19, altrimenti in O18.", [if_(DISPARI, [enter("N19")], [enter("O18")])])
mov("763", "Se si muove un soldato entra in K15; un mezzo tira un dado: 0–2 entra in L13, 3–9 in M15.",
    [if_(VEIC, [die((0, 2, [enter("L13")]), (3, 9, [enter("M15")]))], [enter("K15")])])
mov("262", "Se non ci sono americani attivi a ovest della diagonale P1–Y5, il tedesco esce dalla mappa. Altrimenti, con il numero "
           "d’azione: 0–3 869, 4–6 824, 7–8 825, 9 800.",
    [if_({"ss22_us_ovest_diagonale": True}, NESSUNO, [{"op": "ss22_esce"}])])
mov("411", "[s4] Attiva il Panzer (tedesco 67) in S13, rivolto verso R13: era nascosto in un edificio (vedi 300). Iniziano i Round; "
           "gli americani consapevoli che non vanno nel panico ricevono 2 turni.",
    sighting(4) + [activate([(67, "S13")], "crouching", us_two=True)])
par("300", "Finché il carro è in un edificio spara solo lungo la fila di esagoni davanti a sé. In un esagono di filo spinato paga 2 PM e "
           "fa un controllo d’incidente (se fallisce resta bloccato).", [])

# Ponte di tre esagoni: soldati e mezzi tedeschi che ci arrivano.
PONTE_SOLD = ("Se si muove un soldato con l’esplosivo e qui non c’è un esplosivo né un tedesco con l’esplosivo, passa alla "
              "reazione speciale E. Un soldato senza esplosivo segue la carta.")
mov("151", "Il semicingolato dei genieri lascia qui un geniere (lo gestisce la reazione T dell’autista). " + PONTE_SOLD,
    [if_(ALL(NOT(VEIC), {"ss22_con_esplosivo": True}, NOT({"ss22_esplosivo_qui": True})), [{"op": "g_reaction", "r": "E"}])])
par("155", P["151"]["it"], P["151"]["ops"], "movimento")
par("156", P["151"]["it"], P["151"]["ops"], "movimento")
mov("152", "Se non ci sono esplosivi innescati né tedeschi con l’esplosivo sul ponte, entra in I15. Altrimenti il mezzo va in H14 e chi "
           "spara mira prima a chi è sotto il ponte, poi sul ponte, poi al mezzo.", [enter("I15")])
mov("154", "Se non ci sono esplosivi innescati né tedeschi con l’esplosivo sul ponte, entra in K14. Altrimenti il mezzo va in L14.",
    [enter("K14")])
mov("157", "Con un passeggero dietro l’autista spara (802); i passeggeri con l’esplosivo vanno a minare il ponte, gli altri sparano.",
    [{"op": "nothing"}])

# ------------------------------------------------------------------ ponti, esplosivi ed eventi del ponte
par("483", "[s4] Il soldato vede che il grande ponte da J15 a K14 c’è ancora: segnalini di ponte di pietra intatto in I15, J14 e K14 "
           "(un ponte di tre esagoni da H15 a L14). È il ponte che preoccupava il comando: ora la missione è controllarlo (sotto i "
           "ponti si scende fra i sostegni con un’azione), mettere in sicurezza la zona e difenderlo. Si passa alla Condizione 2. Chi "
           "va nel panico o viene ferito fra i sostegni e fallisce il controllo cade sui massi (danni della mitragliatrice media). "
           "Tira un dado: dispari 617, pari 723.",
    sighting(4) + [{"op": "ss22_ponte3"}, cond(2), pari_dispari([see("617")], [see("723")])[0]])
par("180", "[s9] Il soldato nota che il ponte in O4 è indebolito dagli anni e dall’incuria: potrebbe non reggere.",
    sighting(9) + [{"op": "ss22_ponte_debole"}])
par("331", "Se si muove un soldato: controllo di percezione; se riesce vedi 180. Se si muove un mezzo: controllo di percezione "
           "dell’autista; se riesce vedi 180.", [pc(0, [see("180")])])
par("190", "Sopra il ponte: un semicingolato lo fa crollare con un dispari (vedi 200); una jeep con 8–9; soldati a piedi con 9 (+1 per "
           "ogni soldato oltre il primo). Sotto il ponte nessun evento.",
    [if_({"ss_veicolo_modello": "halftrack"}, pari_dispari([see("200")], NESSUNO),
         [if_(VEIC, [die((0, 7, NESSUNO), (8, 9, [see("200")]))], [die((0, 8, NESSUNO), (9, 9, [see("200")]))])])])
par("200", "Il ponte crolla! I mezzi qui sono fuori uso, chi è a bordo tira i danni della pistola, chi è a piedi quelli della carica "
           "all’aperto; i sopravvissuti finiscono proni in un esagono accanto.", [{"op": "ss22_esplodi_qui"}])
par("228", "Se il ponte è intatto vedi 190; se è distrutto vedi 290.",
    [if_({"ss22_ponte_intatto": True}, [see("190")], [see("290")])])
par("227", "Se il ponte è distrutto vedi 290; altrimenti nessun evento.", [if_({"ss22_ponte_intatto": True}, NESSUNO, [see("290")])])
par("290", "Questo esagono è invalicabile per i mezzi e costa 2 PM ai soldati.", [])
par("590", "Se il ponte è intatto e s0 è avvenuto, nessun evento. Se è intatto e s0 non è avvenuto, vedi 226. Se è distrutto, vedi 290.",
    [if_({"ss22_ponte_intatto": True}, [if_(NOT(S(0)), [see("226")])], [see("290")])])
par("226", "Se si muove un soldato vedi 371; se si muove un mezzo vedi 379.", [if_(VEIC, [see("379")], [see("371")])])
par("371", "Controllo di percezione: se riesce vedi 485; altrimenti nessun evento.", [pc(0, [see("485")])])
par("379", "Chi è sul mezzo fa un controllo di percezione (l’autista normale, gli altri −2): se uno riesce vedi 485. Se falliscono tutti "
           "e s0 non è avvenuto, controllo di attivazione (+1): se riesce 610, altrimenti 611.",
    [pc(0, [see("485")], [if_(NOT(S(0)), [act(1, [see("610")], [see("611")])])])])
par("485", "Il soldato scopre che il ponte è minato: segnalino esplosivo sul lato 2 sotto il ponte (vedi 202). Chi ha superato il "
           "controllo diventa consapevole. Se s0 non è avvenuto, controllo di attivazione: se riesce 610, altrimenti 611.",
    [{"op": "ss22_esplosivo_qui"}, if_(NOT(S(0)), [act(0, [see("610")], [see("611")])])])
par("202", "Per disinnescare un esplosivo servono 2 azioni (anche divise) fra i sostegni del ponte: con la prima il segnalino passa sul "
           "lato 1, con la seconda si toglie e vale 1 PV. Disinnescato quello di V14, il tedesco 26 perde la reazione B. Gli americani "
           "non possono usare gli esplosivi. Se tutti i tedeschi sono fuori combattimento ma restano esplosivi innescati, si resta nei "
           "Round finché non sono disinnescati o saltati.", [])
par("182", "1. Se c’è un esplosivo sul lato 1 con un americano attivo sotto il ponte nello stesso esagono, vedi 191.\n2. Se c’è un "
           "esplosivo sul lato 2 con un americano sotto il ponte nello stesso esagono, vedi 204.\n3. Altrimenti vedi 194.",
    [{"op": "ss22_182"}])
par("191", "Il soldato col PC più alto sotto il ponte, nell’esagono dell’esplosivo sul lato 1, fa subito un controllo di percezione: se "
           "riesce vedi 210, altrimenti 201.", [{"op": "ss22_disinnesco_191"}])
par("201", "L’esplosivo in questo esagono salta. Vedi 181 per gli effetti.", [{"op": "ss22_esplodi_qui"}])
par("204", "Salta un esplosivo sul lato 2 (a caso se più d’uno) in un esagono con un americano attivo sotto il ponte. Vedi 181. Può "
           "succedere più volte.", [{"op": "ss22_esplodi_americano"}])
par("210", "Il soldato disinnesca l’esplosivo un attimo prima che salti: 2 PV invece di 1. Può succedere più volte.", [])
par("181", "Esplosione sotto il ponte. Al primo scoppio quel tratto del ponte è distrutto (niente mezzi, 2 PM e controllo d’appoggio a "
           "piedi: 8–9 si cade sotto, danni della mitragliatrice media); chi è sopra tira i danni della carica all’aperto, chi è fra i "
           "sostegni quelli della carica al chiuso; i mezzi sopra sono fuori uso. Al secondo scoppio il ponte crolla: i tre esagoni "
           "diventano macerie, chi è lì tira i danni della mitragliatrice media, i mezzi sono perduti. Vedi subito 260.", [])
par("194", "Tira un dado: 0–1 117; 2–3 214; 4–5 995; 6 996; 7 997; 8 225; 9 212.",
    [die((0, 1, [see("117")]), (2, 3, [see("214")]), (4, 5, [see("995")]), (6, 6, [see("996")]), (7, 7, [see("997")]),
         (8, 8, [see("225")]), (9, 9, [see("212")]))])
par("225", "Se sotto un ponte c’è un esplosivo innescato, ne salta uno (a caso). Vedi 181. Solo una volta per missione.",
    [{"op": "ss22_esplodi_caso"}])
par("260", "[s3] Il ponte è distrutto: inseguire i tedeschi responsabili (330) o ripiegare e avvisare il comando al più presto (994)?",
    sighting(3) + [{"op": "scelta_attiva", "par": "330", "testo": "Inseguiamo i tedeschi (330)"},
                   {"op": "scelta_attiva", "par": "994", "testo": "Ripieghiamo (994)"}])
par("330", "Si passa alla Condizione 4. La missione finisce quando non ci sono più tedeschi attivi in mappa. Servono 21 PV. Niente PV "
           "persi per i feriti gravi se a fine missione tutti i tedeschi sono fuori combattimento o usciti.",
    [cond(4), {"op": "ss22_modo", "modo": "inseguire", "pv": 21}, {"op": "ss_scelte_22"}])
par("994", "Si passa alla Condizione 3. La missione finisce quando tutti gli americani sono usciti dagli esagoni d’ingresso (W1–Y1). "
           "Servono 20 PV. I feriti gravi portati fuori non costano PV.",
    [cond(3), {"op": "ss22_modo", "modo": "ritirata", "pv": 20}, {"op": "ss_scelte_22"}])
par("269", "La missione finisce nella Condizione 2 quando non ci sono più tedeschi attivi né esplosivi innescati in mappa (se restano "
           "esplosivi si continua con i Round finché non sono disinnescati o saltati). Niente PV persi per i feriti gravi. Servono 21 PV.",
    [{"op": "ss22_letto269"}, {"op": "ss22_modo", "modo": "", "pv": 21}])

# ------------------------------------------------------------------ eventi
par("211", "Se il semicingolato tedesco è in gioco fora una gomma e va solo piano (una volta sola). Altrimenti nessun evento.",
    [{"op": "ss22_gomma_ht"}])
par("229", "Se un mezzo americano è in gioco, uno (a caso) fora una gomma e va solo piano. Una volta sola. Altrimenti nessun evento.",
    [{"op": "ss22_gomma_us"}])
par("212", "Un soldato porta una granata difettosa: nelle Operazioni un americano, nei Round un dado (dispari americano, pari tedesco), "
           "poi a caso. Controllo di percezione: se riesce la getta via senza danni; se fallisce esplode addosso a lui e a chi è "
           "nell’esagono. Solo una volta per missione.", [{"op": "ss_granata_difettosa_c"}])
par("214", "Un’arma tedesca usata nel Round precedente (non il cannone anticarro) finisce le munizioni.", [{"op": "ammo_out"}])
par("400", "Un’arma tedesca usata nell’ultimo Round finisce le munizioni (a caso se più d’una). Può succedere più volte.",
    [{"op": "ammo_out"}])
par("222", "Un soldato a caso ha l’arma col calcio rotto: −1 per colpire. Senza tedeschi attivi tocca a un americano, altrimenti un "
           "dado (dispari americano, pari tedesco). Solo una volta per missione.", [{"op": "ss_calcio_rotto"}])
par("370", "Se un soldato è in un esagono di torrente, uno a caso scivola sui sassi: controllo di percezione, se fallisce perde una "
           "granata. Solo una volta. Altrimenti nessun evento.", [{"op": "ss22_torrente_scivola"}])
par("117", "Nelle Operazioni nessun evento. Nei Round un americano a caso (non un comandante) va nel panico e si butta a terra: si "
           "riprende quando un compagno entra nel suo esagono e spende un’azione. Solo una volta per missione.",
    [{"op": "ss_panico_us"}])
par("995", "Un tedesco ferito, a caso, diventa incapacitato per la perdita di sangue. Solo una volta per missione.",
    [{"op": "dissanguamento", "chiave": "995", "lato": "de"}])
par("996", "Un tedesco incapacitato, a caso, muore per le ferite. Solo una volta per missione.",
    [{"op": "morte_incapacitato", "chiave": "996", "lato": "de"}])
par("997", "Un americano ferito, a caso, diventa incapacitato per la perdita di sangue. Solo una volta per missione.",
    [{"op": "dissanguamento", "chiave": "997", "lato": "us"}])
par("480", "Qui il torrente è invalicabile. Controllo di percezione: se riesce si torna nell’esagono di partenza senza perdere PM; se "
           "fallisce si torna indietro e si perdono 2 PM.", [{"op": "ss_torna_indietro"}])
par("674", "Nessun evento in questa missione.", [])
par("291", "Colloca un segnalino Evento. Se s5 non è avvenuto vedi 617. Se s5 è avvenuto: nelle Operazioni controllo Evento, nei "
           "Round nessun evento.", [EVENT, if_(NOT(S(5)), [see("617")], [{"op": "event_check_ops"}])])

# ------------------------------------------------------------------ controlli e attivazioni
par("372", "Controllo di percezione: se riesce vedi 611. Se fallisce, controllo di attivazione: se riesce 610, altrimenti nessun evento.",
    [pc(0, [see("611")], [act(0, [see("610")])])])
par("373", "Controllo di percezione: se riesce vedi 485. Se fallisce e s0 non è avvenuto, controllo di attivazione: se riesce 610.",
    [pc(0, [see("485")], [if_(NOT(S(0)), [act(0, [see("610")])])])])
par("374", "Controllo di attivazione (−1): se riesce vedi 613. Se fallisce, controllo di percezione: se riesce 612.",
    [act(-1, [see("613")], [pc(0, [see("612")])])])
par("376", "Controllo di percezione (−1): se riesce vedi 612. Se fallisce, controllo di attivazione (−1): se riesce 613.",
    [pc(-1, [see("612")], [act(-1, [see("613")])])])
par("377", "Controllo di percezione: se riesce vedi 612. Se fallisce, controllo di attivazione: se riesce 613.",
    [pc(0, [see("612")], [act(0, [see("613")])])])
par("378", "Controllo di percezione (−1): se riesce vedi 614. Se fallisce, controllo di attivazione: se riesce 619.",
    [pc(-1, [see("614")], [act(0, [see("619")])])])
par("482", "Controllo di attivazione: se riesce vedi 619. Se fallisce, controllo di percezione (−1): se riesce 614.",
    [act(0, [see("619")], [pc(-1, [see("614")])])])
par("484", "Controllo di percezione (−1): se riesce, controllo di attivazione: se riesce 616, altrimenti 618. Se fallisce, nessun evento.",
    [pc(-1, [act(0, [see("616")], [see("618")])])])
par("486", "Controllo di percezione: se riesce, controllo di attivazione: se riesce 616 (chi ha superato il controllo è consapevole), "
           "altrimenti 618. Se fallisce, controllo di attivazione (+1): se riesce 616.",
    [pc(0, [act(0, [see("616")], [see("618")])], [act(1, [see("616")])])])
par("488", "Se si muove un soldato nessun evento; se si muove un mezzo vedi 720.", [if_(VEIC, [see("720")])])
par("720", "Controllo di attivazione (+1): se riesce vedi 616. Se fallisce, controllo di percezione: se riesce 618.",
    [act(1, [see("616")], [pc(0, [see("618")])])])
par("721", "Tira un dado: dispari 616, pari 618.", pari_dispari([see("616")], [see("618")]))
par("591", "Se si muove un mezzo nessun evento; se si muove un soldato vedi 372.", [if_(VEIC, NESSUNO, [see("372")])])
par("592", "Se si muove un mezzo nessun evento; se si muove un soldato vedi 373.", [if_(VEIC, NESSUNO, [see("373")])])
par("593", "Colloca un segnalino Evento. Controllo di attivazione: se riesce vedi 615.", [EVENT, act(0, [see("615")])])
par("594", "Se si muove un mezzo vedi 374; se si muove un soldato vedi 376.", [if_(VEIC, [see("374")], [see("376")])])
par("595", "Se si muove un soldato vedi 376; se si muove un mezzo vedi 377.", [if_(VEIC, [see("377")], [see("376")])])
par("596", "Se si muove un soldato vedi 378; se si muove un mezzo vedi 182.", [if_(VEIC, [see("182")], [see("378")])])
par("597", "Se si muove un soldato vedi 184; se si muove un mezzo vedi 486.", [if_(VEIC, [see("486")], [see("184")])])
par("725", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 183.", [EVENT, pc(0, [see("183")])])
par("421", "Controllo di percezione: se riesce vedi 447, altrimenti 448.", [pc(0, [see("447")], [see("448")])])
par("432", "Controllo di percezione: se riesce vedi 508, altrimenti 509.", [pc(0, [see("508")], [see("509")])])
par("433", "Controllo di attivazione: se riesce vedi 505, altrimenti 506.", [act(0, [see("505")], [see("506")])])
par("420", "Se s7 non è avvenuto vedi 433. Se s4 non è avvenuto vedi 725. Se s4, s6 e s7 sono tutti avvenuti, colloca un segnalino "
           "Evento: nessun evento.",
    [if_(NOT(S(7)), [see("433")], [if_(NOT(S(4)), [see("725")], [EVENT])])])
par("437", "Se s6 non è avvenuto vedi 604. Se s4 non è avvenuto vedi 725. Altrimenti colloca un segnalino Evento: nessun evento.",
    [if_(NOT(S(6)), [see("604")], [if_(NOT(S(4)), [see("725")], [EVENT])])])
par("438", "Se s6 non è avvenuto vedi 604. Se s7 non è avvenuto vedi 421. Altrimenti colloca un segnalino Evento: nessun evento.",
    [if_(NOT(S(6)), [see("604")], [if_(NOT(S(7)), [see("421")], [EVENT])])])
par("449", "Se s0 non è avvenuto vedi 418. Se s1 non è avvenuto vedi 721. Altrimenti colloca un segnalino Evento: nessun evento.",
    [if_(NOT(S(0)), [see("418")], [if_(NOT(S(1)), [see("721")], [EVENT])])])
par("605", "Se il tedesco 26 è uscito o è stato tolto dalla mappa vedi 650; altrimenti nessun evento.",
    [if_({"ss22_uscito": 26}, [see("650")])])
par("607", "Se il tedesco 29 è uscito o è stato tolto dalla mappa vedi 659; altrimenti nessun evento.",
    [if_({"ss22_uscito": 29}, [see("659")])])
par("650", "Il tedesco 26 rientra in piedi in questo esagono. Gli americani qui fanno un controllo di percezione (+2): se uno riesce "
           "vantaggio americano, altrimenti tedesco.", [{"op": "ss22_rientra", "g": 26}, pc(2, [{"op": "ss_vantaggio", "lato": "us"}],
                                                                                                [{"op": "ss_vantaggio", "lato": "de"}])])
par("659", "Il tedesco 29 rientra in piedi in questo esagono. Gli americani qui fanno un controllo di percezione (+2): se uno riesce "
           "vantaggio americano, altrimenti tedesco.", [{"op": "ss22_rientra", "g": 29}, pc(2, [{"op": "ss_vantaggio", "lato": "us"}],
                                                                                                [{"op": "ss_vantaggio", "lato": "de"}])])
TABELLA = ("1. Se s6 non è avvenuto vedi 487. 2. Se s5 non è avvenuto vedi 723. 3. Se s8 non è avvenuto vedi 727. 4. Se s7 non è "
           "avvenuto vedi 724. 5. Se il 26 è uscito o tolto vedi 489; se il 29 è uscito o tolto vedi 728. 6. Se non hai letto il 269 "
           "leggilo ora. 7. Se l’hai letto vedi 182.")


def coda():
    return [if_({"ss22_uscito": 26}, [see("489")], [if_({"ss22_uscito": 29}, [see("728")],
            [if_({"ss22_letto269": True}, [see("182")], [see("269")])])])]


par("722", TABELLA, [if_(NOT(S(6)), [see("487")], [if_(NOT(S(5)), [see("723")], [if_(NOT(S(8)), [see("727")],
    [if_(NOT(S(7)), [see("724")], coda())])])])])
par("726", "1. Se s7 non è avvenuto vedi 724. 2. Se s8 non è avvenuto vedi 727. 3. Se s5 non è avvenuto, dado: dispari 723, pari 617. "
           "4. Se s6 non è avvenuto vedi 487. 5. Se il 29 è uscito o tolto vedi 728; se il 26, 489. 6–7. Il 269, poi il 182.",
    [if_(NOT(S(7)), [see("724")], [if_(NOT(S(8)), [see("727")], [if_(NOT(S(5)), pari_dispari([see("723")], [see("617")]),
        [if_(NOT(S(6)), [see("487")], coda())])])])])
par("729", "1. Se s5 non è avvenuto vedi 617. 2. Se s6 non è avvenuto vedi 487. 3. Se s7 non è avvenuto vedi 724. 4. Se s8 non è "
           "avvenuto vedi 727. 5. Se il 26 è uscito o tolto vedi 489; se il 29, 728. 6–7. Il 269, poi il 182.",
    [if_(NOT(S(5)), [see("617")], [if_(NOT(S(6)), [see("487")], [if_(NOT(S(7)), [see("724")], [if_(NOT(S(8)), [see("727")], coda())])])])])

# Attivazioni.
par("418", "[s0] In questo esagono c’è un tedesco nascosto: attiva il 26 accovacciato nella reazione speciale B. Iniziano i Round. Gli "
           "americani qui fanno un controllo di percezione: se uno riesce vantaggio americano, altrimenti tedesco.",
    sighting(0) + [activate([(26, "@hex")], "crouching", reaction="B"), pc(0, [{"op": "ss_vantaggio", "lato": "us"}],
                                                                          [{"op": "ss_vantaggio", "lato": "de"}])])
for pid, adv in (("610", "de"), ("611", "us")):
    par(pid, f"[s0] Attiva il tedesco 26 accovacciato nella reazione speciale B (dado: 0–3 S10, 4–6 R17, 7–9 W19). Iniziano i Round, "
             f"vantaggio {'tedesco' if adv == 'de' else 'americano'}.",
        sighting(0) + [die((0, 3, [activate([(26, "S10")], "crouching", adv=adv, reaction="B")]),
                           (4, 6, [activate([(26, "R17")], "crouching", adv=adv, reaction="B")]),
                           (7, 9, [activate([(26, "W19")], "crouching", adv=adv, reaction="B")]))])
par("489", "Riattiva il tedesco 26 accovacciato: dispari in Y8, pari in Y12. Iniziano i Round, vantaggio tedesco.",
    pari_dispari([{"op": "ss22_rientra", "g": 26, "hex": "Y8", "stance": "crouching"}, {"op": "ss_inizia_round"}],
                 [{"op": "ss22_rientra", "g": 26, "hex": "Y12", "stance": "crouching"}, {"op": "ss_inizia_round"}]))
par("728", "Riattiva il tedesco 29 accovacciato: dispari in N1, pari in Y8. Iniziano i Round.",
    pari_dispari([{"op": "ss22_rientra", "g": 29, "hex": "N1", "stance": "crouching"}, {"op": "ss_inizia_round"}],
                 [{"op": "ss22_rientra", "g": 29, "hex": "Y8", "stance": "crouching"}, {"op": "ss_inizia_round"}]))
for pid, h, adv in (("612", "P12", "us"), ("613", "P12", "de"), ("614", "O12", "us"), ("616", "Q17", "de"), ("618", "Q17", "us"),
                    ("619", "O12", "de"), ("416", "P12", "de"), ("417", "O12", "de")):
    par(pid, f"[s1] Attiva il tedesco 27 accovacciato nella reazione speciale P in {h}. Iniziano i Round, vantaggio "
             f"{'americano' if adv == 'us' else 'tedesco'}.",
        sighting(1) + [activate([(27, h)], "crouching", adv=adv, reaction="P")])
par("615", "[s2] Attiva il tedesco 29 accovacciato (dado: 0–2 M4, 3–5 X7, 6–9 N1). Iniziano i Round: vantaggio tedesco se non ci sono "
           "stati altri avvistamenti, altrimenti americano.",
    sighting(2) + [die((0, 2, [activate([(29, "M4")], "crouching")]), (3, 5, [activate([(29, "X7")], "crouching")]),
                       (6, 9, [activate([(29, "N1")], "crouching")]))])
par("487", "[s6] Attiva i tedeschi 28 e 46 accovacciati (dado: 0–2 E10, 3–5 F8, 6–9 N19). Iniziano i Round; il 28 riceve 2 turni.",
    sighting(6) + [die((0, 2, [activate([(28, "E10"), (46, "E10")], "crouching", two=[28])]),
                       (3, 5, [activate([(28, "F8"), (46, "F8")], "crouching", two=[28])]),
                       (6, 9, [activate([(28, "N19"), (46, "N19")], "crouching", two=[28])]))])
par("604", "[s6] Attiva i tedeschi 28 e 46 accovacciati nel primo esagono libero da americani fra F8, N19, E10. Iniziano i Round.",
    sighting(6) + [{"op": "ss_due_in_libero", "g": [28, 46], "hex": ["F8", "N19", "E10"]}])
par("608", "[s8] Attiva il tedesco 38 accovacciato nella reazione speciale P nel primo esagono libero da americani fra L14, N14, H13. "
           "Iniziano i Round.", sighting(8) + [{"op": "ss_due_in_libero", "g": [38], "hex": ["L14", "N14", "H13"], "reaction": "P"}])
par("727", "[s8] Attiva il tedesco 38 accovacciato nella reazione speciale P (dado: 0–3 L14, 4–6 F8, 7–9 H13). Iniziano i Round.",
    sighting(8) + [die((0, 3, [activate([(38, "L14")], "crouching", reaction="P")]), (4, 6, [activate([(38, "F8")], "crouching", reaction="P")]),
                       (7, 9, [activate([(38, "H13")], "crouching", reaction="P")]))])
GENIERI = ("[s5] I genieri tedeschi provano a far saltare il ponte: semicingolato in {h} rivolto verso {v}; il 40 accanto all’autista, il "
           "41 alla guida, i genieri 42–45 dietro con gli esplosivi (il 42 alla mitragliatrice leggera). Iniziano i Round.")
par("617", GENIERI.format(h="H15", v="I15") + " Vantaggio tedesco.",
    sighting(5) + [{"op": "ss22_genieri", "hex": "H15", "verso": "I15", "adv": "de"}])
par("723", GENIERI.format(h="L13", v="K14") + " Il 41 riceve 2 turni.",
    sighting(5) + [{"op": "ss22_genieri", "hex": "L13", "verso": "K14", "two": [41]}])
ATG_Q9 = ["Q9", ["P9", "Q10", "R9"]]
ATG_O19 = ["O19", ["N19", "N18", "O18"]]
ATG_K9 = ["K9", ["J9", "K10", "L9"]]
for pid, (h, arco), adv, sorpresa in (("447", ATG_O19, "us", True), ("448", ATG_O19, "de", False), ("505", ATG_K9, "de", False),
                                      ("506", ATG_K9, "us", True), ("508", ATG_Q9, "us", True), ("509", ATG_Q9, "de", False)):
    par(pid, f"[s7] {'Avete sorpreso' if sorpresa else 'C’è'} una squadra tedesca col cannone anticarro nascosta in {h} (spara verso "
             f"{', '.join(arco)}). Iniziano i Round, vantaggio {'americano' if adv == 'us' else 'tedesco'}. Vedi 253.",
        sighting(7) + [{"op": "ss22_atg", "hex": h, "arco": arco, "adv": adv}])
par("724", "[s7] Attiva il cannone anticarro tedesco (dado: 0–2 Q9 verso P9, Q10, R9; 3–5 O19 verso N19, N18, O18; 6–8 K9 verso J9, "
           "K10, L9; 9 si ritira). Iniziano i Round.",
    sighting(7) + [{"op": "ss22_atg", "hex": "", "arco": [], "dado": [ATG_Q9, ATG_O19, ATG_K9], "adv": "us"}])
par("253", "Il cannone anticarro si carica con un’azione e spara con un’altra (non nello stesso turno), solo dai suoi serventi; spara "
           "solo nel suo settore. Gli americani non possono usarlo.", [])
par("790", "[s6] Attiva la squadra del mortaio (tedesco 47) in S10. Iniziano i Round, vantaggio tedesco. Vedi 791.",
    sighting(6) + [{"op": "ss22_mortaio", "hex": "S10", "adv": "de"}])
par("791", "Mortaio col colpo pronto: gittata minima 7 esagoni; si spara e si prepara il colpo nello stesso turno ma una volta "
           "ciascuno; ratés 05. Bersaglio: prima i mezzi visibili più vicini a S10, poi i soldati.", [])

# ------------------------------------------------------------------ azioni dei tedeschi (codice in missione22_ss.gd)
AZ = {
 "216": "Autista del semicingolato (reazione T). Fermo o distrutto il mezzo, toglie la T. Con genieri ed esplosivi dietro va piano sul "
        "ponte e ne fa scendere uno in ogni esagono senza esplosivo; senza genieri dietro aspetta (reazione G).",
 "217": "Secondo del semicingolato (reazione T). Fermo o distrutto il mezzo, toglie la T; altrimenti spara al più vicino.",
 "218": "Geniere sul semicingolato (reazione T): aspetta di essere portato sul ponte; se il mezzo è fermo o distrutto scende e va a "
        "minare il ponte (reazione E).",
 "261": "Reazione E. Senza esplosivo nell’esagono: sul ponte scende fra i sostegni (un’azione); sotto, innesca l’esplosivo (un’azione). "
        "Con l’esplosivo innescato: assalta un americano sotto il ponte nello stesso esagono, spara a chi vede sotto, altrimenti risale; "
        "sopra, toglie la E (il 40 e il 41 passano alla H).",
 "153": "Reazione H (40, 41): se il semicingolato c’è torna a bordo e riprende la T; altrimenti segue la carta.",
 "158": "Reazione G (40): accovacciato, tiro al più facile; quando i genieri sono tornati a bordo riprende la T.",
 "481": "Reazione G (41): aspetta in J14 i genieri sparando al più facile; quando sono a bordo riprende la T.",
 "599": "Reazione B (26). Con un americano nell’esagono, assalto. Disinnescato l’esplosivo di V14 toglie la B. Con un americano sul ponte "
        "di V14 o accanto aziona il detonatore (219): il ponte salta (−1 PV). Altrimenti spara al più vicino al ponte.",
 "219": "Accovacciato, aziona il detonatore e fa saltare il ponte in V14. Toglie la reazione B. Vedi 598.",
 "598": "Il ponte in V14 salta: chi è sopra o sotto tira i danni della carica all’aperto, i mezzi sopra sono fuori uso; i mezzi non "
        "passano più e i soldati pagano 2 PM. −1 PV.",
 "208": "Reazione P. Con il panzerfaust e un mezzo americano entro 3 esagoni, accovacciato gli spara. Senza panzerfaust toglie la P e "
        "ritira il numero d’azione. Altrimenti: 0 840; 1–4 802; 5–7 825; 8–9 869.",
 "209": "Reazione Q. Come il 208, poi: 0 869; 1–2 824; 3–4 825; 5–9 802.",
 "265": "Servente del cannone anticarro: assalto a chi è nell’esagono; con un americano accanto granata o miglior tiro; altrimenti carica "
        "il cannone o spara al mezzo americano più vicino al grande ponte (solo nel suo settore).",
 "266": "Servente: spara col cannone al mezzo più vicino se carico, altrimenti lo carica.",
 "267": "Servente: carica il cannone se è scarico, altrimenti spara al mezzo più facile.",
 "268": "Servente: carica il cannone se è scarico, altrimenti spara al mezzo più vicino al grande ponte.",
 "415": "Il Panzer era nascosto nell’edificio: al primo turno avvia il motore con tutti i punti equipaggio; gli americani entro 3 esagoni "
        "diventano consapevoli per il boato.",
 "339": "Un geniere ferito lascia l’arma e tiene l’esplosivo.",
 "549": "Squadra del mortaio: assalto a chi è nell’esagono; tiro al più facile contro un americano accanto; granata a 2–3 esagoni (o "
        "lanciata in piedi a 4–6); altrimenti prepara o spara il mortaio (502–504).",
 "823": "Se nell’esagono c’è un altro tedesco attivo si butta a terra; altrimenti corre in un esagono scoperto o striscia in un altro.",
 "848": "Con una granata e un bersaglio entro 3 esagoni, accovacciato la lancia al più vicino; a 4–6 esagoni la lancia in piedi. "
        "Altrimenti 815.",
 "431": "Se vede un bersaglio attivo vedi 352; altrimenti si butta a terra.",
}
for k, v in AZ.items():
    par(k, v, [], "azione")
