# Ambush! — edizione digitale italiana

Versione digitale in Godot 4.7 di **Ambush!** (Victory Games, 1983), il wargame tattico in solitario a paragrafi.
Questa edizione contiene la **Missione 1 · Sangue a Saint-Michaux** (*Bloody St. Mick*), giocabile dall’inizio alla fine.

Si gioca nel browser da GitHub Pages; la partita si salva da sola sul dispositivo. Ambush! è un gioco solitario: non c’è modalità online.

## Cosa c’è

- **Operazioni**: ingresso dal margine nord (A1–J1), movimento singolo o di gruppo, controlli di paragrafo sulle quattro carte Condizione della missione, segnalini Evento, controlli Evento con due dadi, avvistamenti s0–s9, cambi di Condizione con i controlli negli esagoni occupati.
- **Tutti i 113 paragrafi di missione e di movimento** raggiungibili dalla Missione 1 e **i 33 paragrafi d’azione** delle sette carte tedesche, verificati sulle scansioni originali e tradotti in italiano. Ogni paragrafo è anche uno script eseguito dal motore (`tools/paragrafi_m1.py`).
- **Round** completi (regola 6): consapevolezza nei Round 1 e 2, fase Evento, iniziativa con vantaggio, pista dei Round originale (2 turni, 1 turno, panico, numeri rossi e comando), turni ceduti dai comandanti, allerta, attivazioni durante i Round, soldati fuori mappa (6/10), cambi di Condizione durante i Round, fine Round con panico e ritorno alle Operazioni.
- **Tedeschi automatici**: carte originali (colonne di Condizione, reazioni speciali A/B, autoconservazione S), numero d’azione tedesco, tutti i paragrafi d’azione usati in missione (tiro migliore, bersaglio più vicino/più facile, tiri rapidi, assalto, granate, cessione dei turni, resa, movimento evasivo e rimozione), movimento con i **riferimenti rossi** della carta della Condizione 4.
- **Combattimento**: tiro mirato e rapido con tabella delle armi, modificatori di terreno e postura (anche edifici), inceppamenti, munizioni, raffiche delle armi automatiche su più bersagli, bazooka; granate e cariche con deviazione (diagrammi A e B) e reazione dei soldati; assalto e carica d’assalto, cattura e prigionieri; panico, ferite, incapacitazione e morte; disinceppamento; campi minati, artiglieria, cecchino nascosto, granata difettosa.
- **Linea di vista** (regola 8) su tutta la mappa A: quote 1–3, boschi, macchie, edifici con porte e finestre, creste e scarpate.
- **Missione**: soldato K da mettere in salvo, Typhoon abbattuto e pilota britannico (carta US 05), ufficiale 34 con passaggio alla Condizione 4, punteggio finale con i due modi di concludere la missione.

## Interfaccia

Tema da campo del 1944: verde oliva, carta dei rapporti, caratteri stampigliati (Stardos Stencil), da macchina da scrivere (Special Elite) e Oswald per le etichette. Pedine ricavate dalle sagome originali del gioco.

- a sinistra la **scheda della squadra** (clic per scegliere, Maiusc/Ctrl+clic per un gruppo nelle Operazioni);
- al centro la **mappa A** originale: rotella per lo zoom, tasto destro per spostarla, passaggio del mouse per terreno, linea di vista dal soldato scelto e probabilità di tiro;
- sotto la mappa i **comandi** del soldato scelto;
- a destra la **pista dei Round**, gli **obiettivi**, le **carte dei tedeschi** attivati e il **rapporto di combattimento** con tutti i paragrafi letti e i tiri di dado.

## Struttura

```
scene/principale.tscn          scena principale
scripts/motore/esagoni.gd      geometria della griglia
scripts/motore/terreno.gd      terreno, costi di movimento, linea di vista
scripts/motore/tabelle.gd      tabelle dello schermo del giocatore e pista dei Round
scripts/motore/partita.gd      Operazioni, Round, paragrafi, combattimento, punteggio, salvataggi
scripts/motore/tedeschi.gd     comportamento dei tedeschi
scripts/ui/                    interfaccia (tema, mappa, pista, schermata principale)
data/                          dati generati: paragrafi, missione, mappa
tools/costruisci_dati.py       genera data/ dalle trascrizioni verificate
tests/                         verifiche e simulazione automatica di partite
assets/reference/              materiale originale di consultazione (escluso dalla build)
```

## Verifica e build

```
python3 tools/costruisci_dati.py
godot --headless --path . --script tests/calcola_alture.gd
godot --headless --path . --script tests/verifica.gd
godot --headless --path . --script tests/simula.gd -- 50 1      # 50 partite simulate
godot --headless --path . --export-release Web build/web/index.html
```

`tests/visivi/scatti.gd` produce schermate dell’interfaccia (serve un display, per esempio `xvfb-run`).

## Note sulla mappa

Terreno e lati speciali vengono dalla revisione manuale della mappa; le quote ancora presunte sono state ricavate dagli esagoni vicini e dal colore di fondo della mappa (livello 3 nell’angolo sud-est, come indicato dal briefing). Nessun esagono dell’altura vede letteralmente tutte le 25 caselle di strada (gli edifici K13–L13 e le scarpate ne coprono qualcuna): come suggerisce la regola 8/3, vale come obiettivo l’esagono dell’altura con la vista più ampia sulla strada (T12), evidenziato in mappa.

Le immagini e i testi del gioco originale restano dei rispettivi titolari e sono usati per uso personale.
