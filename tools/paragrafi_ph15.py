# -*- coding: utf-8 -*-
"""Purple Heart – Missione 15 «Ritorno a casa» (mappa C, in alto è ovest; valle del Rodano, 25 agosto 1944).

La squadra, sfuggita all’accerchiamento, torna al campo; scopre di essere di nuovo dietro le linee e che i tedeschi in ritirata
passeranno di qui. Testo inglese: tools/paragrafi_ph_programma.json, tools/paragrafi_ph_en.json e il database del programma.
"""
from paragrafi_m1 import pc, see, die, if_, S, NOT, ALL, sighting, activate, cond, EVENT

P = {}


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


# ------------------------------------------------------------------ Condizione 1: i resti della battaglia
def jagdpanther(pid, carro, morti):
    par(pid, f"[s0] Un soldato vede un Jagdpanther distrutto e tre americani morti: il relitto è in {carro}, i caduti in {morti}. "
             f"Per perquisire i caduti entra nel loro esagono (vedi 380).",
        sighting(0) + [{"op": "relitto", "hex": carro, "nome": "Jagdpanther distrutto"}, {"op": "leggi_entrando", "hex": morti, "p": "380"}])


jagdpanther("373", "O15", "N14")
jagdpanther("386", "M16", "M14")
jagdpanther("397", "O10", "P9")
par("380", "C’è un bazooka con 2 razzi, un BAR con un caricatore e 2 granate: si possono raccogliere.",
    [bottino(None, [{"arma": "bazooka"}, {"mun": "bazooka", "n": 2}, {"arma": "ar"}, {"mun": "ar", "n": 1}, {"mun": "granata", "n": 2}])])


def sherman_pc(pid, vede):
    par(pid, f"Metti un segnalino Evento. Effettua un controllo di percezione:\n• se riesce, vedi {vede};\n• se fallisce, nessun evento.",
        [EVENT, pc(0, [see(vede)])])


def sherman(pid, carro, morti):
    par(pid, f"[s3] Il soldato vede uno Sherman distrutto in {carro} e due tedeschi morti in {morti}, ciascuno con un fucile a "
             f"otturatore. Nello Sherman c’è ancora un carrista vivo con un messaggio per la squadra: entrando in {carro} vedi 361.",
        sighting(3) + [{"op": "relitto", "hex": carro, "nome": "Sherman distrutto"},
                       bottino(morti, [{"arma": "bolt"}, {"arma": "bolt"}]), {"op": "leggi_entrando", "hex": carro, "p": "361"}])


for a, b in (("302", "308"), ("314", "321"), ("330", "336"), ("344", "353")):
    sherman_pc(a, b)
sherman("308", "R17", "S16")
sherman("321", "T14", "T13")
sherman("336", "S10", "T10")
sherman("353", "S8", "S7")
par("361", "Il carrista racconta che stamattina i tedeschi hanno contrattaccato e respinto la divisione di dieci miglia: la squadra "
           "è di nuovo dietro le linee nemiche! Il carrista muore; ha una pistola con tre caricatori.",
    [bottino(None, [{"arma": "pistol"}, {"mun": "pistol", "n": 3}])])
par("405", "[s6] In questo esagono ci sono un americano e due tedeschi morti. Perquisendo l’esagono (vedi 415) si trovano armi.",
    sighting(6) + [see("415")])
par("415", "Ci sono due fucili a otturatore, una granata e un M-1 con due caricatori: si possono raccogliere.",
    [bottino(None, [{"arma": "bolt"}, {"arma": "bolt"}, {"mun": "granata", "n": 1}, {"arma": "sar"}, {"mun": "sar", "n": 2}])])
par("425", "[s9] In questo esagono ci sono due americani morti, disarmati.", sighting(9))


def battaglia(pid, jeep, pz, sh1, sh2, chi="Un soldato"):
    par(pid, f"[s7] {chi} in questo esagono vede i resti di una battaglia furiosa: una jeep distrutta in {jeep}, un Panzer IV distrutto "
             f"in {pz} e due Sherman distrutti in {sh1} e {sh2}.",
        sighting(7) + [{"op": "relitto", "hex": jeep, "nome": "Jeep distrutta"}, {"op": "relitto", "hex": pz, "nome": "Panzer IV distrutto"},
                       {"op": "relitto", "hex": sh1, "nome": "Sherman distrutto"}, {"op": "relitto", "hex": sh2, "nome": "Sherman distrutto"}])


battaglia("431", "G15", "K15", "J14", "J15", "Tutti i soldati")
battaglia("442", "H13", "I12", "J13", "K13")
battaglia("450", "J9", "L9", "K8", "J10")
battaglia("459", "J7", "I8", "H6", "I6")
battaglia("469", "F6", "G6", "G6", "F5")
battaglia("477", "C5", "D4", "D4", "C4")
battaglia("482", "A4", "B3", "B4", "A3")

# ------------------------------------------------------------------ la collina, la diga e le chiuse
par("491", "• Se s8 non è avvenuto, vedi 498.\n• Se s8 è avvenuto, vedi 505.", [if_(NOT(S(8)), [see("498")], [see("505")])])
par("498", "[s8] I soldati sentono il fragore di una battaglia che infuria verso sud.", sighting(8))
par("505", "Il caposquadra vuole saperne di più e manda un uomo in cima a una collina: appena un soldato occupa la cima di una collina "
           "di livello 4, vedi 519 (una volta sola).", [{"op": "collina_505"}])
par("519", "[s4] Sulla vasta pianura a sud il soldato vede una grande battaglia di carri: gli Alleati contrattaccano e i tedeschi "
           "sembrano ritirarsi da questa parte!\n1. Se il soldato A è attivo, tira un dado e aggiungi il suo PC: con 10 o più vedi 532, "
           "con 9 o meno vedi 550.\n2. Se il soldato A non è attivo, vedi 550.", sighting(4) + [{"op": "sergente_519"}])
par("532", "Passa alla Condizione 2. Il sergente capisce che la sua è l’unica forza combattente efficiente della zona! E capisce anche "
           "che, aprendo le chiuse della diga, si taglierebbe la ritirata ai tedeschi. Vedi 479 per sapere dove sono i comandi delle "
           "chiuse.", [cond(2), see("479")])
par("550", "Passa alla Condizione 3. La squadra è l’unica forza efficiente tra i tedeschi in ritirata e il Vallo occidentale!", [cond(3)])
par("479", "Tira un dado per sapere dove sono i comandi delle chiuse:\n0–2: V12\n3–4: J8\n5–6: L6\n7–8: N5\n9: O5\nEntrando "
           "nell’esagono indicato, vedi 606.",
    [die((0, 2, [{"op": "chiuse", "hex": "V12"}]), (3, 4, [{"op": "chiuse", "hex": "J8"}]), (5, 6, [{"op": "chiuse", "hex": "L6"}]),
         (7, 8, [{"op": "chiuse", "hex": "N5"}]), (9, 9, [{"op": "chiuse", "hex": "O5"}]))])
par("606", "Nei Round servono 4 azioni per aprire le chiuse (anche divise tra più soldati); nelle Operazioni si aprono dopo un controllo "
           "degli eventi casuali. Usa l’azione «Apri le chiuse». Quando sono aperte, vedi 565.", [])
par("565", "L’acqua sfonda le chiuse! Il segnalino Piena parte da N5. Iniziano i Round. All’inizio di ogni Round la piena avanza di "
           "quattro esagoni del letto asciutto del fiume (in questa versione: quattro per Round) finché esce dalla mappa: allora vedi 542. "
           "Ogni esagono attraversato si allaga e resta impraticabile; soldati e mezzi che lo occupano sono travolti (uccisi o distrutti); "
           "il ponte travolto crolla. Si continua nei Round finché la piena esce, poi si torna alle Operazioni se non ci sono tedeschi "
           "attivi.", [{"op": "piena"}])
par("542", "Passa alla Condizione 4. Guadagni 5 PV per aver aperto le chiuse!", [cond(4), {"op": "vp", "n": 5, "why": "chiuse aperte"}])

# ------------------------------------------------------------------ la colonna motorizzata
par("588", "Tira un dado:\n0–7: vedi 593.\n8–9: nessun evento.", [die((0, 7, [see("593")]), (8, 9, []))])
par("593", "[s2] Una colonna motorizzata tedesca entra in mappa! Attiva il tedesco 4 e il tedesco 6, ciascuno su una motocicletta, "
           "in A3. Iniziano i Round, vantaggio tedesco; i tedeschi 4 e 6 ricevono 2 turni in questo Round. Tutti i soldati americani "
           "che vedono A3 sono consapevoli. All’inizio del secondo Round, al posto del controllo degli eventi casuali (o prima, se "
           "questi tedeschi sono fuori combattimento), vedi 598. Vedi 600 per le motociclette.",
    sighting(2) + [{"op": "colonna_ph", "mezzi": [["moto", 4, []], ["moto", 6, []]], "hex": "A3", "two": [4, 6]},
                   {"op": "consapevoli_vede", "hex": "A3"}, {"op": "attesa_598"}])
par("600", "Le motociclette con sidecar sono piccole e non contano nel limite di due mezzi per esagono. Una motocicletta che investe un "
           "soldato attivo fa subito un controllo d’incidente (−2 all’abilità di guida).", [])
par("598", "Attiva i tedeschi 8, 9, 10 e 11 su una Kübelwagen e 12, 14, 15 e 16 su un’auto comando, in A3. Iniziano i Round, "
           "vantaggio tedesco. Se sei nella Condizione 2 vedi 698; nella Condizione 3 vedi 709. (Alla guida: 8 e 16; il tedesco 12 è il "
           "feldmaresciallo.)",
    [{"op": "colonna_ph", "mezzi": [["kubelwagen", 8, [9, 10, 11]], ["auto_comando", 16, [12, 14, 15]]], "hex": "A3", "two": []},
     if_({"cond_in": [2]}, [see("698")], [see("709")])])
par("698", "Ti servono 3 PV per vincere. Perdi 5 PV per ogni tedesco che esce dalla mappa. La missione finisce, nella Condizione 2, 3 o "
           "4, quando non ci sono tedeschi attivi in mappa. Non si perdono PV per i soldati americani incapacitati.",
    [{"op": "regole_fine_15", "uscita": 5}])
par("709", "Ti servono 3 PV per vincere. I PV vengono dalle attivazioni dei tedeschi e da quanto rivelano i paragrafi. Perdi 3 PV per "
           "ogni tedesco che esce dalla mappa. La missione finisce, nella Condizione 2, 3 o 4, quando non ci sono tedeschi attivi in "
           "mappa. Non si perdono PV per i soldati americani incapacitati.", [{"op": "regole_fine_15", "uscita": 3}])

# ------------------------------------------------------------------ Condizione 4: eventi
par("984", "Un soldato americano attivo in piedi in una vigna inciampa e cade: danni sulla colonna Pistola della tabella dei danni. Una "
           "volta sola per missione.", [{"op": "inciampo_vigna"}])

# ------------------------------------------------------------------ movimenti
def veic(pid, si, no):
    mov(pid, f"• Se si muove un mezzo, entra in {si}.\n• Altrimenti entra in {no}.",
        [if_({"vehicle_moving": True}, [enter(si)], [enter(no)])])


for pid, si, no in (("303", "Q14", "P15"), ("305", "R14", "Q15"), ("309", "S14", "R15"), ("311", "T14", "S15"),
                    ("313", "Q9", "R10"), ("315", "P8", "Q10"), ("316", "O8", "P9"), ("319", "N8", "O9"),
                    ("525", "I9", "J8"), ("716", "N14", "M16"), ("722", "L15", "K16"), ("728", "M15", "L16"),
                    ("737", "K15", "K14"), ("741", "J14", "K14"), ("746", "J13", "J12"), ("751", "I13", "J12"),
                    ("757", "I12", "J11"), ("765", "I11", "J10"), ("773", "K9", "K10"), ("896", "U13", "V14"),
                    ("988", "K15", "J15"), ("989", "L15", "M15"), ("991", "M15", "L16"), ("993", "N14", "M16"),
                    ("996", "O15", "N15"), ("998", "P14", "O16")):
    veic(pid, si, no)


def fante(pid, si, no):
    mov(pid, f"• Se si muove un soldato che vede un bersaglio attivo, entra in {si}.\n• Altrimenti entra in {no}.",
        [if_(ALL(NOT({"vehicle_moving": True}), {"g_vede_us": True}), [enter(si)], [enter(no)])])


for pid, si, no in (("899", "E6", "F5"), ("922", "F6", "G6"), ("928", "G7", "H6"), ("940", "H7", "I7"), ("973", "J8", "K8")):
    fante(pid, si, no)
mov("515", "Tira un dado: 0–4 entra in J7; 5–9 entra in I8.", [die((0, 4, [enter("J7")]), (5, 9, [enter("I8")]))])
mov("527", "Tira un dado: 0–4 entra in T15; 5–9 entra in U14.", [die((0, 4, [enter("T15")]), (5, 9, [enter("U14")]))])
mov("614", "• Se il ponte non è intatto, passa alla Condizione 4 e continua il movimento normale.\n• Altrimenti entra in S9.",
    [if_({"ponte_s9": True}, [enter("S9")], [cond(4)])])
mov("694", "• Se il letto del fiume è allagato, passa alla Condizione 4 e continua a muovere questo tedesco.\n• Altrimenti entra in V11.",
    [if_({"fiume_allagato": True}, [cond(4)], [enter("V11")])])
mov("778", "• Se il ponte in S9 è intatto, entra in Q9.\n• Altrimenti entra in P10.", [if_({"ponte_s9": True}, [enter("Q9")], [enter("P10")])])
mov("787", "• Se si muove un mezzo, entra in T7.\n• Altrimenti tira un dado: 0–4 entra in U8; 5–9 entra in U9.",
    [if_({"vehicle_moving": True}, [enter("T7")], [die((0, 4, [enter("U8")]), (5, 9, [enter("U9")]))])])
mov("794", "• Se non vede bersagli attivi, entra in O17.\n• Altrimenti entra in O18.",
    [if_({"g_vede_us": True}, [enter("O18")], [enter("O17")])])
mov("890", "• Se non vede bersagli attivi, entra in Q14.\n• Altrimenti entra in P13.",
    [if_({"g_vede_us": True}, [enter("P13")], [enter("Q14")])])

# ------------------------------------------------------------------ azioni dei tedeschi della colonna
az("613", "1. Se il mezzo è stato bersagliato o danneggiato, vedi 620.\n2. Con 3 o più bersagli attivi in vista, vedi 620.\n3. Con 1 o 2 "
          "bersagli in vista, vedi 828 (guida veloce).\n4. Senza bersagli in vista, vedi 814 (guida lenta).")
az("620", "Scende dal mezzo (1 PM) e si muove il più rapidamente possibile; alla fine cade prono se è in un esagono scoperto e vede un "
          "bersaglio attivo. Alla fine del movimento perde la reazione speciale W.")
az("626", "1. Se il suo mezzo è stato bersagliato o danneggiato, vedi 620.\n2. Con 3 o più bersagli attivi in vista, vedi 802.\n3. Con 1 o "
          "2 bersagli in vista, vedi 801.\n4. Senza bersagli in vista, vedi 840.")
az("322", "• Se il tedesco 12 vede un altro tedesco attivo, vedi 658.\n• Altrimenti esegue 809.")
az("324", "• Se il tedesco 12 è attivo e questo soldato lo vede, vedi 635.\n• Altrimenti esegue 866.")
az("326", "• Se il tedesco 12 è attivo e questo soldato lo vede, vedi 635.\n• Altrimenti esegue 867.")
az("327", "• Se il tedesco 12 è attivo e questo soldato lo vede, vedi 635.\n• Altrimenti esegue 800.")
az("328", "• Se il tedesco 12 è attivo e questo soldato lo vede, vedi 635.\n• Altrimenti esegue 863.")
az("635", "1. Nell’esagono del tedesco 12 con un bersaglio in vista: vedi 640.\n2. Nell’esagono del tedesco 12 senza bersagli: esegue "
          "809.\n3. Fuori dal suo esagono ma vedendo sia il tedesco 12 sia un bersaglio: vedi 650.\n4. Altrimenti vedi 665.")
az("640", "Se il tedesco 12 non è prono, si accovaccia, lo spinge a terra (1 PM) e spara un tiro rapido al bersaglio più vicino; se il "
          "tedesco 12 è già prono, si accovaccia e fa il miglior tiro al più vicino. Non cade prono.")
az("650", "Si accovaccia e fa il miglior tiro al bersaglio più vicino al tedesco 12; poi prono se può.")
az("658", "1. Con un tedesco 13 o superiore nell’esagono e un bersaglio in vista: cade prono e cede un turno al soldato non ferito con "
          "meno turni nello stesso esagono o in uno adiacente (se tutti hanno 2 turni, vedi 802).\n2. Con un tedesco 13 o superiore "
          "nell’esagono e nessun bersaglio in vista: esegue 809.\n3. Altrimenti si muove il più rapidamente possibile, fermandosi in un "
          "esagono con un tedesco attivo; alla fine cade prono.")
az("665", "Si muove il più rapidamente possibile verso il tedesco 12 e, se lo raggiunge, si accovaccia nel suo esagono; altrimenti cade "
          "prono nel primo esagono non scoperto.")
az("675", "• Con un altro tedesco attivo nell’esagono, o da solo con un americano attivo, vedi 839.\n• Da solo con 2 o più americani "
          "attivi, si arrende.\n• Altrimenti esegue 802.")
az("680", "• Nell’esagono del tedesco 12, vedi 833.\n• Altrimenti vedi 812.")
