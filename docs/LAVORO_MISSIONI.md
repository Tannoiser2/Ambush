# Missioni 2-8: stato dei lavori

Richiesta di Stefano: tutte le 8 missioni del gioco base, poi le espansioni. Pubblicare solo quando lo dice.

## Fatto
- Carte Condizione M2-M8: `data/carte/missioneN.json` (chiave = numero condizione; `esagoni`, `evento` 0-18,
  `movimenti` rossi: esagono / paragrafo / USCITA). Costruite da `tools/costruisci_carte.py` con le letture OCR
  (`tools/letture`), le correzioni viste a occhio (`tools/correzioni_carte.json`) e `tools/rossi_carte.py`.
  Valori nuovi: `LAND` (M4, atterraggio paracadute), `XXX` (M8, esagono proibito).
  MANCA la carta Missione 4 Condizione 4 (chiesta a Stefano). `m4_c4.png` è in realtà M3 C4.
- Testo inglese di tutti i paragrafi (OCR del libretto + pagine errata): `tools/paragrafi_en.json`
  (controllare sulle scansioni quando il testo è troncato: es. 008, 101, 119).
- Mappa B: `data/mappa_b.json` (terreno a vista, livelli dal colore, creste/scarpate/porte/finestre approssimate),
  `assets/maps/mappa_b.jpg` e `mappa_b_realistica.jpg` nel reticolo del gioco (`tools/prepara_mappa_b.py`).

- Motore multi-missione (fatto): `Partita.new(n)`, `imposta_missione`, `data/missioneN.json` generati da
  `tools/costruisci_missioni.py` (MISSIONI = testi italiani; tedeschi da `tools/carte_tedeschi.json`;
  carta 19 Kübelwagen = autista 19 + ufficiale 119). Paragrafi: `tools/paragrafi_mN.py`, uniti da
  `tools/costruisci_dati.py` in `data/paragrafi.json` (prima esegui costruisci_dati, poi costruisci_missioni).
  Menu «Nuova partita» = elenco missioni; salvataggi `user://ambush_missioneN.json`.
- Veicoli: `scripts/motore/veicoli.gd` (stato in `s.veicoli`; occupanti con campo `veicolo`; tabella dei colpi
  delle auto, incidenti, guida tedesca lungo i riferimenti rossi, jeep americana con MG montata).
- Missione 2 FATTA (test `tests/missione2.gd`, `tests/simula.gd -- 6 1 2`, scatti `tests/visivi/missione2_ui.gd`).
  Semplificazioni: equipaggiamento pre-generato (niente acquisti); Me-109: tiro all’aereo semplificato.

- Missione 3 FATTA (test `tests/missione3.gd`, `tests/simula.gd -- 6 1 3`, scatti `tests/visivi/missione3_ui.gd`).
  Regole in `missione.regole`: `vista` (terreno.limite_vista; 021/022 la cambiano in `s.vista`), `fiume`
  (ruscello impraticabile salvo ponti), `niente_controlli_round`, `pv_esagoni`, `max_edifici`, `jeep`, `radio`,
  `deposito`. Ponti in `s.ponti` (distrutto, attraversato, controlli/4, cariche, carburante): azioni
  `azioni_ponte`/`azione_ponte` (paragrafo 1000), ponte distrutto = modifica "stream". Staffette J (carta 01,
  178) e K (carta 08: 276/281/263). Carri: `veicoli.gd` (Panzer IV 55, punti equipaggio, cannone, MG).
  Semplificazioni: la radio resta nell’esagono del comandante allo schieramento; la jeep di squadra viene
  parcheggiata automaticamente nell’esagono scoperto accanto alla strada più vicino alla squadra.

- Missione 4 FATTA (test `tests/missione4.gd`, `tests/simula.gd -- 6 1 4`, scatti `tests/visivi/missione4_ui.gd`).
  Lancio: `_lancio`/`_scendi`/`_atterra` (deriva NO/SO, carta C1 «LAND», tabella d’atterraggio), attivazioni
  annotate in `s.attivazioni_lancio` e un solo vantaggio scelto (C2 il migliore per gli USA, C3 per i tedeschi).
  Paracadute `a.paracadute` (2 azioni nei Round, tolto nelle Operazioni); cassa `s.cassa` (apri → oggetti a terra);
  disinnesco ponti `disinnesca_ponte` (4 turni → catturato); notte vista 5 + razzi (`s.razzi`, illuminati r=3).
  Kübelwagen «vk» del generale (470, 554, 055). Carte tedesche: `primo_turno`, `pv_cattura`, `reazione_par`.
  MANCA la carta C4: si usa la C5 (`sostituita: 5`). Equipaggiamento pre-generato (squadra_armi/cassa).

- Missione 5 FATTA (test `tests/missione5.gd`, `simula.gd -- 6 1 5`, scatti `tests/visivi/missione5_ui.gd`).
  Guadi `s.guadi` (terreno.guadi), installazioni `s.installazioni` (carica lanciata nei Round, `demolisci` nelle
  Operazioni), documenti `a.documenti` (PV all’uscita, a terra se cade), V-2 (639), auto comando 13 con
  scienziati 24/42 e ufficiale 7 (`_auto_raccoglie`, `_sali_su_auto`). Carte: `veicolo`, `pv_veicolo`,
  `pv_eliminato`, `pv_uscita_prigioniero`. Equipaggiamento pre-generato.

## Prossimo passo: Missione 6 «Gita in canoa fino al Vallo occidentale» (mappa A, nord in alto)
- Regole (regolamento p. 37–38, testo in /home/claude/aid/rules.txt): fiume H1–O19 attraversabile solo sui ponti o in
  canoa; notte (vista 5, escluso il proprio esagono); 4 canoe (2 soldati + 2 caselle di porto, o 3 soldati),
  si muovono solo sul fiume (4 PM nei Round, 1 per esagono; un esagono per volta nelle Operazioni con controllo
  di paragrafo), servono 2 soldati attivi a bordo; spiaggiare = entrare in un esagono di terra adiacente (1 PM);
  salire/scendere solo a canoa spiaggiata (1 PM / 1 azione); se un tiro tedesco manca, dado pari = canoa forata
  (deve spiaggiare nel turno successivo o affonda). Ingresso in H1 in canoa. Crateri G7 K8 L12 L15 K18 M17,
  macerie K13 L13. Livelli c1 0–1, c2 0–3, c3 0–5, c4 0–7.
- Bunker: esagono come edificio con finestre su tutti i lati e una porta (lato indicato dal paragrafo
  d’attivazione); tabelle dei colpi fronte/porta (muro H, feritoia M/H, porta L = sfondata, equipaggio);
  +2 al tiro contro il bunker; distrutto = occupanti originali fuori combattimento E (macerie O carica esplosa
  dentro). 6 PV per bunker, vittoria 12 PV; fine quando non ci sono americani attivi in mappa.
- Paragrafi mancanti: 90 (561–599, 702–786, 872–899). Attenzione: la carta C3 cita s4:738 e s4:739, ma 738 è
  già un paragrafo della M4 (controllare sulla scansione: forse è un’altra cifra).
- Azioni tedesche ancora da scrivere: 732, 770, 841–843, 926–932 (servono a M6–M8).

## Da fare
1. Motore multi-missione: `data/missioni/N.json`, scelta missione nel menu, mappa A/B, salvataggi per missione,
   codice M1 (R15, T8, K13...) spostato dietro `missione.id == 1`.
2. Paragrafi per missione (testo italiano + ops), come `tools/paragrafi_m1.py`; tedeschi dalle carte
   (`Cards_ready_to_print_v1.5.pdf`, 75 carte + veicoli).
3. Regole speciali: M6 canoe, bunker, notte; M7 jeep, mine anticarro, ingresso per evento casuale, mappa A sud in alto;
   M8 Sherman (entra in A6), blocchi stradali, XXX.
