extends SceneTree
## Gioca partite intere passando dall’interfaccia (modo automatico, velocità altissima) per scovare
## errori in ogni tipo di passo: consapevolezza, evento, iniziativa, turni tedeschi, fine Round.
## Uso: xvfb-run godot --path . --script tests/visivi/partita_ui.gd -- [partite] [seme]
const E = preload("res://scripts/motore/esagoni.gd")
var ui
var conteggio := {}

func _init() -> void:
	DisplayServer.window_set_size(Vector2i(640, 360))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_gioca()

func attendi() -> void:
	var fermo := 0
	var giri := 0
	while fermo < 3 and giri < 4000:
		giri += 1
		await process_frame
		if ui.riproducendo or (ui.p.s.pausa != "" and ui.p.s.fase != "fine"):
			fermo = 0
		else:
			fermo += 1
	if giri >= 4000:
		print("ERRORE: la riproduzione non termina (pausa «%s», in attesa %s)" % [ui.p.s.pausa, ui._in_attesa])
		conteggio["bloccata"] = int(conteggio.get("bloccata", 0)) + 1
		ui._salta_tutto = true

func _verso(a: Dictionary, meta: String, rng: RandomNumberGenerator) -> String:
	var dest: Array = ui.p.destinazioni(a.id)
	var migliore := ""
	var dmin := 999.0
	for d in dest:
		var dd: float = E.distanza(d, meta) + rng.randf() * 1.5
		if dd < dmin:
			dmin = dd
			migliore = d
	return migliore

func _gioca() -> void:
	await create_timer(0.4).timeout
	var args := OS.get_cmdline_user_args()
	var partite := int(args[0]) if args.size() > 0 else 3
	var seme0 := int(args[1]) if args.size() > 1 else 1
	var vinte := 0
	for k in partite:
		var rng := RandomNumberGenerator.new()
		rng.seed = (seme0 + k) * 7919
		var p: Partita = ui.p
		p.nuova(seme0 + k)
		ui._chiudi_finestra()
		ui.automatico = true
		ui.mappa.velocita = 60.0
		ui._aggiorna_tutto(true)
		var mete := ["T8", "K13", "T12"]
		var comandi := 0
		while p.s.fase != "fine" and comandi < 900:
			comandi += 1
			if p.s.fase == "operazioni":
				if p.condizioni_vittoria().ok:
					ui._esito(p.termina_missione("obiettivo"))
					await attendi()
					break
				var attivi: Array = p.americani().filter(func(x): return (x.stato == "attivo" and x.hex != "") or x.stato == "fuori")
				if attivi.is_empty():
					break
				var a: Dictionary = attivi[rng.randi_range(0, attivi.size() - 1)]
				ui.selezione = [a.id]
				ui.modo = ""
				ui._aggiorna_tutto()
				if a.hex != "" and a.postura != "standing":
					ui._esito(p.cambia_postura(a.id, "standing"))
				else:
					var indice: int = "ABCDEFGH".find(a.lettera)
					var meta: String = mete[maxi(0, indice) % 3]
					if a.hex == meta:
						continue
					var v := _verso(a, meta, rng)
					if v == "":
						continue
					ui._clic_mappa(v, 1)
			else:
				var di_turno: Array = p.americani_di_turno()
				if di_turno.is_empty():
					ui._prosegui()
					await attendi()
					continue
				var a: Dictionary = di_turno[0]
				ui.selezione = [a.id]
				ui._aggiorna_tutto()
				var fatto := false
				if a.stato == "fuori":
					ui._esito(p.passa(a.id))
					fatto = true
				elif a.postura == "prone" and p.s.turno.is_empty() and not a.ferito:
					ui._esito(p.cambia_postura(a.id, "crouching"))
					await attendi()
				if not fatto and p.puo_agire(a) == "" and a.postura != "prone":
					for g in p.tedeschi_attivi():
						if fatto:
							break
						if int(a.munizioni.get("granata", 0)) > 0 and rng.randf() < 0.3 and p.probabilita_lancio(a, "granata", g.hex).ok:
							ui._esito(p.lancia(a.id, "granata", g.hex))
							fatto = true
							break
						for arma in p.armi_da_fuoco(a):
							if p.probabilita_tiro(a, arma, g, true).ok:
								ui.arma_scelta[a.id] = arma.tipo
								ui.modo = "mirato"
								ui._aggiorna_tutto()
								ui._spara(a, g)
								fatto = true
								break
				if not fatto and p.puo_agire(a) == "":
					ui._esito(p.passa(a.id))
			await attendi()
		for v in p.s.cronaca:
			if v.t == "errore":
				conteggio["errori_motore"] = int(conteggio.get("errori_motore", 0)) + 1
				print("ERRORE [seme %d]: %s" % [seme0 + k, v.x])
		if p.s.get("fine", {}).get("vinta", false):
			vinte += 1
		print("partita %d: %d comandi, fase %s, round giocati fino al %s, PV %d" % [seme0 + k, comandi, p.s.fase, str(p.s.get("round", {}).get("n", "-")), p.pv_totali()])
	print("RISULTATI UI ", JSON.stringify(conteggio), " vinte ", vinte, "/", partite)
	quit(1 if not conteggio.is_empty() else 0)
