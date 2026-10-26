extends SceneTree
## Calcola gli esagoni dell’altura obiettivo (vista più ampia sulla strada) e li scrive in data/mappa_a.json.
## Da eseguire dopo tools/costruisci_dati.py:  godot --headless --path . --script tests/calcola_alture.gd
func _init() -> void:
	var percorso := "res://data/mappa_a.json"
	var dati: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(percorso))
	dati.erase("alture_obiettivo")
	var f := FileAccess.open(percorso, FileAccess.WRITE)
	f.store_string(JSON.stringify(dati, " "))
	f.close()
	var p := Partita.new()
	p.terreno.alture = []
	var alture: Array = p.alture_obiettivo()
	dati["alture_obiettivo"] = alture
	f = FileAccess.open(percorso, FileAccess.WRITE)
	f.store_string(JSON.stringify(dati, " ") + "\n")
	f.close()
	print("Alture obiettivo: ", alture)
	quit()
