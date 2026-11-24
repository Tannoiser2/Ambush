# -*- coding: utf-8 -*-
"""Silver Star – Missione 24 «Il blues del mulattiere» (Muleskinner Blues; mezze mappe G e H, in alto è ovest, poi mappa F;
ottobre 1943, vicino a Napoli).

La squadra scarica sei muli dalla chiatta e li porta al fronte. Testo inglese: tools/paragrafi_ss_en.json.
Operazioni «ss24_*»: scripts/motore/missione24_ss.gd.
"""
from paragrafi_m1 import pc, act, see, die, if_, S, NOT, ALL, sighting, activate, cond, EVENT

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


NESSUNO = [{"op": "nothing"}]


def pari_dispari(d, pr):
    return [die(*[(i, i, d if i % 2 else pr) for i in range(10)])]


def tabella(*righe):
    return [die(*[(a, b, [see(str(c))] if c else NESSUNO) for a, b, c in righe])]


# ------------------------------------------------------------------ prima parte: mezze mappe G e H
par("320", "Squilla un telefono in questa stanza: il sergente risponde. Il comando ordina di prendere il resto della squadra, andare in "
           "K8 e scaricare i muli dalla chiatta in K7, poi scortarli fino al fronte. Il sergente torna dalla squadra per la strada. I "
           "muli si scaricano solo in K8.", [])
par("179", "[s8] Sulla chiatta ci sono molti muli: l’equipaggio aiuta a scaricarli in K8 (serve un soldato della squadra in K8). Per "
           "ogni mulo un dado: 0–8 scende; 9 scivola dalla passerella (0–2 annega, 3–5 ricade sulla chiatta ferito, 6–9 cade in K8 "
           "ferito e chi è lì fa un controllo di percezione per scansarsi, se fallisce tira i danni della pistola): −1 PV per ogni mulo "
           "perso. Con 6 muli scaricati si parte verso il fronte, fra Y10 e Y14. Al massimo 4 muli per esagono. Vedi 527.",
    sighting(8) + [{"op": "ss24_muli"}])
par("527", "I muli portano munizioni e rifornimenti per il fronte (la squadra non può usarli). Un soldato prende la corda di uno o due "
           "muli nel suo esagono e quelli lo seguono; non entrano nei dirupi. Chi guida i muli spara solo di rapido e non usa bazooka, "
           "BAR e mitragliatrici. Se è ferito o fuori combattimento lascia la corda. Un mulo colpito: 0–3 niente, 4–7 si spaventa e non "
           "si muove per il Round, 8 ferito (2 PM a turno), 9 fuori combattimento (con un altro 9 il carico esplode).", [])
par("175", "Il fronte si è spostato più in fretta del previsto: quando tutta la squadra attiva e i muli sono usciti dal bordo nord fra "
           "Y10 e Y14 vedi 631. −5 PV per ogni mulo attivo lasciato in mappa. Chi esce non rientra. Se il 72 o il 73 sono ancora attivi "
           "quando gli americani sono tutti usciti, +1 PV per ciascuno.", [{"op": "ss24_175"}])
par("631", "[s7] Si toglie la mappa G/H e si passa alla mappa F (in alto è nord): la squadra entra fra A19 e C19 con i muli. Guadi in "
           "K12 e O4, macerie in K10. Si passa alla Condizione 2.",
    sighting(7) + [{"op": "ss24_631"}, cond(2)])
par("170", "Controllo di percezione: se riesce vedi 178.", [pc(0, [see("178")])])
par("178", "[s3] Il soldato trova una cassa di vino e si ferma a bere: chi è nell’esagono perde i turni rimasti. Nelle Operazioni "
           "nessun effetto.", sighting(3))
par("171", "Sulla strada vedi 173; al piano superiore vedi 638.", [if_({"ss24_strada": True}, [see("173")], [see("638")])])
par("173", "Colloca un segnalino Evento. Controllo di attivazione: se riesce vedi 392; se fallisce, controllo di percezione: se riesce 393.",
    [EVENT, act(0, [see("392")], [pc(0, [see("393")])])])
par("177", "Al primo piano: se s3 è avvenuto nessun evento, altrimenti vedi 170. Al secondo piano: dado dispari nessun evento, pari 242.",
    [if_({"ss24_piano": 0}, [if_(NOT(S(3)), [see("170")])], pari_dispari(NESSUNO, [see("242")]))])
par("638", "Trappola esplosiva! Esegui la procedura della trappola esplosiva.", [{"op": "boobytrap"}])
par("242", "Trappola esplosiva! Esegui la procedura della trappola esplosiva.", [{"op": "boobytrap"}])
par("321", "Se s8 è avvenuto nessun evento; altrimenti vedi 636.", [if_(NOT(S(8)), [see("636")])])
par("636", "Colloca un segnalino Evento. Un soldato a caso nell’esagono subisce il tiro di un tedesco nascosto (pistola mitragliatrice, "
           "lunga gittata; con 7–9 mirato). Non iniziano i Round.", [EVENT, {"op": "ss24_tiro_nascosto"}])

# Attivazioni nella prima parte.
for pid, h, adv, reaz in (("401", "V7", "de", None), ("402", "V7", "us", None), ("403", "R8", "de", None), ("404", "R8", "us", None),
                          ("405", "X13", "de", None), ("406", "X13", "us", None), ("408", "O12", "us", "A"), ("409", "O12", "de", "A")):
    par(pid, f"[s0] Attiva i tedeschi 72 e 73 accovacciati in {h}{' nella reazione speciale A' if reaz else ''}. Iniziano i Round, "
             f"vantaggio {'tedesco' if adv == 'de' else 'americano'}.",
        sighting(0) + [activate([(72, h), (73, h)], "crouching", adv=adv, reaction=reaz)])
for pid, h, adv in (("390", "K10", "de"), ("391", "K10", "us"), ("392", "W8", "de"), ("393", "W8", "us"), ("394", "Q9", "de"),
                    ("395", "Q9", "us"), ("398", "G7", "de"), ("399", "G7", "us"), ("324", "L8", "de"), ("427", "S9", "de")):
    par(pid, f"[s1] Attiva i tedeschi 74 e 75 accovacciati in {h}. Iniziano i Round, vantaggio {'tedesco' if adv == 'de' else 'americano'}.",
        sighting(1) + [activate([(74, h), (75, h)], "crouching", adv=adv)])
par("280", "Colloca un segnalino Evento. Controllo di attivazione: se riesce vedi 401.", [EVENT, act(0, [see("401")])])
par("281", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 402; se fallisce, controllo di attivazione: se riesce 401.",
    [EVENT, pc(0, [see("402")], [act(0, [see("401")])])])
par("282", "Colloca un segnalino Evento. Controllo di attivazione: se riesce vedi 403.", [EVENT, act(0, [see("403")])])
par("283", "Colloca un segnalino Evento. Controllo di attivazione: se riesce vedi 403; se fallisce, controllo di percezione: se riesce 404.",
    [EVENT, act(0, [see("403")], [pc(0, [see("404")])])])
par("284", "Colloca un segnalino Evento. Controllo di attivazione: se riesce vedi 409.", [EVENT, act(0, [see("409")])])
par("285", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 408; se fallisce, controllo di attivazione: se riesce 409.",
    [EVENT, pc(0, [see("408")], [act(0, [see("409")])])])
par("286", "Colloca un segnalino Evento. Controllo di attivazione: se riesce vedi 405.", [EVENT, act(0, [see("405")])])
par("287", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 406; se fallisce, controllo di attivazione: se riesce 405.",
    [EVENT, pc(0, [see("406")], [act(0, [see("405")])])])
par("288", "Colloca un segnalino Evento. Controllo di attivazione (+1): se riesce vedi 405; se fallisce, controllo di percezione: se "
           "riesce 406.", [EVENT, act(1, [see("405")], [pc(0, [see("406")])])])
par("407", "Colloca un segnalino Evento. Controllo di attivazione: se riesce vedi 390; se fallisce, controllo di percezione: se riesce "
           "391 (gli americani consapevoli ricevono 2 turni).", [EVENT, act(0, [see("390")], [pc(0, [see("391")])])])
par("521", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 639.", [EVENT, pc(0, [see("639")])])
par("522", "Colloca un segnalino Evento. Controllo di percezione: se riesce vedi 395; se fallisce, controllo di attivazione: se riesce 394.",
    [EVENT, pc(0, [see("395")], [act(0, [see("394")])])])
par("523", "Colloca un segnalino Evento. Controllo di attivazione: se riesce vedi 398; se fallisce, controllo di percezione: se riesce 399.",
    [EVENT, act(0, [see("398")], [pc(0, [see("399")])])])
par("639", "[s2] Il soldato sente il rumore di una battaglia nell’angolo nord-est: la squadra decide di andare a vedere e di portare i "
           "rifornimenti agli uomini laggiù.", sighting(2))

# ------------------------------------------------------------------ controlli evento
par("172", "1. Se s4 non è avvenuto, vedi 396.\n2. Se c’è un americano attivo a est della colonna K, vedi 176.\n3. Se s5 e s6 sono "
           "avvenuti, vedi 637.\n4. Se c’è un mulo incustodito, vedi 529.\n5. Nelle Operazioni nessun evento.\n6. Dado: 0 212; 1 222; "
           "2–3 400; 4–5 993; 6–7 117; 8–9 500.",
    [if_(NOT(S(4)), [see("396")], [if_(ALL({"ss24_est_di_k": True}, NOT(S(5))), [see("176")], [if_(ALL(S(5), S(6)), [see("637")],
        [if_({"ss24_incustoditi": True}, [see("529")], [if_({"in_rounds": True}, tabella((0, 0, 212), (1, 1, 222), (2, 3, 400), (4, 5, 993),
                                                                                        (6, 7, 117), (8, 9, 500)))])])])])])
par("632", "1. Se s9 non è avvenuto, vedi 746.\n2. Altrimenti dado: 0 116; 1 221; 2 117; 3 995; 4 996; 5 997; 6–7 634; 8–9 529.",
    [if_(NOT(S(9)), [see("746")], tabella((0, 0, 116), (1, 1, 221), (2, 2, 117), (3, 3, 995), (4, 4, 996), (5, 5, 997), (6, 7, 634),
                                           (8, 9, 529)))])
par("176", "[s5 e s6] Attiva la squadra del mortaio (tedesco 77: dispari in Y1, pari in R19) e il cecchino 76 in Y8 nella reazione "
           "speciale B, tutti accovacciati. Iniziano i Round; il mortaio e il 76 ricevono 2 turni. Vedi 524.",
    sighting(5, 6) + [pari_dispari([{"op": "ss22_mortaio24", "hex": "Y1"}], [{"op": "ss22_mortaio24", "hex": "R19"}])[0],
                      activate([(76, "Y8")], "crouching", reaction="B", two=[76])])
par("524", "Mortaio col colpo pronto: gittata minima 7 esagoni, ratés 05; prima spara dove il cecchino 76 dà le coordinate, poi sul "
           "segnalino del colpo precedente, poi su chi vede.", [])
par("637", "Si passa alla Condizione 3. Servono 21 PV: +1 per ogni americano uscito dall’angolo nord-est (W1, X1, Y1–Y3), +2 per ogni "
           "mulo uscito da lì, +1 per ogni tedesco attivo rimasto in mappa; −2 per ogni mulo attivo rimasto in mappa. I feriti gravi in "
           "un edificio o portati fuori non costano PV. La missione finisce quando non ci sono più americani attivi in mappa. I tedeschi "
           "72–76 passano alla reazione speciale M (sparano prima ai muli).",
    [cond(3), {"op": "ss24_consegna"}])
par("174", "La galleria è stata distrutta dai tedeschi: gli ingressi W6/W7 e W9/W10 sono crollati, si passa solo per i monti. Nella "
           "Condizione 2 i tedeschi 72–77 passano alla reazione speciale M (sparano prima ai muli).",
    [{"op": "ss24_reazione_m", "g": [72, 73, 74, 75, 76]}])
par("529", "Un mulo incustodito (a caso) si imbizzarrisce: dado 0–5 si sposta di un esagono (nord, nord-est, sud-est, sud, sud-ovest, "
           "nord-ovest), 6 torna indietro di due esagoni, 7–9 non si muove per il Round. Chi è nell’esagono dove arriva fa un controllo "
           "di percezione o tira i danni della pistola.", [{"op": "ss24_scappa"}])
par("500", "Se un soldato è a terra nell’esagono di un mulo attivo, un mulo si spaventa e lo calpesta: chi fallisce il controllo di "
           "percezione tira i danni della pistola. Può succedere più volte.", [{"op": "ss24_calpesta"}])
par("642", "[s9] Il 72 e il 73 (se erano attivi alla fine della Condizione 1 o erano stati tolti) rientrano accovacciati nel primo "
           "esagono libero fra Y16, R19 e O19 (nella Condizione 3 nella reazione speciale M). Iniziano i Round.",
    sighting(9) + [{"op": "ss24_rientra", "tab": ["Y16", "Y16", "Y16"], "primo_libero": ["Y16", "R19", "O19"]}])
par("746", "[s9] Il 72 o il 73, se erano attivi alla fine della Condizione 1 e sono stati tolti, rientrano (dado: 0–3 T19, 4–6 Y16, "
           "7–9 O19). Iniziano i Round.", sighting(9) + [{"op": "ss24_rientra", "tab": ["T19", "Y16", "O19"]}])
par("634", "Un’arma tedesca usata nell’ultimo Round (non il mortaio) finisce le munizioni.", [{"op": "ammo_out"}])
par("289", "Se vede un americano attivo, dado: dispari 824, pari 825. Altrimenti vedi 397.",
    [if_({"ss24_us_visto": True}, pari_dispari([{"op": "ss24_g_par", "n": "824"}], [{"op": "ss24_g_par", "n": "825"}]), [see("397")])], "movimento")
par("397", "Il tedesco esce: −1 PV.", [{"op": "ss22_esce24"}])
par("322", "Se il tedesco si è mosso e gli resta almeno metà dei PM, si accovaccia e fa un tiro rapido; se si è mosso e gliene restano "
           "meno, si accovaccia; se non si è mosso esce dalla mappa (−1 PV, −2 per ogni mulo che porta via).", [], "azione")

# ------------------------------------------------------------------ pattuglia MM (78–81)
par("396", "[s4] Segnalino pattuglia MM (dado: 0 A1; 1 G1; 2–3 O1; 4–5 W10; 6–7 Y17; 8–9 V14). Avanza di un esagono verso l’americano "
           "più vicino per ogni esagono percorso da un americano (nei Round 4 PM). Se il segnalino vede un americano vedi 525; se un "
           "americano vede il segnalino vedi 741. Non si può attaccare.",
    sighting(4) + [{"op": "ss24_pattuglia", "tab": ["A1", "G1", "O1", "O1", "W10", "W10", "Y17", "Y17", "V14", "V14"]}])
par("741", "Gli americani che vedono il segnalino fanno un controllo di percezione: se uno riesce vedi 745 (chi riesce è consapevole e "
           "riceve 2 turni). Se falliscono tutti, controllo di attivazione: se riesce 633, altrimenti 526.",
    [{"op": "ss24_pc_osservatori", "ok": [see("745")], "ko": [act(0, [see("633")], [see("526")])]}])
par("525", "Controllo di attivazione: se riesce vedi 633. Altrimenti gli americani che vedono il segnalino fanno un controllo di "
           "percezione: se uno riesce 745, altrimenti 510.",
    [act(0, [see("633")], [{"op": "ss24_pc_osservatori", "ok": [see("745")], "ko": [see("510")]}])])
par("633", "La pattuglia 78–81 si schiera intorno al segnalino (diagramma col dado). Iniziano i Round, vantaggio tedesco. Vedi 748.",
    [{"op": "ss24_schiera_pattuglia", "adv": "de"}])
par("745", "La pattuglia 78–81 si schiera intorno al segnalino (diagramma col dado). Iniziano i Round, vantaggio americano. Vedi 748.",
    [{"op": "ss24_schiera_pattuglia", "adv": "us"}])
par("748", "I tedeschi della pattuglia non sono automaticamente consapevoli: controllo di percezione (+2 accanto a un americano o a "
           "un mulo nello stesso esagono, +1 entro 3); chi fallisce è inconsapevole nel primo Round.", [])
par("510", "Nessuna attivazione: il segnalino continua ad avanzare.", [])
par("526", "Nessun evento: si continua. Se un americano arriva dove vede il segnalino, di nuovo 741.", [])

# ------------------------------------------------------------------ eventi comuni
par("212", "Granata difettosa: un soldato fa un controllo di percezione; se fallisce la granata gli esplode addosso. Solo una volta.",
    [{"op": "ss_granata_difettosa_c"}])
par("222", "Un soldato a caso ha l’arma col calcio rotto: −1 per colpire. Solo una volta.", [{"op": "ss_calcio_rotto"}])
par("400", "Un’arma tedesca usata nell’ultimo Round finisce le munizioni.", [{"op": "ammo_out"}])
par("116", "Un tedesco a caso va fuori di testa (2 turni, carica gli americani). Solo una volta.", [{"op": "ss_berserk_de"}])
par("221", "Un americano a caso va fuori di testa (2 turni, carica i tedeschi). Solo una volta.", [{"op": "ss_berserk_us"}])
par("117", "Nei Round un americano a caso (non un comandante) va nel panico e si butta a terra. Solo una volta.", [{"op": "ss_panico_us"}])
par("370", "Se qualcuno è in un esagono di torrente, uno a caso scivola: se fallisce il controllo di percezione perde una granata. Solo "
           "una volta.", [{"op": "ss22_torrente_scivola24"}])
par("993", "Un americano non prono cade: se fallisce il controllo di percezione tira i danni della pistola. Solo una volta.",
    [{"op": "ss_caduta_21"}])
par("995", "Un tedesco ferito, a caso, diventa incapacitato. Solo una volta.", [{"op": "dissanguamento", "chiave": "995", "lato": "de"}])
par("996", "Un tedesco incapacitato, a caso, muore. Solo una volta.", [{"op": "morte_incapacitato", "chiave": "996", "lato": "de"}])
par("997", "Un americano ferito, a caso, diventa incapacitato. Solo una volta.", [{"op": "dissanguamento", "chiave": "997", "lato": "us"}])

# ------------------------------------------------------------------ azioni (codice in tedeschi_ss.gd e missione24_ss.gd)
AZ = {
 "740": "Reazione A (72, 73): senza americani in vista toglie la A, striscia verso P12 e passa alla reazione B; altrimenti segue la "
        "colonna della Condizione 1.",
 "749": "Reazione B (72, 73): senza americani in vista né a est del torrente sparisce; altrimenti segue la colonna della Condizione 1.",
 "520": "Reazione B (76): spara al bersaglio più vicino al mortaio (o dà le coordinate); senza serventi del mortaio attivi toglie la B "
        "(nella Condizione 3 passa alla M).",
 "501": "Squadra del mortaio: assalto, tiro contro chi è accanto, granate a 2–6 esagoni, altrimenti prepara o spara il mortaio.",
 "742": "Pattuglia: assalto; mitra sull’esagono con più americani; carica d’assalto; altrimenti spara e avanza (verso i muli "
        "incustoditi se non vede americani).",
 "743": "Pattuglia: assalto; granata all’esagono accanto o entro 3; altrimenti tiro rapido e avanza; prende i muli incustoditi (747).",
 "744": "Capo della pattuglia: assalto; dà turni ai suoi uomini vicino agli americani o ai muli; altrimenti 742.",
 "747": "Prende la corda di due muli e li porta verso U19 o Y17 (il più vicino); lì esce dalla mappa (−1 PV, −2 per ogni mulo).",
 "635": "Granata entro 3 esagoni (accovacciato) o a 4–6 (in piedi); altrimenti 815 con un numero d’azione dispari, 840 con un pari.",
 "848": "Granata entro 3 esagoni (accovacciato) o a 4–6 (in piedi); altrimenti 815.",
 "849": "Granata in piedi al bersaglio più vicino entro 6 esagoni; altrimenti accovacciato.",
 "883": "In piedi, tiri rapidi a quanti più bersagli possibile, prima i più vicini; senza bersagli a terra.",
 "884": "In piedi, miglior tiro con l’arma personale al bersaglio più facile; poi a terra se può.",
 "846": "Con 3 o più bersagli in vista a terra; con 2 vedi 815; con uno in piedi miglior tiro al più vicino.",
 "847": "Entro 8 esagoni da un altro tedesco attivo vedi 869; altrimenti a terra.",
}
for k, v in AZ.items():
    par(k, v, [], "azione")
