# Ambush! — edizione digitale italiana

Progetto Godot 4.7 per la missione base 1, «Sangue a Saint-Michaux». Aprire `project.godot` con Godot o eseguire `godot --path .`.

## Stato effettivo

La versione 0.3 permette ingresso da A1–J1, movimento singolo e di gruppo durante le Operazioni, posture, controllo dei riferimenti neri delle quattro carte Condizione della missione 1, eventi, avvistamenti e 112 paragrafi tradotti. Registra campi minati permanenti, risolve i controlli di percezione all’ingresso e applica i danni da granata al chiuso della tabella originale. Il diario mostra i tiri e i motivi delle diramazioni. Salva automaticamente sul dispositivo. Ambush è progettato esclusivamente per il gioco in solitario; non include modalità online.

Questa **non è una missione completa**: combattimento, scelta dell’equipaggiamento dopo una ferita, linea di vista, terreno, uso dei riferimenti rossi dei Round, punteggio e la maggior parte dei paragrafi sono ancora in lavorazione. I 46 riferimenti rossi della Condizione 4 sono trascritti ma non ancora usati dal motore. Quando serve una regola non verificata, il motore sospende la partita senza improvvisare una risoluzione. L’OCR inglese in `data/source` è una fonte da controllare sulle scansioni, non testo pronto per il gioco.

## Verifica

`godot --headless --path . --script tests/smoke.gd`

`godot --headless --path . --export-release Web build/web/index.html`

La build web è destinata a HTTPS/GitHub Pages e usa l’esportazione senza thread. L’archivio TTS originale resta fuori dal repository. Le immagini e i testi del gioco originale sono da usare nel rispetto dei diritti applicabili.
