# -*- coding: utf-8 -*-
"""Purple Heart – Missione 16 «In guardia» (mappa C, Valle del Rodano, 3 settembre 1944).

La squadra sorveglia di notte il deposito avanzato di carburante; i commando tedeschi arrivano dal fiume
in battelli d’assalto o dai bordi della mappa, con esplosivi a tempo.
Testo inglese: tools/paragrafi_ph_en.json (OCR del libretto, esagoni ricontrollati).
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


def dopo(p):
    return {"op": "al_prossimo_round", "p": p}


INFO = " Vedi 432 per il movimento dei battelli, 628 per le condizioni di vittoria e 414 per il combattimento nel deposito."


# ------------------------------------------------------------------ controlli e avvistamenti
def ev_pc(pid, mod, ok, ko=None):
    m = f" ({mod:+d})" if mod else ""
    if ko:
        it = f"Colloca un segnalino Evento. Effettua un controllo di percezione{m}:\n• se riesce, vedi {ok};\n• se fallisce, vedi {ko}."
        par(pid, it, [EVENT, pc(mod, [see(ok)], [see(ko)])])
    else:
        it = f"Colloca un segnalino Evento. Effettua un controllo di percezione{m}:\n• se riesce, vedi {ok};\n• se fallisce, nessun evento."
        par(pid, it, [EVENT, pc(mod, [see(ok)])])


ev_pc("329", -2, "338")
ev_pc("345", -2, "349")
ev_pc("357", -2, "365")
ev_pc("396", -1, "407")
ev_pc("436", -1, "451")
ev_pc("470", 0, "475")
ev_pc("488", 0, "490")
ev_pc("723", -2, "732", "740")
ev_pc("760", -2, "768", "775")
ev_pc("790", -2, "793", "796")
ev_pc("844", -2, "845", "851")
ev_pc("879", -2, "887", "891")

par("338", "[s0] Il soldato sente un raschiare metallico che viene dal fiume. Passa alla Condizione 2.", sighting(0) + [cond(2)])
par("349", "[s0] Il soldato sente un fruscio verso nord. Passa alla Condizione 3.", sighting(0) + [cond(3)])
par("365", "[s0] Il soldato sente un fruscio verso ovest. Passa alla Condizione 3.", sighting(0) + [cond(3)])
par("385", "[s2] Questa bella locanda di campagna francese fa sognare al soldato il Wisconsin del nord.", sighting(2))
par("366", "Passa alla Condizione 5.", [cond(5)])
par("615", "Passa alla Condizione 4.", [cond(4)])

# ------------------------------------------------------------------ attivazioni dal fiume (battelli d’assalto)
def dal_fiume(pid, h, dopo_p):
    par(pid, f"[s7] Commando tedeschi all’attacco del deposito! Attiva i tedeschi 20, 21, 28 e 29 in un battello d’assalto in {h}. "
             f"Iniziano i Round, vantaggio tedesco; questi tedeschi ricevono 2 turni in questo Round. All’inizio del secondo turno del "
             f"Round 1 vedi {dopo_p} (qui: all’inizio del Round successivo)." + INFO,
        sighting(7) + [activate([(20, h), (21, h), (28, h), (29, h)], "crouching", adv="de", two=[20, 21, 28, 29]),
                       {"op": "imbarca", "g": [20, 21, 28, 29], "hex": h}, dopo(dopo_p)])


def secondo_battello(pid, h):
    par(pid, f"[s5] Attiva i tedeschi 36, 37, 38 e 39 in un battello d’assalto in {h}. Iniziano i Round, vantaggio tedesco; questi "
             f"tedeschi ricevono un solo turno in questo Round. Vedi 628 per le condizioni di vittoria.",
        sighting(5) + [activate([(36, h), (37, h), (38, h), (39, h)], "crouching", adv="de"),
                       {"op": "imbarca", "g": [36, 37, 38, 39], "hex": h}])


dal_fiume("407", "L1", "421")
secondo_battello("421", "L1")
dal_fiume("451", "N5", "460")
secondo_battello("460", "N5")
dal_fiume("475", "Q8", "481")
secondo_battello("481", "Q8")

for pid, extra in (("490", ""), ("501", " (Il soldato americano J in V12 con la carta US 04 non è disponibile in questa versione.)")):
    adv = "de" if pid == "490" else "us"
    par(pid, "[s5 e s7] Commando tedeschi all’attacco del deposito! Attiva i tedeschi 20, 21, 28 e 29 in X15 e i tedeschi 36, 37, 38 e 39 "
             "in U12, accovacciati. Colloca un battello d’assalto vuoto in U11 e uno in X14. Iniziano i Round, vantaggio "
             + ("tedesco." if adv == "de" else "americano.") + INFO + extra,
        sighting(5, 7) + [activate([(20, "X15"), (21, "X15"), (28, "X15"), (29, "X15"), (36, "U12"), (37, "U12"), (38, "U12"), (39, "U12")],
                                   "crouching", adv=adv),
                          {"op": "imbarca", "g": [], "hex": "U11"}, {"op": "imbarca", "g": [], "hex": "X14"}])


# ------------------------------------------------------------------ attivazioni dai bordi
def dal_bordo(pid, h, adv, dopo_p):
    if adv == "us":
        it = (f"[s7] Commando tedeschi all’attacco del deposito! Attiva i tedeschi 20, 21 e 36 in {h}, in piedi. Iniziano i Round, "
              f"vantaggio americano. I soldati americani che vedono {h} sono automaticamente consapevoli in questo turno. All’inizio del "
              f"Round successivo, prima del controllo degli eventi casuali, vedi {dopo_p}. Vedi 414 per il combattimento nel deposito.")
        ops = [activate([(20, h), (21, h), (36, h)], "standing", adv="us"), {"op": "consapevoli_vede", "hex": h}]
    else:
        it = (f"[s7] Commando tedeschi all’attacco del deposito! Attiva i tedeschi 20, 21 e 36 in {h}, in piedi. Iniziano i Round, "
              f"vantaggio tedesco; questi tedeschi ricevono 2 turni in questo Round. All’inizio del Round successivo, prima del controllo "
              f"degli eventi casuali, vedi {dopo_p}. Vedi 414 per il combattimento nel deposito.")
        ops = [activate([(20, h), (21, h), (36, h)], "standing", adv="de", two=[20, 21, 36])]
    par(pid, it, sighting(7) + ops + [dopo(dopo_p)])


def rinforzi(pid, h):
    par(pid, f"[s5] Attiva i tedeschi 28, 29, 37, 38 e 39 in {h}, in piedi. Iniziano i Round. Vedi 628 per le condizioni di vittoria.",
        sighting(5) + [activate([(28, h), (29, h), (37, h), (38, h), (39, h)], "standing")])


dal_bordo("732", "A3", "us", "754"); dal_bordo("740", "A3", "de", "754"); rinforzi("754", "A17")
dal_bordo("768", "A10", "us", "781"); dal_bordo("775", "A10", "de", "781"); rinforzi("781", "A18")
dal_bordo("793", "A19", "us", "838"); dal_bordo("796", "A19", "de", "838"); rinforzi("838", "H19")
dal_bordo("845", "I19", "us", "870"); dal_bordo("851", "I19", "de", "870"); rinforzi("870", "R19")
dal_bordo("887", "M19", "us", "894"); dal_bordo("891", "M19", "de", "894"); rinforzi("894", "R19")

# ------------------------------------------------------------------ regole
par("414", "Combattimento nel deposito.\n1. I soldati americani non possono sparare di proposito in un esagono del deposito senza tedeschi "
           "attivi né tentare di farlo saltare. Se un tiro contro un esagono del deposito manca, tira un dado: con 0–3 il carburante "
           "esplode. Colloca un segnalino Edificio in fiamme: chi è nell’esagono muore; chi è negli esagoni adiacenti effettua un controllo "
           "di percezione (se riesce si butta a terra) e poi subisce i danni della colonna Granata al chiuso. Qualsiasi esplosione in un "
           "esagono del deposito (granata, carica da demolizione…) fa esplodere il carburante.\n2. Un tedesco che deve entrare in un "
           "esagono del deposito in fiamme effettua un controllo di percezione: se riesce passa, se fallisce muore (in questa versione "
           "non si applica).", [])
par("432", "Battelli d’assalto. Lento: 4 esagoni di fiume per turno; veloce: 6 (servono 4 tedeschi con turni). Dove va lo decidono i "
           "riferimenti di movimento delle carte Condizione; con un solo tedesco a bordo non si muove, e non si muove più di una volta per "
           "turno. Chi sbarca va prono nell’esagono indicato e finisce il turno. Dal battello i tedeschi sparano con −2 e, se colpiti, "
           "contano come accovacciati in terreno libero (in questa versione i colpi al battello stesso non sono gestiti).", [])
par("619", "Se questo tedesco si è già mosso in questo turno, esegue 840. Altrimenti si accovaccia e piazza l’esplosivo (un’azione): "
           "colloca un segnalino Esplosivo con il lato 2 in alto. Per disinnescarlo servono due azioni, anche di soldati diversi: la "
           "prima lo gira sul lato 1, la seconda lo toglie. Ogni esplosivo disinnescato vale 2 PV bonus. IMPORTANTE: ignora le istruzioni "
           "precedenti sulla fine della missione: finisce quando non ci sono tedeschi attivi in mappa e tutti gli esplosivi sono stati "
           "disinnescati o sono saltati.", [{"op": "pianta_esplosivo"}])
par("628", "I commando vogliono il deposito. Ti servono 24 PV per vincere. Oltre ai PV delle attivazioni ricevi 1 PV per ogni esagono del "
           "deposito intatto alla fine e perdi 2 PV per ogni esagono distrutto. Altri PV saranno rivelati. La missione finisce quando non ci "
           "sono tedeschi attivi in mappa; gli incapacitati americani non costano PV.", [])

# ------------------------------------------------------------------ eventi
par("533", "Se nessun tedesco è entrato nel deposito, nessun evento. Se ci sono entrati ma ora ce ne sono 2 o meno attivi, vedi 638 e "
           "passa alla Condizione 5. Altrimenti nessun evento.",
    [if_({"deposito_entrati": True}, [if_({"deposito_attivi_max": 2}, [see("638"), cond(5)])])])
par("591", "Se nessun tedesco è entrato nel deposito, nessun evento. Se ci sono entrati ma ora ce ne sono 2 o meno attivi, vedi 638 e "
           "passa alla Condizione 4. Altrimenti nessun evento.",
    [if_({"deposito_entrati": True}, [if_({"deposito_attivi_max": 2}, [see("638"), cond(4)])])])
par("638", "Se in un edificio c’è un esplosivo sul lato 1 con un soldato americano attivo, vedi 660. Se in un edificio c’è un esplosivo sul "
           "lato 2, vedi 651. Altrimenti vedi 639.",
    [if_({"esplosivo_mezzo_us": True}, [see("660")], [if_({"esplosivo_intero_edificio": True}, [see("651")], [see("639")])])])
par("639", "Tira un dado:\n0–1: vedi 447.\n2–3: vedi 443.\n4–5: vedi 485.\n6: vedi 461.\n7: vedi 623.\n8–9: nessun evento.",
    [die((0, 1, [see("447")]), (2, 3, [see("443")]), (4, 5, [see("485")]), (6, 6, [see("461")]), (7, 7, [see("623")]), (8, 9, []))])
par("651", "Un esplosivo salta per la spoletta a tempo! Se ce n’è più d’uno, scegli a caso. Togli il segnalino e colloca un Edificio in "
           "fiamme: chi è nell’esagono muore (tedeschi compresi); chi è negli esagoni adiacenti effettua un controllo di percezione (se riesce "
           "si butta a terra) e subisce i danni della colonna Granata al chiuso. Può accadere più volte.", [{"op": "esplosivo_a_tempo"}])
par("660", "Il soldato con la percezione più alta nell’esagono con l’esplosivo effettua subito un controllo di percezione:\n• se riesce, "
           "vedi 669;\n• se fallisce, vedi 679.", [{"op": "disinnesco_pc"}])
par("669", "Il soldato disinnesca l’esplosivo un attimo prima che scatti! Togli il segnalino e guadagni 2 PV.", [])
par("679", "L’esplosivo salta! Togli il segnalino e colloca un Edificio in fiamme: chi è nell’esagono muore; chi è negli esagoni adiacenti "
           "effettua un controllo di percezione (se riesce si butta a terra) e subisce i danni della colonna Granata al chiuso.", [])
par("443", "Un’arma tedesca usata nel Round precedente ha finito le munizioni (a caso se più d’una).", [{"op": "ammo_out"}])
par("447", "Un soldato americano a caso con IN 3 o meno va nel panico e cade prono: si riprende solo quando un altro soldato entra nel suo "
           "esagono e spende un’azione. Una volta sola per missione.", [{"op": "panico_mo"}])
par("461", "Un tedesco incapacitato a caso muore per le ferite. Una volta sola per missione.",
    [{"op": "morte_incapacitato", "lato": "de", "chiave": "ph461"}])
par("485", "Un tedesco ferito a caso diventa incapacitato per la perdita di sangue. Una volta sola per missione.",
    [{"op": "dissanguamento", "lato": "de", "chiave": "ph485"}])
par("623", "Un soldato americano ferito a caso diventa incapacitato per la perdita di sangue. Una volta sola per missione.",
    [{"op": "dissanguamento", "lato": "us", "chiave": "ph623"}])

# ------------------------------------------------------------------ telefono e camion
par("370", "Squilla un telefono in J8. Se entri in J8 durante questa Condizione e rispondi, vedi 381.", [{"op": "telefono"}])
par("381", "[s8] Il comando di divisione avverte che una colonna di camion sta arrivando a prendere il carburante per l’offensiva di domani: "
           "proteggila. «Li sento arrivare, signore. Passo e chiudo.» Vedi subito 717.", sighting(8) + [see("717")])
par("717", "[s6] Un camion americano entra in mappa in A3 (carta US 05): deve fermarsi in U14, caricare il carburante e uscire da A3 (+2 PV; "
           "−2 PV se messo fuori uso). In questa versione i camion non sono ancora gestiti.", sighting(6) + [{"op": "camion"}])

# ------------------------------------------------------------------ movimenti: battelli
def fiume(pid, sbarco, barca, solo=None, nota=""):
    it = f"Se il soldato deve sbarcare, entra in {sbarco}; altrimenti il battello d’assalto entra in {barca}." + nota
    mov(pid, it, [{"op": "barca", "sbarco": sbarco, "barca": barca, "solo": solo or []}])


for pid, a, b in (("371", "L5", "M5"), ("376", "M6", "N5"), ("382", "M6", "N6"), ("389", "N7", "O7"), ("392", "O8", "P7"),
                  ("399", "P8", "Q8"), ("406", "Q9", "R8"), ("416", "R9", "S9"), ("420", "R9", "S10"), ("427", "S11", "T10"),
                  ("434", "T11", "U11"), ("439", "V12", "W12"), ("449", "V12", "X12"), ("458", "W13", "X13"), ("466", "W14", "X14"),
                  ("472", "K5", "L3"), ("480", "L5", "L4"), ("487", "M6", "M5"), ("496", "M6", "N5"), ("502", "N7", "N6"),
                  ("510", "O8", "O7"), ("516", "P8", "P7"), ("524", "Q9", "Q8"), ("528", "R9", "R8"), ("536", "R9", "S9"),
                  ("545", "S11", "S10"), ("552", "U10", "T10"), ("560", "V10", "U11"), ("567", "W11", "V11"), ("572", "X11", "W12"),
                  ("579", "Y13", "X12"), ("584", "Y14", "X13")):
    fiume(pid, a, b)
mov("561", "Se si muove uno dei tedeschi 36–39, o se questo tedesco deve sbarcare, vedi 568. Altrimenti il battello entra in V11.",
    [{"op": "barca", "sbarco": "U12", "barca": "V11", "solo": [36, 37, 38, 39]}])
mov("568", "Con 2 o più bersagli attivi in vista vedi 801; altrimenti sbarca in U12 (il battello resta in U11).",
    [{"op": "barca", "sbarco": "U12", "barca": "", "solo": [20, 21, 28, 29, 36, 37, 38, 39]}])
mov("987", "Con 2 o più bersagli attivi in vista vedi 801; altrimenti sbarca in W15 (il battello resta in W14).",
    [{"op": "barca", "sbarco": "W15", "barca": "", "solo": [20, 21, 28, 29, 36, 37, 38, 39]}])

# ------------------------------------------------------------------ movimenti: esplosivi nel deposito
for pid, h in (("332", "W14"), ("334", "W14"), ("339", "W13"), ("347", "V12"), ("352", "U12"), ("580", "V15"), ("586", "W15"),
               ("594", "W14"), ("601", "V14"), ("687", "U15"), ("692", "T14"), ("700", "W13"), ("708", "W14"), ("915", "V15"),
               ("924", "V14"), ("926", "W15")):
    mov(pid, f"Se questo tedesco ha un esplosivo, qui non ne è già stato piazzato uno e nessun altro tedesco attivo nell’esagono ne ha, "
             f"vedi 619. Altrimenti entra in {h}.",
        [if_({"g_esplosivo": True}, [see("619")], [enter(h)])])

# ------------------------------------------------------------------ altri movimenti
mov("360", "Entra in T11; quando finisce il turno di questo tedesco, vedi 366.", [enter("T11"), see("366")])
mov("608", "Entra in S14; se nel deposito non ci sono tedeschi attivi, quando finisce il turno di questo tedesco vedi 615.",
    [enter("S14"), if_({"deposito_attivi_max": 0}, [see("615")])])
mov("596", "Se vede un bersaglio attivo entra in R18; altrimenti entra in R14.", [if_({"g_vede_almeno": 1}, [enter("R18")], [enter("R14")])])
mov("602", "Se vede un bersaglio attivo entra in P13; altrimenti entra in O15.", [if_({"g_vede_almeno": 1}, [enter("P13")], [enter("O15")])])
mov("609", "Se vede un bersaglio attivo entra in I15; altrimenti entra in J13.", [if_({"g_vede_almeno": 1}, [enter("I15")], [enter("J13")])])
mov("622", "Tira un dado: 0–4 entra in Q10; 5–9 entra in R9.", [die((0, 4, [enter("Q10")]), (5, 9, [enter("R9")]))])
mov("788", "Se vede 2 o più soldati americani attivi entra in F12; altrimenti entra in F10.",
    [if_({"g_vede_almeno": 2}, [enter("F12")], [enter("F10")])])
mov("875", "Se vede 2 o più soldati americani attivi entra in M17; altrimenti entra in M16.",
    [if_({"g_vede_almeno": 2}, [enter("M17")], [enter("M16")])])
mov("904", "Se vede 3 o più soldati americani attivi entra in J7; altrimenti entra in I8.",
    [if_({"g_vede_almeno": 3}, [enter("J7")], [enter("I8")])])
mov("912", "Tira un dado: 0–4 entra in U15; 5–9 entra in T15.", [die((0, 4, [enter("U15")]), (5, 9, [enter("T15")]))])

# ------------------------------------------------------------------ azioni dei commando (carte GE 20, 21, 28, 29, 36–39)
az("509", "Se è in un battello d’assalto vedi 513. Altrimenti tira un dado: 0–2 vedi 868; 3–5 vedi 867; 6 vedi 866; 7 vedi 865; 8 vedi 864; "
          "9 vedi 800.")
az("513", "Se il battello è danneggiato, reazione speciale C per questo tedesco. Se nel battello c’è un solo tedesco attivo, reazione "
          "speciale A. Altrimenti vedi 522.")
az("522", "1. Se il battello si è già mosso in questo turno, vedi 801. 2. Se il battello è stato colpito o ci sono bersagli attivi in vista, "
          "il battello va veloce. 3. Altrimenti va lento.")
az("531", "1. Sbarca. 2. Se è già sbarcato: con 3 o più bersagli in vista vedi 801; con 1 o 2 si alza, fa un tiro rapido e poi corre usando "
          "fino a metà dei suoi PM, prono se può; senza bersagli vedi 868.")
az("538", "Sbarca. Se è già sbarcato: nelle Condizioni 1–3 vedi 549, nelle Condizioni 4–6 vedi 556.")
az("549", "Con 3 o più bersagli in vista vedi 801. Con 1 o 2 fa un tiro rapido al più vicino e corre usando fino a metà dei suoi PM, prono se "
          "può. Senza bersagli vedi 868.")
az("556", "Se vede un altro tedesco attivo vedi 866; altrimenti si arrende.")
az("576", "Se nel suo esagono c’è un americano attivo, assalta per uccidere. Altrimenti, se è in un edificio vedi 816, se no vedi 868.")
