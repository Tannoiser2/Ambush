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

## Da fare
1. Motore multi-missione: `data/missioni/N.json`, scelta missione nel menu, mappa A/B, salvataggi per missione,
   codice M1 (R15, T8, K13...) spostato dietro `missione.id == 1`.
2. Paragrafi per missione (testo italiano + ops), come `tools/paragrafi_m1.py`; tedeschi dalle carte
   (`Cards_ready_to_print_v1.5.pdf`, 75 carte + veicoli).
3. Regole speciali: M3 nebbia 6 esagoni, niente controlli in Round, jeep, deposito carburante L10;
   M4 lancio (deriva, LAND, tabella atterraggio, paracadute), notte 5, sminare ponti; M5 guadi, documenti;
   M6 canoe, bunker, notte; M7 jeep, mine anticarro, ingresso per evento casuale, mappa A sud in alto;
   M8 Sherman (entra in A6), blocchi stradali, XXX.
