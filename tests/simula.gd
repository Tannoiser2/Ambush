extends SceneTree
## Gioca automaticamente molte partite con scelte casuali ma sensate, per scovare errori del motore.
## Uso: godot --headless --path . --script tests/simula.gd -- [partite] [seme]

const E = preload("res://scripts/motore/esagoni.gd")
const PartitaScript = preload("res://scripts/motore/partita.gd")

var obiettivi := ["T8", "K13", "V16", "L13", "R15", "G10"]
var statistiche := {"vinte": 0, "perse": 0, "round": 0, "attivazioni": 0, "errori": 0, "passi": 0}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 30
	var seme := int(args[1]) if args.size() > 1 else 1
	for i in n:
		gioca(seme + i)
	print("RISULTATI ", JSON.stringify(statistiche))
	quit(1 if statistiche.errori > 0 else 0)

func gioca(seme: int) -> void:
	var p = PartitaScript.new()
	p.nuova(seme)
	var rng := RandomNumberGenerator.new()
	rng.seed = seme * 7919
	var bersaglio_di := {}
	for a in p.americani():
		bersaglio_di[a.id] = obiettivi[rng.randi_range(0, obiettivi.size() - 1)]
	var passi := 0
	var ultimo_n := -1
	while p.s.fase != "fine" and passi < 2500:
		passi += 1
		if p.s.pausa != "":
			p.prosegui()
			continue
		if p.s.fase == "operazioni":
			if p.condizioni_vittoria().ok:
				p.termina_missione("obiettivo")
				break
			_mossa_operazioni(p, rng, bersaglio_di, passi)
		elif p.s.fase == "round":
			if int(p.s.round.get("n", 0)) != ultimo_n:
				ultimo_n = int(p.s.round.get("n", 0))
				statistiche.round += 1
			var di_turno: Array = p.americani_di_turno()
			if di_turno.is_empty():
				p.prosegui()
				continue
			_mossa_round(p, rng, di_turno[rng.randi_range(0, di_turno.size() - 1)], bersaglio_di)
	if p.s.fase != "fine":
		p.termina_missione("ritirata")
	if OS.get_environment("AMBUSH_CRONACA") == "1":
		print(JSON.stringify(p.s.fine))
	for v in p.s.cronaca:
		if v.t == "errore":
			statistiche.errori += 1
			print("ERRORE [seme %d]: %s" % [seme, v.x])
	statistiche.attivazioni += p.s.attivati.size()
	statistiche.passi += passi
	if p.s.fine.get("vinta", false):
		statistiche.vinte += 1
	else:
		statistiche.perse += 1
	# Salvataggio e ricarica devono funzionare in qualsiasi momento.
	var dati: Dictionary = JSON.parse_string(JSON.stringify(p.salva()))
	var q = PartitaScript.new()
	if not q.carica(dati):
		statistiche.errori += 1
		print("ERRORE [seme %d]: ricarica fallita" % seme)

func _passo_verso(p, a: Dictionary, meta: String, rng: RandomNumberGenerator) -> String:
	var dest: Array = p.destinazioni(a.id)
	if dest.is_empty():
		return ""
	dest.shuffle()
	var migliore: String = dest[0]
	var dmin := 999
	for d in dest:
		var dd: int = E.distanza(d, meta) + (rng.randi_range(0, 2) if rng.randf() < 0.3 else 0)
		if dd < dmin:
			dmin = dd
			migliore = d
	return migliore

func _mossa_operazioni(p, rng: RandomNumberGenerator, bersaglio_di: Dictionary, passi: int) -> void:
	var candidati: Array = p.americani().filter(func(x): return (x.stato == "attivo" and x.hex != "") or x.stato == "fuori")
	if candidati.is_empty():
		p.termina_missione("ritirata")
		return
	var a: Dictionary = candidati[rng.randi_range(0, candidati.size() - 1)]
	if a.hex != "" and a.postura == "prone":
		p.cambia_postura(a.id, "standing")
		return
	if not bersaglio_di.has(a.id): bersaglio_di[a.id] = "K13"
	if a.hex == bersaglio_di[a.id] or rng.randf() < 0.02:
		bersaglio_di[a.id] = obiettivi[rng.randi_range(0, obiettivi.size() - 1)]
	# Trascina K o i feriti verso un edificio, ogni tanto.
	if a.hex != "":
		for x in p.unita_in(a.hex, "us", false):
			if x.stato == "incapacitato" and a.postura == "standing" and rng.randf() < 0.5:
				var verso := _passo_verso(p, a, "K13", rng)
				if verso != "":
					p.trascina(a.id, x.id, verso)
					return
		if a.hex == "R15" and p.s.pilota == "intrappolato" and not a.ferito:
			p.libera_pilota(a.id)
			return
		var ogg: Array = p.oggetti_disponibili(a.id)
		if not ogg.is_empty() and rng.randf() < 0.3:
			if a.postura == "standing":
				p.cambia_postura(a.id, "crouching")
			p.prendi(a.id, ogg[0])
			return
	if passi > 1500 and a.hex != "" and E.riga(a.hex) == 1 and E.colonna(a.hex) <= 9:
		p.esci(a.id)
		return
	var meta: String = bersaglio_di[a.id] if passi < 1500 else "E1"
	var verso := _passo_verso(p, a, meta, rng)
	if verso == "":
		if a.postura != "standing":
			p.cambia_postura(a.id, "standing")
		return
	var gruppo: Array = [a.id]
	if a.hex != "" and rng.randf() < 0.4:
		for x in p.unita_in(a.hex, "us"):
			if x.id != a.id and x.postura == a.postura:
				gruppo.append(x.id)
	var r: Dictionary = p.muovi(gruppo, verso)
	if not r.ok:
		p.muovi([a.id], verso)

func _mossa_round(p, rng: RandomNumberGenerator, a: Dictionary, bersaglio_di: Dictionary) -> void:
	if a.stato == "fuori":
		p.scegli_azione(a.id, "muovi")
		var r: Dictionary = p.muovi([a.id], "%s1" % char(65 + rng.randi_range(0, 9)))
		if not r.ok:
			p.passa(a.id)
		elif not p.s.turno.is_empty():
			p.fine_azione(a.id)
		return
	# Nemico nello stesso esagono: assalto.
	var stessi: Array = p.unita_in(a.hex, "de")
	if not stessi.is_empty():
		if a.postura != "standing":
			p.cambia_postura(a.id, "standing")
		var r: Dictionary = p.assalta(a.id, stessi[0].id, "cattura" if rng.randf() < 0.5 else "uccidi")
		if r.ok:
			return
	# Granata ogni tanto.
	if int(a.munizioni.get("granata", 0)) > 0 and rng.randf() < 0.15:
		for g in p.tedeschi_attivi():
			if E.distanza(a.hex, g.hex) <= 3 and E.distanza(a.hex, g.hex) >= 1:
				if a.postura == "prone":
					p.cambia_postura(a.id, "crouching")
				if p.lancia(a.id, "granata", g.hex).ok:
					return
	# Bazooka da preparare.
	var bz: Dictionary = p.arma_di(a, "bazooka")
	if not bz.is_empty() and not bz.preparata and int(a.munizioni.get("bazooka", 0)) > 0 and rng.randf() < 0.5:
		if a.postura == "prone":
			p.cambia_postura(a.id, "crouching")
		if p.prepara(a.id, "bazooka").ok:
			return
	for arma in a.armi:
		if arma.inceppata and rng.randf() < 0.7:
			if a.postura == "prone":
				p.cambia_postura(a.id, "crouching")
			if p.disinceppa(a.id, arma.tipo).ok:
				return
	# Tiro al miglior bersaglio visibile.
	var migliore := {}
	var prob := -1
	var arma_scelta := ""
	var postura_tiro: String = a.postura if a.postura != "prone" else "crouching"
	var vecchia: String = a.postura
	a.postura = postura_tiro
	for g in p.tedeschi_attivi():
		for arma in p.armi_da_fuoco(a):
			var pr: Dictionary = p.probabilita_tiro(a, arma, g, true)
			if pr.ok and int(pr.prob) > prob:
				prob = int(pr.prob)
				migliore = g
				arma_scelta = arma.tipo
	a.postura = vecchia
	if not migliore.is_empty():
		if a.postura == "prone":
			p.cambia_postura(a.id, "crouching")
		var mirato := rng.randf() < 0.7
		var r: Dictionary = p.tiro(a.id, arma_scelta, migliore.id, mirato)
		if r.ok:
			if not mirato and not p.s.turno.is_empty() and p.s.turno.id == a.id:
				var r2: Dictionary = p.tiro(a.id, arma_scelta, migliore.id, false)
				if not r2.ok and not p.s.turno.is_empty() and p.s.turno.id == a.id:
					p.fine_azione(a.id)
			return
	# Comandante: cede turni o allerta.
	if a.comandante:
		for x in p.americani_attivi_in_mappa():
			if x.id != a.id and not x.consapevole and not x.ferito and E.distanza(x.hex, a.hex) <= 2:
				if p.sveglia(a.id, x.id).ok:
					return
	# Movimento verso il tedesco più vicino o l’obiettivo.
	if a.postura == "prone" and rng.randf() < 0.6:
		p.cambia_postura(a.id, "standing")
	var meta: String = bersaglio_di.get(a.id, "K13")
	var vicino := 99
	for g in p.tedeschi_attivi():
		var d: int = E.distanza(g.hex, a.hex)
		if d < vicino:
			vicino = d
			meta = g.hex
	if a.postura == "prone" or rng.randf() < 0.2:
		p.passa(a.id)
		return
	var tipo := "carica" if vicino == 1 and rng.randf() < 0.5 else "muovi"
	if not p.scegli_azione(a.id, tipo).ok:
		p.passa(a.id)
		return
	for i in 4:
		if p.s.turno.is_empty() or p.s.turno.id != a.id:
			return
		var verso := _passo_verso(p, a, meta, rng)
		if verso == "" or not p.muovi([a.id], verso).ok:
			break
		if tipo == "carica":
			var qui: Array = p.unita_in(a.hex, "de")
			if not qui.is_empty() and p.s.turno.get("id", "") == a.id:
				p.assalta(a.id, qui[0].id, "uccidi")
				return
	if not p.s.turno.is_empty() and p.s.turno.id == a.id:
		if p.s.turno.azione == "carica":
			# Carica senza bersaglio: si annulla trasformandola in movimento.
			p.s.turno.azione = "muovi"
		p.fine_azione(a.id)
