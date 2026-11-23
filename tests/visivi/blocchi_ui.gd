extends SceneTree
## Cerca i «blocchi» dell’interfaccia: momenti in cui tocca a un soldato americano (o c’è una pausa)
## e nel pannello delle azioni non c’è nessun bottone attivo per andare avanti.
## Gioca premendo bottoni a caso del pannello e muovendo i soldati verso esagoni a caso.
## Uso: xvfb-run godot --path . --script tests/visivi/blocchi_ui.gd -- [missione] [partite] [seme]
var ui
var rng := RandomNumberGenerator.new()
var blocchi := 0
var esclusi := ["Equipaggiamento", "Esci", "Briefing", "Regole", "Grafica", "Legenda", "Nuova partita", "Resoconto", "Altra missione"]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var m := int(args[0]) if args.size() > 0 else 1
	var n := int(args[1]) if args.size() > 1 else 3
	var seme := int(args[2]) if args.size() > 2 else 1
	DisplayServer.window_set_size(Vector2i(1366, 900))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_gioca(m, n, seme)

func bottoni(nodo: Node, out: Array) -> void:
	for c in nodo.get_children():
		if c is Button and c.visible and not c.disabled:
			out.append(c)
		bottoni(c, out)

func _schiera(p) -> void:
	var ing: Array = p.esagoni_ingresso()
	var i := 0
	for a in p.americani():
		var h: String = ing[(i * 7) % ing.size()]
		if bool(p.regola("uno_per_esagono", false)):
			h = ing[i % ing.size()]
		elif int(p.regola("max_edifici", 0)) > 0:
			h = ing[(i % 3) * 5]
		elif int(p.regola("canoe", 0)) > 0:
			h = "H1"
		p.schiera([a.id], h)
		i += 1
	p.inizia_missione()

func _gioca(m: int, n: int, seme: int) -> void:
	await process_frame
	for k in n:
		rng.seed = seme * 1000 + k
		ui._chiudi_pagina_missioni()
		ui._avvia_missione(m, false)
		ui._chiudi_finestra()
		var p = ui.p
		p.nuova(seme * 100 + k, true)
		_schiera(p)
		ui.selezione = []
		ui._aggiorna_tutto(true)
		ui.automatico = true
		var passi := 0
		var stesso := 0
		var ultimo := ""
		while p.s.fase != "fine" and passi < 2500:
			passi += 1
			if ui.finestra.visible:
				ui._chiudi_finestra()
			var attese := 0
			while ui.riproducendo and attese < 400:
				attese += 1
				ui._premi_continua()
				await process_frame
			var firma := "%s|%s|%s|%s" % [p.s.fase, str(p.s.pausa), str(p.s.get("round", {}).get("n", 0)), str(p.s.turno)]
			stesso = stesso + 1 if firma == ultimo else 0
			if OS.get_environment("DEBUG_UI") == "1" and passi < 40:
				print(passi, " ", firma.left(120), " ripr=", ui.riproducendo, " fin=", ui.finestra.visible, " sel=", ui.selezione)
			ultimo = firma
			if p.s.fase == "operazioni":
				_mossa_operazioni(p)
				if passi > 1200:
					for a in p.americani_attivi_in_mappa():
						a.stato = "uscito"
						a.hex = ""
					p._controlla_fine_automatica()
				continue
			var di_turno: Array = p.americani_di_turno()
			if p.s.pausa == "" and not di_turno.is_empty() and (ui.selezione.is_empty() or not (p.u(ui.selezione[0]) in di_turno)):
				ui.selezione = [di_turno[0].id]
			ui._aggiorna_tutto(false)
			var lista: Array = []
			bottoni(ui.flusso_azioni, lista)
			lista = lista.filter(func(b): return not esclusi.any(func(e): return str(b.text).begins_with(e)))
			if lista.is_empty():
				blocchi += 1
				var a: Dictionary = p.u(ui.selezione[0]) if not ui.selezione.is_empty() else {}
				print("BLOCCO M%d partita %d: fase %s pausa «%s» turno %s · soldato %s (%s, %s, paracadute %s, veicolo %s) · testo: %s" % [m, k, p.s.fase, p.s.pausa, str(p.s.turno),
					a.get("id", "-"), a.get("hex", "-"), a.get("postura", "-"), str(a.get("paracadute", 0)), str(a.get("veicolo", "")), ui.aiuto_azioni.text.left(160)])
				# Sblocca per proseguire la ricerca.
				if not di_turno.is_empty():
					p.s.turno = {}
					p._termina_azione(di_turno[0]) if p.s.turno.is_empty() else null
					di_turno[0].turni = 0
					di_turno[0].slot = "finito"
				p._flusso()
				continue
			if stesso > 25:
				# Bottoni che non fanno avanzare: si preferiscono quelli di chiusura.
				var fine: Array = lista.filter(func(b): return str(b.text).begins_with("Passa") or str(b.text).begins_with("Fine") or str(b.text).begins_with("Prosegui") or str(b.text).begins_with("Termina"))
				if not fine.is_empty():
					lista = fine
			# Movimento: se si è in modalità movimento, si prova un esagono di destinazione.
			if not ui.selezione.is_empty() and p.fase_round() and not p.s.turno.is_empty() and str(p.s.turno.get("azione", "")) in ["muovi", "muovi_spara"] and rng.randf() < 0.6:
				var dest: Array = p.destinazioni(ui.selezione[0])
				if not dest.is_empty():
					p.muovi([ui.selezione[0]], dest[rng.randi_range(0, dest.size() - 1)])
					continue
			var b: Button = lista[rng.randi_range(0, lista.size() - 1)]
			b.emit_signal("pressed")
			# Mortai (Missione 10): si tocca l’esagono di un tedesco.
			if str(ui.modo).begins_with("mortaio"):
				var bers: Array = p.tedeschi_attivi()
				ui._clic_mappa(bers[rng.randi_range(0, bers.size() - 1)].hex if not bers.is_empty() else "M10", 1)
			# Tiro o lancio in modalità: si sceglie un bersaglio a caso.
			if str(ui.modo) in ["mirato", "rapido", "granata"] and not ui.selezione.is_empty():
				var tedeschi: Array = p.tedeschi_attivi()
				if not tedeschi.is_empty():
					var g: Dictionary = tedeschi[rng.randi_range(0, tedeschi.size() - 1)]
					var arma: String = str(ui.arma_scelta.get(ui.selezione[0], ""))
					if ui.modo == "granata":
						p.lancia(ui.selezione[0], "granata", g.hex)
					elif arma != "":
						p.tiro(ui.selezione[0], arma, g.id, ui.modo == "mirato")
				ui.modo = ""
		var err: Array = p.s.cronaca.filter(func(c): return str(c.get("t", "")) == "errore")
		if p.s.fase == "round":
			print("  tedeschi attivi: ", p.tedeschi_attivi().map(func(g): return "%s@%s %s" % [g.id, g.hex, str(g.get("stato", ""))]), " · americani: ", p.americani().map(func(x): return "%s@%s %s" % [x.id, x.hex, x.stato]))
		print("M%d partita %d: %s dopo %d passi, Round %d, errori nella cronaca %d" % [m, k, p.s.fase, passi, int(p.s.get("round", {}).get("n", 0)), err.size()])
	print("BLOCCHI TOTALI M%d: %d" % [m, blocchi])
	quit()

func _mossa_operazioni(p) -> void:
	var cand: Array = p.americani().filter(func(x): return x.stato == "attivo" and x.hex != "")
	var mobili: Array = cand.filter(func(x): return not p.destinazioni(x.id).is_empty())
	if not mobili.is_empty() and rng.randf() < 0.85:
		cand = mobili
	if cand.is_empty():
		p._controlla_fine_automatica()
		if p.s.fase != "fine":
			p.termina_missione("ritirata")
		return
	var a: Dictionary = cand[rng.randi_range(0, cand.size() - 1)]
	ui.selezione = [a.id]
	ui._aggiorna_tutto(false)
	var lista: Array = []
	bottoni(ui.flusso_azioni, lista)
	lista = lista.filter(func(b): return not esclusi.any(func(e): return str(b.text).begins_with(e)) and not str(b.text).begins_with("Prono"))
	if not lista.is_empty() and rng.randf() < 0.25:
		lista[rng.randi_range(0, lista.size() - 1)].emit_signal("pressed")
		return
	var dest: Array = p.destinazioni(a.id)
	if dest.is_empty():
		if a.postura != "standing":
			p.cambia_postura(a.id, "standing")
		return
	p.muovi([a.id], dest[rng.randi_range(0, dest.size() - 1)])
