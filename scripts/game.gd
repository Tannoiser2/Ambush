class_name AmbushGame
extends RefCounted
## All solo-play state transitions occur here; the UI submits commands.
## Unimplemented source instructions stop resolution; they never become "no event".
signal changed
const VERSION := 1
const Hex = preload("res://scripts/hex_grid.gd")
const Damage = preload("res://scripts/damage.gd")
const RoundRules = preload("res://scripts/round_rules.gd")
const MapATerrain = preload("res://scripts/map_a_terrain.gd")
var mission: Dictionary
var paragraphs: Dictionary
var german_cards: Dictionary
var german_actions: Dictionary
var map_terrain := MapATerrain.new()
var state: Dictionary = {}
var rng := RandomNumberGenerator.new()
var forced_rolls: Array = [] # test-only injection, never exposed by UI/network
var _steps := 0
var _minefield_checked_entry := false
var _entry_soldiers: Array = []
var _pc_success_soldier := ""

func _init() -> void:
	mission = JSON.parse_string(FileAccess.get_file_as_string("res://data/mission_01.json"))
	paragraphs = JSON.parse_string(FileAccess.get_file_as_string("res://data/paragraphs_it.json"))
	german_cards = JSON.parse_string(FileAccess.get_file_as_string("res://data/german_cards_m1.json")).cards
	german_actions = JSON.parse_string(FileAccess.get_file_as_string("res://data/german_actions_it.json")).actions

func german_action_reference(card_id: String, condition: int, roll: int, special: String = "") -> int:
	var card: Dictionary = german_cards.get(card_id, {})
	if card.is_empty() or roll < 0 or roll > 9: return -1
	var column := special if special != "" else str(condition)
	if not card.columns.has(column): return -1
	for index in range(card.roll_groups.size()):
		for die in card.roll_groups[index]:
			if roll == int(die): return int(card.columns[column][index])
	return -1

func map_los(a: String, b: String) -> Dictionary:
	return map_terrain.los(a,b,state.get("terrain_overrides",{}))

func map_terrain_at(hex_id: String) -> Dictionary:
	return map_terrain.terrain(hex_id,state.get("terrain_overrides",{}))

func german_action_text(reference: int) -> String:
	return str(german_actions.get(str(reference), ""))

func german_action_column(id: String) -> String:
	for enemy in state.get("enemies", []):
		if str(enemy.id) != id or enemy.get("status", "active") != "active": continue
		for unit in state.squad:
			if unit.status == "active" and unit.hex != "" and Hex.distance(str(enemy.hex), str(unit.hex)) <= 1:
				return "S"
		return str(enemy.get("special_reaction", "")) if enemy.get("special_reaction", "") != "" else str(state.condition)
	return ""

func german_turn_reference(id: String, action_number: int) -> int:
	var column := german_action_column(id)
	return german_action_reference(id, int(state.condition), action_number, column) if column != "" else -1

func german_turn_references(action_number: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy in state.get("enemies", []):
		if enemy.get("status", "active") != "active": continue
		result.append({"id":str(enemy.id), "letter":str(enemy.get("letter", "")), "column":german_action_column(str(enemy.id)), "reference":german_turn_reference(str(enemy.id),action_number)})
	result.sort_custom(func(a: Dictionary,b: Dictionary): return a.letter < b.letter)
	return result

func us_in_command(id: String) -> bool:
	var unit := soldier(id)
	return not unit.is_empty() and RoundRules.in_command(unit, state.get("squad", []))

func action_round_turns(id: String, roll: int) -> Dictionary:
	var unit := soldier(id)
	if unit.is_empty(): return {}
	return RoundRules.turn_result(int(unit.initiative), roll, true, us_in_command(id), bool(unit.wounded))

func prepare_awareness_phase(previous: Dictionary, visible_ids: Array, rolls: Dictionary) -> Dictionary:
	if state.get("phase", "") != "rounds" or state.get("round_setup", {}).is_empty(): return {}
	return RoundRules.awareness_phase(state.squad, previous, int(state.round_setup.number),
		visible_ids, rolls, str(state.round_setup.get("auto_aware_soldier", "")))

func prepare_round_track(awareness: Dictionary, us_die: int, german_die: int) -> Dictionary:
	if state.get("phase", "") != "rounds" or state.get("round_setup", {}).is_empty(): return {}
	var first_round: bool = int(state.round_setup.get("number", 0)) == 1
	return RoundRules.assign_turns(state.squad,state.enemies,awareness,us_die,german_die,
		str(state.round_setup.get("advantage", "roll")) if first_round else "roll",
		state.round_setup.get("german_two_turns", []) if first_round else [],
		bool(state.round_setup.get("us_two_turns", false)) if first_round else false)

func prepare_action_sequence(awareness: Dictionary, us_die: int, german_die: int) -> Dictionary:
	return RoundRules.start_action_sequence(prepare_round_track(awareness, us_die, german_die))

func new_game(seed_value: int = 0) -> void:
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value
	state = {"version": VERSION, "mission": "base_01", "revision": 0, "condition": 1,
		"phase": "operations", "squad": mission.squad.duplicate(true), "enemies": [],
		"round_setup": {},
		"sightings": [], "event_markers": [], "items": {}, "landmarks": {}, "terrain_overrides": {}, "vp": 0,
		"evasive_removals": {}, "ban_evasive_return": false, "minefields": [], "pending_drop": "",
		"pending_ops": [], "pending_hex_check": "", "pilot_found": false,
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
	if command.get("type", "") == "drop_port":
		if state.pending_drop == "": return "Nessun equipaggiamento da lasciare."
		if str(command.get("soldier", "")) != state.pending_drop: return "La scelta riguarda un altro soldato."
		var index := int(command.get("index", -1))
		if index not in [0,1] or soldier(state.pending_drop).port_boxes[index] == "": return "Scegli un oggetto trasportato."
		return ""
	if not state.blocked.is_empty(): return "Risoluzione sospesa: " + state.blocked
	if state.phase != "operations": return "Le Operazioni sono sospese."
	var u := soldier(str(command.get("soldier", "")))
	if u.is_empty() or u.status != "active": return "Seleziona un soldato attivo."
	match command.get("type", ""):
		"rescue_pilot":
			if not state.pilot_found or not state.landmarks.has("R15") or not soldier("J").is_empty(): return "Il pilota non può essere soccorso qui."
			if u.hex != "R15" or u.wounded: return "Serve un soldato non ferito in R15."
		"drag", "exit_drag":
			var casualty := soldier(str(command.get("casualty", "")))
			if casualty.is_empty() or casualty.id == u.id or casualty.status not in ["incapacitated", "killed"]: return "Seleziona un soldato inattivo da trasportare."
			if u.hex == "" or casualty.hex != u.hex: return "I due soldati devono occupare lo stesso esagono."
			if u.stance != "standing": return "Il soccorritore deve essere in piedi."
			if "" not in u.port_boxes: return "Il soccorritore deve avere uno spazio di trasporto libero."
			if command.type == "drag":
				var target := str(command.get("hex", ""))
				if not Hex.valid(target) or Hex.distance(u.hex, target) != 1: return "Trascina il ferito in un esagono adiacente."
				if target in state.minefields and casualty.status == "incapacitated": return "Il trasporto del ferito in un campo minato richiede una regola ancora da verificare."
			else:
				if not Hex.is_entry(u.hex): return "Per evacuare il ferito raggiungi A1–J1."
		"move", "move_group":
			var target := str(command.get("hex", ""))
			if not Hex.valid(target): return "Esagono non valido."
			if u.stance == "prone": return "Un soldato prono non può muoversi: cambia postura."
			if u.hex == "":
				if not Hex.is_entry(target): return "L’ingresso è consentito solo da A1 a J1."
			elif Hex.distance(u.hex, target) != 1: return "Durante le Operazioni muovi un esagono alla volta."
			if command.type == "move_group":
				var ids: Array = command.get("group", [])
				if ids.is_empty() or u.id not in ids: return "Gruppo non valido."
				var unique: Array = []
				for id in ids:
					if id in unique: return "Un soldato compare due volte nel gruppo."
					unique.append(id)
					var member := soldier(str(id))
					if member.is_empty() or member.status != "active" or member.hex != u.hex or member.stance != u.stance: return "I soldati del gruppo devono essere attivi, nello stesso esagono e con la stessa postura."
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
	_pc_success_soldier = ""
	match command.type:
		"rescue_pilot":
			state.context_hex = "R15"
			state.trigger_soldier = u.id
			log_line("SOCCORSO DEL PILOTA", u.name + " libera il pilota; esegui un controllo Evento.", "check")
			read_reference("EVENT")
			if state.blocked == "" and state.phase == "operations": resolve("454")
		"drop_port":
			var index := int(command.index)
			var item: String = u.port_boxes[index]
			if not state.items.has(u.hex): state.items[u.hex] = []
			state.items[u.hex].append(item)
			u.port_boxes[index] = ""
			if index == 0: u.weapon = "Nessuna"
			else: u.extra = ""
			state.pending_drop = ""
			state.blocked = ""
			log_line("EQUIPAGGIAMENTO", u.name + " lascia " + item + " in " + u.hex + ". La risoluzione riprende.", "check")
			var resume: Array = state.pending_ops.duplicate(true)
			state.pending_ops.clear()
			run_ops(resume)
			if state.blocked == "" and state.pending_hex_check != "":
				var resume_hex: String = state.pending_hex_check
				state.pending_hex_check = ""
				check_hex(resume_hex, true)
		"move":
			u.hex = command.hex
			_entry_soldiers = [u.id]
			state.context_hex = command.hex
			state.trigger_soldier = u.id
			log_line("MOVIMENTO · " + u.id, "%s entra in %s." % [u.name, u.hex])
			check_hex(command.hex)
		"drag":
			var casualty := soldier(str(command.casualty))
			u.hex = command.hex
			casualty.hex = command.hex
			_entry_soldiers = [casualty.id, u.id]
			state.context_hex = command.hex
			state.trigger_soldier = u.id
			log_line("TRASCINAMENTO", "%s trascina %s in %s." % [u.name, casualty.name, command.hex])
			if casualty.status == "incapacitated":
				var roll := d10()
				log_line("SOPRAVVIVENZA · " + casualty.name, "D10: %d; con 0 il ferito muore." % roll, "dice")
				if roll == 0:
					casualty.status = "killed"
					log_line("CADUTO", casualty.name + " muore durante il trasporto.")
			check_hex(command.hex)
		"exit_drag":
			var casualty := soldier(str(command.casualty))
			u.hex = ""
			u.status = "exited"
			casualty.hex = ""
			if casualty.status == "incapacitated":
				casualty.status = "evacuated"
				if casualty.id == "K":
					state.vp += 3
					log_line("SOCCORSO", "Il soldato K è salvo: +3 PV.", "check")
			log_line("EVACUAZIONE", u.name + " porta fuori dalla mappa " + casualty.name + ".")
			finish_if_withdrawn()
		"move_group":
			var names: Array[String] = []
			_entry_soldiers = command.group.duplicate()
			for id in command.group:
				var member := soldier(str(id))
				member.hex = command.hex
				names.append(member.name)
			state.context_hex = command.hex
			state.trigger_soldier = u.id
			log_line("MOVIMENTO DI GRUPPO", ", ".join(names) + " entrano in " + command.hex + ".")
			check_hex(command.hex)
		"stance":
			u.stance = command.stance
			var names := {"standing": "in piedi", "crouching": "accovacciato", "prone": "prono"}
			log_line("POSTURA · " + u.id, u.name + " è " + names[u.stance] + ".")
		"exit":
			u.hex = ""; u.status = "exited"
			log_line("RITIRATA", u.name + " ha lasciato il campo di battaglia.")
			finish_if_withdrawn()
	state.revision += 1
	state.rng = str(rng.state)
	changed.emit()
	return {"ok": true}

func finish_if_withdrawn() -> void:
	for unit in state.squad:
		if unit.status == "active": return
	state.phase = "ended"
	log_line("MISSIONE TERMINATA", "Ritirata completa. Punti vittoria: %d / 13." % net_vp())

func check_hex(hex_id: String, skip_minefield := false) -> void:
	_minefield_checked_entry = skip_minefield
	if not skip_minefield and hex_id in state.minefields:
		check_minefield(hex_id)
		_minefield_checked_entry = true
		if state.blocked != "":
			if state.pending_drop != "": state.pending_hex_check = hex_id
			return
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
		if state.phase == "operations" and state.context_hex not in state.event_markers: state.event_markers.append(state.context_hex)
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
	for i in ops.size():
		if state.blocked != "": return
		var op: Dictionary = ops[i]
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
				if op.kind == "pc": _pc_success_soldier = str(u.id) if success else ""
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
				var success := false
				match op.condition.kind:
					"sighting":
						success = op.condition.id in state.sightings
						log_line("CONTROLLO AUTOMATICO", "%s %s avvenuto." % [op.condition.id, "è già" if success else "non è ancora"], "check")
					"enemy_evaded":
						success = int(state.evasive_removals.get(op.condition.id, 0)) > 0
						log_line("CONTROLLO AUTOMATICO", "Tedesco %s %s rimosso per movimento evasivo." % [op.condition.id, "già" if success else "mai"], "check")
					_:
						stop_resolution("Condizione non implementata."); return
				run_ops(op.yes if success else op.no)
			"ban_evasive_return":
				state.ban_evasive_return = true
				log_line("REGOLA ATTIVA", "I tedeschi già rimossi con movimento evasivo non possono rientrare.", "check")
			"minefield":
				if state.context_hex not in state.minefields:
					state.minefields.append(state.context_hex)
					log_line("CAMPO MINATO", "Segnalino permanente in " + state.context_hex + ".", "check")
				if not _minefield_checked_entry: check_minefield(state.context_hex)
				_minefield_checked_entry = true
			"sighting": register_sighting(op.id)
			"item":
				if not state.items.has(state.context_hex): state.items[state.context_hex] = []
				if op.item not in state.items[state.context_hex]: state.items[state.context_hex].append(op.item)
			"rescue_target":
				if soldier("K").is_empty(): state.squad.append({"id":"K","name":"Ferito da soccorrere","hex":"G10","status":"incapacitated","stance":"prone","pc":0,"initiative":0,"ws":0,"weapon":"Nessuna","extra":"2 caricatori mitra · 1 granata","port_boxes":["",""],"clips":2,"grenades":1,"commander":false,"wounded":false})
			"encounter":
				for s in op.sightings: register_sighting(s)
				for enemy in op.enemies:
					var exists := false
					for current in state.enemies:
						if current.id == enemy.id: exists = true
					if not exists:
						var card: Dictionary = german_cards.get(str(enemy.id), {})
						if card.is_empty():
							stop_resolution("Scheda tedesca %s non verificata." % enemy.id); return
						var active_enemy: Dictionary = enemy.duplicate(true)
						for key in ["letter", "role", "initiative", "pc", "ws", "mpa", "weapons", "activation_vp", "conditional_vp"]:
							active_enemy[key] = card[key]
						active_enemy.status = "active"
						active_enemy.wounded = false
						active_enemy.panicked = false
						active_enemy.special_reaction = ""
						state.enemies.append(active_enemy)
						state.vp += int(card.activation_vp)
						log_line("ATTIVAZIONE TEDESCA", "GE %s (%s): +%d PV all'attivazione." % [enemy.id, card.letter, card.activation_vp], "check")
				state.phase = "rounds"
				state.advantage = op.advantage
				state.round_setup = {"number":1, "advantage":op.advantage,
					"german_two_turns":op.get("first_round_german_two_turns", []),
					"us_two_turns":bool(op.get("first_round_us_two_turns", false)),
					"auto_aware_soldier":_pc_success_soldier if bool(op.get("trigger_aware_if_pc", false)) else ""}
				state.condition = maxi(state.condition, int(op.condition))
				state.event_markers.clear()
				if not state.round_setup.german_two_turns.is_empty():
					log_line("PRIMO ROUND", "GE %s: due turni assegnati dal paragrafo." % ", ".join(state.round_setup.german_two_turns), "check")
				if state.round_setup.us_two_turns:
					log_line("PRIMO ROUND", "Tutti gli americani consapevoli che non vanno nel panico ricevono due turni.", "check")
				stop_resolution("Contatto nemico registrato. La sequenza di combattimento dei Round non è ancora eseguita.")
			"crash":
				state.landmarks[op.hex] = {"name":"Typhoon abbattuto","entry_paragraph":op.entry_paragraph}
				kill_hex(op.hex)
			"kill_hex": kill_hex(op.hex)
			"remove_landmark": state.landmarks.erase(op.hex)
			"pilot_found": state.pilot_found = true
			"pilot_rescued":
				if soldier("J").is_empty():
					state.squad.append({"id":"J","name":"Pilota britannico","hex":"R15","status":"active","stance":"prone","pc":5,"initiative":2,"ws":-1,"driving":2,"mp":2,"weapon":"Pistola","extra":"","port_boxes":["",""],"clips":1,"grenades":0,"commander":false,"wounded":true})
					state.vp += 2
					log_line("SOCCORSO", "Pilota salvato: +2 PV. Il suo valore finale dipenderà dalla sopravvivenza.", "check")
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
				var impact_hex := String.chr(64+col) + str(row)
				var original_terrain: String = str(map_terrain.terrain(impact_hex).get("terrain", ""))
				var result_terrain := "rubble" if original_terrain.ends_with("_building") else "crater"
				state.terrain_overrides[impact_hex] = result_terrain
				log_line("IMPATTO D'ARTIGLIERIA", "%s: %s." % [impact_hex,"macerie" if result_terrain == "rubble" else "cratere"], "check")
				kill_hex(impact_hex)
			_: stop_resolution("Istruzione non riconosciuta: " + str(op.op))
		if state.blocked != "" and state.pending_drop != "":
			state.pending_ops.append_array(ops.slice(i+1))
			return

func kill_hex(hex_id: String) -> void:
	for u in state.squad:
		if u.hex == hex_id and u.status in ["active", "incapacitated"]:
			u.status = "killed"
			log_line("CADUTO", u.name + " è stato ucciso in " + hex_id + ".")
	for enemy in state.enemies:
		if str(enemy.get("hex", "")) != hex_id or enemy.get("status", "active") not in ["active","incapacitated","captured"]: continue
		if enemy.get("status", "active") == "active": apply_enemy_damage(str(enemy.id),"K")
		else: enemy.status = "killed"
		log_line("TEDESCO CADUTO", "GE %s è stato ucciso in %s." % [enemy.id,hex_id])

func check_minefield(hex_id: String) -> void:
	for id in _entry_soldiers:
		var u := soldier(str(id))
		if u.is_empty() or u.hex != hex_id: continue
		if u.status == "incapacitated":
			stop_resolution("Campo minato in %s: verifica del ferito trasportato ancora da implementare." % hex_id)
			return
		if u.status != "active": continue
		var roll := d10()
		var success := check_success(roll, int(u.pc))
		log_line("MINA · " + u.name, "D10: %d · percezione %d → %s." % [roll, u.pc, "EVITATA" if success else "ESPLOSA"], "dice")
		if not success:
			var damage_roll := d10()
			var result := Damage.grenade_indoors(damage_roll, u.stance == "prone")
			log_line("DANNI · " + u.name, "Granata al chiuso · D10: %d → %s." % [damage_roll, result], "dice")
			apply_soldier_damage(u, result)
			if state.blocked != "": return

func apply_soldier_damage(u: Dictionary, result: String) -> void:
	match result:
		"P":
			# Panic from damage during Operations has no effect (rules 13/1).
			log_line("PANICO", u.name + ": nessun effetto durante le Operazioni.", "check")
		"W":
			if u.wounded:
				u.status = "incapacitated"
				log_line("INCAPACITATO", u.name + " subisce una seconda ferita.")
			else:
				u.wounded = true
				u.stance = "prone"
				u.mp = 2
				log_line("FERITO", u.name + " cade prono; movimento ridotto a 2.")
				if u.port_boxes[1] != "":
					if u.port_boxes[0] == u.port_boxes[1]:
						if not state.items.has(u.hex): state.items[u.hex] = []
						state.items[u.hex].append(u.weapon)
						u.port_boxes = ["", ""]
						u.weapon = "Nessuna"
						log_line("EQUIPAGGIAMENTO", u.name + " lascia a terra l’arma che occupava due spazi di trasporto.")
					else:
						state.pending_drop = u.id
						stop_resolution(u.name + ": scegli quale dei due oggetti trasportati lasciare dopo la ferita.")
		"I":
			u.status = "incapacitated"
			u.stance = "prone"
			log_line("INCAPACITATO", u.name + " non può più agire.")
		"K":
			u.status = "killed"
			log_line("CADUTO", u.name + " è stato ucciso.")
		_:
			stop_resolution("Risultato di danno sconosciuto: " + result)

func register_sighting(id: String) -> void:
	if id not in state.sightings:
		state.sightings.append(id)
		log_line("AVVISTAMENTO " + id.to_upper(), "Registrato. Le condizioni future terranno conto di questo evento.", "check")

func apply_enemy_damage(id: String, result: String) -> void:
	for enemy in state.enemies:
		if str(enemy.id) != id: continue
		if enemy.get("status", "active") not in ["active"]: return
		match result:
			"P":
				if state.phase == "rounds": enemy.panicked = true
			"W":
				if bool(enemy.get("wounded", false)):
					enemy.status = "incapacitated"
				else:
					enemy.wounded = true
					enemy.stance = "prone"
					enemy.mpa = 2
			"I": enemy.status = "incapacitated"; enemy.stance = "prone"
			"K": enemy.status = "killed"
			"C":
				enemy.status = "captured"
				var card: Dictionary = german_cards.get(id, {})
				if card.get("conditional_vp_if", "") == "captured":
					state.vp += int(card.conditional_vp)
					log_line("CATTURA", "GE %s catturato: +%d PV." % [id, card.conditional_vp], "check")
			_: stop_resolution("Danno tedesco sconosciuto: " + result); return
		if id == "34" and enemy.status in ["killed", "captured", "incapacitated"] and int(state.condition) < 4:
			state.condition = 4
			state.event_markers.clear()
			log_line("CONDIZIONE 4", "GE 34 non è più attivo: entra in vigore la Condizione 4.", "check")
		return

func stop_resolution(reason: String) -> void:
	state.blocked = reason
	log_line("LIMITE DELLA VERSIONE DI SVILUPPO", reason + " La partita è conservata; nessuna scelta viene risolta arbitrariamente.", "blocked")

func objective_status() -> Array[Dictionary]:
	var active_hexes: Array[String] = []
	var present_hexes: Array[String] = []
	for u in state.squad:
		if u.status == "active" and u.hex != "": active_hexes.append(u.hex)
		if u.status in ["active", "incapacitated"] and u.hex != "": present_hexes.append(u.hex)
	var t8 := "T8" in active_hexes
	var central := "K13" in present_hexes and "L13" in present_hexes
	var no_enemies := true
	for enemy in state.enemies:
		if enemy.get("status", "active") == "active": no_enemies = false
	return [
		{"title":"Edificio T8", "met":t8, "known":true},
		{"title":"Edifici K13 e L13", "met":central, "known":true},
		{"title":"Nessun tedesco attivo", "met":no_enemies, "known":true},
		{"title":"Altura sud-est con vista su tutta la strada", "met":false, "known":false},
		{"title":"Almeno 13 punti vittoria", "met":net_vp()>=13, "known":true},
	]

func net_vp() -> int:
	var losses := 0
	for u in state.squad:
		if u.id in ["A","B","C","D","E","F","G","H"] and u.status in ["incapacitated", "killed"]:
			losses += 2
	var pilot := soldier("J")
	var pilot_bonus := 2 if state.phase == "ended" and not pilot.is_empty() and pilot.status in ["active", "exited"] else 0
	return int(state.vp) - losses + pilot_bonus

func snapshot() -> Dictionary:
	var result := state.duplicate(true)
	result.rng = str(rng.state) # decimal string preserves int64 through JSON saves
	return result

func restore(candidate: Variant) -> bool:
	if not candidate is Dictionary: return false
	if candidate.get("version") != VERSION or candidate.get("mission") != "base_01": return false
	# Saves created before the evasive-movement state was added are still valid.
	candidate = candidate.duplicate(true)
	if not candidate.has("evasive_removals"): candidate.evasive_removals = {}
	if not candidate.has("ban_evasive_return"): candidate.ban_evasive_return = false
	if not candidate.has("minefields"): candidate.minefields = []
	if not candidate.has("pending_drop"): candidate.pending_drop = ""
	if not candidate.has("pending_ops"): candidate.pending_ops = []
	if not candidate.has("pending_hex_check"): candidate.pending_hex_check = ""
	if not candidate.has("pilot_found"): candidate.pilot_found = false
	if not candidate.has("round_setup"): candidate.round_setup = {}
	if not candidate.has("terrain_overrides"): candidate.terrain_overrides = {}
	for unit in candidate.get("squad", []):
		if unit is Dictionary and not unit.has("wounded"): unit.wounded = false
		if unit is Dictionary and not unit.has("port_boxes"):
			var item2: String = unit.weapon if unit.id in ["A","G"] else "Bazooka" if unit.id == "C" else "Carica esplosiva" if unit.id in ["F","H"] else ""
			unit.port_boxes = [unit.weapon, item2]
	for key in ["squad", "enemies", "log", "sightings", "event_markers", "history", "minefields", "pending_ops"]:
		if not candidate.get(key) is Array: return false
	for key in ["items", "landmarks", "evasive_removals", "terrain_overrides"]:
		if not candidate.get(key) is Dictionary: return false
	for hex_id in candidate.terrain_overrides:
		if not Hex.valid(str(hex_id)) or candidate.terrain_overrides[hex_id] not in ["crater","rubble"]: return false
	if not candidate.round_setup is Dictionary: return false
	if not candidate.get("ban_evasive_return") is bool: return false
	if not candidate.get("pilot_found") is bool: return false
	for key in ["rng", "blocked", "context_hex", "last_paragraph", "trigger_soldier", "phase", "pending_drop", "pending_hex_check"]:
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
		if not unit.get("wounded") is bool: return false
		if not unit.get("port_boxes") is Array or unit.port_boxes.size() != 2: return false
		for item in unit.port_boxes:
			if not item is String: return false
		if unit.id in ids or unit.id not in ["A","B","C","D","E","F","G","H","J","K"]: return false
		ids.append(unit.id)
		if unit.hex != "" and not Hex.valid(unit.hex): return false
		if unit.status not in ["active","exited","evacuated","incapacitated","killed"]: return false
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
