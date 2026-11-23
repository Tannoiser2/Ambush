# -*- coding: utf-8 -*-
"""Move Out! – Missione 11 «La nebbia della guerra» (mappa A, Ardenne, dicembre 1944).

Paragrafi del libretto di Move Out! (spazio separato dal gioco base: data/paragrafi_mo.json).
Testo inglese: tools/paragrafi_mo_en.json. Qui: traduzione italiana + ops per il motore.
"""
from paragrafi_m1 import pc, act, see, if_, S, NOT, sighting, activate, cond

P = {}
EVENT = {"op": "event_marker"}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def azione(pid, it):
    """Paragrafi d’azione dei tedeschi: li esegue scripts/motore/tedeschi_mo.gd."""
    par(pid, it, [], "azione")


def para_fuori(pid, s, num, h):
    par(pid, f"[s{s}] Attiva il tedesco {num} in {h}, in piedi. Iniziano i Round. Il tedesco {num} riceve 2 turni in questo Round. "
        "È atterrato fuori mappa: vedi 463 per la qualità dell’atterraggio.",
        sighting(s) + [{"op": "atterraggio_fuori", "g": num, "hex": h}])


par("401", "Metti un segnalino Evento. Effettua un controllo di percezione: se riesce, vedi 404; se fallisce, nessun evento.",
    [EVENT, pc(0, [see("404")])])
par("404", "[s0] La sentinella sente il rumore di motori d’aereo che si avvicinano a bassa quota. Effettua un controllo di percezione: se riesce, vedi 406.",
    sighting(0) + [pc(0, [see("406")])])
par("406", "Il soldato capisce che gli aerei arrivano da est (se fossero bombardieri alleati che tornano a casa, perché volerebbero così bassi?).", [])
par("409", "[s1] Paracadutisti tedeschi sbucano dalle nuvole! Devono prendere il ponte sul fiume (appena fuori mappa a ovest) per le colonne "
    "corazzate di una grande controffensiva. Se la sentinella riesce a entrare nell’edificio in T8, vedi 411; se viene uccisa o "
    "incapacitata prima, vedi 414. Si attivano i tedeschi 29, 39, 42, 43, 45, 47, 48 e 49, uno a caso in ciascuno degli esagoni "
    "A16, A17, A18, A19, B19, C19, D19 ed E19. Poi vedi 422.",
    sighting(1) + [{"op": "lancio_tedeschi", "g": [29, 39, 42, 43, 45, 47, 48, 49],
                    "hex": ["A16", "A17", "A18", "A19", "B19", "C19", "D19", "E19"]}])
par("411", "La sentinella usa il telefono del casello e dà l’allarme al resto della squadra. Guadagni 4 PV. All’inizio del prossimo Round "
    "tutti gli americani sono consapevoli. I soldati entrano in Y8 dopo aver speso 2 azioni fuori mappa (al terzo turno). "
    "Quando entra l’ultimo soldato attivo si passa alla Condizione 3. Vedi 416 per i PV e la fine della missione.",
    [{"op": "vp", "n": 4}, {"op": "sveglia", "azioni": 2, "consapevoli": True}, see("416")])
par("414", "La sentinella non è riuscita a usare il telefono del casello in T8. All’inizio del prossimo Round tutti gli americani sono "
    "inconsapevoli e fanno subito i controlli di consapevolezza; dal terzo Round sono tutti consapevoli. I soldati consapevoli entrano "
    "in Y8 dopo aver speso 4 azioni fuori mappa (al quinto turno). Quando entra l’ultimo soldato attivo si passa alla Condizione 3. "
    "Vedi 416 per i PV e la fine della missione.",
    [{"op": "sveglia", "azioni": 4, "consapevoli": False, "round_consapevoli": 3}, see("416")])
par("416", "Oltre ai PV per l’attivazione e la cattura dei tedeschi, ricevi 2 PV per ogni soldato attivo che esce dal bordo ovest tra "
    "A1 e A19. Gli incapacitati portati fuori dal bordo ovest non costano PV. La missione finisce appena non ci sono più soldati "
    "americani attivi sulla mappa; i tedeschi attivi rimasti non contano.",
    [{"op": "nota", "chiave": "mo416"}])
par("422", "Per ogni paracadutista: deriva un esagono alla volta (423) finché la carta non dice «Atterra», poi si stabilisce "
    "l’atterraggio (424). Quando sono tutti a terra si passa alla Condizione 2 e iniziano i Round, che restano finché c’è un tedesco attivo.",
    [])
par("423", "Deriva: 0–6 un esagono a nord-est, 7–8 a nord, 9 a sud-est (se esce dalla mappa si ritira). Nel nuovo esagono si legge la carta: "
    "con «Atterra» il paracadutista tocca terra.", [])
par("424", "All’atterraggio il terreno decide come va (425). Il paracadutista è a terra, prono, col paracadute addosso (2 azioni per toglierlo).", [])
par("425", "Fiume ghiacciato: 0–8 bene; 9 il ghiaccio cede e annega (si mette un guado). Libero o strada: 0–8 bene; 9 ferito. "
    "Copertura o cespugli: 0–8 bene; 9 nuovo dado, 0–4 ferito, 5–9 incapacitato. Bosco: 0–4 bene; 5–9 nuovo dado: 0–5 niente, "
    "6–8 ferito, 9 nuovo dado (0–4 ferito, 5–9 incapacitato). Vedi 426 per il paracadute.", [])
par("426", "I paracadutisti sono proni e devono togliersi il paracadute prima di fare altro (si ignora l’autoconservazione): "
    "da accovacciati o in piedi, due azioni anche non consecutive.", [])
par("428", "Questo edificio è un casello abbandonato. Dentro ci sono una scrivania e un telefono.", [])
par("431", "Il ghiaccio scricchiola! Tira un dado e togli 1 per ogni soldato nell’esagono: con 0 il ghiaccio cede (si mette un guado). "
    "Ogni soldato nell’esagono fa subito un controllo di percezione: se fallisce cade nel fiume (non si muove più in questo turno, perde "
    "le armi nelle caselle di porto ed è bagnato fino alla fine); se riesce torna prono nell’esagono da cui era entrato e perde il resto "
    "del turno. Uscire dal fiume costa un’azione. Nei guadi si entra normalmente, ma ci si bagna.",
    [{"op": "ghiaccio"}])
par("435", "Tira due dadi: con 0, 9 o 18 un soldato in terreno libero o di copertura cade prono in un cumulo di neve, perde una granata e il "
    "resto del turno (nei Round gli serve un’azione per uscirne; nelle Operazioni perde solo la granata). Chi è prono nella neve è −2 da colpire.",
    [{"op": "neve"}])
par("439", "[s3] Il soldato sente in lontananza il rumore di cannoni contraerei.", sighting(3))
par("441", "L’arma di un soldato si inceppa per il gran freddo. Dado pari: un tedesco a caso; dispari: un americano a caso. "
    "Se è accovacciato o in piedi prova subito a sbloccarla, senza spendere azioni.", [{"op": "inceppa_freddo"}])
par("444", "Un soldato prono si scalda le mani e riceve un solo turno in questo Round, anche se l’iniziativa gliene darebbe due. "
    "Dado pari: un americano; dispari: un tedesco.", [{"op": "mani_fredde"}])
par("447", "Una raffica gelida di vento e neve riduce la visibilità a un esagono per tutto questo Round. Non può capitare in due Round di fila.",
    [{"op": "bufera"}])
par("449", "Un americano caduto nel fiume viene incapacitato dal freddo. Capita una volta sola per missione.", [{"op": "assiderato"}])
par("450", "1. Se l’avvistamento 4 non è avvenuto, vedi 452. 2. Se non è avvenuto il 5, vedi 454. 3. Se non è avvenuto il 6, vedi 456. "
    "4. Se non è avvenuto il 7, vedi 457. 5. Altrimenti vedi 460.",
    [if_(NOT(S(4)), [see("452")], [if_(NOT(S(5)), [see("454")], [if_(NOT(S(6)), [see("456")], [if_(NOT(S(7)), [see("457")], [see("460")])])])])])
para_fuori("452", 4, 28, "W1")
para_fuori("454", 5, 38, "G1")
para_fuori("456", 6, 44, "A8")
para_fuori("457", 7, 46, "B19")
par("460", "Se non ci sono americani attivi a sud della riga 10 (compresa), passa alla Condizione 4; se non ce ne sono a nord della riga 10, "
    "alla Condizione 5; altrimenti alla Condizione 6. In ogni caso si toglie la reazione speciale Z a tutti i tedeschi.",
    [{"op": "condizione_righe", "riga": 10, "sud": 4, "nord": 5, "altrimenti": 6}, {"op": "togli_reazioni", "r": ["Z"]}])
par("463", "Tira un dado per il terreno in cui è atterrato: 0–3 libero o strada, 4–6 copertura o cespugli, 7–8 bosco, 9 fiume ghiacciato; "
    "poi vedi 425. Se non è ucciso né incapacitato, entra in gioco nell’esagono indicato.", [])
azione("466", "Si accovaccia e comincia o continua a togliersi il paracadute. Se l’ha già tolto, vedi 865.")
azione("469", "Si accovaccia e comincia o continua a togliersi il paracadute. Se l’ha già tolto, vedi 863.")
azione("471", "Si accovaccia e comincia o continua a togliersi il paracadute. Se l’ha già tolto, vedi 864.")
azione("476", "Se c’è un tedesco attivo nello stesso esagono o adiacente, si accovaccia e cede un turno a quello che ne ha meno "
       "(a parità, a chi ha l’abilità con le armi più alta); se hanno tutti due turni, vedi 466. Altrimenti vedi 466.")
par("477", "Metti in vigore la reazione speciale Z per questo tedesco.", [{"op": "g_reaction", "r": "Z"}], "azione")
par("485", "Un tedesco ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Una volta sola per missione.",
    [{"op": "dissanguamento", "lato": "de", "chiave": "mo485"}])
par("623", "Un americano ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Una volta sola per missione.",
    [{"op": "dissanguamento", "lato": "us", "chiave": "mo623"}])
par("935", "Un americano incapacitato, scelto a caso, muore per le ferite. Una volta sola per missione.",
    [{"op": "morte_incapacitato", "lato": "us", "chiave": "mo935"}])
