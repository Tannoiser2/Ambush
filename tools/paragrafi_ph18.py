# -*- coding: utf-8 -*-
"""Purple Heart – Missione 18 «Il mattino dopo» (mappe B + E, in alto è est; Ardenne, 20 dicembre 1944).

La squadra, isolata in un paesino, si sveglia: rumore di cingoli da est. Panzer IV, granatieri corazzati, Sherman di
rinforzo (all’inizio non ai tuoi ordini) e la decisione finale: tenere la posizione o ripiegare verso ovest.
Testo inglese: tools/paragrafi_ph_programma.json, tools/paragrafi_ph_en.json e il database del programma.
"""
import json
import pathlib

from paragrafi_m1 import pc, see, die, if_, S, NOT, ALL, sighting, activate, cond, EVENT

P = {}
R = pathlib.Path(__file__).resolve().parent


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def mov(pid, it, ops):
    par(pid, it, ops, "movimento")


def az(pid, it):
    par(pid, it, [], "azione")


def enter(h):
    return {"op": "g_enter", "hex": h}


def bottino(h, ogg):
    return {"op": "bottino", "hex": h, "oggetti": ogg}


def pc_ev(pid, ok):
    par(pid, f"Metti un segnalino Evento. Effettua un controllo di percezione:\n• se riesce, vedi {ok};\n• se fallisce, nessun evento.",
        [EVENT, pc(0, [see(ok)])])


def dado2(pid, soglia, a, b):
    par(pid, f"Tira un dado:\n0–{soglia}: entra in {a}.\n{soglia + 1}–9: entra in {b}.", [die((0, soglia, [enter(a)]), (soglia + 1, 9, [enter(b)]))])
    P[pid]["tipo"] = "movimento"


def se_mezzo(pid, a, b):
    mov(pid, f"• Se si muove un mezzo, entra in {a}.\n• Altrimenti entra in {b}.", [if_({"vehicle_moving": True}, [enter(a)], [enter(b)])])


# ------------------------------------------------------------------ Condizione 1: il paese all’alba
par("507", "[s1] I soldati sentono dei corazzati che arrivano da est! Iniziano i Round anche senza tedeschi in mappa. Tutti gli "
           "americani sono consapevoli all’inizio del Round 1 (panico e comando si determinano normalmente). All’inizio del Round 2, "
           "al posto del controllo degli eventi casuali, vedi 512.", sighting(1) + [{"op": "m18_rumore"}])
par("512", "[s0] Attiva i tedeschi 57, 58, 59 e 60 (Panzer IV) fuori mappa accanto ad A5. Iniziano i Round; ricevono 2 turni in questo "
           "Round. Passa alla Condizione 2. Ciascun carro entra in A5 al suo primo turno, pagando il costo dell’esagono.",
    sighting(0) + [{"op": "m18_panzer", "hex": ["A5", "A5", "A5", "A5"], "fuori": True}, cond(2)])
pc_ev("633", "642")
pc_ev("683", "691")
par("642", "[s3] Il soldato vede una Kübelwagen distrutta in E17, con il muro tra D16 ed E17 sfondato. Sotto il mezzo sembra esserci un "
           "sopravvissuto: entrando in E17 vedi 653.",
    sighting(3) + [{"op": "relitto", "hex": "E17", "nome": "Kübelwagen distrutta"}, {"op": "muro_sfondato", "a": "D16", "b": "E17"},
                   {"op": "leggi_entrando", "hex": "E17", "p": "653"}])
par("691", "[s3] Il soldato vede una Kübelwagen distrutta in O17. Sotto il mezzo sembra esserci un sopravvissuto: entrando in O17 vedi "
           "653.", sighting(3) + [{"op": "relitto", "hex": "O17", "nome": "Kübelwagen distrutta"}, {"op": "leggi_entrando", "hex": "O17", "p": "653"}])
par("653", "Sotto la Kübelwagen c’è un ufficiale tedesco! Guadagni 2 PV. È in fin di vita, ma ti dice che resistere non serve: perché non "
           "arrendersi ed evitare un inutile spargimento di sangue? (Arrendendoti la missione finisce e la squadra passa il resto della "
           "guerra in un campo di prigionia.) Mentre ridi della sua sfrontatezza, ti chiede di accendergli una sigaretta.\n• Se un tuo "
           "soldato gli accende la sigaretta, vedi 663.\n• Se rifiuti, vedi 677.",
    [{"op": "vp", "n": 2, "why": "ufficiale tedesco sotto la Kübelwagen"}, {"op": "m18_ufficiale"}])
par("663", "Il soldato che accende la sigaretta effettua un controllo di percezione:\n• se riesce, vedi 677;\n• se fallisce, vedi 673.",
    [{"op": "m18_sigaretta"}])
par("677", "Il soldato si accorge che dalla Kübelwagen cola benzina e saggiamente rifiuta. Il tedesco muore; ha una Luger. Dell’autista "
           "nessuna traccia.", [{"op": "m18_luger"}])
par("673", "Accendendo la sigaretta il soldato dà fuoco alla benzina che cola: la Kübelwagen esplode! Tutti i soldati nell’esagono "
           "muoiono.", [{"op": "m18_esplosione_kubel"}])
par("m18resa", "La squadra si arrende all’ufficiale tedesco: la missione finisce e passa il resto della guerra in un campo di prigionia.",
    [{"op": "m18_resa"}])
pc_ev("564", "574")
pc_ev("605", "621")
par("574", "[s5] Il soldato vede un Jagdpanther distrutto in H17, rivolto a est. Entrando in H17 vedi 585.",
    sighting(5) + [{"op": "m18_relitto_jagd", "hex": "H17"}, {"op": "leggi_entrando", "hex": "H17", "p": "585"}])
par("621", "[s5] Il soldato vede un Jagdpanther distrutto in N14, rivolto a est. Entrando in N14 vedi 585.",
    sighting(5) + [{"op": "m18_relitto_jagd", "hex": "N14"}, {"op": "leggi_entrando", "hex": "N14", "p": "585"}])
par("585", "Il Jagdpanther sembra fuori uso solo in parte. Se vuoi, manda un soldato dentro a esaminarlo: vedi 599.",
    [{"op": "scelta_attiva", "par": "599", "testo": "Esamina l’interno del Jagdpanther"}])
par("599", "Il soldato vede che il cannone e la mitragliatrice di scafo sono intatti! Due soldati americani attivi possono servire il mezzo "
           "come un equipaggio di 2 con abilità con le armi −1. Cannone e mitragliatrice si usano come un’arma di squadra (regola 9/7): "
           "il cannone non è carico e restano quattro colpi. Il Jagdpanther non è mai un bersaglio attivo per il fuoco.",
    [{"op": "m18_jagdpanther"}])
par("537", "[s6] In questo esagono ci sono un americano e due tedeschi caduti. Perquisendo l’esagono (vedi 547) si trovano armi.",
    sighting(6) + [see("547")])
par("547", "Ci sono un mitra Thompson con 2 caricatori, 2 fucili a otturatore e 2 granate.",
    [bottino(None, [{"arma": "smg"}, {"mun": "smg", "n": 2}, {"arma": "bolt"}, {"arma": "bolt"}, {"mun": "granata", "n": 2}])])
par("553", "[s7] In questo esagono ci sono una jeep fuori uso e due americani caduti. Perquisendo la jeep (vedi 563) si trovano armi.",
    sighting(7) + [{"op": "relitto_qui", "nome": "Jeep fuori uso"}, see("563")])
par("563", "Ci sono un bazooka con 3 razzi e una pistola con due caricatori.",
    [bottino(None, [{"arma": "bazooka"}, {"mun": "bazooka", "n": 3}, {"arma": "pistol"}, {"mun": "pistol", "n": 2}])])
par("310", "In questo esagono ci sono una mitragliatrice media con tre caricatori, 2 granate e un bazooka con un razzo.",
    [bottino(None, [{"arma": "mmg"}, {"mun": "mmg", "n": 3}, {"mun": "granata", "n": 2}, {"arma": "bazooka"}, {"mun": "bazooka", "n": 1}])])
par("c18", "Un tedesco caduto: ha un fucile a otturatore con un caricatore e forse una granata (dado: 0–4 una granata, 5–9 nessuna).",
    [{"op": "m18_caduto_tedesco"}])

for pid, (tedeschi, ht, cerca) in json.loads((R / "caduti_ph18.json").read_text()).items():
    par(pid, f"[s8] In questo esagono ci sono quattro soldati morti (tre americani). Un tedesco caduto in ciascuno di {', '.join(tedeschi)}; "
             f"un semicingolato distrutto in {ht}. Ogni tedesco caduto ha un fucile a otturatore con un caricatore e forse una granata "
             f"(perquisendolo, dado 0–4: una granata). Per perquisire l’esagono {cerca} vedi 310.",
        sighting(8) + [{"op": "m18_caduti", "tedeschi": tedeschi, "semicingolato": ht, "cerca": cerca}])

par("699", "• Se s6 e s8 sono avvenuti, vedi 705.\n• Altrimenti nessun evento.", [if_(ALL(S(6), S(8)), [see("705")])])
par("705", "1. Se un americano attivo vede D4, vedi 714.\n2. Se vede H6, vedi 719.\n3. Se vede N7, vedi 724.\n4. Se vede R9, vedi 730.\n"
           "5. Vedi 739.",
    [if_({"see_hex": "D4"}, [see("714")], [if_({"see_hex": "H6"}, [see("719")], [if_({"see_hex": "N7"}, [see("724")],
                                                                                [if_({"see_hex": "R9"}, [see("730")], [see("739")])])])])])


def panzer(pid, h4):
    par(pid, f"[s0] Attiva il tedesco 57 in {h4[0]}, il 58 in {h4[1]}, il 59 in {h4[2]} e il 60 in {h4[3]}. Iniziano i Round; i carri "
             f"ricevono 2 turni in questo Round. Passa alla Condizione 2. Per il rumore dei mezzi tutti gli americani sono consapevoli.",
        sighting(0) + [{"op": "m18_panzer", "hex": h4, "fuori": False}, cond(2)])


panzer("714", ["D4", "C4", "B4", "A5"])
panzer("719", ["H6", "G6", "F5", "E5"])
panzer("724", ["N7", "M7", "L6", "K6"])
panzer("730", ["R9", "Q9", "P8", "O8"])
par("739", "[s1] I soldati sentono di nuovo il rumore di mezzi meccanizzati che si avvicinano.", sighting(1))

# ------------------------------------------------------------------ Condizioni 2–4: l’assalto
par("749", "Tira un dado:\n0–3: vedi 583.\n4–7: vedi 762.\n8–9: nessun evento.",
    [die((0, 3, [see("583")]), (4, 7, [see("762")]), (8, 9, []))])
par("583", "• Se uno o più americani attivi sono a est del fiume, vedi 703.\n• Altrimenti vedi 755.",
    [if_({"us_est_fiume": True}, [see("703")], [see("755")])])


def granatieri(pid, hx):
    par(pid, f"[s4] Attiva il tedesco 19 in {hx[0]}, i 25 e 26 in {hx[1]}, i 33 e 34 in {hx[2]} e il 27 in {hx[3]}, in piedi. Iniziano i "
             f"Round; ricevono 2 turni in questo Round.\n• Se sei nella Condizione 2, passa alla Condizione 3.\n• Se sei nella Condizione 4, "
             f"resti nella Condizione 4.",
        sighting(4) + [activate([(19, hx[0]), (25, hx[1]), (26, hx[1]), (33, hx[2]), (34, hx[2]), (27, hx[3])], "standing",
                                two=[19, 25, 26, 27, 33, 34]), if_({"cond_in": [2]}, [cond(3)])])


granatieri("703", ["G2", "H1", "I1", "J1"])
granatieri("755", ["I9", "J8", "K8", "L7"])
par("762", "[s9] I rinforzi hanno rotto l’accerchiamento tedesco! Passa alla Condizione 4. Iniziano i Round. Tre Sherman (carte "
           "americane 01, 02 e 03) non ai tuoi ordini: li metti fuori mappa accanto a B19, F19, K19, N19 o R19 (anche più d’uno nello "
           "stesso). Ogni Sherman entra appena riceve un turno, pagando il primo esagono. Si resta nei Round finché c’è uno Sherman attivo.",
    sighting(9) + [{"op": "m18_sherman"}, cond(4)])
par("982", "• Se s9 non è avvenuto, vedi 983.\n• Se s9 è avvenuto, vedi 986.", [if_(NOT(S(9)), [see("983")], [see("986")])])
par("983", "Tira un dado:\n0–6: vedi 762.\n7–9: vedi 981.", [die((0, 6, [see("762")]), (7, 9, [see("981")]))])
par("986", "• Se un comandante americano è ancora attivo, vedi 990.\n• Se non ci sono comandanti attivi, vedi 994.",
    [if_({"comandante_us": True}, [see("990")], [see("994")])])
par("990", "La battaglia dipende dalla tua prossima decisione: si può respingere l’assalto tedesco, o la squadra deve ripiegare sulle "
           "posizioni americane a ovest? All’inizio di questo o del prossimo Round, al posto della fase degli eventi, devi decidere:\n"
           "• se tieni la posizione come da ordini, vedi 992;\n• se salvi la squadra e ripieghi, vedi 994.", [{"op": "m18_decisione"}])
par("306", "La battaglia dipende dalla tua prossima decisione: si può respingere l’assalto tedesco, o la squadra deve ripiegare sulle "
           "posizioni americane a ovest? All’inizio del prossimo Round devi decidere:\n• se tieni la posizione come da ordini, vedi "
           "992;\n• se salvi la squadra e ripieghi, vedi 994.", [{"op": "m18_decisione"}])
par("301", "• Se un comandante americano è ancora attivo, vedi 306.\n• Se non ci sono comandanti attivi, vedi 994.",
    [if_({"comandante_us": True}, [see("306")], [see("994")])])
par("995", "• Se s4 non è avvenuto, vedi 997.\n• Se s4 è avvenuto, vedi 301.", [if_(NOT(S(4)), [see("997")], [see("301")])])
par("997", "Tira un dado:\n0–6: vedi 583.\n7–9: nessun evento.", [die((0, 6, [see("583")]), (7, 9, []))])
par("992", "Avanti! Passa alla Condizione 5. Per vincere servono 36 PV. Oltre ai PV per le attivazioni e i mezzi distrutti, ricevi 1 PV "
           "per ogni americano attivo (soldato o mezzo) a est del fiume alla fine. La missione finisce, nelle Condizioni 5 o 6, quando non "
           "ci sono tedeschi attivi in mappa. Non perdi PV per gli incapacitati.", [{"op": "m18_tieni"}, cond(5)])
par("994", "Ripiegate! Passa alla Condizione 6. Per vincere servono 30 PV. Oltre ai PV per le attivazioni e i mezzi distrutti, ricevi 2 PV "
           "per ogni americano attivo (soldato o mezzo) che esce dal bordo ovest tra A19 e Y19, e perdi 2 PV per ogni tedesco attivo "
           "(soldato o mezzo) che esce da quel bordo. La missione finisce nella Condizione 6 appena non ci sono americani attivi in mappa. "
           "Gli incapacitati portati fuori dal bordo ovest con la squadra non fanno perdere PV.", [{"op": "m18_ripiega"}, cond(6)])

# ------------------------------------------------------------------ Condizione 5: eventi
par("312", "• Se la radio è presidiata e funziona, vedi 318.\n• Se funziona ma non è presidiata, vedi 318 appena (e se) lo diventa.",
    [{"op": "m18_radio_312"}])
par("318", "Gli Sherman passano ai tuoi ordini! Non si leggono più paragrafi per muoverli e si ignorano i loro paragrafi d’azione: da ora "
           "alla fine della missione muovono e sparano come vuoi. Se l’evento è già avvenuto, nessun evento.", [{"op": "m18_sherman_comando"}])
par("981", "Un’arma tedesca usata nel Round precedente ha finito le munizioni (a caso, se ne hanno sparato più d’una). Se il tedesco non ha "
           "un’altra arma personale, mette in effetto la reazione speciale A (che si toglie se trova una nuova arma; vale su ogni altra "
           "reazione tranne l’autoconservazione). Il Panzerfaust non ne è toccato.", [{"op": "m18_981"}])

# ------------------------------------------------------------------ movimenti
mov("518", "• Se si muove un mezzo tedesco e ci sono americani attivi (soldati o mezzi) a est del fiume, entra in F11.\n• Se si muove un "
           "mezzo americano e ci sono mezzi tedeschi attivi a est del fiume, entra in F11.\n• Altrimenti entra in F12.",
    [if_({"m18_guado": "si"}, [enter("F11")], [enter("F12")])])
mov("557", "• Se si muove un mezzo tedesco e ci sono soldati americani attivi a est del fiume, entra in O10.\n• Se si muove un mezzo "
           "americano e ci sono mezzi tedeschi attivi a est del fiume, entra in O10.\n• Altrimenti entra in N11.",
    [if_({"m18_guado": "soldati"}, [enter("O10")], [enter("N11")])])
dado2("558", 4, "N3", "O4")
mov("766", "• Se si muove un mezzo tedesco e c’è un americano attivo a est di questo esagono, entra in N6.\n• Altrimenti tira un dado: "
           "0–4 entra in O8, 5–9 in M8.",
    [if_(ALL({"veicolo_lato": "de"}, {"us_a_est_hex": True}), [enter("N6")], [die((0, 4, [enter("O8")]), (5, 9, [enter("M8")]))])])
dado2("770", 1, "I14", "H15")
dado2("772", 4, "Q12", "S11")
dado2("774", 4, "F13", "E13")
dado2("779", 1, "B18", "C17")
dado2("782", 6, "J17", "J16")
dado2("786", 7, "L14", "M15")
dado2("792", 4, "N12", "L12")
dado2("795", 4, "R15", "R16")
mov("798", "• Se si muove un mezzo, entra in I12.\n• Altrimenti tira un dado: 0–4 entra in K13, 5–9 in I13.",
    [if_({"vehicle_moving": True}, [enter("I12")], [die((0, 4, [enter("K13")]), (5, 9, [enter("I13")]))])])
se_mezzo("799", "H14", "F14")
mov("880", "Mette in effetto la reazione speciale B.", [{"op": "g_reaction", "r": "B"}, {"op": "ferma_g"}])
se_mezzo("931", "E16", "C17")
se_mezzo("933", "D16", "C18")
se_mezzo("936", "H17", "H18")
se_mezzo("938", "L15", "N15")
mov("942", "• Se si muove un mezzo americano, entra in R16.\n• Se si muove un mezzo tedesco, entra in Q18.\n• Altrimenti entra in S17.",
    [if_({"veicolo_lato": "us"}, [enter("R16")], [if_({"veicolo_lato": "de"}, [enter("Q18")], [enter("S17")])])])
se_mezzo("945", "U17", "W16")
se_mezzo("947", "J15", "I16")
se_mezzo("950", "J13", "I13")
mov("952", "• Se non vede bersagli nemici, entra in F15.\n• Altrimenti entra in E15.", [if_({"senza_bersagli": True}, [enter("F15")], [enter("E15")])])
se_mezzo("954", "G15", "F16")
dado2("957", 6, "L14", "K15")
se_mezzo("960", "L13", "M15")
se_mezzo("961", "O15", "N13")
se_mezzo("966", "O13", "O12")
se_mezzo("968", "R12", "S14")
se_mezzo("970", "V14", "W14")
se_mezzo("972", "K18", "L18")
mov("974", "• Se non vede bersagli nemici, entra in E18.\n• Altrimenti entra in D17.", [if_({"senza_bersagli": True}, [enter("E18")], [enter("D17")])])
dado2("976", 4, "S19", "Q19")
mov("978", "• Se si muove un mezzo americano, entra in R15.\n• Altrimenti entra in R17.", [if_({"veicolo_lato": "us"}, [enter("R15")], [enter("R17")])])
mov("980", "• Se si muove un mezzo americano, entra in Q12.\n• Altrimenti entra in R11.", [if_({"veicolo_lato": "us"}, [enter("Q12")], [enter("R11")])])
se_mezzo("704", "I7", "H7")
se_mezzo("726", "I8", "I9")
se_mezzo("727", "J6", "I8")
se_mezzo("734", "J7", "J8")
se_mezzo("742", "K6", "K7")

# ------------------------------------------------------------------ azioni dei tedeschi (Purple Heart)
PZF = "1. Se ha il Panzerfaust e vede un mezzo americano attivo entro 3 esagoni, si accovaccia e lo spara al mezzo più vicino.\n2. "
AZ = {
    "806": PZF + "Esegue 864.",
    "819": PZF + "Esegue 865.",
    "831": PZF + "Esegue 866.",
    "836": PZF + "Esegue 867.",
    "837": PZF + "Esegue 858.",
    "841": PZF + "Esegue 834.",
    "843": "• Se i tedeschi 27 e 34 sono inattivi, vedi 813.\n• Altrimenti vedi 806.",
    "850": "• Se i tedeschi 27 e 34 sono inattivi, vedi 817.\n• Altrimenti vedi 836.",
    "853": "• Se i tedeschi 27 e 34 sono inattivi, vedi 830.\n• Altrimenti vedi 831.",
    "854": "• Se i tedeschi 27 e 34 sono inattivi, vedi 820.\n• Altrimenti vedi 829.",
    "861": "1. Se è entro 2 esagoni da un soldato (nemico o amico) ucciso o incapacitato e non vede bersagli attivi, corre dalla vittima "
           "e cade prono; al turno dopo si accovaccia e prende l’arma; al turno dopo si alza e corre nell’esagono di prima, poi prono se "
           "può.\n2. Se ha il Panzerfaust e vede un mezzo americano attivo entro 3 esagoni, si accovaccia e lo spara al più vicino.\n3. "
           "Esegue 868.",
    "882": "• Nelle Condizioni 1–4 vedi 801.\n• Nella Condizione 5 toglie la reazione speciale B e vede 843.\n• Nella Condizione 6 toglie "
           "la reazione speciale B e vede 806.",
    "885": "• Nelle Condizioni 1–4 vedi 802.\n• Nella Condizione 5 toglie la reazione speciale B e vede 850.\n• Nella Condizione 6 toglie "
           "la reazione speciale B e vede 819.",
    "888": "• Nelle Condizioni 1–4 vedi 869.\n• Nella Condizione 5 toglie la reazione speciale B e vede 853.\n• Nella Condizione 6 toglie "
           "la reazione speciale B e vede 831.",
    "892": "• Nelle Condizioni 1–4 vedi 801.\n• Nella Condizione 5 toglie la reazione speciale B e vede 854.\n• Nella Condizione 6 toglie "
           "la reazione speciale B e vede 836.",
    # Panzer IV
    "914": "• A est del fiume e con i portelli ancora aperti, vedi 917.\n• Altrimenti vedi 921.",
    "917": "Guida veloce. Spara col cannone a un mezzo americano attivo o a un bersaglio attivo in un edificio, se in vista; carica il "
           "cannone se non può sparare. Se il cannone è carico e non c’è un bersaglio per il cannone, tiro rapido con la coassiale al "
           "più vicino.",
    "932": "• Con uno o più bersagli attivi in vista chiude i portelli; se sono già chiusi, vedi 934.\n• Senza bersagli in vista apre; se "
           "sono già aperti, vedi 935.",
    "934": "Tiro rapido con la mitragliatrice di scafo al più vicino. Cannone contro un mezzo americano o un bersaglio in un edificio, se in "
           "vista; altrimenti carica. Se il cannone è carico e non ha bersagli, non fa altro.",
    "935": "Guida veloce.",
    "937": "• Con uno o più bersagli attivi in vista l’equipaggio si arrende.\n• Altrimenti non fa nulla.",
    # Sherman (carte americane 01–03, finché non passano ai tuoi ordini)
    "939": "• Con 3 o più bersagli attivi in vista chiude i portelli; se sono già chiusi, vedi 943.\n• Con 1 o 2 bersagli chiude; se sono "
           "già chiusi, vedi 944.\n• Senza bersagli apre; se è già aperto, vedi 944.",
    "943": "Tiro mirato con la mitragliatrice di scafo al più vicino. Cannone contro un mezzo o un bersaglio in un edificio, se in vista; "
           "altrimenti carica. Se il cannone è carico e non ha bersagli, tiro mirato con la coassiale al secondo più vicino.",
    "944": "Guida lento. Cannone contro un mezzo o un bersaglio in un edificio, se in vista; altrimenti carica. Se il cannone è carico e "
           "non ha bersagli, tiro rapido con la coassiale al secondo più vicino. Tiro rapido con la mitragliatrice di scafo al più vicino.",
    "946": "• Con 2 o più bersagli attivi in vista chiude i portelli; se sono già chiusi, vedi 949.\n• Con 1 bersaglio chiude; se sono già "
           "chiusi, vedi 951.\n• Senza bersagli apre; se è già aperto, vedi 953.",
    "949": "Tiro mirato con la mitragliatrice di scafo al più vicino. Cannone contro un mezzo o un bersaglio in un edificio, se in vista; "
           "altrimenti carica. Se il cannone è carico e non ha bersagli, tiro mirato con la coassiale al secondo più vicino.",
    "951": "Tiro rapido con la mitragliatrice di scafo al più vicino. Cannone contro un mezzo o un bersaglio in un edificio, se in vista; "
           "altrimenti carica.",
    "953": "Guida veloce. Cannone contro un mezzo o un bersaglio in un edificio, se in vista; altrimenti carica. Tiri rapidi con la "
           "coassiale al secondo più vicino e poi al più vicino.",
    "956": "• Con 2 o più bersagli attivi in vista chiude i portelli; se sono già chiusi, vedi 958.\n• Con 1 bersaglio chiude; se sono già "
           "chiusi, vedi 965.\n• Senza bersagli apre; se è già aperto, vedi 967.",
    "958": "Tiro mirato con la mitragliatrice di scafo al più vicino. Cannone contro un mezzo o un bersaglio in un edificio, se in vista; "
           "altrimenti carica.",
    "965": "Tiro rapido con la mitragliatrice di scafo al più vicino. Cannone contro un mezzo o un bersaglio in un edificio, se in vista; "
           "altrimenti carica.",
    "967": "Guida veloce.",
    "969": "Tiro mirato con la coassiale al più vicino.",
}
for k, v in AZ.items():
    az(k, v)
