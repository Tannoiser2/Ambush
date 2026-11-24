extends SceneTree
## Gioca automaticamente molte partite con scelte casuali ma sensate, per scovare errori del motore.
## Uso: godot --headless --path . --script tests/simula.gd -- [partite] [seme] [missione]

const E = preload("res://scripts/motore/esagoni.gd")
const PartitaScript = preload("res://scripts/motore/partita.gd")

var obiettivi := ["T8", "K13", "V16", "L13", "R15", "G10"]
var missione := 1
var letti := {}
var statistiche := {"vinte": 0, "perse": 0, "round": 0, "attivazioni": 0, "errori": 0, "passi": 0}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 30
	var seme := int(args[1]) if args.size() > 1 else 1
	missione = int(args[2]) if args.size() > 2 else 1
	if missione == 2:
		obiettivi = ["O6", "P5", "Q5", "K7", "J13", "S13", "N12", "L10", "V8"]
	elif missione == 3:
		obiettivi = ["A3", "T3", "G13", "G14", "L10", "A15", "V3", "C3"]
	elif missione == 8:
		obiettivi = ["M12", "Y8", "S12", "K13", "T8", "O16"]
	elif missione == 7:
		obiettivi = ["R11", "Q16", "N12", "T8", "V15", "Y10"]
	elif missione == 6:
		obiettivi = ["K8", "K11", "H16", "T13", "M12", "J10"]
	elif missione == 5:
		obiettivi = ["S6", "S13", "K7", "J13", "N9", "X10", "A14", "G12"]
	elif missione == 9:
		obiettivi = ["M7", "O15", "S17", "W15", "Y8"]
	elif missione == 12:
		obiettivi = ["G13", "Q8", "R7", "S13", "A10"]
	elif missione == 10:
		obiettivi = ["S13", "O9", "M12", "R14", "I13", "T8"]
	elif missione == 11:
		obiettivi = ["S12", "T8", "M6", "A8", "A12", "K13", "T8"]
	elif missione == 16:
		obiettivi = ["V12", "W14", "U15", "S14", "T11", "W16"]
	elif missione == 4:
		obiettivi = ["G13", "G14", "M6", "S13", "J13", "G5", "L10"]
	elif missione == 20:
		obiettivi = ["F4", "I5", "N4", "S4", "W6", "W10", "X12", "J14", "F16", "B19", "A8"]
	elif missione == 21:
		obiettivi = ["S13", "T12", "G14", "H13", "U13", "I13"]
	elif missione == 22:
		obiettivi = ["W8", "O4", "V14", "K14", "J14", "I15", "L14", "H15"]
	elif missione == 23:
		obiettivi = ["W8", "O14", "Q16", "S13", "V14", "P15", "T12"]
	elif missione == 24:
		obiettivi = ["K8", "K8", "Y12", "Y11", "Y13"]
	elif missione == 19:
		obiettivi = ["D1", "F4", "J7", "M7", "C6", "I7", "S1", "Q5"]
	for i in n:
		gioca(seme + i)
	print("RISULTATI ", JSON.stringify(statistiche))
	if OS.get_environment("AMBUSH_PAR") == "1":
		var chiavi := letti.keys()
		chiavi.sort()
		print("PARAGRAFI ", " ".join(chiavi.map(func(k): return "%s:%d" % [k, letti[k]])))
	quit(1 if statistiche.errori > 0 else 0)

func gioca(seme: int) -> void:
	var p = PartitaScript.new(missione)
	if bool(p.regola("sbarramento", false)):
		p.nuova(seme, true)
		p.inizia_missione()
	elif bool(p.regola("prigionieri_mo", false)):
		# Missione 12: la parte sulla mappa A è un percorso obbligato (Claude, chiatta); si simula la mappa B.
		p.nuova(seme, true)
		for a in p.americani().filter(func(x): return x.stato == "fuori"):
			p.schiera([a.id], "S1")
		p.inizia_missione()
		p.leggi("433", {"hex": "P11", "ids": []})
		for a in p.americani_attivi_in_mappa():
			a.hex = "M12"
		p._controlla_fine_automatica()
		var ch: Dictionary = p.veicoli.v("chiatta")
		p.s.imbarco = true
		for a in p.americani_attivi_in_mappa():
			p.veicoli.sali(a, ch)
		p.s.imbarco = false
		ch.hex = "O19"
		for a in p.veicoli.occupanti(ch):
			a.hex = "O19"
		p._controlla_fine_automatica()
		for a in p.americani_attivi_in_mappa():
			p.veicoli.scendi(a)
			a.hex = "B6"
	elif p.missione.get("regole", {}).has("angoli"):
		# Missione 16: due soldati per angolo, il resto vicino al deposito.
		p.nuova(seme, true)
		var angoli := ["B2", "B18", "X2", "X18"]
		var i16 := 0
		for a in p.americani():
			p.schiera([a.id], angoli[i16 % 4] if i16 < 8 else "S12")
			i16 += 1
		p.inizia_missione()
	elif not p.regola("sezioni", []).is_empty():
		p.nuova(seme, true)
		for a in p.americani():
			var messo := false
			for sez in p.regola("sezioni", []):
				for h in sez.esagoni:
					if p.schiera([a.id], h).ok:
						messo = true
						break
				if messo:
					break
		p.inizia_missione()
	elif bool(p.regola("sentinella", false)):
		p.nuova(seme, true)
		p.schiera([p.americani()[0].id], "Y8")
		p.inizia_missione()
	elif bool(p.regola("convoglio", false)):
		p.nuova(seme, true)
		var ing_c: String = ["A8", "B19"][seme % 2]
		for a in p.americani():
			p.schiera([a.id], ing_c)
		p.inizia_missione()
	elif bool(p.regola("lancio", false)) or int(p.regola("max_edifici", 0)) > 0 or int(p.regola("canoe", 0)) > 0 or int(p.regola("schieramento_ruscello", 0)) > 0:
		p.nuova(seme, true)
		var ingressi: Array = p.esagoni_ingresso()
		var i := 0
		for a in p.americani():
			if bool(p.regola("lancio", false)):
				p.schiera([a.id], ingressi[i])
			elif int(p.regola("canoe", 0)) > 0:
				p.schiera([a.id], str(p.esagoni_ingresso()[0]) if p.ss.attiva() else "H1")
			elif int(p.regola("schieramento_ruscello", 0)) > 0:
				p.schiera([a.id], ingressi[(i * 37) % ingressi.size()])
			else:
				p.schiera([a.id], ingressi[(i % 3) * 7])
			i += 1
		p.inizia_missione()
	else:
		p.nuova(seme)
	if p.ss.m22.attiva():
		for a in p.americani():
			if str(a.get("veicolo", "")) != "":
				p.scendi_veicolo(a.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seme * 7919
	var bersaglio_di := {}
	for a in p.americani():
		bersaglio_di[a.id] = obiettivi[rng.randi_range(0, obiettivi.size() - 1)]
	var passi := 0
	var ultimo_n := -1
	while p.s.fase != "fine" and passi < 2500:
		passi += 1
		if p.ph.m18.decisione_pendente() and rng.randf() < 0.5:
			p.esegui_scelta(["992", "994"][rng.randi_range(0, 1)])
			continue
		if not p.s.get("scelte", {}).is_empty() and rng.randf() < 0.05:
			var ks: Array = p.s.scelte.keys()
			p.esegui_scelta(str(ks[rng.randi_range(0, ks.size() - 1)]))
			continue
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
	if OS.get_environment("AMBUSH_CODA") != "":
		for v in p.s.cronaca.slice(-int(OS.get_environment("AMBUSH_CODA"))):
			print("  [%s] %s" % [v.t, str(v.x).left(160)])
	for v in p.s.cronaca:
		if v.t == "par" and OS.get_environment("AMBUSH_PAR") == "1":
			var k := str(v.get("id", ""))
			letti[k] = int(letti.get(k, 0)) + 1
		if v.t == "errore":
			statistiche.errori += 1
			if OS.get_environment("AMBUSH_ERRORI") == "1":
				print("ERRORE CRONACA: ", str(v.x).left(200))
			print("ERRORE [seme %d]: %s" % [seme, v.x])
	statistiche.attivazioni += p.s.attivati.size()
	statistiche.passi += passi
	if OS.get_environment("AMBUSH_CRONACA") == "1":
		for c in p.s.cronaca:
			if str(c.t) in ["danno", "combattimento", "dado", "tedesco", "par", "info", "attivazione"]:
				print("  [%s] %s" % [c.t, str(c.x).left(160)])
	if OS.get_environment("AMBUSH_FINE") == "1":
		print("FINE [seme %d] fase=%s passi=%d %s" % [seme, p.s.fase, passi, JSON.stringify(p.s.fine).left(400)])
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

## Missione 20: la jeep in testa segue la strada verso la tappa successiva; davanti a un blocco qualcuno scende e lo sgombra.
func _strada_bfs(p, v: Dictionary, da: String, meta: String) -> String:
	var prec := {da: ""}
	var coda: Array = [da]
	while not coda.is_empty():
		var h: String = coda.pop_front()
		if h == meta:
			break
		for n in E.vicini(h):
			if prec.has(n):
				continue
			var t: String = p.terreno.tipo(n)
			if not (t == "road" or p.terreno.ponte(n)) and n != meta:
				continue
			if p.veicoli.costo(v, h, n) < 0 and not (n in p.s.get("blocchi", [])):
				continue
			prec[n] = h
			coda.append(n)
	if not prec.has(meta):
		return ""
	var x := meta
	while prec[x] != da and prec[x] != "":
		x = prec[x]
	return x

func _tappa20(p, v: Dictionary) -> String:
	var fine: Dictionary = p.s.get("ss", {}).get("fine20", {})
	var tappe: Array = (["W6", "W10", "F16", "B19"] if p.s.get("ss", {}).get("ingresso20", "A8") == "A8" else ["W10", "W6", "F4", "A8"])
	if not fine.is_empty():
		tappe = [fine.mezzi[0]]
	var k := 0
	while k < tappe.size() - 1 and str(tappe[k]) in v.get("passati", []):
		k += 1
	return str(tappe[k])

func _guida_round(p, a: Dictionary) -> bool:
	var v: Dictionary = p.veicoli.di(a)
	if not v.get("convoglio", false) or not p.veicoli.e_autista(a) or not p.veicoli.attivo(v):
		return false
	var fine: Dictionary = p.s.get("ss", {}).get("fine20", {})
	if not fine.is_empty() and v.hex in fine.mezzi:
		return p.esci(a.id).ok
	p.scegli_azione(a.id, "muovi")
	if p.s.turno.is_empty() or p.s.turno.get("id", "") != a.id:
		return false
	for i in 5:
		var verso := _strada_bfs(p, v, v.hex, _tappa20(p, v))
		if verso == "" or verso in p.s.get("blocchi", []) or p.s.turno.is_empty() or p.s.turno.get("id", "") != a.id:
			break
		if not p.muovi([a.id], verso).ok:
			break
	if not p.s.turno.is_empty() and p.s.turno.get("id", "") == a.id:
		p.fine_azione(a.id)
	return true

func _mossa_convoglio(p, rng: RandomNumberGenerator) -> bool:
	var m20 = p.ss.m20
	var lista: Array = m20.mezzi_attivi()
	if lista.is_empty():
		return false
	var v: Dictionary = lista[0]
	var autista: Dictionary = p.veicoli.autista(v)
	if autista.is_empty() or not p.attivo(autista):
		return false
	var fine: Dictionary = p.s.get("ss", {}).get("fine20", {})
	if not fine.is_empty() and v.hex in fine.mezzi:
		p.esci(autista.id)
		return true
	var verso := _strada_bfs(p, v, v.hex, _tappa20(p, v))
	if verso == "":
		return false
	if verso in p.s.get("blocchi", []):
		for x in p.americani_attivi_in_mappa():
			if x.hex == verso and str(x.get("veicolo", "")) == "":
				p.sgombra_blocco_ss(x.id)
				return true
		for x in p.veicoli.occupanti(v):
			if not p.veicoli.e_autista(x):
				if p.scendi_veicolo(x.id).ok:
					p.muovi([x.id], verso)
					return true
		return false
	return p.muovi([autista.id], verso).ok

func _mossa_operazioni(p, rng: RandomNumberGenerator, bersaglio_di: Dictionary, passi: int) -> void:
	if p.ss.m20.attiva() and rng.randf() < 0.85 and _mossa_convoglio(p, rng):
		return
	if p.sherman_entrabile() and rng.randf() < 0.5:
		p.entra_sherman()
		return
	var candidati: Array = p.americani().filter(func(x): return (x.stato == "attivo" and x.hex != "") or x.stato == "fuori")
	if candidati.is_empty():
		p.termina_missione("ritirata")
		return
	var a: Dictionary = candidati[rng.randi_range(0, candidati.size() - 1)]
	if p.ss.puo_esplosivo(a):
		p.ss.piazza_esplosivo(a)
		return
	var vc: Dictionary = p.veicoli.di(a)
	if p.veicoli.e_canoa(vc) and not p.veicoli.e_autista(a):
		if p.veicoli.spiaggiata(vc):
			p.scendi_veicolo(a.id)
		return
	if p.veicoli.e_canoa(vc) and p.veicoli.spiaggiata(vc) and rng.randf() < 0.5:
		p.scendi_veicolo(a.id)
		return
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
				var verso := _passo_verso(p, a, obiettivi[0], rng)
				if verso != "":
					p.trascina(a.id, x.id, verso)
					return
		if p.s.has("cassa") and p.s.cassa.stato == "chiusa" and p.s.cassa.hex == a.hex:
			p.cambia_postura(a.id, "crouching")
			p.apri_cassa(a.id)
			return
		if p.ponti().has(a.hex) and bool(p.regola("disinnesco", false)) and p.disinnesca_ponte(a.id).ok:
			return
		for hi in p.installazioni_vicine(a):
			if p.demolisci(a.id, hi).ok:
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
	if passi > 1500 and a.hex != "" and p.e_uscita(a.hex):
		p.esci(a.id)
		return
	var meta: String = bersaglio_di[a.id] if passi < 1500 else str(p.esagoni_ingresso()[0])
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
	if p.ss.m20.attiva() and rng.randf() < 0.7 and _guida_round(p, a):
		return
	if p.ss.m24.attiva() and p.ss.m24.puo_prendere(a) and rng.randf() < 0.5:
		p.azione_ss(a.id, "prendi_muli")
		return
	if p.ss.m21.attiva() and p.veicoli.attivo(p.veicoli.v("vpb")) and str(a.get("veicolo", "")) != "vpb":
		bersaglio_di[a.id] = p.veicoli.v("vpb").hex
	if a.get("artiglieria", false):
		var bers: Array = p.tedeschi_attivi()
		if bers.is_empty():
			p.passa(a.id)
			return
		var k := 0 if p.s.turno.is_empty() or not (0 in p.s.turno.get("colpi", [])) else 1
		if not p.mo.colpo(a.id, k, bers[rng.randi_range(0, bers.size() - 1)].hex).get("ok", false):
			p.passa(a.id)
		return
	if int(a.get("paracadute", 0)) > 0:
		if a.postura == "prone":
			p.cambia_postura(a.id, "crouching")
		if not p.togli_paracadute(a.id).ok:
			p.passa(a.id)
		return
	if a.stato != "fuori" and p.ponti().has(a.hex) and bool(p.regola("disinnesco", false)) and p.disinnesca_ponte(a.id).ok:
		return
	for hb in p.bunker_in_vista(a):
		for arma in p.armi_da_fuoco(a):
			if a.postura == "prone":
				p.cambia_postura(a.id, "crouching")
			if rng.randf() < 0.5 and p.tiro_bunker(a.id, arma.tipo, hb).ok:
				return
	if a.stato == "fuori":
		p.scegli_azione(a.id, "muovi")
		if p.s.turno.is_empty() or p.s.turno.get("id", "") != a.id:
			return
		var ingr: Array = p.esagoni_ingresso()
		var r: Dictionary = p.muovi([a.id], ingr[rng.randi_range(0, ingr.size() - 1)])
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
