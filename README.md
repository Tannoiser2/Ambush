# Ambush! — edizione digitale italiana

Progetto Godot 4.7 per la missione base 1, «Sangue a Saint-Michaux». Aprire `project.godot` con Godot o eseguire `godot --path .`.

## Stato effettivo

La versione 0.3 permette ingresso da A1–J1, movimento singolo e di gruppo durante le Operazioni, postura e trascinamento dei feriti con evacuazione dal margine nord. Controlla i riferimenti neri delle quattro carte Condizione della missione 1, eventi, avvistamenti e 112 paragrafi tradotti. Registra campi minati permanenti, risolve i controlli di percezione all’ingresso e applica i danni da granata al chiuso della tabella originale. Il colpo d’artiglieria del paragrafo 011 ora uccide i soldati nell’esagono e crea un cratere o macerie in un edificio; il terreno modificato resta nel salvataggio e partecipa alla LOS preliminare. Gestisce la perdita o scelta dell’equipaggiamento dopo una ferita, la penalità di 2 PV per ciascun soldato ucciso o incapacitato, il premio di 3 PV per il soldato K e il soccorso del pilota britannico con la sua carta e i relativi PV. Le schede dei tedeschi attivati forniscono caratteristiche, PV di attivazione e riferimenti della tabella azioni. I 31 riferimenti d'azione presenti in queste schede, più il riferimento 830 richiamato da uno di essi, sono tradotti in italiano ma non ancora eseguiti dal motore. Il diario mostra i tiri e i motivi delle diramazioni. Salva automaticamente sul dispositivo. Ambush è progettato esclusivamente per il gioco in solitario; non include modalità online.

Questa **non è una missione completa**. Sono disponibili Operazioni, quattro carte Condizione, 112 paragrafi italiani rivisti, una parte della LOS, la pista dei Round, il movimento americano e il primo caso di tiro mirato verificato. Mancano ancora molti paragrafi e riferimenti rossi, aperture degli edifici, quote gialle, gran parte del combattimento, movimenti e attacchi tedeschi, soccorso del pilota nei Round e parte del conteggio finale dei PV. Le classi di terreno sono candidate per 475 esagoni; M5 è verificato visivamente per il combattimento, mentre le altre quote gialle e molte aperture restano indeterminate. Il motore sospende le regole che non può applicare in modo affidabile. L'OCR inglese in `data/source` è una fonte da verificare sulle scansioni, non testo pronto per il gioco.

Le attivazioni che si verificano mentre sono già in corso i Round registrano il nuovo tedesco e gli eventuali PV senza riavviare il primo Round né modificare vantaggio e consapevolezza già determinati. La collocazione del rinforzo sulla pista resta sospesa finché non sarà implementata la sequenza dei Round (regola 6/6).

Quando il cursore è sopra un tedesco attivo durante i Round, la scheda mostra un'anteprima del tiro mirato del soldato selezionato: LOS preliminare, motivo di un eventuale blocco e probabilità stimata dalla tabella dell'arma, distanza, abilità, terreno, postura e ferita. È un ausilio di pianificazione: non tira dadi, non consuma munizioni e non risolve il combattimento. Edifici e terreni senza modificatore verificato restano indeterminati.

Il pulsante «Prepara il Round» ora esegue i controlli di consapevolezza del primo Round quando la LOS è determinabile, tira i dadi d'iniziativa, applica vantaggio, panico, comando e turni speciali, e salva la pista dei turni. Il giocatore può passare un turno americano disponibile; il motore esegue le azioni tedesche già automatizzate e si ferma sulle altre. Se una LOS necessaria è indeterminata, la preparazione si ferma prima dei tiri. Il tiro mirato è limitato al caso descritto sotto; molte azioni tedesche restano da implementare.
Il movimento dei Round permette ora a un americano con turno disponibile di percorrere più esagoni adiacenti nella stessa azione, con un clic per esagono e il pulsante «Termina movimento». Usa i costi per terreno e lati dalla tabella originale del Player Aid Screen, compresi creste, scarpate in salita e strisciamento; rifiuta lati e aperture non verificati. In ingresso si controlla il paragrafo, mentre un riferimento Evento pone soltanto il segnalino come prescrive la regola 6. Il tiro mirato è eseguibile contro un singolo tedesco in M5, esagono di bosco e quota 1 controllato visivamente sulla scansione originale, se il soldato americano è nello stesso esagono o in uno adiacente con LOS libera. Risolve nell'ordine inceppamento, colpo, danno e consumo del caricatore. Altri bersagli, fuoco rapido e molte azioni tedesche restano da implementare.

Durante un turno americano, un soldato non ferito può cambiare postura gratuitamente una volta, poi usare o passare il turno. Il numero d'azione tedesca viene tirato una volta per la casella di turno e il paragrafo 800 («Sdraiati prono») è eseguito automaticamente; gli altri paragrafi interrompono ancora la sequenza mostrando il riferimento e il testo italiano. Alla fine del Round i soldati in panico cadono proni; se non restano tedeschi attivi tornano le Operazioni, altrimenti il pulsante «Round successivo» esegue il controllo Evento (dal secondo Round) e apre la preparazione della nuova pista. Un evento non ancora supportato sospende la risoluzione.

La squadra usa le pedine A–H originali del modulo TTS, raggruppate per esagono; un clic aggiunge o toglie dalla selezione i soldati nello stesso esagono e con la stessa postura. Il clic sulla carta muove solo le pedine selezionate. La carta usa anche le pedine tedesche originali della missione 1. Le azioni della regola 5/3 sono elencate nella barra laterale: il movimento e il trascinamento sono disponibili quando legali; scambio equipaggiamento, preparazione arma, disinceppamento e movimento dei prigionieri sono visibili ma disabilitati finché le rispettive procedure non sono automatizzate. «Mappa semplificata» mostra in verde gli esagoni verificati, in ocra quelli con terreno candidato e in rosso quelli senza quota; il passaggio del cursore indica che cosa va controllato. Questa vista è un elenco visivo delle lacune, non un editor.

## Verifica

`godot --headless --path . --script tests/smoke.gd`

`godot --headless --path . --script tests/round_rules.gd`

`godot --headless --path . --script tests/fire_rules.gd`

`godot --headless --path . --script tests/los_geometry.gd`

`godot --headless --path . --export-release Web build/web/index.html`

La build web è destinata a HTTPS/GitHub Pages e usa l’esportazione senza thread. L’archivio TTS originale resta fuori dal repository. Le immagini e i testi del gioco originale sono da usare nel rispetto dei diritti applicabili.

`python3 tools/extract_map_a_candidates.py` misura l'immagine originale; `python3 tools/build_map_a_terrain.py` produce `data/map_a_terrain.json` con le classi candidate dei 475 esagoni e le eccezioni visivamente riconosciute per gli edifici K13, L13 e T8. Il classificatore non distingue in modo affidabile le quote gialle 2 e 3 e non rileva tutte le aperture o i lati speciali: la LOS resta diagnostica fuori dai casi di combattimento strettamente verificati. Il centro degli edifici, per esempio, sembra terreno libero a un classificatore di pixel.
