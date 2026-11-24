# -*- coding: utf-8 -*-
"""Silver Star – Missione 23 «Sconosciuti nella notte» (Strangers in the Night; mappa F, in alto è sud; settembre 1944, a sud
della linea Gotica).

All’alba, nella nebbia, la squadra occupa il villaggio davanti a una galleria. Testo inglese: tools/paragrafi_ss_en.json.
Operazioni «ss23_*»: scripts/motore/missione23_ss.gd.
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


def tabella(*righe):
    """righe: (da, a, paragrafo)."""
    return [die(*[(a, b, [see(str(c))] if c else NESSUNO) for a, b, c in righe])]


# ------------------------------------------------------------------ controlli evento delle carte (nebbia che si dirada)
par("381", "1. Se s0 non è avvenuto, vedi 385.\n2. Nelle Operazioni, se s0 è avvenuto, nessun evento.\n3. Tira un dado: 0–1 212; 2–3 "
           "400; 4–5 993; 6–7 370; 8 117; 9 nessun evento.",
    [if_(NOT(S(0)), [see("385")], [if_({"in_rounds": True}, tabella((0, 1, 212), (2, 3, 400), (4, 5, 993), (6, 7, 370), (8, 8, 117),
                                                                 (9, 9, None)))])])
par("387", "1. Se s1 non è avvenuto, vedi 389.\n2. La nebbia comincia a diradarsi: ora si vede fino a 5 esagoni.\n3. Tira un dado: "
           "0–1 212; 2–3 993; 4 370; 5–6 400; 7 117; 8–9 116.",
    [if_(NOT(S(1)), [see("389")], [{"op": "vista", "n": 5}] + tabella((0, 1, 212), (2, 3, 993), (4, 4, 370), (5, 6, 400), (7, 7, 117),
                                                                      (8, 9, 116)))])
par("318", "1. La nebbia continua a diradarsi: ora si vede fino a 10 esagoni.\n2. Se s2 non è avvenuto, vedi 441.\n3. Se s9 non è "
           "avvenuto, vedi 413.\n4. Tira un dado: 0 995; 1 996; 2 997; 3 117; 4–6 698; 7 116; 8 993; 9 370.",
    [{"op": "vista", "n": 10}, if_(NOT(S(2)), [see("441")], [if_(NOT(S(9)), [see("413")],
        tabella((0, 0, 995), (1, 1, 996), (2, 2, 997), (3, 3, 117), (4, 6, 698), (7, 7, 116), (8, 8, 993), (9, 9, 370)))])])
par("278", "Si passa alla Condizione 2.", [cond(2)])

# ------------------------------------------------------------------ pattuglie
par("385", "[s0] Segnalino pattuglia NN (dado: 0 A19; 1–2 S10; 3 N19; 4–5 Y8; 6–7 Y1; 8–9 S14). Nelle Operazioni si resta nelle "
           "Operazioni: per ogni esagono percorso da un americano il segnalino avanza di un esagono verso l’americano più vicino (nei "
           "Round 5 PM all’inizio di ogni Round). Se il segnalino vede un americano, 620; se un americano vede il segnalino, 492. Il "
           "segnalino non si può attaccare.",
    sighting(0) + [{"op": "ss23_pattuglia", "nome": "NN", "tab": ["A19", "S10", "S10", "N19", "Y8", "Y8", "Y1", "Y1", "S14", "S14"]}])
par("389", "[s1] Segnalino pattuglia MM (dado: 0 A15; 1 F14; 2 J19; 3–4 O14; 5–6 U13; 7 Y1; 8 M12; 9 si ritira). Come il 385, ma "
           "nei Round avanza di 4 PM.",
    sighting(1) + [{"op": "ss23_pattuglia", "nome": "MM", "tab": ["A15", "F14", "J19", "O14", "O14", "U13", "U13", "Y1", "M12", ""]}])
par("492", "Gli americani che vedono il segnalino fanno un controllo di percezione: se uno riesce vedi 383 (chi riesce è consapevole). "
           "Se falliscono tutti, controllo di attivazione: se riesce 380, altrimenti 519.",
    [{"op": "ss23_pc_osservatori", "ok": [see("383")], "ko": [act(0, [see("380")], [see("519")])]}])
par("620", "Controllo di attivazione: se riesce vedi 380. Altrimenti gli americani che vedono il segnalino fanno un controllo di "
           "percezione: se uno riesce 383, se falliscono tutti 510.",
    [act(0, [see("380")], [{"op": "ss23_pc_osservatori", "ok": [see("383")], "ko": [see("510")]}])])
par("380", "La pattuglia si schiera intorno al segnalino (diagramma 1–4 col dado; il segnalino si toglie): pattuglia MM i tedeschi "
           "62–65, pattuglia NN i 55–58. Iniziano i Round, vantaggio tedesco. Vedi 499.",
    [{"op": "ss23_schiera_pattuglia", "adv": "de"}])
par("383", "La pattuglia si schiera intorno al segnalino (diagramma 1–4 col dado; il segnalino si toglie): pattuglia MM i tedeschi "
           "62–65, pattuglia NN i 55–58. Iniziano i Round, vantaggio americano. Vedi 499.",
    [{"op": "ss23_schiera_pattuglia", "adv": "us"}])
par("499", "I tedeschi della pattuglia non sono automaticamente consapevoli: controllo di percezione (+2 se nell’esagono di un "
           "americano, +1 se accanto); chi fallisce è inconsapevole nel primo Round.", [])
par("510", "Nessuna attivazione: il segnalino continua ad avanzare.", [])
par("515", "Nessun evento: si continua. Se un americano arriva dove vede il segnalino, di nuovo 492.", [])
par("519", "Se s2 non è avvenuto, dado: 0–8 515, 9 388. Se s2 è avvenuto, 515.",
    [if_(NOT(S(2)), [die((0, 8, [see("515")]), (9, 9, [see("388")]))], [see("515")])])
par("388", "[s8] Terribile errore: non era una pattuglia tedesca ma il superstite di una pattuglia americana (US 06), accovacciato "
           "nell’esagono del segnalino (che resta in mappa). Chi ha fallito il controllo del 492 gli spara un tiro rapido gratis: se muore "
           "−4 PV (2 per la morte, 2 per l’errore); se è incapacitato, la perdita normale. Se sopravvive si unisce alla squadra e si rifà "
           "il 492, con il controllo di attivazione a −1.",
    sighting(8) + [{"op": "ss23_superstite", "hex": "@hex", "errore": True}])

# ------------------------------------------------------------------ superstite e soccorsi
par("414", "[s2] Attiva il superstite americano US 06, prono, in questo esagono: si unisce alla squadra.",
    sighting(2) + [{"op": "ss23_superstite", "hex": "@hex"}])
par("441", "[s2] Attiva il superstite americano US 06, prono (dado: 0–1 X19; 2–3 J19; 4–5 P19; 6–7 Y17; 8–9 N1): si unisce alla squadra.",
    sighting(2) + [die((0, 1, [{"op": "ss23_superstite", "hex": "X19"}]), (2, 3, [{"op": "ss23_superstite", "hex": "J19"}]),
                       (4, 5, [{"op": "ss23_superstite", "hex": "P19"}]), (6, 7, [{"op": "ss23_superstite", "hex": "Y17"}]),
                       (8, 9, [{"op": "ss23_superstite", "hex": "N1"}]))])
par("413", "Se un comandante è ancora attivo vedi 442; altrimenti 329.", [if_({"ss23_comandante": True}, [see("442")], [see("329")])])
par("442", "Vi serve aiuto? Se sì, 328; se no, 329.",
    [{"op": "scelta_attiva", "par": "328", "testo": "Chiediamo aiuto (328)"}, {"op": "scelta_attiva", "par": "329", "testo": "Ce la facciamo da soli (329)"}])
par("328", "[s9] Lo Sherman US 07 entra (dispari in B19, pari in A8): non è ai tuoi ordini, agisce col numero d’azione tedesco e segue "
           "i riferimenti di movimento neri delle carte. Riceve 2 turni in questo Round. Nel prossimo Round, al posto del controllo "
           "Evento, vedi 316. Servono 17 PV. La missione finisce nella Condizione 3 dopo s7 e s8, quando non ci sono tedeschi attivi. "
           "I feriti gravi in un edificio o nella galleria non costano PV.",
    sighting(9) + [{"op": "ss23_sherman"}, {"op": "ss23_modo", "modo": "aiuto", "pv": 17}, {"op": "ss_scelte_23"},
                   {"op": "ss_inizia_round"}])
par("329", "Servono 14 PV. La missione finisce nella Condizione 3 dopo s7 e s8, quando non ci sono tedeschi attivi. I feriti gravi in "
           "un edificio o nella galleria non costano PV.", [{"op": "ss23_modo", "modo": "soli", "pv": 14}, {"op": "ss_scelte_23"}])
par("435", "Lo Sherman gira per entrare in X12: gli arbusti si impigliano nei cingoli e resta bloccato qui (spara ancora).",
    [{"op": "ss23_sherman_bloccato"}])
par("609", "Lo Sherman gira per entrare in P12: gli arbusti si impigliano nei cingoli e resta bloccato qui (spara ancora).",
    [{"op": "ss23_sherman_bloccato"}])
par("603", "Se si muove un soldato vedi 168; se si muove un mezzo vedi 435.", [if_(VEIC, [see("435")], [see("168")])])
par("646", "Se si muove un soldato nessun evento; se si muove un mezzo vedi 609.", [if_(VEIC, [see("609")])])

# ------------------------------------------------------------------ Panzer
PANZER = "Attiva il Panzer 67 in {h} rivolto verso {v} (vedi 300: nascosto in una casa). Iniziano i Round."
for pid, h, v, extra, adv, us_two in (("410", "S13", "R13", " Vantaggio tedesco.", "de", False),
                                      ("411", "S13", "R13", " Gli americani consapevoli che non vanno nel panico ricevono 2 turni.", None, True),
                                      ("732", "P15", "Q16", " Chi ha superato il controllo è consapevole.", None, False),
                                      ("733", "P15", "Q16", " Dado: dispari vantaggio tedesco, pari il Panzer riceve 2 turni.", "de", False),
                                      ("736", "U15", "T15", " Dado: dispari vantaggio americano, pari gli americani consapevoli ricevono 2 turni.", "us", False),
                                      ("737", "U15", "T15", " Vantaggio tedesco.", "de", False)):
    par(pid, "[s4] " + PANZER.format(h=h, v=v) + extra,
        sighting(4) + [{"op": "ss23_panzer", "hex": h, "verso": v, "adv": adv, "us_two": us_two}])
par("300", "Finché il carro è in un edificio spara solo lungo la fila di esagoni davanti a sé. Nel filo spinato paga 2 PM e fa un "
           "controllo d’incidente.", [])
par("296", "Controllo di percezione (+1): se riesce vedi 411, altrimenti 410.", [pc(1, [see("411")], [see("410")])])
par("310", "Controllo di attivazione: se riesce vedi 410, altrimenti 411.", [act(0, [see("410")], [see("411")])])
par("311", "Controllo di percezione (+1): se riesce vedi 411, altrimenti 410.", [pc(1, [see("411")], [see("410")])])
par("298", "Controllo di percezione: se riesce vedi 736. Se fallisce, controllo di attivazione: se riesce 737.",
    [pc(0, [see("736")], [act(0, [see("737")])])])
par("738", "Controllo di percezione (+1): se riesce vedi 736, altrimenti 731.", [pc(1, [see("736")], [see("731")])])
par("294", "Se c’è un edificio fortificato in P15 vedi 242. Altrimenti, se s4 non è avvenuto, controllo di percezione (+1): se riesce "
           "732; se fallisce, controllo di attivazione: se riesce 733. Se s4 è avvenuto, segnalino Evento.",
    [if_({"ss23_fortificato": ["P15"]}, [see("242")], [if_(NOT(S(4)), [pc(1, [see("732")], [act(0, [see("733")])])], [EVENT])])])
par("299", "In un edificio fortificato nessun evento. Se s4 non è avvenuto vedi 732. Altrimenti vedi 242.",
    [if_({"ss23_fortificato": ["P15"]}, NESSUNO, [if_(NOT(S(4)), [see("732")], [see("242")])])])
par("301", "Con un edificio fortificato in P15, segnalino Evento. Altrimenti, se s4 non è avvenuto, controllo di percezione: se riesce "
           "732, altrimenti 733. Se s4 è avvenuto, segnalino Evento.",
    [if_({"ss23_fortificato": ["P15"]}, [EVENT], [if_(NOT(S(4)), [pc(0, [see("732")], [see("733")])], [EVENT])])])
for pid, h, v in (("602", "F19", "F18"), ("643", "R19", "R18"), ("439", "O1", "O2")):
    par(pid, f"[s6] Attiva il Panzer 68 in {h} rivolto verso {v}. Iniziano i Round. Per il rumore del carro, gli americani "
             f"inconsapevoli entro 6 esagoni fanno un controllo di percezione (+2).",
        sighting(6) + [{"op": "ss23_panzer68", "hex": h}])
par("316", "[s6] Attiva il Panzer 68 (dado: 0–2 F19; 3–5 R19; 6–9 O1). Iniziano i Round; riceve 2 turni.",
    sighting(6) + [{"op": "ss23_panzer68", "hex": "", "tab": [["F19"], ["R19"], ["O1"]], "two": [68]}])

# Tracce di cingoli.
TRACCE1 = "Il soldato nota tracce di cingoli in R16 e S16 che si allontanano dalle case. O ci portano?"
par("164", TRACCE1, [{"op": "ss23_tracce", "k": 164, "testo": TRACCE1}])
par("166", "Controllo di percezione (+1): se riesce vedi 164.", [pc(1, [see("164")])])
par("293", "Controllo di percezione: se riesce vedi 164.", [pc(0, [see("164")])])
TRACCE2 = "Il soldato nota tracce di cingoli in Q14 che si allontanano dalla casa. O ci portano?"
par("297", TRACCE2, [{"op": "ss23_tracce", "k": 297, "testo": TRACCE2}])
par("295", "Controllo di percezione (+2): se riesce vedi 297.", [pc(2, [see("297")])])
par("734", "Controllo di percezione: se riesce vedi 297.", [pc(0, [see("297")])])

# ------------------------------------------------------------------ filo spinato ed edifici fortificati
par("731", "Filo spinato: nelle Operazioni si passa normalmente; nei Round costa 1 PM in più e l’americano che entra si butta a terra; "
           "uscendo tira un dado, con 0 si ferisce. Non ha effetto sui tedeschi. Una carica da demolizione lo sgombra.", [])
FILO = "[s5] C’è una fila di filo spinato in {h} (vedi 731). Se s8 non è avvenuto, dado: 0–6 {a}, 7–9 {b}."
for pid, esa, a, b in (("160", ["R12", "S12", "T11", "U12"], "276", "271"), ("161", ["U16", "V15", "W15", "W14", "W13"], "167", "272"),
                       ("162", ["N14", "N13", "O13", "P13"], "169", "270"), ("165", ["N15", "O16", "P16", "Q17"], "626", "273")):
    par(pid, FILO.format(h=", ".join(esa), a=a, b=b),
        sighting(5) + [{"op": "ss23_filo", "hex": esa}, if_(NOT(S(8)), [die((0, 6, [see(a)]), (7, 9, [see(b)]))])])
FORT = "[s8] Attiva i tedeschi 59 e 66 accovacciati in un edificio fortificato in {h}, porta verso {p} (vedi 517). Iniziano i Round.{x} Se s5 non è avvenuto, vedi {f}. Si passa alla Condizione 3."
for pid, h, porta, filo, adv, two, us_two, x in (
        ("167", "V13", "V14", "161", None, [], True, " Gli americani consapevoli che non vanno nel panico ricevono 2 turni."),
        ("169", "O14", "P13/P14", "162", "us", [], True, " Vantaggio americano; gli americani consapevoli ricevono 2 turni."),
        ("270", "O14", "P13/P14", "162", "de", [59], False, " Vantaggio tedesco; il 59 riceve 2 turni."),
        ("271", "T12", "S13", "160", "de", [59], False, " Vantaggio tedesco; il 59 riceve 2 turni."),
        ("272", "V13", "V14", "161", "de", [59], False, " Vantaggio tedesco; il 59 riceve 2 turni."),
        ("273", "P15", "Q16", "162", "de", [59], False, " Vantaggio tedesco; il 59 riceve 2 turni."),
        ("276", "T12", "S13", "160", "us", [], True, " Vantaggio americano; gli americani consapevoli ricevono 2 turni."),
        ("626", "P15", "Q16", "162", "us", [], True, " Vantaggio americano; gli americani consapevoli ricevono 2 turni.")):
    par(pid, FORT.format(h=h, p=porta, x=x, f=filo),
        sighting(8) + [{"op": "ss23_fortificato", "hex": h, "porta": porta, "adv": adv, "two": two, "us_two": us_two},
                       if_(NOT(S(5)), [see(filo)]), cond(3)])
par("517", "Edificio fortificato: muri rinforzati, una sola porta, tutti e quattro i lati sono finestre. Chi è dentro è più difficile "
           "da colpire (−2).", [])
par("163", "Controllo di percezione: se riesce vedi 167, altrimenti 272.", [pc(0, [see("167")], [see("272")])])
par("495", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 276, altrimenti 271.", [EVENT, pc(0, [see("276")], [see("271")])])
par("496", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 167, altrimenti 275.", [EVENT, pc(0, [see("167")], [see("275")])])
par("274", "Dado: dispari 160, pari 162.", pari_dispari([see("160")], [see("162")]))
par("627", "Dado: dispari 162, pari 165.", pari_dispari([see("162")], [see("165")]))
par("428", "Dado: dispari 165, pari 169.", pari_dispari([see("165")], [see("169")]))
par("518", "1. Se s8 non è avvenuto, controllo di percezione: se riesce 276, altrimenti 271.\n2. Se s7 non è avvenuto, controllo di "
           "percezione: se riesce 386, altrimenti 384.\n3. Altrimenti segnalino Evento.",
    [if_(NOT(S(8)), [pc(0, [see("276")], [see("271")])], [if_(NOT(S(7)), [pc(0, [see("386")], [see("384")])], [EVENT])])])

# ------------------------------------------------------------------ razzi illuminanti e fili d’inciampo
par("512", "Colloca un segnalino Evento. Un razzo illuminante tedesco (dado: 0–1 B5; 2 F2; 3 E3; 4–5 D4; 6–7 G4; 8–9 H1) illumina "
           "l’esagono e i sei intorno; chi è illuminato fa un controllo di percezione e se riesce si butta a terra. Se c’è qualcuno "
           "illuminato vedi 629.",
    [EVENT, {"op": "ss23_razzo", "tab": ["B5", "B5", "F2", "E3", "D4", "D4", "G4", "G4", "H1", "H1"], "con": [see("629")]}])
par("516", "Colloca un segnalino Evento. Un razzo illuminante (dado: 0 B9; 1 E8; 2 H9; 3 K6; 4 N9; 5 N6; 6 N3; 7 Q5; 8 P1; 9 si "
           "ritira). Se nessuno è illuminato vedi 278; altrimenti, dopo i controlli di percezione, 625.",
    [EVENT, {"op": "ss23_razzo", "tab": ["B9", "E8", "H9", "K6", "N9", "N6", "N3", "Q5", "P1", ""], "con": [see("625")],
             "senza": [see("278")]}])
par("625", "Dado: 0–6 un illuminato (a caso) subisce un tiro rapido da un tedesco nascosto (lunga gittata, pistola mitragliatrice, "
           "WS +1); 7–9 lo stesso ma mirato. Poi il razzo si spegne e si passa alla Condizione 2.",
    [{"op": "ss23_tiro_nascosto", "arma": "mp", "ws": 1, "gittata": "lunga"}, cond(2)])
par("629", "Dado: 0–6 un illuminato (a caso) subisce un tiro rapido da un tedesco nascosto (media gittata, fucile, WS 0); 7–9 mirato. "
           "Poi il razzo si spegne.", [{"op": "ss23_tiro_nascosto", "arma": "bolt", "ws": 0, "gittata": "media"}])
INCIAMPO = ("Il soldato inciampa in un filo e accende un razzo nell’esagono: l’esagono e i sei intorno sono illuminati fino alla fine "
            "del Round; chi è illuminato fa un controllo di percezione e se riesce si butta a terra.")
par("514", INCIAMPO + " Se s7 non è avvenuto, vedi 622.", [{"op": "ss23_razzo", "hex": "@hex", "con": []}, if_(NOT(S(7)), [see("622")])])
par("275", INCIAMPO + " Se s8 non è avvenuto, vedi 272.", [{"op": "ss23_razzo", "hex": "@hex", "con": []}, if_(NOT(S(8)), [see("272")])])
par("277", INCIAMPO + " Se s8 non è avvenuto, vedi 273.", [{"op": "ss23_razzo", "hex": "@hex", "con": []}, if_(NOT(S(8)), [see("273")])])
par("279", INCIAMPO + " Se s8 non è avvenuto, vedi 270.", [{"op": "ss23_razzo", "hex": "@hex", "con": []}, if_(NOT(S(8)), [see("270")])])
par("511", "C’è un filo d’inciampo: il soldato lo evita e lo disattiva. +1 PV.", [{"op": "vp", "n": 1, "why": "filo d’inciampo disattivato"}])
par("490", "Colloca un segnalino Evento. Chi è nell’esagono fa un controllo di percezione: se riescono tutti 511, altrimenti 279.",
    [EVENT, pc(0, [see("511")], [see("279")])])
par("494", "Colloca un segnalino Evento. Chi è nell’esagono fa un controllo di percezione: se riescono tutti 511, altrimenti 277.",
    [EVENT, pc(0, [see("511")], [see("277")])])
par("491", "Colloca un segnalino Evento. Chi è nell’esagono fa un controllo di percezione: se riescono tutti 623, altrimenti 514.",
    [EVENT, pc(0, [see("623")], [see("514")])])
par("498", "Colloca un segnalino Evento. Controllo di percezione: se riesce e s7 non è avvenuto, 628 (nelle Operazioni) o un controllo "
           "di attivazione (nei Round: 623, altrimenti 628); se fallisce, 514 (nei Round, con s7 non avvenuto, solo se riesce un "
           "controllo di attivazione). Solo la prima volta.",
    [EVENT, {"op": "ss23_tracce", "k": 498, "testo": "—"}, pc(0, [if_(NOT(S(7)), [if_({"in_rounds": True}, [act(0, [see("623")], [see("628")])], [see("628")])])],
                                                                  [if_(S(7), [see("514")], [act(0, [see("514")])])])])
par("628", "Il soldato sente dei rumori vicino all’ingresso della galleria in W6/W7.", [])

# ------------------------------------------------------------------ guardie della galleria (39, 69)
for pid, h39, h69, adv in (("382", "V6", "V9", None), ("384", "X9", "V9", "de"), ("386", "X9", "V9", "us"), ("622", "V6", "X6", "de"),
                           ("623", "V6", "X6", "us")):
    par(pid, f"[s7] Attiva i tedeschi 39 accovacciato in {h39} e 69 accovacciato in {h69}. Iniziano i Round"
             + ("." if adv is None else f", vantaggio {'tedesco' if adv == 'de' else 'americano'}."),
        sighting(7) + [activate([(39, h39), (69, h69)], "crouching", adv=adv)])
par("168", "1. Se s7 non è avvenuto, controllo di attivazione: se riesce 384, altrimenti 386.\n2. Se s5 non è avvenuto, vedi 161.\n"
           "3. Altrimenti segnalino Evento.",
    [if_(NOT(S(7)), [act(0, [see("384")], [see("386")])], [if_(NOT(S(5)), [see("161")], [EVENT])])])
par("493", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 386; se fallisce, controllo di attivazione: se riesce "
           "384.", [EVENT, pc(0, [see("386")], [act(0, [see("384")])])])
par("497", "Controllo di attivazione: se riesce vedi 622, altrimenti 623.", [act(0, [see("622")], [see("623")])])
par("624", "Controllo di attivazione: se riesce vedi 384, altrimenti 386.", [act(0, [see("384")], [see("386")])])
par("314", "Se il 39 o il 69 è stato tolto dalla mappa, controllo di percezione: se riesce 443, altrimenti 444. Se sono entrambi fuori "
           "combattimento, segnalino Evento. Altrimenti nessun evento.",
    [if_({"ss23_tolto": [39, 69]}, [pc(0, [see("443")], [see("444")])], [if_({"ss23_inattivi": [39, 69]}, [EVENT])])])
par("443", "Il 39 e/o il 69 tolti dalla mappa rientrano accovacciati in questo esagono. Iniziano i Round, vantaggio americano.",
    [{"op": "ss23_rientra", "hex": "@hex", "adv": "us"}])
par("444", "Il 39 e/o il 69 tolti dalla mappa rientrano accovacciati in questo esagono. Iniziano i Round, vantaggio tedesco.",
    [{"op": "ss23_rientra", "hex": "@hex", "adv": "de"}])
par("440", "Il 39 e/o il 69 tolti dalla mappa rientrano accovacciati in W8. Iniziano i Round, vantaggio tedesco. Se sono entrambi fuori "
           "combattimento, segnalino Evento.",
    [if_({"ss23_tolto": [39, 69]}, [{"op": "ss23_rientra", "hex": "W8", "adv": "de"}], [if_({"ss23_inattivi": [39, 69]}, [EVENT])])])
par("412", "Controllo di percezione: se riesce vedi 319, altrimenti 440.", [pc(0, [see("319")], [see("440")])])
par("319", "C’è una botola con una scala che scende nella galleria (2 PM per scendere).", [])

# ------------------------------------------------------------------ galleria (come nelle Missioni 20 e 22)
par("245", "Ingresso di una galleria stradale fra le montagne, da W7 a W9: dentro si paga il costo della strada; per il buio da W6 o "
           "W10 si vede un solo esagono dentro.", [{"op": "ss_galleria"}])
par("465", "Nella galleria gli incidenti sono più gravi: −2 al dado dei danni.", [])
mov("307", "Se si muove un mezzo entra in W9. Se si muove un soldato e non vede americani attivi, esce dalla mappa; se ne vede, 802.",
    [if_(VEIC, [enter("W9")], [if_({"ss23_us_vista": True}, NESSUNO, [{"op": "ss23_togli_se_nessuno"}])])])
mov("308", "Un soldato entra nella galleria (da W6 in W7, da W10 in W9). Un mezzo in W10 entra in W11; in W6 entra nella galleria in W7.",
    [if_({"g_hex": "W10"}, [if_(VEIC, [enter("W11")], [enter("W9")])], [enter("W7")])])
mov("317", "Se si muove un soldato entra in W8; un mezzo esce dalla galleria ed entra in W10.", [if_(VEIC, [enter("W10")], [enter("W8")])])

# ------------------------------------------------------------------ movimento (riferimenti rossi)
mov("302", "Con un edificio fortificato in P15 o O14 entra in Q15; con uno in T12 o V13 entra in S15.",
    [if_({"ss23_fortificato": ["P15", "O14"]}, [enter("Q15")], [enter("S15")])])
mov("303", "Con un edificio fortificato in P15 entra in N16; altrimenti in M15.", [if_({"ss23_fortificato": ["P15"]}, [enter("N16")], [enter("M15")])])
mov("304", "Con un edificio fortificato in P15 o O14 entra in Q15; altrimenti in R14.",
    [if_({"ss23_fortificato": ["P15", "O14"]}, [enter("Q15")], [enter("R14")])])
mov("305", "Con un edificio fortificato in V13 entra in X12; altrimenti in V11.", [if_({"ss23_fortificato": ["V13"]}, [enter("X12")], [enter("V11")])])
mov("306", "Se gli americani a sud della riga 6 sono più di quelli a ovest della colonna U, entra in W6; altrimenti in V7.",
    [if_({"ss23_piu": [6, "U"]}, [enter("W6")], [enter("V7")])])
mov("309", "Se gli americani dalla riga 10 in su sono più di quelli a ovest della colonna U, entra in W10; altrimenti in U9.",
    [if_({"ss23_piu": [10, "U"]}, [enter("W10")], [enter("U9")])])
mov("312", "Se gli americani a sud della riga 6 sono più di quelli a ovest della colonna V, entra in Y7; altrimenti in W6.",
    [if_({"ss23_piu": [6, "V"]}, [enter("Y7")], [enter("W6")])])
mov("313", "Con un americano attivo entro 2 esagoni entra in Y9; altrimenti in W10.",
    [if_({"ss23_us_entro": ["@hex", 2, 1]}, [enter("Y9")], [enter("W10")])])
mov("315", "Con 2 o più americani attivi entro 3 esagoni da W8 entra in Q3; altrimenti in P3.",
    [if_({"ss23_us_entro": ["W8", 3, 2]}, [enter("Q3")], [enter("P3")])])
mov("644", "Se si muove un soldato vedi 293; un mezzo entra in S18.", [if_(VEIC, [enter("S18")], [see("293")])])
mov("645", "Se si muove un soldato vedi 168; un mezzo entra in Y14.", [if_(VEIC, [enter("Y14")], [see("168")])])

# ------------------------------------------------------------------ eventi
par("513", "Se qui c’è un bunker distrutto vedi 621; altrimenti segnalino Evento.", [if_({"g_hex": "K10"}, [see("621")], [EVENT])])
par("621", "Trappola esplosiva! Esegui la procedura (se esplode, il bunker distrutto diventa macerie).", [{"op": "boobytrap"}])
par("242", "Trappola esplosiva! Esegui la procedura della trappola esplosiva.", [{"op": "boobytrap"}])
par("212", "Granata difettosa: un soldato (nelle Operazioni un americano, nei Round un dado) fa un controllo di percezione; se fallisce "
           "la granata gli esplode addosso. Solo una volta.", [{"op": "ss_granata_difettosa_c"}])
par("116", "Un tedesco a caso va fuori di testa (2 turni, carica gli americani). Solo una volta.", [{"op": "ss_berserk_de"}])
par("117", "Nei Round un americano a caso (non un comandante) va nel panico e si butta a terra. Solo una volta.", [{"op": "ss_panico_us"}])
par("370", "Se qualcuno è in un esagono di torrente, uno a caso scivola: se fallisce il controllo di percezione perde una granata. Solo "
           "una volta.", [{"op": "ss22_torrente_scivola"}])
par("400", "Un’arma tedesca usata nell’ultimo Round finisce le munizioni.", [{"op": "ammo_out"}])
par("698", "Un’arma tedesca usata nel Round precedente finisce le munizioni.", [{"op": "ammo_out"}])
par("993", "Un americano non prono, a caso, fuori da strade e terreno aperto, cade: controllo di percezione; se fallisce tira i danni "
           "della pistola. Solo una volta.", [{"op": "ss_caduta_21"}])
par("995", "Un tedesco ferito, a caso, diventa incapacitato per la perdita di sangue. Solo una volta.",
    [{"op": "dissanguamento", "chiave": "995", "lato": "de"}])
par("996", "Un tedesco incapacitato, a caso, muore. Solo una volta.", [{"op": "morte_incapacitato", "chiave": "996", "lato": "de"}])
par("997", "Un americano ferito, a caso, diventa incapacitato per la perdita di sangue. Solo una volta.",
    [{"op": "dissanguamento", "chiave": "997", "lato": "us"}])

# ------------------------------------------------------------------ azioni (codice in missione23_ss.gd)
AZ = {
 "730": "SS della pattuglia MM: assalto a chi è nell’esagono; con un americano accanto, carica d’assalto (WS +1 o +2) o granata; se 2 "
        "o più compagni sono fuori combattimento si ritira (e sparisce fuori vista); altrimenti spara e avanza verso l’americano "
        "più vicino.",
 "735": "Capo della pattuglia: assalto a chi è nell’esagono; altrimenti come i suoi uomini (730 o 762).",
 "739": "Primo turno della pattuglia: assalto; granata contro un americano visibile entro 6 esagoni (accovacciato fino a 3, in "
        "piedi a 4–6); altrimenti 730 o 762.",
 "762": "SS della pattuglia NN: assalto; tiro col mitra all’esagono con più americani; carica d’assalto contro un americano accanto; "
        "se più di 2 compagni sono fuori combattimento si ritira; altrimenti 802 o avanza verso l’americano più vicino.",
}
for k, v in AZ.items():
    par(k, v, [], "azione")
