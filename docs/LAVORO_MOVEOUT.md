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
