class_name AmbushGame
extends RefCounted
## All state transitions occur here. UI and network submit the same commands.
## Unimplemented source instructions stop resolution; they never become "no event".
signal changed
const VERSION := 1
const Hex = preload("res://scripts/hex_grid.gd")
var mission: Dictionary
var paragraphs: Dictionary
var state: Dictionary = {}
var rng := RandomNumberGenerator.new()
var forced_rolls: Array = [] # test-only injection, never exposed by UI/network
var _steps := 0

func _init() -> void:
	mission = JSON.parse_string(FileAccess.get_file_as_string("res://data/mission_01.json"))
	paragraphs = JSON.parse_string(FileAccess.get_file_as_string("res://data/paragraphs_it.json"))

func new_game(seed_value: int = 0) -> void:
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value
	state = {"version": VERSION, "mission": "base_01", "revision": 0, "condition": 1,
		"phase": "operations", "squad": mission.squad.duplicate(true), "enemies": [],
		"sightings": [], "event_markers": [], "items": {}, "landmarks": {}, "vp": 0,
		"log": [], "blocked": "", "context_hex": "", "last_paragraph": "", "history": [],
		"trigger_soldier": "", "rng": str(rng.state)}
	log_line("ORDINE DI OPERAZIONE", "Entrate da A1–J1. Seleziona un soldato, poi un esagono del margine nord.", "briefing")
	changed.emit()

func soldier(id: String) -> Dictionary:
	for unit in state.get("squad", []):
		if unit.id == id: return unit
	return {}

func log_line(title: String, text: String, kind := "info") -> void:
	state.log.append({"title": title, "text": text, "kind": kind})
	if state.log.size() > 250: state.log.pop_front()

func d10() -> int:
	if not forced_rolls.is_empty(): return int(forced_rolls.pop_front())
	return rng.randi_range(0, 9)

static func check_success(roll: int, target: int) -> bool:
	return roll == 0 or (roll != 9 and roll <= target)

func best_observer(hex_id: String) -> Dictionary:
	var best: Dictionary = {}
	for u in state.squad:
		if u.hex == hex_id and u.status == "active" and (best.is_empty() or u.pc > best.pc): best = u
	return best

func validate_command(command: Dictionary) -> String:
	if not state.blocked.is_empty(): return "Risoluzione sospesa: " + state.blocked
	if state.phase != "operations": return "Le Operazioni sono sospese."
	var u := soldier(str(command.get("soldier", "")))
	if u.is_empty() or u.status != "active": return "Seleziona un soldato attivo."
	match command.get("type", ""):
		"move":
			var target := str(command.get("hex", ""))
			if not Hex.valid(target): return "Esagono non valido."
			if u.stance == "prone": return "Un soldato prono non può muoversi: cambia postura."
			if u.hex == "":
				if not Hex.is_entry(target): return "L’ingresso è consentito solo da A1 a J1."
			elif Hex.distance(u.hex, target) != 1: return "Durante le Operazioni muovi un esagono alla volta."
		"stance":
			if command.get("stance", "") not in ["standing", "crouching", "prone"]: return "Postura non valida."
		"exit":
			if not Hex.is_entry(u.hex): return "Per ritirarti raggiungi A1–J1."
			if u.stance == "prone": return "Un soldato prono non può uscire dalla mappa."
		_: return "Comando non riconosciuto."
	return ""

func dispatch(command: Dictionary) -> Dictionary:
	var error := validate_command(command)
	if error != "": return {"ok": false, "error": error}
	var u := soldier(command.soldier)
	_steps = 0
	match command.type:
		"move":
			u.hex = command.hex
			state.context_hex = command.hex
			state.trigger_soldier = u.id
			log_line("MOVIMENTO · " + u.id, "%s entra in %s." % [u.name, u.hex])
			check_hex(command.hex)
		"stance":
			u.stance = command.stance
			var names := {"standing": "in piedi", "crouching": "accovacciato", "prone": "prono"}
			log_line("POSTURA · " + u.id, u.name + " è " + names[u.stance] + ".")
		"exit":
			u.hex = ""; u.status = "exited"
			log_line("RITIRATA", u.name + " ha lasciato il campo di battaglia.")
			var active := false
			for unit in state.squad:
				if unit.status == "active": active = true
			if not active:
				state.phase = "ended"
				log_line("MISSIONE TERMINATA", "Ritirata completa. Punti vittoria: %d / 13." % state.vp)
	state.revision += 1
	state.rng = str(rng.state)
	changed.emit()
	return {"ok": true}

func check_hex(hex_id: String) -> void:
	if hex_id in state.event_markers:
		log_line("CONTROLLO AUTOMATICO", hex_id + ": segnalino Evento presente; nessun nuovo controllo in questa Condizione.", "check")
		return
	if state.landmarks.has(hex_id):
		resolve(str(state.landmarks[hex_id].get("entry_paragraph", "")))
		return
	var condition: Dictionary = mission.conditions.get(str(state.condition), {})
	if condition.is_empty():
		stop_resolution("Carta della Condizione %d non ancora verificata." % state.condition); return
	read_reference(str(condition.hexes.get(hex_id, "UNVERIFIED")))

func read_reference(reference: String) -> void:
	if reference == "NONE":
		log_line("CONTROLLO AUTOMATICO", state.context_hex + ": nessun paragrafo da risolvere.", "check"); return
	if reference == "UNVERIFIED": stop_resolution("Riferimento esagono non verificato."); return
	if reference == "EVENT":
		var a := d10(); var b := d10()
		log_line("EVENTO · 2D10", "%d + %d = %d. Consultazione automatica della carta condizione." % [a, b, a+b], "dice")
		var ref: String = mission.conditions[str(state.condition)].events[str(a+b)]
		read_reference(ref)
		if state.context_hex not in state.event_markers: state.event_markers.append(state.context_hex)
		return
	if reference.contains(":"):
		var parts := reference.split(":")
		if parts[0] in state.sightings:
			log_line("CONDIZIONE SODDISFATTA", "Avvistamento %s già registrato: paragrafo ignorato." % parts[0], "check"); return
		log_line("CONTROLLO AVVISTAMENTO", "%s non è ancora avvenuto: leggi %s." % [parts[0],parts[1]], "check")
		reference = parts[1]
	resolve(reference)

func resolve(id: String) -> void:
	_steps += 1
	if _steps > 100: stop_resolution("Catena di paragrafi troppo lunga: controllo dei rimandi necessario."); return
	state.last_paragraph = id
	if not paragraphs.has(id):
		stop_resolution("Il paragrafo %s deve ancora essere tradotto e verificato." % id); return
	var paragraph: Dictionary = paragraphs[id]
	state.history.append(id)
	log_line("PARAGRAFO " + id, paragraph.it, "paragraph")
	run_ops(paragraph.ops)

func run_ops(ops: Array) -> void:
	for op in ops:
		if state.blocked != "": return
		match op.op:
			"goto": resolve(op.id)
			"unsupported": stop_resolution(op.reason)
			"event_marker":
				if state.context_hex not in state.event_markers: state.event_markers.append(state.context_hex)
				log_line("EVENTO REGISTRATO", "Segnalino Evento collocato in " + state.context_hex + ".", "check")
			"check":
				var u := best_observer(state.context_hex)
				if op.kind == "pc" and u.is_empty(): stop_resolution("Nessun osservatore attivo per il controllo di percezione."); return
				var base := int(u.get("pc", 0)) if op.kind == "pc" else int(mission.activation_levels[state.condition-1])
				var target := base + int(op.modifier)
				var roll := d10()
				var success := check_success(roll, target)
				var label := "PERCEZIONE · " + str(u.get("name", "")) if op.kind == "pc" else "ATTIVAZIONE"
				log_line(label, "D10: %d · soglia %d (%d%+d) → %s. 0 riesce sempre; 9 fallisce sempre." % [roll, target, base, int(op.modifier), "RIUSCITO" if success else "FALLITO"], "dice")
				run_ops(op.success if success else op.failure)
			"die":
				var roll := d10()
				log_line("D10", "Risultato: %d." % roll, "dice")
				for branch in op.branches:
					if roll >= branch.min and roll <= branch.max:
						run_ops(branch.ops); break
			"if":
				if op.condition.kind != "sighting": stop_resolution("Condizione non implementata."); return
				var success: bool = op.condition.id in state.sightings
				log_line("CONTROLLO AUTOMATICO", "%s %s avvenuto." % [op.condition.id, "è già" if success else "non è ancora"], "check")
				run_ops(op.yes if success else op.no)
			"sighting": register_sighting(op.id)
			"item":
				if not state.items.has(state.context_hex): state.items[state.context_hex] = []
				if op.item not in state.items[state.context_hex]: state.items[state.context_hex].append(op.item)
			"rescue_target":
				if soldier("K").is_empty(): state.squad.append({"id":"K","name":"Ferito da soccorrere","hex":"G10","status":"incapacitated","stance":"prone","pc":0,"initiative":0,"ws":0,"weapon":"Nessuna","extra":"2 caricatori mitra · 1 granata","clips":2,"grenades":1,"commander":false})
			"encounter":
				for s in op.sightings: register_sighting(s)
				for enemy in op.enemies:
					var exists := false
					for current in state.enemies:
						if current.id == enemy.id: exists = true
					if not exists: state.enemies.append(enemy.duplicate(true))
				state.phase = "rounds"
				state.advantage = op.advantage
				state.condition = maxi(state.condition, int(op.condition))
				state.event_markers.clear()
				stop_resolution("Contatto nemico registrato. Round di combattimento, carte nemiche e nuova Condizione sono ancora in implementazione.")
			"crash":
				state.landmarks[op.hex] = {"name":"Typhoon abbattuto","entry_paragraph":op.entry_paragraph}
				kill_hex(op.hex)
			"artillery":
				var a := d10(); var b := d10()
				var col := mini(a,b)*10+maxi(a,b)
				log_line("ARTIGLIERIA · COLONNA", "Dadi %d, %d → %02d." % [a,b,col], "dice")
				if col > 25 or col == 0:
					log_line("ARTIGLIERIA", "Esplosione fuori mappa."); continue
				a = d10(); b = d10()
				var row := mini(a,b)*10+maxi(a,b)
				log_line("ARTIGLIERIA · RIGA", "Dadi %d, %d → %02d." % [a,b,row], "dice")
				if row > 19 or row == 0:
					log_line("ARTIGLIERIA", "Esplosione fuori mappa."); continue
				# Terrain destruction requires a reviewed terrain model. Preserve the rolls.
				stop_resolution("Artiglieria in %s%d: distruzione del terreno e danni da verificare." % [String.chr(64+col),row])
			_: stop_resolution("Istruzione non riconosciuta: " + str(op.op))

func kill_hex(hex_id: String) -> void:
	for u in state.squad:
		if u.hex == hex_id and u.status in ["active", "incapacitated"]:
			u.status = "killed"
			log_line("CADUTO", u.name + " è stato ucciso in " + hex_id + ".")

func register_sighting(id: String) -> void:
	if id not in state.sightings:
		state.sightings.append(id)
		log_line("AVVISTAMENTO " + id.to_upper(), "Registrato. Le condizioni future terranno conto di questo evento.", "check")

func stop_resolution(reason: String) -> void:
	state.blocked = reason
	log_line("LIMITE DELLA VERSIONE DI SVILUPPO", reason + " La partita è conservata; nessuna scelta viene risolta arbitrariamente.", "blocked")

func snapshot() -> Dictionary:
	var result := state.duplicate(true)
	result.rng = str(rng.state) # decimal string preserves int64 through JSON/Firebase
	return result

func restore(candidate: Variant) -> bool:
	if not candidate is Dictionary: return false
	if candidate.get("version") != VERSION or candidate.get("mission") != "base_01": return false
	for key in ["squad", "enemies", "log", "sightings", "event_markers", "history"]:
		if not candidate.get(key) is Array: return false
	for key in ["items", "landmarks"]:
		if not candidate.get(key) is Dictionary: return false
	for key in ["rng", "blocked", "context_hex", "last_paragraph", "trigger_soldier", "phase"]:
		if not candidate.get(key) is String: return false
	if not candidate.rng.is_valid_int(): return false
	if int(candidate.get("condition", 0)) not in [1,2,3,4]: return false
	if not candidate.get("revision") is float and not candidate.get("revision") is int: return false
	if not candidate.has("vp"): return false
	var ids: Array = []
	for unit in candidate.squad:
		if not unit is Dictionary: return false
		for key in ["id","name","hex","status","stance","weapon","extra"]:
			if not unit.get(key) is String: return false
		for key in ["pc","initiative","ws","clips","grenades"]:
			if not unit.get(key) is float and not unit.get(key) is int: return false
		if unit.id in ids or unit.id not in ["A","B","C","D","E","F","G","H","K"]: return false
		ids.append(unit.id)
		if unit.hex != "" and not Hex.valid(unit.hex): return false
		if unit.status not in ["active","exited","incapacitated","killed"]: return false
		if unit.stance not in ["standing","crouching","prone"]: return false
	for id in ["A","B","C","D","E","F","G","H"]:
		if id not in ids: return false
	for entry in candidate.log:
		if not entry is Dictionary or not entry.get("title") is String or not entry.get("text") is String or not entry.get("kind") is String: return false
	state = candidate.duplicate(true)
	state.condition = int(state.condition)
	state.revision = int(state.revision)
	rng.state = int(state.rng)
	changed.emit()
	return true
