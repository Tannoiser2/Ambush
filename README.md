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

Tema da campo del 1944: verde oliva, carta dei rapporti, caratteri stampigliati (Stardos Stencil) per i titoli e Oswald per tutti i testi da leggere; la macchina da scrivere (Special Elite) resta solo per l’ordine di missione. Pedine ricavate dalle sagome originali del gioco.

L’interfaccia è costruita per far capire sempre **in che fase si è, chi agisce, perché e con quale esito**:

- **Schieramento iniziale**: una partita nuova comincia disponendo i soldati sul margine nord (A1–J1). Si possono spostare a piacere; nessuna carta viene letta e nessun nemico si attiva finché non si preme «Inizia la missione». Chi resta fuori può entrare più tardi.
- **Linee di vista**: il pulsante sulla mappa le mostra o le nasconde (linea dal soldato scelto all’esagono puntato e linee di chi vede chi).
- **Barra delle fasi** sotto il titolo: Operazioni, oppure Round n con Consapevolezza, Evento, Iniziativa, le quattro caselle dei turni (2 turni e 1 turno, prima chi ha il vantaggio) e Fine Round. La fase in corso è accesa, quelle fatte hanno la spunta, quelle saltate sono barrate.
- **Riproduzione a passi**: ogni comando del motore è diviso in passi (una fase, un tedesco, un’azione del giocatore). A ogni passo la **scheda dell’azione** sotto la mappa mostra *chi agisce* (pedina, posizione, turno), *perché* (per i tedeschi la tabella della loro carta con riga del dado e colonna evidenziate, il numero d’azione e il testo del paragrafo; per le fasi la regola e i dadi) e *cosa succede* (calcolo del tiro con base e modificatori, dadi, danni). «Continua» (Spazio) passa al passo successivo; «Modo: automatico» scorre da solo; «Velocità» e «Salta tutto» accorciano.
- **Pannelli allineati**: pista dei Round, scheda della squadra e barra delle fasi mostrano lo stato del passo che si sta guardando, non quello finale.
- **Mappa**: pedine dello stesso esagono affiancate; inconsapevoli scuriti con un punto di domanda, pallini per i turni rimasti, fascia PANICO; linee di tiro (gialle americane, arancioni tedesche) che restano con l’esito scritto sul bersaglio fino al comando successivo; scie dei movimenti; linee tratteggiate per chi vede chi (rosse dal soldato scelto, azzurre dal tedesco di turno); probabilità di colpire accanto a ogni bersaglio valido.
- **Comandi** raggruppati (Postura, Movimento, Fuoco, Assalto, Comando, Equipaggiamento, Fine), con la riga di aiuto che dice che cosa toccare.
- **Mouse e tocco**: rotella o pizzico con due dita per lo zoom, trascinamento (anche con un dito) per spostare la mappa, tocco su un esagono per sceglierlo e leggerne le informazioni.
- A destra la **pista dei Round** con i dadi dell’iniziativa, gli **obiettivi**, i **tedeschi incontrati** (tocca per la carta) e il **rapporto** con tutti i paragrafi e i tiri. «Legenda» in alto spiega tutti i segni.

## Struttura

```
scene/principale.tscn          scena principale
scripts/motore/esagoni.gd      geometria della griglia
scripts/motore/terreno.gd      terreno, costi di movimento, linea di vista
scripts/motore/tabelle.gd      tabelle dello schermo del giocatore e pista dei Round
scripts/motore/partita.gd      Operazioni, Round, paragrafi, combattimento, punteggio, salvataggi
scripts/motore/tedeschi.gd     comportamento dei tedeschi
scripts/ui/                    interfaccia: tema, mappa, pista, barra delle fasi, tabella della carta, schermata principale
data/                          dati generati: paragrafi, missione, mappa
tools/costruisci_dati.py       genera data/ dalle trascrizioni verificate
tests/                         verifiche e simulazione automatica di partite
assets/reference/              materiale originale di consultazione (escluso dalla build)
```

## Verifica e build

```
python3 tools/costruisci_dati.py
python3 tools/controlla_glifi.py                                  # ogni carattere esiste nei font
godot --headless --path . --script tests/calcola_alture.gd
godot --headless --path . --script tests/verifica.gd
godot --headless --path . --script tests/schieramento.gd
godot --headless --path . --script tests/simula.gd -- 50 1      # 50 partite simulate sul motore
xvfb-run godot --path . --script tests/visivi/tocco.gd           # gesti a tocco sulla mappa
xvfb-run godot --path . --script tests/visivi/partita_ui.gd -- 2 1   # partite intere attraverso l’interfaccia
xvfb-run godot --path . --script tests/visivi/scatti.gd -- 7 1600 900 /tmp/ambush_scatti   # schermate a ogni passo
godot --headless --path . --export-release Web build/web/index.html
```

`scatti.gd` accetta seme, larghezza, altezza e cartella: con `1024 768` produce le schermate in formato iPad.

## Pubblicazione

Solo su richiesta: «Run workflow» a mano su GitHub, oppure un commit su `main` con `[pubblica]` nel messaggio. Un push normale non pubblica.

## Regole

La sequenza dei Round (6/1), il comando (6/3), il panico (6/4), la consapevolezza (6/5), le attivazioni durante i Round (6/6), le azioni (6/7) e il comportamento dei tedeschi (6/8, 6/9) sono stati riletti sul regolamento: numero d’azione tedesco tirato a ogni turno in cui i tedeschi agiscono e valido per tutti, tedeschi in ordine alfabetico, parità d’iniziativa ai tedeschi, autoconservazione nello stesso esagono o adiacente. Le tabelle dello schermo del giocatore (tabella delle armi con gittate, inceppamenti, danni e munizioni; modificatori del tiro; granate e cariche; assalto; costi di movimento; disinceppamento; pista dei Round con i numeri rossi) sono state confrontate casella per casella con la scansione originale: coincidono. Dove la tabella ridisegnata del modulo TTS differisce dall’originale (macchia, bersaglio prono: −3 invece di −2) vale l’originale.

Non sono implementate, perché la Missione 1 non le usa, le armi di squadra, i veicoli e la carica da demolizione piazzata con ritardo.

## Note sulla mappa

Terreno e lati speciali vengono dalla revisione manuale della mappa; le quote ancora presunte sono state ricavate dagli esagoni vicini e dal colore di fondo della mappa (livello 3 nell’angolo sud-est, come indicato dal briefing). Nessun esagono dell’altura vede letteralmente tutte le 25 caselle di strada (gli edifici K13–L13 e le scarpate ne coprono qualcuna): come suggerisce la regola 8/3, vale come obiettivo l’esagono dell’altura con la vista più ampia sulla strada (T12), evidenziato in mappa.

Le immagini e i testi del gioco originale restano dei rispettivi titolari e sono usati per uso personale.
