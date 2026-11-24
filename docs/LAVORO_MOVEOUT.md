# Move Out! (missioni 9–12): stato dei lavori

Richiesta di Stefano (23/11): «Puoi fare gli scenari della prima espansione?». Pubblicare solo quando lo dice.

## Fonti (dal modulo TTS in ~/Desktop/Ludoteca/Ambush/Mods)
- Libretto regole + paragrafi Move Out!: PDF 9AA9CB05…; testo anche nel foglio Excel (AMBPARAGRAPHS, «Move out»).
  Testo inglese: `tools/paragrafi_mo_en.json` (371 paragrafi 400–1000). Manca 835 (non stampato: usare 833).
  ATTENZIONE: i numeri 400–999 si sovrappongono a quelli del gioco base → spazio separato («mo:NNN»).
- Carte tedesche GE11–57 + mezzi US01/02/05/06 (foglio 505A94…png, 10×7, indice = CardID−1600):
  `tools/carte_moveout.json` (OCR + correzioni a occhio). Colonne con chiavi «1,2,4», «3,5», «1-2», speciali A/L/S/Y/Z.
  Carri: `equipaggio` {crew: IN PC WS DS par[4]} con `gruppi` del dado. GE51/53 un turno, assistono 50/52.
- Carte Condizione M9–M12: `tools/carte_excel.json` (Mov_M9_C1…; M10 ora estratta con xl_carte.py corretto).
- Regole delle missioni: pagine 4–5 del libretto (vedi /home/claude/moveout/mo.txt, testo -layout).

## Paragrafi per missione (raggiungibili dalle carte)
M9: 75 di missione + 59 d’azione · M10: 5 + 92 · M11: 31 + 18 · M12: 78 + 42.
Ordine scelto: M11, M10, M12, M9.

## Regole speciali
- M9 «The Dawn's Early Light»: mappa A (C1, Round continui, 14 tedeschi schierati, artiglieria US 2 colpi/turno IN 3
  con dispersione) poi mappa B (C2+, ingresso da nord Y1–Y19, top = ovest). Ruscello attraversabile.
  NB: nel libretto i testi di M9 e M10 sono mescolati nelle colonne: rileggere bene.
- M10 «Assault to Kill»: …
- M11 «The Fog of War»: mappa A, una sentinella in Y8, gli altri dormono fuori mappa (entrano da Y8 dopo 2 o 4 azioni,
  411/414), paracadutisti (409), 30? PV → controllare. Vista notturna?
- M12 «Through the Eye of the Needle»: mappa A, nord in alto, ingresso Q1–W1, ponte M12 distrutto, fiume solo dai ponti,
  vista 4 esagoni, A libero, B + 3 a caso prigionieri, 19 PV, 5 PV per prigioniero liberato uscito.
- Mezzi americani (US01 jeep, US02/US05 Sherman, US06 Claude): si muovono come i tedeschi con le carte Condizione.

## Piano tecnico
1. Spazio paragrafi «mo:»: `partita.chiave_par(n)` usa il prefisso se `missione.libro == "mo"`.
2. Azioni tedesche Move Out!: `scripts/motore/tedeschi_mo.gd` (esegui per numero), chiamato da `tedeschi.esegui`.
3. `tools/costruisci_missioni.py`: MISSIONI[9..12] con `libro: "mo"` e tedeschi da carte_moveout.json.
4. `tedeschi.colonna`: chiavi con virgole («1,2,4»).

## Stato (23 novembre 2026)
- Infrastruttura fatta: `libro: "mo"` → `partita.paragrafi` = base + data/paragrafi_mo.json (i numeri MO sostituiscono
  quelli base). Regole e operazioni MO in `scripts/motore/missioni_mo.gd`, azioni tedesche MO in
  `scripts/motore/tedeschi_mo.gd`. Builder: `tools/costruisci_moveout.py` (+ `tools/paragrafi_moNN.py`).
- M11 FATTA: sentinella, 409 paracadutisti con deriva/atterraggio (423/425), 411/414 risveglio con attese fuori
  mappa, C3 quando entra l’ultimo, 450→452/454/456/457 (463) →460, ghiaccio 431, neve 435, 441, 444, 447, 449,
  reazione Z (477, anche nei movimenti rossi), uscita ovest +2 PV. Test: tests/missione11.gd, simula 11, fuzzer UI.
  Limiti: −2 al tiro contro chi è prono nella neve non applicato; 36 movimenti rossi del foglio Excel scartati
  perché non adiacenti (il tedesco resta fermo).
- Colonne con virgole: non servono per M11; da fare per M9/M10/M12 se compaiono.
- M10 FATTA: C1 sulla mappa A con i mortai (unità «MOR» del giocatore, IN 3, due colpi per turno, diagrammi di
  dispersione), 14 tedeschi sulla riga 19 con 2 turni e vantaggio; fine C1 quando nessun tedesco attivo in mappa →
  `partita.cambia_mappa("B")` (anche nel salvataggio: `s.mappa`), squadra da Y1–Y19; 871 → 875…888 riattivano gli usciti;
  873 colpo pesante a caso; PV solo per perdite inflitte (pv_eliminato, pv_cattura ufficiali, pv_distrutto carri) e
  malus per uscite dal bordo nord e per chi resta in mappa a fine missione. Carri MO convertiti nel formato «carro»;
  azioni 919–931, 968–973 in tedeschi_mo.esegui_carro. Limiti: 893 lo Sherman lo comanda il giocatore (come in M8);
  980 senza piani degli edifici.
- M12 FATTA: prigionieri iniziali (B + 3 a caso, stato «dorme», senz’armi), Claude (unità J, pistola + coltello
  `knife` in tabelle), chiatta (modello «chiatta», canoa da 10, non si buca) in M12 dopo il 433, uscita da O19 → 465
  mappa B in A6; sentinella 11 (terne di paragrafi), villaggio (647–681), 682 → 487 galleria (G13 + linea H12–R7,
  invisibili ai tedeschi, solo paragrafi T 976/977, botole N9/R7), 687–690 generale SS, 692 prigionieri legati
  (slegare = un’azione), faro 944–948, partigiano 947, 949/694. Fine: dalla C3 quando l’ultimo esce da A1–A19 sulla
  mappa B; +5 PV per compagno liberato uscito; incapacitati della C1 senza malus.
  Limiti: 474 si sceglie sempre di aprire il fuoco; piani degli edifici non rappresentati; filo spinato (497/600/604)
  non raggiungibile dalle carte e non implementato.
- PIANI DEGLI EDIFICI (tutte le missioni): l’unico edificio a due piani di Ambush! e Move Out! è il campanile di S13
  sulla mappa B (`mappa_b.json` «campanile» → `terreno.torri`). Campo `piano` delle unità (0/1, `partita.piano(x)`):
  linea di vista dal piano superiore a quota +1 e senza muri; il campanile blocca le linee di livello 2; tra i due piani
  non ci si vede né ci si spara né ci si assalta; granate su/giù come esagono adiacente, esplodono su un piano solo;
  scale: 1 PM in piedi nei Round, libere nelle Operazioni (`cambia_piano`); i tedeschi scendono pagando 1 PM.
  Paragrafi: base 069/496/471/477/636 (`al_piano`), 265 e MO 980 (`scala_tedesco`), MO 651/652/898, 969, faro 948.
  Test: tests/piani.gd.
- M9 FATTA: razzi illuminanti (400/408/413/419 → fuoco nascosto 405/410/417/418 → C2), sentinelle 20/40/41
  (terne → C3), filo spinato (497/600/604: +1 PM e proni nei Round, 0 = ferito uscendo, la carica lo apre), casa
  che crolla (601), tedesco 21, bunker S17 e W15 (6 PV, già nel motore), Jagdpanther immobile in U16 (GE12, carro
  con «immobile», squarcio 668 → l’equipaggio si arrende), alba 874 (vista 10, C4), pieno giorno 883 (C5), radio portata
  da A (25% di rompersi se ferito), 885 colonna chiamabile con la radio (scelta) o 889 obbligata, colonna 887 =
  Sherman Z + jeep con J e K comandati dal giocatore, +5 PV per mezzo uscito da Y8, contrattacco 892 coi Panzerfaust
  (823–827 anche come riferimenti di movimento), Panzerbüchse (806/807/809), azioni MO 803–821, 901–904, 932–933.
  Limiti: la colonna la comanda il giocatore; «assiste» dei Gioventù hitleriana non gestito; razzo senza segnalino 2D.

# Purple Heart (missioni 13–18)

## Dati
- Carte Condizione: OCR delle 26 carte del mod TTS (`tools/letture/m13_c1.json`…), riferimenti rossi riletti
  (`/home/claude/strumenti/rossi2.py`) e controllati a vista; la carta 6 della missione 18 è trascritta a mano
  (correzioni in `tools/correzioni_carte.json`). Uscita: `data/carte/missione13..18.json`.
- Paragrafi inglesi: `tools/paragrafi_ph_en.json` (OCR del libretto; mancano per scelta del libretto 636, 637, 647…).
- Carte tedesche e dei mezzi: `tools/carte_ph.json` (tutte le 60: GE04–GE69 e US01–US05), costruito da
  `tools/carte_ph_da_programma.py` unendo il database del programma d’aiuto «ePurpleHeart» (Purple_Heart.zip, FileMaker 5,
  letto con `tools/fm5.py`), il foglio del mod TTS (`tools/carte_ph_foglio.json`, OCR verificato) e le correzioni a vista
  dal foglio stampato bgg9583.pdf (PM, guida dei mezzi, carte con dati incompleti nel database).
- Le carte Condizione sono anche allineate ai dati del programma (`tools/carte_ph_programma.json`,
  `tools/allinea_carte_ph.py`, 77 correzioni). Testo dei paragrafi del programma: `tools/paragrafi_ph_programma.json`.
- Mappe: `tools/prepara_mappe_ph.py` (immagini nel reticolo del gioco, anche realistiche) e `tools/costruisci_mappe_ph.py`
  (terreno: `tools/terreno_c.json`, `terreno_d.json`, `terreno_e.json`, colore + correzioni a vista).
  Mappe del gioco: `C`, `AD` (A + mezza D, base navale), `BE` (B + mezza E, città). Muretti di pietra, scarpate e creste
  di C, D, E non sono ancora trascritti; i lati degli edifici sono tutti finestre.
- Nuovi terreni: acqua (vietata), spiaggia (2 PM), banchina, base dei sottomarini, serbatoi e monumento (pieni, bloccano la
  vista), vigna (come copertura, vietata ai mezzi a ruote: per ora solo costo 2 per i mezzi); muretto di pietra come lato
  («stonewall»: +1 PM, copre il soldato prono).

## Motore
- `missione.libro == "ph"`: si caricano `data/paragrafi_ph.json` (costruito da `tools/costruisci_ph.py` con i file
  `tools/paragrafi_ph<n>.py`), `scripts/motore/missioni_ph.gd` (op, test, agganci) e `scripts/motore/tedeschi_ph.gd`
  (paragrafi d’azione propri di Purple Heart).

## Missione 13 «Dispersi» (mappa A, poi A + mezza D = lettera «AD»)
- Lancio (regola atterraggio_ph): controllo automatico all’avvio, −2 PV per ogni soldato perso; nord-ovest del fiume
  tracciato in s.ph.nw_fiume (571 → 589).
- Condizione 1: sentinella 61 con due cani (pseudo-carte 91/92, colonna unica 391): 2 turni, corsa di 6 esagoni, attacco
  a dado (panico/ferito/incapacitato); 649 rianima un cane una volta.
- 495 → mappa AD: faro E11 (ruota in senso orario, illumina il cono di 120° in vista), antenna U14 (895: −10 PV),
  cannoni costieri W12/X12 (554/682 → 672: carica da demolizione nel deposito munizioni, +4 PV).
- Deposito della marina (607/526): esplosivi al plastico (2 a testa) — nei Round saltano all’inizio del secondo Round,
  nelle Operazioni quando nessun americano è entro un esagono; +2 PV per esagono di edificio, 616 per il deposito,
  725 per i serbatoi (incendio che illumina).
- Mezzi: 67/68 motosiluranti (modello eboat, solo acqua), 69 Panzer IV; 662 cattura della motosilurante; auto comando
  (713) e scialuppa (718, +10 PV uscendo a ovest; parte già sulla spiaggia in I18).
- Non gestiti: tiro ai cani (−3), cassa delle armi del lancio, treno (486), soldati «fuori di testa» (655/689), ritorno
  della sentinella 61 in E11 (648, 3–4), colpi al faro con le armi (si distrugge solo con un esplosivo).
- Il bot delle simulazioni non usa gli esplosivi: perde sempre, ma serve a cercare errori (0 in 20 partite).

## Missione 17 «Sul filo del rasoio» (mappe B + E, in alto è ovest)
- Avvio (regola fine_ponti_17): macerie negli edifici a ovest del fiume, 5 cariche gratis; ponti G11 (legno), J11 e R10
  (pietra, regola ponti_pietra). Niente PV per le attivazioni (pv 0 nel costruttore).
- Ponti (regola ponti_timer): sul ponte si piazzano le cariche (1 legno, 2 pietra), poi «Timer: salta tra N Round» (1–4,
  s.ph.timer_ponti, esplode all’inizio del Round) o, nelle Operazioni, «Innesca» (salta appena nessun americano è entro un
  esagono). Il 759 fa gettare una carica al tedesco sul ponte. Non gestiti: scendere sotto il ponte e le sue regole di tiro.
- Treno (471/486, s.ph.treno): locomotiva + 3 vagoni + cisterna su BINARIO_BE (Y5 → A13), 12 esagoni all’inizio di ogni
  Round; travolge chi non supera il controllo di percezione; deraglia sul ponte G11 distrutto (vagoni rovesciati: 595,
  +10 PV una volta); uscita o deragliamento → Condizione 3; i Round restano obbligati finché il treno è in mappa. Non
  gestiti: binari fatti saltare e treno colpito dal bazooka, scivolamento dei vagoni.
- Motocicletta 48/49 (559) e auto comando 52/53 (566) con colonna_ph senza reazione W; corriere SS 53: fuori combattimento
  lascia la borsa sigillata (oggetto documenti con par 652: +5 PV a chi la raccoglie).
- Paragrafi d’azione di Purple Heart diversi dal gioco base (341–363, 624–661, 710–785, 804, 834, 846–919): in
  tedeschi_ph.esegui. Il 23 non ha colonne di Condizione: assiste la mitragliatrice del 22, poi reazione X, un turno per Round.
- Fine (Condizioni 3–4): 1. niente tedeschi attivi e tutti i ponti minati o distrutti (o finite le cariche): tutti e tre
  valgono 10 PV; 2. ponti distrutti e nessuna linea di vista; 3. nessun americano attivo. +1 PV per tedesco fuori combattimento.
- Correzioni: la carta C4 rimandava a 634 (evento del faro della Missione 13): sostituito con 639; nel 649 della Missione 13
  il rimando corretto è 485 (non 486, che è il treno).

## Missione 14 «Ricognizione in forze» (mappa C, in alto è ovest)
- Ingresso in Y7 sulle due jeep (regola jeep_caricate: vjeep1/vjeep2, quattro uomini ciascuna); radio portata dal
  sergente A (regola radio_portata_ph: presidiata finché A è attivo in mappa).
- Condizione 1: 618 (radio, messaggio diverso a ogni lettura), mine (539), trappole (581), relitti, 331 (massacro della
  squadra 2, macerie in J8); 340/684 → 348/690/355 → 541/562 (superstiti J e K incapacitati, op superstiti: +2 PV se
  trascinati fuori) → 362/368 (ripiegamento: +2 PV per soldato uscito dal bordo nord Y1–Y19; anche trascinando) e
  Condizione 2.
- Condizione 2: artiglieria (383 a due dadi, 544, 592, 555 con dispersione semplificata attorno a K9), 378 (ponte S9).
- Condizione 3: 398 → 17/35 in U19; eventi 462/467/476 → 438 (40–42), 445 (Panzer IV 43), 453 (44–45), 575.
- Carta C3: W18 rimandava a 449 (paragrafo della Missione 16): corretto in 499 (reazione L) nel costruttore.
- Paragrafi dei carri di Purple Heart (900–911, 921–929) riscritti in tedeschi_ph.esegui_carro: sono diversi da quelli
  del gioco base (valgono anche per il Panzer IV della Missione 13). 909: «a est del fiume» = riga più alta del ruscello.
- Non gestito: la mitragliatrice media montata sulla jeep (non c’è l’acquisto dell’equipaggiamento).

## Missione 15 «Ritorno a casa» (mappa C, in alto è ovest)
- Avvio (regola diga): letto N6–Y15 asciutto = copertura (s.modifiche "cover", S9 resta ponte), diga N5 "clear" con
  terreno.accessi {N5: [O5, M6]}; tabella delle munizioni consumate (regola munizioni_consumate) tirata in automatico.
- Condizione 1: relitti (s.punti), caduti da perquisire (leggi_entrando + bottino a terra), 491 → 498/505; 505 annota la
  collina: un americano su quota 4 → 519 → 532 (Condizione 2, chiuse 479) o 550 (Condizione 3).
- Chiuse (azione «Apri le chiuse»): 4 azioni nei Round, un controllo eventi nelle Operazioni → 565: piena di 4 esagoni
  all’inizio di ogni Round (approssimazione: il libro dice ogni turno), allaga (water), travolge, crolla il ponte S9;
  i Round restano obbligati finché la piena è in mappa; uscita → 542 (Condizione 4, +5 PV).
- Colonna (593/598, op colonna_ph): motociclette (modello moto, velocità ipotizzate 5/10), Kübelwagen 8–11, auto comando
  16, 12, 14, 15; reazione W (613 autisti, 626 passeggeri, 620 scendono); primo turno 814/840; a bordo ignorano
  l’autoconservazione (ignora_s_veicolo). 598 arriva al secondo Round al posto del controllo eventi o prima se 4 e 6 sono
  fuori combattimento. 698/709: −5/−3 PV per tedesco uscito, fine quando non ci sono tedeschi attivi in mappa, niente PV
  persi per gli incapacitati. Feldmaresciallo 12: cattura +15 PV; guardie 14/15 con 635/640/650/665/680.
- Non gestiti: Jagdpanther utilizzabile (599), le motociclette che investono i soldati (600).

## Missione 16 «In guardia» (mappa C)
- Schieramento: almeno due soldati entro 10 esagoni da ogni angolo, nessuno nel deposito (U15, U16, V12–V15, W13–W15).
- Battelli d’assalto (432): s.ph.barche; i tedeschi a bordo hanno `barca`; 522 muove il battello (lento 4, veloce 6) seguendo
  i paragrafi «sbarca/il battello entra»; 531/538 fanno sbarcare. Non gestiti: −2 al tiro dal battello, colpi al battello.
- Esplosivi (619): il commando fermo piazza un esplosivo (lato 2); il giocatore lo disinnesca in due azioni (+2 PV);
  638/651/660/669/679 per le esplosioni a tempo; deposito (414): ogni esplosione nel deposito e i tiri americani mancati
  (0–3) fanno saltare il carburante; fine: +1 PV per esagono intatto, −2 per esagono distrutto.
- «Al prossimo Round» (al_prossimo_round): l’arrivo del secondo gruppo; «secondo turno del Round 1» è approssimato col Round 2.
- Non gestiti: camion della colonna (717, US 05), soldato J della carta US 04 (501), regola «in allerta», entrata nei
  depositi in fiamme (414.2), seconda jeep.

## Missione 18 «Il mattino dopo» (mappe B + E, in alto è est)
- Avvio (regola missione_18, scripts/motore/missione18_ph.gd = ph.m18): squadra in K15, un soldato ferito a caso, radio
  portata dal sergente A (radio_portata_ph), munizioni consumate (ph.munizioni_consumate), macerie B11–P18, guadi I11, O10,
  V11 (s.guadi; regola guadi_veicoli: i mezzi li passano con 3 PM; il fiume senza guado ferma i mezzi). «A est del fiume» =
  righe sopra il fiume (regola est_in_alto, vale anche per 909/914).
- Condizione 1: 507 fa partire i Round senza tedeschi (tutti consapevoli) e al Round 2, al posto degli eventi, il 512: Panzer
  57–60 fuori mappa accanto ad A5 (fuori_mappa_ph: non si vedono e non vedono; entrano al primo turno pagando l’esagono,
  veic.mp_ingresso). 699/705 → 714/719/724/730 (carri in mappa, tutti consapevoli). 642/691: Kübelwagen distrutta con
  l’ufficiale (653, +2 PV; scelte: sigaretta 663 → PC → 677 Luger / 673 esplosione; rifiuto 677; resa = fine). 642 sfonda
  il muro D16/E17 (terreno.muri_sfondati). 574/621 → 585 → 599 Jagdpanther da servire: due soldati salgono («Sali sul
  Jagdpanther»), cannone (4 colpi, scarico, si carica con «Carica il cannone») e mitragliatrice di scafo con abilità −1,
  solo verso est (60°), servono due serventi; il Jagdpanther non è mai un bersaglio (vede_unita). s8: 26 paragrafi
  (tools/caduti_ph18.json) con semicingolato, tedeschi caduti da perquisire (c18: fucile + caricatore, granata 0–4) e il
  310; s.da_leggere accetta più paragrafi separati da virgola.
- Condizioni 2–4: 749/583/703/755 (granatieri 19, 25–27, 33, 34 con Panzerfaust: 806/819/831/836/837/841, 843–854 secondo
  27 e 34, 861 reazione A che recupera l’arma di un caduto in tre turni, 882–892 reazione B per Condizione); 762 tre Sherman
  (carte US 01–03 in missione.carri_us) fuori mappa accanto a B19/F19/K19/N19/R19 (ingresso scelto dal giocatore con il
  pulsante «Sherman AA: entra da …»), guidati dai paragrafi 939–969 (turni_sherman in _flusso, all’inizio della casella
  americana; numero d’azione proprio) finché il 318 (312 con la radio presidiata) non li mette ai tuoi ordini; i Round
  restano obbligati finché uno Sherman guidato è in gioco. 981: un’arma tedesca finisce le munizioni (reazione A se non ne
  restano, il Panzerfaust no). Panzer IV: 909/914/917/921/932/934/935/937.
- Decisione (306/990 dopo 301/986): all’inizio del Round seguente, al posto degli eventi, la pausa di inizio Round
  mostra «Tieni la posizione (992)» e «Ripiega verso ovest (994)» e non si prosegue senza scegliere. 992: Condizione 5,
  36 PV, +1 PV per americano (soldato o mezzo) a est del fiume, fine senza tedeschi attivi, niente perdite per gli
  incapacitati. 994: Condizione 6, 30 PV, uscita dal bordo ovest A19–Y19 (+2 PV, −2 per tedesco), fine senza americani.
- Test: tests/missione18.gd, simula 18, tests/visivi/missione18_ui.gd.

