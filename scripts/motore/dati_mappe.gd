extends RefCounted
## Dati delle mappe: quelli del gioco (res://data) oppure, se l'editor delle mappe li ha cambiati,
## la copia modificata salvata sul dispositivo (user://mappe). Nomi come «mappa_a» e «mappa_a_3d».

const CARTELLA := "user://mappe"
## Mappe che l'editor sa aprire: lettera → nome per l'elenco.
const MAPPE := {
	"a": "Mappa A (Ambush!)",
	"b": "Mappa B (Ambush!)",
	"ad": "Mappa A con D (Move Out!)",
	"c": "Mappa C (Purple Heart)",
	"be": "Mappa B con E (Purple Heart)",
	"f": "Mappa F (Silver Star)",
	"fh": "Mappa F con H (Silver Star)",
	"fg": "Mappa F con G (Silver Star)",
	"gh": "Mezze mappe G e H (Silver Star)",
}

## Nei test le modifiche dell'editor non devono contare.
static var solo_originali := OS.get_environment("AMBUSH_MAPPE_ORIGINALI") == "1"

static func _utente(nome: String) -> String:
	return "%s/%s.json" % [CARTELLA, nome]

static func originale(nome: String) -> Dictionary:
	var percorso := "res://data/%s.json" % nome
	if not FileAccess.file_exists(percorso):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(percorso))
	return d if d is Dictionary else {}

static func modificata(nome: String) -> bool:
	return not solo_originali and FileAccess.file_exists(_utente(nome))

static func leggi(nome: String) -> Dictionary:
	if modificata(nome):
		var d = JSON.parse_string(FileAccess.get_file_as_string(_utente(nome)))
		if d is Dictionary and not d.is_empty():
			return d
	return originale(nome)

static func esiste(nome: String) -> bool:
	return modificata(nome) or FileAccess.file_exists("res://data/%s.json" % nome)

static func scrivi(nome: String, dati: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	var f := FileAccess.open(_utente(nome), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(dati))
	f.close()
	return true

static func cancella(nome: String) -> void:
	if FileAccess.file_exists(_utente(nome)):
		DirAccess.remove_absolute(_utente(nome))

## Tutte le modifiche in un solo documento, da esportare: {"versione": 1, "mappe": {nome: dati}}.
static func pacchetto() -> Dictionary:
	var mappe := {}
	for l in MAPPE:
		for nome in ["mappa_%s" % l, "mappa_%s_3d" % l]:
			if modificata(nome):
				mappe[nome] = leggi(nome)
	return {"gioco": "Ambush!", "versione": 1, "mappe": mappe}

## Legge un pacchetto esportato; restituisce quante mappe ha caricato (-1 se il file non va bene).
static func importa(testo: String) -> int:
	var d = JSON.parse_string(testo)
	if not (d is Dictionary) or not d.has("mappe") or not (d.mappe is Dictionary):
		return -1
	var n := 0
	for nome in d.mappe:
		var s := str(nome)
		if not s.begins_with("mappa_") or not (d.mappe[nome] is Dictionary):
			continue
		if scrivi(s, d.mappe[nome]):
			n += 1
	return n
