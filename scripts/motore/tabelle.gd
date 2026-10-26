class_name Tabelle
extends RefCounted
## Tabelle dello schermo del giocatore (Player Aid Screen) e della pista dei Round.

## Pista dei Round sulla mappa: colonne di iniziativa 0–5, risultati del dado 0–9.
const DUE_TURNI := [[9], [4, 6], [3, 5, 8], [1, 2, 7, 9], [0, 2, 5, 6, 7], [0, 1, 3, 4, 5, 8]]
const PANICO := [[0, 2], [1], [], [], [], []]
## Numeri rossi: panico per i soli americani fuori comando.
const ROSSI := [[1, 4, 6, 8, 9], [3, 4, 5, 7], [0, 2, 3, 8], [6, 7, 9], [2, 5], []]

## Armi: gittate massime (corta, media, lunga), inceppamento mirato/rapido (%), munizioni (%),
## danni sul personale per dado 0–9: P panico, W ferita, I incapacitato, K ucciso.
const ARMI := {
	"pistol":  {"nome": "Pistola", "breve": "Pistola", "gittate": [3, 5, 20], "inc": [5, 5], "mun": 25, "auto": false,
		"danni": "PPPWWWWWIK", "porte": 0},
	"bolt":    {"nome": "Fucile a otturatore", "breve": "Fucile", "gittate": [6, 14, 99], "inc": [5, 5], "mun": 25, "auto": false,
		"danni": "PPWWWWIIIK", "porte": 1},
	"scoped":  {"nome": "Fucile con ottica", "breve": "Fucile ott.", "gittate": [8, 18, 99], "inc": [5, 5], "mun": 25, "auto": false,
		"danni": "PWWWWIIIKK", "porte": 1},
	"sar":     {"nome": "Fucile semiautomatico", "breve": "Garand", "gittate": [6, 14, 99], "inc": [5, 5], "mun": 25, "auto": false,
		"danni": "PPWWWWIIIK", "porte": 1},
	"carbine": {"nome": "Carabina", "breve": "Carabina", "gittate": [5, 11, 99], "inc": [5, 5], "mun": 25, "auto": false,
		"danni": "PPWWWWWIIK", "porte": 1},
	"mp":      {"nome": "Pistola mitragliatrice", "breve": "MP 40", "gittate": [4, 9, 99], "inc": [5, 10], "mun": 50, "auto": true,
		"danni": "PPWWWWWIIK", "porte": 1},
	"smg":     {"nome": "Mitra", "breve": "Thompson", "gittate": [4, 9, 99], "inc": [5, 10], "mun": 50, "auto": true,
		"danni": "PPWWWIIIKK", "porte": 1},
	"ar":      {"nome": "Fucile automatico", "breve": "BAR", "gittate": [9, 16, 99], "inc": [5, 10], "mun": 50, "auto": true,
		"danni": "PWWWIIIKKK", "porte": 2},
	"bazooka": {"nome": "Bazooka", "breve": "Bazooka", "gittate": [4, 8, 14], "inc": [5, 5], "mun": 100, "auto": false,
		"danni": "IIKKKKKKKK", "porte": 1, "esplosivo": true},
	"satchel": {"nome": "Carica da demolizione", "breve": "Carica", "porte": 1},
}

## Granate e cariche: danni per dado 0–9 (P panico, Q ferita/se prono panico, W, I, K).
const GRANATA_DENTRO := "PPPQQWWIIK"
const GRANATA_FUORI := "PPPPPQQWIK"
const CARICA_DENTRO := "QWWWIIIKKK"
const CARICA_FUORI := "PQQWWWWIIK"

const ASSALTO_UCCIDERE := "-PPWWWWIIK"
const ASSALTO_CATTURARE := "-PPXXCCCCI"   # X: ferita, o cattura se già ferito/in panico

## Disinceppamento: per abilità +2…−3, dado 0–9 (C liberata, J ancora inceppata, B rotta).
const DISINCEPPA := {
	2: "CCCCCCCCJB", 1: "CCCCCCJJJB", 0: "CCCCCCJJBB",
	-1: "CCCCJJJJBB", -2: "CCJJJJBBBB", -3: "CCBBBBBBBB",
}

## Modificatori del tiro per terreno del bersaglio e postura (in piedi, accovacciato, prono).
const MOD_TERRENO := {
	"clear": [1, 0, -1], "road": [1, 0, -1], "stream": [1, 0, -1], "bridge": [1, 0, -1], "ford": [1, 0, -1],
	"cover": [0, -1, -3], "brush": [0, -1, -2], "rough": [-1, -2, -3], "rubble": [-1, -2, -3],
	"crater": [-1, -2, -3], "woods": [-2, -3, -4],
}
const MOD_INTERNO_LONTANO := [-2, -4, 99]   # 99: tiro vietato
const MOD_INTERNO_VICINO := [-1, -2, -3]

const POSTURE := ["standing", "crouching", "prone"]
const NOMI_POSTURA := {"standing": "in piedi", "crouching": "accovacciato", "prone": "prono"}

static func indice_postura(p: String) -> int:
	return maxi(0, POSTURE.find(p))

static func base_per_distanza(arma: String, dist: int) -> int:
	if dist == 0:
		return 8
	if dist == 1:
		return 6
	var g: Array = ARMI[arma].gittate
	if dist <= g[0]:
		return 5
	if dist <= g[1]:
		return 4
	if dist <= g[2]:
		return 3
	return -1

static func nome_gittata(arma: String, dist: int) -> String:
	if dist == 0:
		return "stesso esagono"
	if dist == 1:
		return "adiacente"
	var g: Array = ARMI[arma].gittate
	if dist <= g[0]:
		return "corta"
	if dist <= g[1]:
		return "media"
	if dist <= g[2]:
		return "lunga"
	return "fuori gittata"

## Granata: corta 2, media 3–4, lunga 5–6. Carica: media 2, lunga 3.
static func base_lancio(tipo: String, dist: int) -> int:
	if dist == 1:
		return 6
	if tipo == "satchel":
		return 4 if dist == 2 else (3 if dist == 3 else -1)
	if dist == 2:
		return 5
	if dist <= 4:
		return 4
	if dist <= 6:
		return 3
	return -1

static func esito_turni(iniziativa: int, dado: int, americano: bool, in_comando: bool, ferito: bool) -> Dictionary:
	iniziativa = clampi(iniziativa, 0, 5)
	var rosso: bool = dado in ROSSI[iniziativa]
	if dado in PANICO[iniziativa] or (americano and rosso and not in_comando):
		return {"turni": 0, "panico": true, "rosso": rosso}
	var t := 2 if dado in DUE_TURNI[iniziativa] else 1
	if ferito:
		t = mini(t, 1)
	return {"turni": t, "panico": false, "rosso": rosso}

static func lettera_danno(tabella: String, dado: int) -> String:
	return tabella.substr(clampi(dado, 0, 9), 1)
