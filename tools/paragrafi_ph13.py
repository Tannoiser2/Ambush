# -*- coding: utf-8 -*-
"""Purple Heart – Missione 13 «Dispersi» (mappa A, poi A + mezza mappa D; Francia del nord, notte del 6 giugno 1944).

I paracadutisti, lanciati lontano dalla zona prevista, finiscono sopra una base navale tedesca e cercano di fare
più danni possibile prima dello sbarco. Testo inglese: tools/paragrafi_ph_programma.json e tools/paragrafi_ph_en.json.
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


CANI = " Vedi 391 per i cani."

# ------------------------------------------------------------------ Condizione 1: sentinella e cani
def sentinella(pid_act, pid_pc, pid_vede, pid_us, h):
    par(pid_act, f"Effettua un controllo di attivazione (+4):\n• se riesce, vedi {pid_us[0]};\n• se fallisce, vedi {pid_pc}.",
        [act(4, [see(pid_us[0])], [see(pid_pc)])])
    par(pid_pc, f"Effettua un controllo di percezione (−2):\n• se riesce, vedi {pid_vede};\n• se fallisce, nessun evento.",
        [pc(-2, [see(pid_vede)])])
    par(pid_vede, f"Il soldato vede la sagoma di una sentinella tedesca in piedi in {h}. Se vuoi cominciare i Round vedi "
                  f"{pid_us[1]}; altrimenti continua a muovere nelle Operazioni.", [{"op": "scelta_attiva", "par": pid_us[1], "testo": f"Attacca la sentinella in {h}"}])
    par(pid_us[0], f"[s3] Una sentinella tedesca e due cani da guardia! Attiva il tedesco 61 in piedi in {h} con i due cani. "
                   f"Iniziano i Round, vantaggio tedesco." + CANI,
        sighting(3) + [activate([(61, h)], "standing", adv="de"), {"op": "cani"}])
    par(pid_us[1], f"[s3] Una sentinella tedesca e due cani da guardia! Attiva il tedesco 61 in piedi in {h} con i due cani. "
                   f"Iniziano i Round, vantaggio americano; i soldati consapevoli che non vanno nel panico ricevono 2 turni in "
                   f"questo Round." + CANI,
        sighting(3) + [activate([(61, h)], "standing", adv="us", us_two=True), {"op": "cani"}])


sentinella("354", "374", "379", ("359", "384"), "Q7")
sentinella("393", "410", "419", ("401", "426"), "S6")
sentinella("435", "446", "452", ("441", "456"), "X4")
for pid, h in (("464", "Q9"), ("468", "T7"), ("474", "X7")):
    par(pid, f"[s3] Una sentinella tedesca e due cani da guardia! Attiva il tedesco 61 in piedi in {h} con i due cani. Iniziano i "
             f"Round, vantaggio tedesco." + CANI, sighting(3) + [activate([(61, h)], "standing", adv="de"), {"op": "cani"}])

par("391", "I cani da guardia. 1. Non hanno segnalini AR: ricevono 2 turni per Round (1 se feriti) e corrono 6 esagoni per turno (4 "
           "se feriti) verso il soldato americano attivo più vicino, senza badare al terreno ma girando attorno agli ostacoli "
           "vietati. 2. Un cane che comincia il turno nell’esagono di un americano attivo lo attacca; se è a 3 esagoni o meno (2 se "
           "ferito) lo raggiunge e attacca subito; altrimenti si avvicina. 3. L’attacco non usa la probabilità di colpire: tira un "
           "dado, 0–5 nessun effetto, 6–7 il soldato va nel panico, 8 è ferito, 9 è incapacitato. Nell’assalto i cani hanno abilità +2 "
           "e non vanno mai nel panico. 4. Un cane continua ad attaccare lo stesso soldato finché uno dei due resta attivo. 5. Due cani "
           "nello stesso esagono con più bersagli ne scelgono uno a caso ciascuno. 6. Chi spara a un cane ha −3 (in questa versione "
           "non si applica). 7. Per granate e cariche i cani sono in piedi.", [])

# ------------------------------------------------------------------ la base navale
par("495", "[s0] Il soldato vede uno spettacolo incredibile: sotto di lui c’è la costa francese e una base navale tedesca! Si passa alla "
           "mappa A con la mezza mappa D sopra (i soldati restano negli stessi esagoni). In U14 c’è un’antenna, in E11 un faro e in "
           "W12 e X12 due batterie costiere rivolte a nord-ovest. Vedi 548 per il faro. Questa base potrebbe fare molti danni allo "
           "sbarco del mattino: senza tempo per pensarci, la squadra decide di seminare più distruzione possibile. Vedi 508 per i PV e "
           "come vincere. Passa alla Condizione 2.",
        sighting(0) + [{"op": "mappa_d"}, see("508"), cond(2)])
par("508", "Ti servono 21 PV per vincere. Oltre ai PV delle attivazioni ci saranno PV bonus rivelati durante il gioco. La missione "
           "finisce, nella Condizione 3 o 4, quando tutti i soldati americani attivi sono usciti da un qualsiasi bordo della mappa; "
           "uscendo si evitano anche i PV persi per gli incapacitati. Nota: perdi 2 PV per ogni soldato incapacitato o ucciso nel lancio.",
        [])
par("548", "Il faro all’inizio è rivolto a ovest. Quando richiesto ruota di 90° in senso orario (da ovest a nord, da nord a est…). Il "
           "fascio è potentissimo: illumina tutti gli esagoni in vista del faro nella direzione in cui punta, e chi è illuminato si vede "
           "da qualsiasi distanza. Il faro si distrugge con un risultato di penetrazione leggera o migliore (+1 per colpirlo; in questa "
           "versione: con un esplosivo nell’esagono).", [])
par("571", "Se un soldato americano attivo è o è stato a nord-ovest del fiume, vedi 589. Altrimenti vedi 604.",
    [if_({"nw_fiume": True}, [see("589")], [see("604")])])
par("589", "[s2] Attiva il tedesco 69 (Panzer IV) in Y15. Iniziano i Round; il tedesco 69 riceve 2 turni in questo Round. Passa "
           "alla Condizione 3.", sighting(2) + [activate([(69, "Y15")], "crouching", two=[69]), cond(3)])
par("604", "Il faro ruota di una posizione in senso orario, se non sta illuminando un americano attivo. Se s9 è avvenuto, vedi 629.",
    [{"op": "faro_ruota"}, if_(S(9), [see("629")])])
par("632", "Il faro ruota di una posizione in senso orario, se non sta illuminando un americano attivo. Poi: se s6 non è avvenuto, "
           "vedi 643; altrimenti vedi 648.", [{"op": "faro_ruota"}, if_(NOT(S(6)), [see("643")], [see("648")])])
par("648", "Il faro ruota di una posizione in senso orario, se non sta illuminando un americano attivo. Poi tira un dado:\n0: un "
           "esplosivo piazzato (a caso) salta.\n1–2: un edificio accanto a un edificio in fiamme prende fuoco ed esplode (ricevi i PV "
           "dell’edificio).\n3–4: vedi 443 (il ritorno del tedesco 61 in E11 non è gestito).\n5–6: vedi 649.\n7–9: se ci sono incendi "
           "entro 2 esagoni dai serbatoi, vedi 725.",
    [{"op": "faro_ruota"}, die((0, 0, [{"op": "esplosivo_us_casuale"}]), (1, 2, [{"op": "incendio_adiacente"}]),
                               (3, 4, [see("443")]), (5, 6, [see("649")]), (7, 9, [{"op": "solo_testo", "testo": "Nessun incendio vicino ai serbatoi."}]))])
par("629", "Se è stato piazzato un esplosivo, tira i dadi percentuali: con 75 o più uno salta in anticipo (a caso se più d’uno).",
    [{"op": "esplosione_prematura"}])
par("634", "Tira un dado:\n0–5: vedi 648.\n6: vedi 461.\n7: vedi 623.\n8: vedi 641.\n9: vedi 646.",
    [die((0, 5, [see("648")]), (6, 6, [see("461")]), (7, 7, [see("623")]), (8, 8, [see("641")]), (9, 9, [see("646")]))])
par("646", "Tira un dado: 0–4 vedi 655; 5–9 vedi 689.", [die((0, 4, [see("655")]), (5, 9, [see("689")]))])
par("641", "Un soldato tedesco a caso, non in un mezzo, si arrende. Può accadere più volte.", [{"op": "arresa_casuale"}])
par("649", "Se un cane da guardia era stato incapacitato, uno si riprende (ferito) e riparte verso l’americano attivo più vicino. Una "
           "volta sola per missione. Se nessun cane può riprendersi, vedi 485.", [{"op": "cane_recupera"}])
par("655", "Un soldato tedesco a caso va fuori di testa e carica gli americani… (in questa versione l’evento non ha effetti).",
    [{"op": "solo_testo"}])
par("689", "Un soldato americano a caso (non un comandante) va fuori di testa e carica i tedeschi… (in questa versione l’evento non ha "
           "effetti).", [{"op": "solo_testo"}])

# ------------------------------------------------------------------ attivazioni della guarnigione
def guarnigione(pid, s, coppie, testo_h):
    par(pid, f"[s{s}] Attiva {testo_h}, accovacciati. Iniziano i Round. Se s5 è avvenuto (o si è già sparato), questi tedeschi "
             f"hanno il vantaggio e 2 turni in questo Round; altrimenti i soldati americani consapevoli che non vanno nel panico "
             f"ricevono 2 turni.",
        sighting(s) + [if_(S(5), [activate(coppie, "crouching", adv="de", two=[n for n, _ in coppie])],
                           [activate(coppie, "crouching", adv="us", us_two=True)])])


guarnigione("517", 7, [(65, "M13")], "il tedesco 65 in M13")
guarnigione("534", 4, [(63, "S15"), (64, "S15")], "i tedeschi 63 e 64 in S15 (al piano di sopra)")
guarnigione("540", 8, [(62, "G12"), (66, "G12")], "i tedeschi 62 e 66 in G12")
guarnigione("578", 8, [(62, "P14"), (66, "P14")], "i tedeschi 62 e 66 in P14")

# ------------------------------------------------------------------ deposito, cannoni, motosiluranti
par("607", "Se questo edificio (o un esagono collegato) è stato colpito in qualsiasi modo, nessun avvistamento. Altrimenti vedi 526.",
    [see("526")])
par("526", "[s9] Tutto l’edificio è un deposito della marina! Centinaia di rifornimenti, tra cui esplosivi al plastico a tempo che "
           "distruggono tutto in un esagono: perfetti per far saltare la base! Ricevi 2 PV per ogni esagono di edificio distrutto e "
           "4 PV per ogni cannone costiero distrutto. Ogni esplosivo occupa una casella di porto.\n1. Nei Round piazzarlo costa "
           "un’azione: all’inizio del Round seguente si gira sul lato 1, all’inizio del secondo Round salta.\n2. Nelle Operazioni "
           "si piazza da solo e salta quando decidi tu (qui: quando la squadra si è allontanata).\n3. In un edificio lascia un "
           "Edificio in fiamme.\n4. Chi è nell’esagono muore; chi è negli esagoni adiacenti subisce i danni della colonna Granata al "
           "chiuso.\n5. Se il deposito salta o è colpito da cannone, bazooka, granata o carica, vedi 616.\n6. Un incendio fa da "
           "sfondo: chi ha la vista su un edificio in fiamme vede i bersagli lungo quella linea.",
        sighting(9) + [{"op": "deposito_navale"}])
par("616", "Tutto il deposito esplode! Chi è negli esagoni del deposito muore; chi è negli esagoni adiacenti è incapacitato; chi è "
           "entro 2 esagoni è colpito come da un tiro di pistola. Un segnalino Edificio in fiamme in ogni esagono del deposito.",
    [{"op": "deposito_esplode"}])
par("612", "I cannoni costieri sono così massicci che solo un colpo diretto da 406 mm potrebbe distruggerli.", [])
par("554", "La porta del cannone costiero in W12 è aperta: hai sorpreso la guarnigione! Se un soldato entra nel bunker, vedi 672.",
    [{"op": "porta_cannone", "hex": "W12"}])
par("682", "La porta del cannone costiero in X12 è aperta: hai sorpreso la guarnigione! Se un soldato entra nel bunker, vedi 672.",
    [{"op": "porta_cannone", "hex": "X12"}])
par("672", "Il soldato vede un enorme cannone navale da 406 mm e un deposito di polvere e proiettili. Con una carica da demolizione "
           "piazzata nel deposito (due azioni nei Round, automatica nelle Operazioni) cannone e bunker saltano: chi è nell’esagono "
           "muore, chi è negli esagoni adiacenti è incapacitato.", [{"op": "magazzino"}])
par("725", "I due serbatoi esplodono con una forza tremenda! Tutti entro 6 esagoni cadono proni e perdono i turni del Round; chi è "
           "entro 2 esagoni subisce i danni della colonna Granata al chiuso; gli edifici entro 2 esagoni crollano. Da ora ogni esagono "
           "in vista dei serbatoi è illuminato dall’incendio.", [{"op": "serbatoi"}])
par("643", "[s6] I motori rombano e due motosiluranti escono dalla base dei sottomarini! Attiva il tedesco 67 in G15 e il tedesco "
           "68 in F15, rivolti a nord-ovest. Iniziano i Round. Vedi 654.", sighting(6) + [{"op": "attiva_eboat"}])
par("662", "[s6] Il soldato vede due motosiluranti che si preparano a fuggire! Se un soldato americano in questo esagono ha un’azione "
           "da spendere, spara una raffica, punta l’arma alla testa del capitano più vicino e grida «Halt!»: la motosilurante in G15 "
           "si arrende ed è affondata (+5 PV); quella in F15 fugge (si attiva solo il tedesco 68, vantaggio americano). Altrimenti "
           "vedi subito 643.", sighting(6) + [{"op": "eboat_662"}])
par("654", "Le motosiluranti hanno siluri (solo contro le navi alleate) e una mitragliatrice pesante e una leggera che sparano in "
           "tutte le direzioni. Servono 2 punti equipaggio per muoversi o per un tiro mirato, 1 per un tiro rapido; non fanno "
           "controlli d’incidente. Si possono distruggere anche con una carica da demolizione lanciata a bordo (−3). Affondata: "
           "+10 PV.", [])

# ------------------------------------------------------------------ Condizione 3: auto e scialuppa
par("702", "Tira un dado: 0–4 vedi 713; 5–9 vedi 718.", [die((0, 4, [see("713")]), (5, 9, [see("718")]))])
par("713", "[s1] Il soldato vede un’auto comando abbandonata in I14. Se un soldato entra nell’esagono, vedi 897.",
    sighting(1) + [{"op": "auto_comando"}])
par("897", "Le chiavi sono nel cruscotto e c’è benzina in abbondanza.", [])
par("718", "[s1] Il soldato vede una scialuppa rovesciata in I14: potrebbe essere la via verso la flotta! Ci sta tutta la squadra; si "
           "vara da una spiaggia o da una banchina, si rema di 2 esagoni per turno. Chi è a bordo è accovacciato in copertura. Uscendo "
           "dal bordo ovest in scialuppa guadagni 10 PV. (In questa versione la scialuppa si trova già sulla spiaggia in I18.)",
    sighting(1) + [{"op": "scialuppa"}])

# ------------------------------------------------------------------ eventi generici
par("404", "Un soldato americano incapacitato a caso muore per le ferite. Una volta sola per missione.",
    [{"op": "morte_incapacitato", "lato": "us", "chiave": "ph404"}])
par("443", "Un’arma tedesca usata nel Round precedente ha finito le munizioni (a caso se più d’una).", [{"op": "ammo_out"}])
par("447", "Un soldato americano a caso con IN 3 o meno va nel panico e cade prono. Una volta sola per missione.", [{"op": "panico_mo"}])
par("457", "Se un soldato americano ha una granata, una granata esplode per sbaglio (vedi la procedura delle granate difettose).",
    [{"op": "grenade_accident"}])
par("461", "Un tedesco incapacitato a caso muore per le ferite. Una volta sola per missione.",
    [{"op": "morte_incapacitato", "lato": "de", "chiave": "ph461"}])
par("485", "Un tedesco ferito a caso diventa incapacitato per la perdita di sangue. Una volta sola per missione.",
    [{"op": "dissanguamento", "lato": "de", "chiave": "ph485"}])
par("623", "Un soldato americano ferito a caso diventa incapacitato per la perdita di sangue. Una volta sola per missione.",
    [{"op": "dissanguamento", "lato": "us", "chiave": "ph623"}])
par("489", "[s5] Il tedesco aziona un interruttore e in lontananza suona una sirena. Reazione speciale A per questo tedesco.",
    sighting(5) + [{"op": "g_reaction", "r": "A"}])

# ------------------------------------------------------------------ movimenti
mov("478", "Se questo tedesco ha un’azione da spendere e s5 non è avvenuto, vedi 489. Altrimenti esegue 801.",
    [if_(NOT(S(5)), [see("489")])])
mov("484", "Il motore del carro tossisce e scoppietta entrando in I10.", [])
mov("546", "Il carro resta senza benzina: non si muove più, ma spara normalmente.", [{"op": "solo_testo", "testo": "Il carro non si muove più."}])
mov("617", "Passa alla Condizione 4.", [cond(4)])
mov("625", "Se i serbatoi in J13 e K14 sono intatti entra in I13; altrimenti entra in I12.", [enter("I13")])
mov("678", "Se si muove il Panzer IV entra in Q15; altrimenti entra in R13.",
    [if_({"vehicle_moving": True}, [enter("Q15")], [enter("R13")])])
mov("688", "Se si muove il Panzer IV entra in Q15; altrimenti entra in R15.",
    [if_({"vehicle_moving": True}, [enter("Q15")], [enter("R15")])])
mov("695", "Se si muove il tedesco 67 entra in S18; altrimenti entra in T17.",
    [if_({"g_num": 67}, [enter("S18")], [enter("T17")])])

# ------------------------------------------------------------------ azioni della sentinella, della guarnigione e dei mezzi
az("403", "Se i cani sono attivi, si accovaccia e fa il miglior tiro al bersaglio più vicino non nell’esagono di un cane. Se i cani sono "
          "fuori combattimento e non vede bersagli, esce dalla mappa; se ne vede, corre via e sparisce nel primo esagono fuori vista.")
az("411", "Se i cani sono attivi, si accovaccia e spara di rapido a quanti più bersagli può (non negli esagoni dei cani). Se i cani sono "
          "fuori combattimento e non vede bersagli, esce dalla mappa; se ne vede, corre via e sparisce fuori vista, altrimenti cade prono.")
az("428", "Se i cani sono attivi vedi 840. Se sono fuori combattimento e non vede bersagli, esce dalla mappa; se ne vede, corre e cade "
          "prono nell’ultimo esagono.")
az("573", "Con un bersaglio in vista entro 6 esagoni e una granata, si alza e la lancia; anche senza vista, se un bersaglio è entro 6 "
          "esagoni (−3). Senza granate ma con un bersaglio in vista esegue 801; altrimenti si accovaccia.")
az("711", "Con 2 o più americani attivi nel suo esagono si arrende; altrimenti si alza e fa il miglior tiro al più vicino, poi prono se "
          "può.")
az("869", "Con una granata e un bersaglio entro tre esagoni si accovaccia e la lancia al più vicino, poi prono se può; altrimenti esegue "
          "801.")
az("877", "Con un bersaglio in vista esegue 815. Se non vede bersagli ma uno è entro 6 esagoni e ha una granata, si alza e la lancia "
          "(−3); poi prono se può. Altrimenti prono.")
az("883", "Con un bersaglio in vista si alza e spara di rapido con l’arma personale al più vicino e al secondo più vicino; altrimenti "
          "prono.")
az("884", "Si alza e fa il miglior tiro con l’arma personale al bersaglio più facile, poi prono se può.")
az("895", "Se non vede bersagli e l’antenna è intatta, trasmette al comando che l’invasione è cominciata: perdi 10 PV (una volta "
          "sola). Altrimenti non fa nulla.")
az("874", "Si arrende.")
az("826", "Se il mezzo è già stato bersagliato va veloce, altrimenti lento.")
for pid, it in (("733", "Avanza lento. Tiro mirato con la mitragliatrice pesante al più vicino, tiro rapido con la leggera al secondo."),
                ("736", "Avanza lento. Tiri rapidi con la mitragliatrice leggera e con la pesante."),
                ("747", "Avanza veloce. Tiro mirato con la pesante al secondo più vicino, tiro rapido con la leggera al più vicino."),
                ("758", "Avanza veloce."), ("763", "Avanza lento. Tiro mirato con la mitragliatrice leggera al più vicino."),
                ("776", "Avanza veloce. Tiro mirato con la mitragliatrice pesante al bersaglio più facile."),
                ("847", "Avanza lento."), ("849", "Avanza veloce."),
                ("873", "Si arrende (la motosilurante si arena sulla spiaggia più vicina).")):
    az(pid, it)
