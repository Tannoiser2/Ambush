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
- Carte tedesche: `tools/carte_ph.json` (GE04–GE40 dal foglio del mod). **Mancano i tedeschi 41–69 e le carte dei mezzi**:
  il mod TTS non li contiene (servono alle missioni 13, 14, 17, 18).
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
