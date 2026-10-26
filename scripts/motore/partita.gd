class_name Partita
extends RefCounted
## Motore della Missione 1: Operazioni, Round, paragrafi, combattimento e punteggio.
## Tutto lo stato è in `s` (dizionario serializzabile in JSON).

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")
const TerrenoScript = preload("res://scripts/motore/terreno.gd")
const TedeschiScript = preload("res://scripts/motore/tedeschi.gd")

signal aggiornata

var s: Dictionary = {}
var missione: Dictionary
var paragrafi: Dictionary
var terreno: Terreno
var ia: RefCounted
var rng := RandomNumberGenerator.new()
## Voci di cronaca prodotte dall’ultimo comando (per la scheda dei paragrafi).
var recenti: Array = []
var _profondita := 0
var _stampa := OS.get_environment("AMBUSH_CRONACA") == "1"

func _init() -> void:
	missione = JSON.parse_string(FileAccess.get_file_as_string("res://data/missione1.json"))
	paragrafi = JSON.parse_string(FileAccess.get_file_as_string("res://data/paragrafi.json"))
	terreno = TerrenoScript.new()
	ia = TedeschiScript.new(self)

# =================================================================== stato
func nuova(seme := 0) -> void:
	if seme == 0:
		seme = int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
	rng.seed = seme
	s = {
		"versione": 2, "seme": seme, "fase": "operazioni", "condizione": 1,
		"avvistamenti": [false, false, false, false, false, false, false, false, false, false],
		"pv": [], "eventi": {}, "mine": {}, "modifiche": {}, "oggetti": {}, "punti": {},
		"unita": {}, "evasi": {}, "no_rientro": false, "pilota": "", "cronaca": [],
		"round": {}, "turno": {}, "pausa": "", "fine": {}, "nota_mine": false, "attivati": [],
	}
	for d in missione.squadra:
		var u := _nuovo_americano(d)
		s.unita[u.id] = u
	terreno.imposta_modifiche(s.modifiche)
	_log("titolo", "Missione 1 · Sangue a Saint-Michaux")
	_log("info", missione.briefing)
	_log("info", "Condizione 1. Livello di attivazione 0–1. Entra con i soldati dal margine nord (A1–J1).")
	recenti.clear()
	aggiornata.emit()

func _nuovo_americano(d: Dictionary) -> Dictionary:
	var armi: Array = []
	for p in d.porte:
		armi.append({"tipo": p, "inceppata": false, "rotta": false, "preparata": false, "catturata": false})
	return {
		"id": d.id, "lato": "us", "lettera": d.id, "nome": d.nome, "IN": d.IN, "PC": d.PC, "WS": d.WS,
		"DS": d.DS, "MPA": d.MPA, "comandante": d.comandante, "hex": "", "postura": "standing",
		"stato": "fuori", "ferito": false, "panico": false, "consapevole": false, "turni": 0, "slot": "",
		"armi": armi, "munizioni": d.munizioni.duplicate(), "sul_ponte": false, "prigionieri": [],
		"senza_carta": false, "protetto": false,
	}

func salva() -> Dictionary:
	s.rng_stato = str(rng.state)
	return s.duplicate(true)

func carica(dati: Dictionary) -> bool:
	if int(dati.get("versione", 0)) != 2:
		return false
	s = dati.duplicate(true)
	rng.seed = int(s.seme)
	if s.has("rng_stato"):
		rng.state = int(s.rng_stato)
	terreno.imposta_modifiche(s.modifiche)
	recenti.clear()
	aggiornata.emit()
	return true

# =================================================================== utilità
func d10(motivo := "") -> int:
	var r := rng.randi_range(0, 9)
	if motivo != "":
		_log("dado", "%s: %d" % [motivo, r])
	return r

func percentuale() -> int:
	return rng.randi_range(0, 99)

func _log(tipo: String, testo: String, extra := {}) -> void:
	var v := {"t": tipo, "x": testo}
	if not extra.is_empty():
		v.merge(extra)
	if s.has("round") and not s.round.is_empty():
		v.r = int(s.round.get("n", 0))
	s.cronaca.append(v)
	if s.cronaca.size() > 600:
		s.cronaca = s.cronaca.slice(s.cronaca.size() - 600)
	recenti.append(v)
	if _stampa:
		print("[%s] %s%s" % [tipo, ("§" + str(extra.id) + " ") if extra.has("id") else "", testo])

func u(id: String) -> Dictionary:
	return s.unita.get(id, {})

func nome(x) -> String:
	var un: Dictionary = x if x is Dictionary else u(str(x))
	if un.is_empty():
		return "?"
	if not un.has("lettera"):
		return "Un cecchino nascosto"
	if un.lato == "de":
		return "tedesco %d (%s)" % [int(un.num), un.lettera]
	return "%s %s" % [un.lettera, un.nome]

func attivo(un: Dictionary) -> bool:
	return un.get("stato", "") == "attivo"

func in_mappa(un: Dictionary) -> bool:
	return attivo(un) and un.hex != ""

func americani() -> Array:
	var out: Array = []
	for k in s.unita:
		if s.unita[k].lato == "us":
			out.append(s.unita[k])
	return out

func tedeschi() -> Array:
	var out: Array = []
	for k in s.unita:
		if s.unita[k].lato == "de":
			out.append(s.unita[k])
	out.sort_custom(func(a, b): return a.lettera < b.lettera)
	return out

func americani_attivi_in_mappa() -> Array:
	return americani().filter(func(x): return in_mappa(x))

func tedeschi_attivi() -> Array:
	return tedeschi().filter(func(x): return in_mappa(x))

func unita_in(h: String, lato := "", solo_attivi := true) -> Array:
	var out: Array = []
	for k in s.unita:
		var x: Dictionary = s.unita[k]
		if x.hex != h:
			continue
		if lato != "" and x.lato != lato:
			continue
		if solo_attivi and not attivo(x):
			continue
		if not solo_attivi and x.stato in ["fuori", "uscito", "rimosso"]:
			continue
		out.append(x)
	return out

func pv_totali() -> int:
	var t := 0
	for v in s.pv:
		t += int(v.n)
	return t

func _pv(n: int, motivo: String) -> void:
	s.pv.append({"n": n, "motivo": motivo})
	_log("pv", "%+d PV — %s" % [n, motivo])

func livello_attivazione() -> int:
	return int(missione.attivazione.get(str(s.condizione), 8))

func fase_round() -> bool:
	return s.fase == "round"

func esagoni_strada() -> Array[String]:
	var out: Array[String] = []
	for h in E.tutti():
		if terreno.tipo(h) == "road" or terreno.ponte(h):
			out.append(h)
	return out

func vede_unita(osservatore: Dictionary, bersaglio: Dictionary) -> bool:
	if not in_mappa(osservatore) or bersaglio.hex == "":
		return false
	return terreno.vede(osservatore.hex, bersaglio.hex, osservatore.postura, bersaglio.postura)

func qualcuno_vede_hex(h: String) -> bool:
	for a in americani_attivi_in_mappa():
		if terreno.vede(a.hex, h, a.postura, "standing"):
			return true
	return false

func in_vista_americani(g: Dictionary) -> bool:
	for a in americani_attivi_in_mappa():
		if vede_unita(a, g):
			return true
	return false

# =================================================================== equipaggiamento
func arma_di(un: Dictionary, tipo: String) -> Dictionary:
	for a in un.armi:
		if a.tipo == tipo:
			return a
	return {}

func porte_usate(un: Dictionary) -> int:
	var n := 0
	for a in un.armi:
		n += int(T.ARMI.get(a.tipo, {}).get("porte", 1))
	return n

func porte_massime(un: Dictionary) -> int:
	return 1 if un.ferito else 2

func scatole_munizioni(un: Dictionary) -> int:
	var n := 0
	for k in un.munizioni:
		n += int(un.munizioni[k])
	for a in un.armi:
		if a.tipo == "pistol":
			n += 1
	return n

func munizioni_arma(un: Dictionary, tipo: String) -> int:
	return int(un.munizioni.get(tipo, 0))

## Armi da fuoco utilizzabili (non inceppate, non rotte, con munizioni).
func armi_da_fuoco(un: Dictionary) -> Array:
	var out: Array = []
	for a in un.armi:
		if a.tipo == "satchel" or a.rotta or a.inceppata:
			continue
		if un.lato == "us":
			if a.tipo == "bazooka":
				if not a.preparata:
					continue
			elif munizioni_arma(un, a.tipo) <= 0:
				continue
		else:
			if a.get("scarica", false):
				continue
		out.append(a)
	return out

func _lascia_oggetto(h: String, ogg: Dictionary) -> void:
	if not s.oggetti.has(h):
		s.oggetti[h] = []
	s.oggetti[h].append(ogg)

# =================================================================== paragrafi
func riferimento(h: String, cond := -1) -> String:
	var c: Dictionary = missione.condizioni[str(s.condizione if cond < 0 else cond)]
	return str(c.esagoni.get(h, "NONE"))

func riferimento_evento(n: int) -> String:
	var c: Dictionary = missione.condizioni[str(s.condizione)]
	return str(c.evento.get(str(n), "NONE"))

func movimento_rosso(h: String) -> String:
	var c: Dictionary = missione.condizioni[str(s.condizione)]
	return str(c.movimenti.get(h, ""))

## Risolve un riferimento delle carte (con eventuale prefisso di avvistamento).
func _risolvi_riferimento(rif: String, ctx: Dictionary) -> void:
	if rif == "NONE" or rif == "":
		return
	if rif.begins_with("s") and ":" in rif:
		var parti := rif.split(":")
		var n := int(parti[0].substr(1))
		if s.avvistamenti[n]:
			_log("info", "Riferimento %s ignorato: l’avvistamento s%d è già avvenuto." % [parti[1], n])
			return
		leggi(parti[1], ctx)
	else:
		leggi(rif, ctx)

func leggi(pid: String, ctx: Dictionary) -> void:
	if not paragrafi.has(pid):
		_log("errore", "Paragrafo %s non disponibile." % pid)
		return
	_profondita += 1
	if _profondita > 40:
		_profondita -= 1
		return
	var p: Dictionary = paragrafi[pid]
	_log("par", p.it, {"id": pid})
	_esegui(p.ops, ctx)
	_profondita -= 1

func _esegui(ops: Array, ctx: Dictionary) -> void:
	for o in ops:
		if s.fase == "fine":
			return
		_op(o, ctx)

func _op(o: Dictionary, ctx: Dictionary) -> void:
	match str(o.op):
		"goto":
			leggi(str(o.p), ctx)
		"sighting":
			var n := int(o.s)
			if not s.avvistamenti[n]:
				s.avvistamenti[n] = true
				_log("info", "Avvistamento s%d segnato sulla scheda." % n)
		"event_marker":
			if ctx.get("hex", "") != "":
				s.eventi[ctx.hex] = true
		"check":
			_op_controllo(o, ctx)
		"die":
			var r := d10("Dado")
			for b in o.b:
				if r >= int(b[0]) and r <= int(b[1]):
					_esegui(b[2], ctx)
					break
		"if":
			if _test(o.t, ctx):
				_esegui(o.then, ctx)
			else:
				_esegui(o.get("else", []), ctx)
		"activate":
			_op_attiva(o, ctx)
		"condition":
			cambia_condizione(int(o.n))
		"sniper":
			_op_cecchino(ctx)
		"place_k":
			_op_soldato_k()
		"place_smg":
			var h: String = ctx.get("hex", "I11")
			_lascia_oggetto(h, {"tipo": "smg", "inceppata": false, "rotta": false, "preparata": false, "catturata": false})
			_log("info", "Un mitra senza munizioni è a terra in %s: si può raccogliere." % h)
		"minefield":
			_op_campo_minato(ctx)
		"artillery":
			_op_artiglieria()
		"grenade_accident":
			_op_granata_difettosa()
		"ammo_out":
			_op_munizioni_finite()
		"typhoon_crash":
			s.punti["R15"] = "typhoon"
			for x in unita_in("R15"):
				_uccidi(x, "schiacciato dal Typhoon")
		"typhoon_burn":
			s.punti.erase("R15")
			for x in unita_in("R15"):
				_uccidi(x, "nel rogo del Typhoon")
			if s.pilota == "intrappolato":
				s.pilota = "morto"
				_log("info", "Il pilota britannico muore tra le fiamme.")
		"pilot_found":
			if s.pilota == "":
				s.pilota = "intrappolato"
				_log("info", "Per liberare il pilota usa l’azione «Libera il pilota» con un soldato non ferito in R15.")
		"pilot_joins":
			_op_pilota()
		"no_reentry":
			s.no_rientro = true
		"birds":
			pass
		"mine_hint":
			s.nota_mine = true
		"nothing":
			pass
		"best_pc":
			_op_miglior_pc(o, ctx)
		"group_pc":
			_op_pc_gruppo(o, ctx)
		"g_enter":
			ia.entra_da_paragrafo(ctx, str(o.hex))
		"g_reaction":
			ia.imposta_reazione(ctx, str(o.r))
		_:
			_log("errore", "Istruzione sconosciuta: %s" % o.op)

func _test(t: Dictionary, ctx: Dictionary) -> bool:
	if t.has("s"):
		return bool(s.avvistamenti[int(t.s)])
	if t.has("not"):
		return not _test(t.not, ctx)
	if t.has("all"):
		for x in t.all:
			if not _test(x, ctx):
				return false
		return true
	if t.has("see_hex"):
		return qualcuno_vede_hex(str(t.see_hex))
	if t.has("evaded"):
		return int(s.evasi.get(str(int(t.evaded)), 0)) >= 1
	if t.has("in_clear"):
		return terreno.tipo(ctx.get("hex", "")) == "clear"
	if t.has("on_bridge"):
		return bool(ctx.get("sul_ponte", false))
	if t.has("us_visible_east_of"):
		var g: Dictionary = u(ctx.get("g", ""))
		var limite := str(t.us_visible_east_of).unicode_at(0) - 65
		for a in americani_attivi_in_mappa():
			if E.colonna(a.hex) > limite and (g.is_empty() or vede_unita(g, a)):
				return true
		return false
	if t.has("us_visible_from"):
		for a in americani_attivi_in_mappa():
			if terreno.vede(str(t.us_visible_from), a.hex, "standing", a.postura):
				return true
		return false
	return false

## Soldato che effettua i controlli di percezione per un esagono: il PC più alto tra gli attivi.
func _soldato_pc(ctx: Dictionary) -> Dictionary:
	var candidati: Array = []
	var h: String = ctx.get("hex", "")
	if h != "":
		candidati = unita_in(h, "us")
	if candidati.is_empty():
		candidati = americani_attivi_in_mappa()
	var migliore := {}
	for c in candidati:
		if migliore.is_empty() or int(c.PC) > int(migliore.PC):
			migliore = c
	return migliore

func controllo_pc(un: Dictionary, mod: int, motivo := "") -> bool:
	var soglia := int(un.PC) + mod
	var r := d10()
	var ok := r == 0 or (r != 9 and r <= soglia)
	_log("dado", "Controllo di percezione di %s (PC %d%s): %d → %s" % [nome(un), int(un.PC), ("" if mod == 0 else " %+d" % mod), r, "riuscito" if ok else "fallito"] + ("" if motivo == "" else " · " + motivo))
	return ok

func _op_controllo(o: Dictionary, ctx: Dictionary) -> void:
	var mod := int(o.mod)
	var ok := false
	if o.kind == "pc":
		var sold := _soldato_pc(ctx)
		if sold.is_empty():
			return
		ok = controllo_pc(sold, mod)
		if ok:
			ctx.ultimo_pc = sold.id
	else:
		var livello := livello_attivazione() + mod
		var r := d10()
		ok = r == 0 or (r != 9 and r <= livello)
		_log("dado", "Controllo di attivazione (livello %d%s): %d → %s" % [livello_attivazione(), ("" if mod == 0 else " %+d" % mod), r, "riuscito" if ok else "fallito"])
	_esegui(o.ok if ok else o.ko, ctx)

func _op_miglior_pc(o: Dictionary, ctx: Dictionary) -> void:
	var migliore := {}
	for a in americani_attivi_in_mappa():
		if terreno.vede(a.hex, str(o.hex), a.postura, "standing"):
			if migliore.is_empty() or int(a.PC) > int(migliore.PC):
				migliore = a
	if migliore.is_empty():
		_log("info", "Nessun soldato vede %s: nessun controllo." % o.hex)
		return
	if controllo_pc(migliore, int(o.mod)):
		ctx.ultimo_pc = migliore.id
		_esegui(o.ok, ctx)

func _op_pc_gruppo(o: Dictionary, ctx: Dictionary) -> void:
	var h := str(o.hex)
	var riusciti: Array = []
	var fatti := 0
	for a in americani_attivi_in_mappa():
		if terreno.vede(a.hex, h, a.postura, "standing"):
			fatti += 1
			if controllo_pc(a, int(o.mod)):
				riusciti.append(a.id)
	if fatti == 0:
		_log("info", "Nessun soldato vede %s: nessun evento." % h)
		return
	ctx.indicato = h
	if not riusciti.is_empty():
		ctx.ultimo_pc = riusciti[0]
		_esegui(o.any, ctx)
	else:
		_esegui(o.all_fail, ctx)

# =================================================================== controlli di paragrafo
## Controllo di paragrafo per un esagono appena raggiunto (regola 5/1).
func controllo_paragrafo(h: String, ids: Array, opzioni := {}) -> void:
	var ctx := {"hex": h, "ids": ids, "sul_ponte": opzioni.get("sul_ponte", false)}
	if s.eventi.has(h) and not opzioni.get("ignora_evento", false):
		_log("info", "%s ha già un segnalino Evento: nessun controllo." % h)
		return
	var rif := riferimento(h)
	if rif == "EVENT":
		if s.fase == "operazioni" and not opzioni.get("cambio", false):
			_log("info", "%s: controllo Evento." % h)
			evento_casuale(ctx)
		else:
			_log("info", "%s: Evento ignorato, si colloca il segnalino." % h)
		s.eventi[h] = true
		return
	if rif == "NONE":
		_log("info", "%s: nessun paragrafo." % h)
	else:
		_risolvi_riferimento(rif, ctx)

func evento_casuale(ctx: Dictionary) -> void:
	var a := d10()
	var b := d10()
	var somma := a + b
	var rif := riferimento_evento(somma)
	_log("dado", "Controllo Evento: %d + %d = %d → %s" % [a, b, somma, "nessun evento" if rif == "NONE" else rif.replace(":", " ")])
	_risolvi_riferimento(rif, ctx)

func cambia_condizione(n: int) -> void:
	if n <= int(s.condizione):
		return
	s.condizione = n
	s.eventi.clear()
	_log("condizione", "Passa alla Condizione %d. Livello di attivazione 0–%d. Tutti i segnalini Evento sono rimossi." % [n, livello_attivazione()])
	# Controlli di paragrafo negli esagoni occupati, in ordine di numero (5/5 e 6/11).
	var esagoni_occ: Array = []
	for a in americani_attivi_in_mappa():
		if not (a.hex in esagoni_occ):
			esagoni_occ.append(a.hex)
	esagoni_occ.sort_custom(func(x, y): return E.numero(x) < E.numero(y))
	var era_operazioni: bool = s.fase == "operazioni"
	for h in esagoni_occ:
		if s.fase == "fine":
			return
		if era_operazioni and s.fase == "round":
			break
		var ids: Array = unita_in(h, "us").map(func(x): return x.id)
		if ids.is_empty():
			continue
		controllo_paragrafo(h, ids, {"cambio": true})

# =================================================================== attivazione
func _op_attiva(o_orig: Dictionary, ctx: Dictionary) -> void:
	var o := o_orig.duplicate()
	o.two = o_orig.get("two", []).map(func(x): return int(x))
	var nuovi: Array = []
	for coppia in o.g:
		var num := int(coppia[0])
		var h := str(coppia[1])
		if h == "@indicato":
			h = ctx.get("indicato", "")
		if h == "":
			continue
		var gid := "g%d" % num
		var esistente := u(gid)
		if not esistente.is_empty():
			if esistente.stato == "rimosso":
				if s.no_rientro:
					_log("info", "Il tedesco %d non può rientrare in gioco (paragrafo 027)." % num)
					continue
			else:
				continue
		var g := _crea_tedesco(num, h, str(o.stance))
		if o.get("reaction") != null and str(o.reaction) != "":
			g.reazione = str(o.reaction)
		nuovi.append(g)
		if not (str(num) in s.attivati):
			s.attivati.append(str(num))
			var dati: Dictionary = missione.tedeschi[str(num)]
			_pv(int(dati.pv), "attivazione del tedesco %d" % num)
		_log("attivazione", "Attivato il %s in %s, %s." % [nome(g), h, T.NOMI_POSTURA[g.postura]])
		# Americani attivi nello stesso esagono? Nessun effetto immediato; il Round lo deciderà.
	if nuovi.is_empty():
		return
	var aware_id: String = ctx.get("ultimo_pc", "") if o.get("aware", false) else ""
	if s.fase == "operazioni":
		_inizia_round_da_attivazione(nuovi, o, aware_id)
	elif int(s.round.get("n", 0)) == 0:
		# Round in preparazione: si aggiungono ai tedeschi della prima pista.
		s.round.attivati_ora.append_array(nuovi.map(func(x): return x.id))
		for g in nuovi:
			if int(g.num) in o.two:
				s.round.due_turni_de.append(g.id)
	elif not s.round.get("iniziativa_fatta", false):
		# Attivazione nella fase Evento: la pista sarà impostata dall’iniziativa di questo Round.
		for g in nuovi:
			if int(g.num) in o.two:
				s.round.due_turni_de.append(g.id)
	else:
		for g in nuovi:
			_attivazione_durante_round(g, int(g.num) in o.two)

func _crea_tedesco(num: int, h: String, postura: String) -> Dictionary:
	var gid := "g%d" % num
	var d: Dictionary = missione.tedeschi[str(num)]
	var armi: Array = []
	for a in d.armi:
		armi.append({"tipo": a, "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "scarica": false})
	var vecchio := u(gid)
	var g := {
		"id": gid, "lato": "de", "num": num, "lettera": d.lettera, "nome": d.ruolo, "IN": d.IN, "PC": d.PC,
		"WS": d.WS, "MPA": d.MPA, "comandante": d.get("comandante", false), "hex": h, "postura": postura,
		"stato": "attivo", "ferito": false, "panico": false, "turni": 0, "slot": "completo",
		"armi": armi, "munizioni": {"granata": int(d.granate)}, "reazione": "", "no_auto": false,
		"hex_attivazione": h, "solo_S": false, "guardia": "", "rimuovi_fine_round": false,
		"bersagli_round": [], "cambio_libero": true,
	}
	if not vecchio.is_empty():
		g.armi = vecchio.armi
		g.munizioni = vecchio.munizioni
		g.ferito = vecchio.ferito
	s.unita[gid] = g
	return g

func _inizia_round_da_attivazione(nuovi: Array, o: Dictionary, aware_id: String) -> void:
	s.fase = "round"
	for a in americani():
		a.consapevole = false
		a.turni = 0
	s.round = {
		"n": 0, "vantaggio": "", "vantaggio_forzato": str(o.adv) if o.adv != null else "",
		"due_turni_de": nuovi.filter(func(g): return int(g.num) in o.two).map(func(g): return g.id),
		"due_turni_us": bool(o.us_two), "consapevole_auto": aware_id,
		"attivati_ora": nuovi.map(func(g): return g.id), "numero_azione": -1, "slot_azione": "",
		"sparato": [], "sparato_prec": [], "iniziativa": [],
	}
	_log("round", "Iniziano i Round.")
	s.pausa = "inizio_round"

## Regola 6/6: tedesco attivato a Round in corso.
func _attivazione_durante_round(g: Dictionary, due: bool) -> void:
	if due:
		g.turni = 1 if g.ferito else 2
		g.slot = "turni"
		_log("info", "Il %s riceve 2 turni in questo Round." % nome(g))
	else:
		var r := d10()
		s.round.numero_azione = r
		var es := T.esito_turni(int(g.IN), r, false, true, g.ferito)
		_log("dado", "Nuovo numero d’azione tedesco per il %s: %d → %s" % [nome(g), r, _descrivi_esito(es)])
		if es.panico:
			g.panico = true
			g.turni = 0
			g.slot = "panico"
		else:
			g.turni = es.turni
			g.slot = "turni" if es.turni > 0 else "completo"

func _descrivi_esito(es: Dictionary) -> String:
	if es.panico:
		return "panico"
	return "%d turn%s" % [es.turni, "o" if es.turni == 1 else "i"]

# =================================================================== Round
## Comando dell’interfaccia: prosegue dopo una pausa.
func prosegui() -> void:
	recenti.clear()
	var p: String = s.pausa
	s.pausa = ""
	match p:
		"inizio_round":
			_avvia_round()
		"azioni_tedesche", "":
			_flusso()
		"fine_round":
			_fine_round()
	terreno.imposta_modifiche(s.modifiche)
	_controlla_fine_automatica()
	aggiornata.emit()

func _avvia_round() -> void:
	var r: Dictionary = s.round
	r.n = int(r.n) + 1
	r.sparato_prec = r.get("sparato", [])
	r.sparato = []
	r.slot_azione = ""
	r.iniziativa_fatta = false
	for g in tedeschi():
		g.bersagli_round = []
	_log("round", "ROUND %d" % r.n)
	# 1. Consapevolezza (solo Round 1 e 2).
	if r.n <= 2:
		_fase_consapevolezza(r)
	else:
		for a in americani():
			if attivo(a) or a.stato == "fuori":
				a.consapevole = true
	# 2. Evento (non nel Round 1).
	if r.n >= 2:
		_log("info", "Fase Evento.")
		evento_casuale({"hex": "", "ids": []})
		if s.fase != "round":
			return
	# 3. Iniziativa.
	_iniziativa(r)
	_flusso()

func _fase_consapevolezza(r: Dictionary) -> void:
	var auto_id: String = r.get("consapevole_auto", "")
	for a in americani():
		if not (attivo(a) or a.stato == "fuori") or a.consapevole:
			continue
		if a.stato == "fuori" and r.n == 1:
			continue  # 6/10: fuori mappa durante il Round 1
		if a.id == auto_id and r.n == 1:
			a.consapevole = true
			_log("info", "%s è automaticamente consapevole." % nome(a))
			continue
		if a.stato == "attivo" and a.hex == "" :
			continue
		if r.n == 1:
			var vede := false
			for gid in r.attivati_ora:
				var g := u(gid)
				if not g.is_empty() and in_mappa(g) and vede_unita(a, g):
					vede = true
			if not vede:
				continue
		a.consapevole = controllo_pc(a, 0, "consapevolezza")

func in_comando(un: Dictionary) -> bool:
	var tot := 0
	for o in americani():
		if not (attivo(o) or o.stato == "fuori"):
			continue
		var stesso: bool = o.hex == un.hex
		var vicino: bool = un.hex != "" and o.hex != "" and E.distanza(un.hex, o.hex) <= 2
		var raggio_proprio: bool = un.comandante and not un.panico
		var raggio_altro: bool = o.comandante and not o.panico
		if stesso or (vicino and (raggio_proprio or raggio_altro)):
			tot += int(o.IN)
	return tot >= 5

func _iniziativa(r: Dictionary) -> void:
	var du := d10()
	var dt := d10()
	var vant: String = "us" if du > dt else "de"
	if r.n == 1 and r.get("vantaggio_forzato", "") != "":
		vant = r.vantaggio_forzato
	r.vantaggio = vant
	r.dado_us = du
	r.dado_de = dt
	_log("dado", "Iniziativa: americani %d, tedeschi %d → vantaggio %s." % [du, dt, "americano" if vant == "us" else "tedesco"])
	for a in americani():
		a.panico = false
		if not (attivo(a) or a.stato == "fuori"):
			a.turni = 0
			a.slot = "inattivo"
			continue
		if not a.consapevole:
			a.turni = 0
			a.slot = "inconsapevole"
			continue
		var es := T.esito_turni(int(a.IN), du, true, in_comando(a), a.ferito)
		if r.n == 1 and r.get("due_turni_us", false) and not es.panico:
			es.turni = 1 if a.ferito else 2
		if es.panico:
			a.panico = true
			a.turni = 0
			a.slot = "panico"
		else:
			a.turni = es.turni
			a.slot = "turni"
	for g in tedeschi():
		g.panico = false
		if not in_mappa(g):
			g.turni = 0
			g.slot = "inattivo"
			continue
		var es := T.esito_turni(int(g.IN), dt, false, true, g.ferito)
		if g.id in r.get("due_turni_de", []):
			es = {"turni": 1 if g.ferito else 2, "panico": false}
		if es.panico:
			g.panico = true
			g.turni = 0
			g.slot = "panico"
		else:
			g.turni = es.turni
			g.slot = "turni"
	r.due_turni_de = []
	r.iniziativa_fatta = true
	var righe: Array = []
	for x in americani() + tedeschi():
		if x.slot in ["turni", "panico"] and (attivo(x) or x.stato == "fuori"):
			righe.append("%s %s" % [x.lettera, "panico" if x.panico else str(x.turni)])
	_log("info", "Turni: " + ", ".join(righe))

## Lato a cui appartiene una casella della pista.
func _ordine_caselle() -> Array:
	var v: String = s.round.vantaggio
	var o := "de" if v == "us" else "us"
	return [[2, v], [2, o], [1, v], [1, o]]

func casella_attuale() -> Array:
	for c in _ordine_caselle():
		for x in s.unita.values():
			if x.lato == c[1] and int(x.turni) == c[0] and x.slot == "turni" and (attivo(x) or x.stato == "fuori"):
				return c
	return []

## Americani che possono agire adesso.
func americani_di_turno() -> Array:
	if s.fase != "round" or s.pausa != "":
		return []
	var c := casella_attuale()
	if c.is_empty() or c[1] != "us":
		return []
	var out: Array = []
	for a in americani():
		if int(a.turni) == c[0] and a.slot == "turni" and (attivo(a) or a.stato == "fuori"):
			out.append(a)
	return out

func _flusso() -> void:
	var giri := 0
	while s.fase == "round" and s.pausa == "" and giri < 50:
		giri += 1
		var c := casella_attuale()
		if c.is_empty():
			_fine_round()
			return
		if c[1] == "us":
			return  # attende il giocatore
		# Turno tedesco: nuovo numero d’azione all’inizio della casella.
		var chiave := "%d%s" % [c[0], c[1]]
		if s.round.slot_azione != chiave:
			s.round.slot_azione = chiave
			s.round.numero_azione = d10()
			_log("dado", "Numero d’azione tedesco: %d" % s.round.numero_azione)
		var agiti := false
		for g in tedeschi():
			if s.fase != "round":
				return
			if int(g.turni) == c[0] and g.slot == "turni" and in_mappa(g):
				ia.turno(g)
				agiti = true
				if int(g.turni) == c[0]:
					_consuma_turno(g)
		if agiti:
			s.pausa = "azioni_tedesche"
			return

func _consuma_turno(x: Dictionary) -> void:
	x.turni = maxi(0, int(x.turni) - 1)
	if x.turni == 0 and x.slot == "turni":
		x.slot = "completo"

func _fine_round() -> void:
	_log("round", "Fine del Round %d." % int(s.round.n))
	for x in s.unita.values():
		if x.panico and attivo(x):
			x.panico = false
			if x.hex != "" and x.postura != "prone":
				if terreno.tipo(x.hex) == "stream" and not (terreno.ponte(x.hex) and x.get("sul_ponte", false)):
					pass  # nel ruscello chi è in panico non si sdraia
				else:
					x.postura = "prone"
					_log("info", "%s, in preda al panico, si getta a terra." % nome(x))
		if x.lato == "us":
			x.turni = 0
	for g in tedeschi():
		if in_mappa(g) and g.rimuovi_fine_round:
			g.rimuovi_fine_round = false
			if not in_vista_americani(g):
				ia.rimuovi_evasivo(g)
	if tedeschi_attivi().is_empty():
		_torna_operazioni()
		return
	s.pausa = "inizio_round"

func _torna_operazioni() -> void:
	s.fase = "operazioni"
	s.round = {}
	s.turno = {}
	for a in americani():
		a.consapevole = false
		a.turni = 0
		a.slot = ""
		a.panico = false
	_log("round", "Nessun tedesco attivo sulla mappa: riprendono le Operazioni.")
	_controlla_fine_automatica()

# =================================================================== azioni americane
func _errore(m: String) -> Dictionary:
	return {"ok": false, "errore": m}

const OK := {"ok": true}

func _inizio_comando() -> void:
	recenti.clear()

func _fine_comando() -> void:
	terreno.imposta_modifiche(s.modifiche)
	_controlla_fine_automatica()
	aggiornata.emit()

func puo_agire(a: Dictionary) -> String:
	if s.fase == "fine":
		return "La missione è terminata."
	if s.pausa != "":
		return "Premi «Continua»."
	if not (attivo(a) or a.stato == "fuori"):
		return "%s non può agire." % nome(a)
	if s.fase == "round":
		if not (a in americani_di_turno()):
			return "Non è il turno di %s." % nome(a)
		var t: Dictionary = s.turno
		if not t.is_empty() and t.id != a.id:
			return "%s sta ancora agendo." % nome(u(t.id))
	return ""

## Turno in corso dell’americano (Round).
func _turno_di(a: Dictionary) -> Dictionary:
	if s.turno.is_empty() or s.turno.id != a.id:
		s.turno = {"id": a.id, "azione": "", "mp": int(effettivo_mpa(a)), "mp_max": int(effettivo_mpa(a)),
			"cambio_libero": not a.ferito, "spari": 0, "mosso": false, "liberazione": 0}
	return s.turno

func effettivo_mpa(un: Dictionary) -> int:
	var m := int(un.MPA)
	if un.ferito:
		m = mini(m, 2)
	if un.lato == "us" and not un.get("prigionieri", []).is_empty():
		m = mini(m, 2)
	return m

func _termina_azione(a: Dictionary) -> void:
	s.turno = {}
	_consuma_turno(a)
	_flusso()

## Cambio di postura (gratuito nelle Operazioni; nei Round uno gratuito per turno, poi 1 PM).
func cambia_postura(id: String, postura: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a)
	if e != "":
		return _errore(e)
	if a.hex == "":
		return _errore("Il soldato non è ancora sulla mappa.")
	if a.postura == postura:
		return _errore("È già %s." % T.NOMI_POSTURA[postura])
	if postura == "prone" and terreno.tipo(a.hex) == "stream" and not a.sul_ponte:
		return _errore("Nel ruscello non ci si può sdraiare.")
	if postura == "crouching" and terreno.tipo(a.hex) == "stream" and not a.sul_ponte:
		return _errore("Nel ruscello si sta soltanto in piedi.")
	if s.fase == "round":
		var t := _turno_di(a)
		if t.cambio_libero:
			t.cambio_libero = false
		elif t.azione in ["muovi", "muovi_spara", "carica"] and int(t.mp) >= 1:
			t.mp = int(t.mp) - 1
		elif t.azione == "":
			# Un soldato ferito cambia postura spendendo 1 PM: è un’azione di movimento.
			t.azione = "muovi"
			t.mp = int(t.mp) - 1
			if int(t.mp) < 0:
				return _errore("Punti movimento insufficienti.")
		else:
			return _errore("Nessun cambio di postura disponibile in questo turno.")
	a.postura = postura
	_log("azione", "%s ora è %s." % [nome(a), T.NOMI_POSTURA[postura]])
	_fine_comando()
	return OK

## Esagoni in cui un soldato (o un gruppo) può entrare adesso.
func destinazioni(id: String) -> Array:
	var a := u(id)
	var out: Array = []
	if a.is_empty():
		return out
	if a.hex == "":
		if a.stato != "fuori":
			return out
		for c in 10:
			out.append(E.da(c, 1))
		return out
	for v in E.vicini(a.hex):
		if _verifica_passo(a, v, true) == "":
			out.append(v)
	return out

func _costo_passo(a: Dictionary, da_hex: String, verso: String) -> int:
	if da_hex == "":
		return terreno.costo_movimento(verso, verso) if false else _costo_ingresso(verso)
	return terreno.costo_movimento(da_hex, verso)

func _costo_ingresso(h: String) -> int:
	match terreno.tipo(h):
		"rough", "brush", "woods", "rubble", "stream":
			return 2
	return 1

func _verifica_passo(a: Dictionary, verso: String, silenzioso := false) -> String:
	if a.postura == "prone":
		return "Un soldato prono non può muoversi."
	var da_hex: String = a.hex
	if da_hex != "" and not E.adiacenti(da_hex, verso):
		return "Si può entrare solo in un esagono adiacente."
	if da_hex == "" and not (E.riga(verso) == 1 and E.colonna(verso) <= 9):
		return "Si entra dal margine nord, tra A1 e J1."
	var costo := _costo_passo(a, da_hex, verso)
	if costo < 0:
		return "Non si può attraversare un muro senza aperture."
	if a.postura == "crouching":
		if da_hex != "" and not terreno.strisciare_possibile(da_hex, verso):
			return "Strisciando non si entra nel ruscello."
		if da_hex == "" and terreno.tipo(verso) == "stream":
			return "Strisciando non si entra nel ruscello."
	if s.fase == "round":
		var t: Dictionary = s.turno if (not s.turno.is_empty() and s.turno.id == a.id) else {}
		if t.is_empty() or not (t.azione in ["muovi", "muovi_spara", "carica"]):
			return "" if silenzioso else "Scegli prima un’azione di movimento."
		if a.postura == "crouching":
			if t.mosso:
				return "Strisciando ci si muove di un solo esagono."
		elif costo > int(t.mp):
			return "Punti movimento insufficienti (servono %d, restano %d)." % [costo, int(t.mp)]
		if t.get("fermo", false):
			return "Il soldato è entrato in un esagono con un nemico: deve fermarsi."
	return ""

## Movimento di un soldato o di un gruppo (stessi esagono e postura) in un esagono adiacente.
func muovi(ids: Array, verso: String) -> Dictionary:
	_inizio_comando()
	if ids.is_empty():
		return _errore("Nessun soldato selezionato.")
	var primo := u(str(ids[0]))
	for id in ids:
		var a := u(str(id))
		var e := puo_agire(a)
		if e != "":
			return _errore(e)
		if a.hex != primo.hex or a.postura != primo.postura:
			return _errore("Il gruppo deve essere nello stesso esagono e nella stessa postura.")
		if a.stato != "attivo" and a.stato != "fuori":
			return _errore("%s non può muoversi." % nome(a))
	if s.fase == "round" and ids.size() > 1:
		return _errore("Nei Round ogni soldato si muove con la propria azione.")
	var e2 := _verifica_passo(primo, verso)
	if e2 != "":
		return _errore(e2)
	var da_hex: String = primo.hex
	var costo := _costo_passo(primo, da_hex, verso)
	if s.fase == "round":
		var t := _turno_di(primo)
		if primo.postura == "crouching":
			t.mp = 0
		else:
			t.mp = int(t.mp) - costo
		t.mosso = true
	var sul_ponte := terreno.ponte(verso) and da_hex in terreno.capi_ponte(verso)
	var nomi: Array = []
	for id in ids:
		var a := u(str(id))
		if a.stato == "fuori":
			a.stato = "attivo"
		a.hex = verso
		a.sul_ponte = sul_ponte
		nomi.append(a.lettera)
		for pid in a.prigionieri:
			var p := u(pid)
			if not p.is_empty() and p.stato == "catturato":
				p.hex = verso
	_log("azione", "%s %s in %s (%s)." % [", ".join(nomi), "entra" if nomi.size() == 1 else "entrano", verso, terreno.nome_tipo(verso)])
	# Cattura dei tedeschi arresi.
	for g in unita_in(verso, "de", false):
		if g.stato == "arreso":
			g.stato = "catturato"
			g.guardia = str(ids[0])
			u(str(ids[0])).prigionieri.append(g.id)
			_log("info", "Il %s, arreso, viene fatto prigioniero." % nome(g))
			_premio_cattura(g)
	# Fermarsi in un esagono con un nemico attivo.
	if s.fase == "round" and not unita_in(verso, "de").is_empty():
		s.turno.fermo = true
	_ingresso(verso, ids, sul_ponte)
	if s.fase == "round" and not s.turno.is_empty() and s.turno.id == str(ids[0]):
		var t: Dictionary = s.turno
		var a := u(str(ids[0]))
		if not attivo(a) or (t.azione == "muovi" and (a.postura == "crouching" or int(t.mp) <= 0) and not t.cambio_libero):
			_termina_azione(a)
	elif fase_round() and s.turno.is_empty() and s.pausa == "":
		_flusso()
	_fine_comando()
	return OK

## Effetti dell’ingresso in un esagono: campi minati, relitto, controllo di paragrafo.
func _ingresso(h: String, ids: Array, sul_ponte: bool) -> void:
	if s.mine.has(h):
		_log("info", "%s è un campo minato." % h)
		for id in ids:
			var a := u(str(id))
			if not attivo(a):
				continue
			if not controllo_pc(a, 0, "campo minato"):
				_log("combattimento", "Una mina esplode sotto %s!" % nome(a))
				_danno_esplosione(a, T.GRANATA_DENTRO)
	if s.fase == "fine":
		return
	var vivi: Array = ids.filter(func(i): return attivo(u(str(i))))
	if vivi.is_empty():
		return
	controllo_paragrafo(h, vivi, {"sul_ponte": sul_ponte})
	if h == "R15" and s.punti.get("R15", "") == "typhoon" and s.pilota == "":
		leggi("349", {"hex": h, "ids": vivi})

## Fine di un’azione di movimento nei Round (o di qualsiasi azione a più passi).
func fine_azione(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	if s.fase != "round" or s.turno.is_empty() or s.turno.id != id:
		return _errore("Nessuna azione in corso.")
	if s.turno.azione == "carica":
		return _errore("La carica termina con l’assalto.")
	_termina_azione(a)
	_fine_comando()
	return OK

## Sceglie il tipo di azione (Round): muovi, muovi_spara, rapido, carica.
func scegli_azione(id: String, azione: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a)
	if e != "":
		return _errore(e)
	if s.fase != "round":
		return _errore("Nelle Operazioni le azioni sono libere.")
	var t := _turno_di(a)
	if t.azione != "":
		return _errore("Azione già scelta.")
	match azione:
		"muovi":
			if a.postura == "prone":
				return _errore("Prima alzati: un soldato prono non si muove.")
			t.azione = "muovi"
		"muovi_spara":
			if armi_da_fuoco(a).filter(func(x): return x.tipo != "bazooka").is_empty():
				return _errore("Nessuna arma pronta al tiro.")
			t.azione = "muovi_spara"
			t.mp = mini(int(t.mp), int(effettivo_mpa(a)) / 2)
		"carica":
			t.azione = "carica"
			t.mp = mini(int(t.mp), int(effettivo_mpa(a)) / 2)
		_:
			return _errore("Azione sconosciuta.")
	_log("azione", "%s: %s." % [nome(a), {"muovi": "movimento", "muovi_spara": "movimento e tiro rapido", "carica": "carica d’assalto"}[azione]])
	_fine_comando()
	return OK

func passa(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a)
	if e != "":
		return _errore(e)
	if s.fase != "round":
		return _errore("Nelle Operazioni non ci sono turni.")
	_log("azione", "%s passa il turno." % nome(a))
	_termina_azione(a)
	_fine_comando()
	return OK

# ------------------------------------------------------------------- combattimento
## Probabilità di colpire (regola 9). Restituisce {ok, prob, base, mods[], motivo}.
func probabilita_tiro(tiratore: Dictionary, arma: Dictionary, bersaglio: Dictionary, mirato: bool) -> Dictionary:
	if bersaglio.is_empty() or not in_mappa(bersaglio):
		return {"ok": false, "motivo": "bersaglio non valido"}
	if tiratore.postura == "prone":
		return {"ok": false, "motivo": "da prono non si spara"}
	var dist := E.distanza(tiratore.hex, bersaglio.hex)
	if dist > 0 and not vede_unita(tiratore, bersaglio):
		return {"ok": false, "motivo": terreno.vista(tiratore.hex, bersaglio.hex, tiratore.postura, bersaglio.postura).motivo}
	# Non si spara in un esagono con un amico attivo (salvo stesso esagono).
	if dist > 0:
		for x in unita_in(bersaglio.hex, tiratore.lato):
			if x.id != tiratore.id:
				return {"ok": false, "motivo": "nell’esagono c’è un compagno"}
	var tipo: String = arma.tipo
	var base := T.base_per_distanza(tipo, dist)
	if base < 0:
		return {"ok": false, "motivo": "fuori gittata"}
	if tipo == "bazooka" and not mirato:
		return {"ok": false, "motivo": "il bazooka non spara di rapido"}
	var mods: Array = []
	var ws := int(tiratore.WS) - (1 if arma.get("catturata", false) else 0)
	if ws != 0:
		mods.append(["abilità", ws])
	if not mirato:
		mods.append(["tiro rapido", -2])
	if tiratore.ferito:
		mods.append(["tiratore ferito", -1])
	if mirato and T.ARMI[tipo].get("auto", false):
		var extra := unita_in(bersaglio.hex, bersaglio.lato).size() - 1
		if extra > 0:
			mods.append(["bersagli multipli", extra])
	var ip := T.indice_postura(bersaglio.postura)
	var th := terreno.tipo(bersaglio.hex)
	if terreno.edificio(bersaglio.hex) and not (terreno.edificio(tiratore.hex) and dist <= 1 and terreno.tipo_lato(tiratore.hex, bersaglio.hex) == ""):
		var vicino := dist <= 1
		var m: int = (T.MOD_INTERNO_VICINO if vicino else T.MOD_INTERNO_LONTANO)[ip]
		if m == 99:
			return {"ok": false, "motivo": "un prono dentro l’edificio non è bersagliabile"}
		mods.append(["interno, " + T.NOMI_POSTURA[bersaglio.postura], m])
	else:
		if th == "stream" and terreno.ponte(bersaglio.hex):
			th = "bridge"
		var tab: Array = T.MOD_TERRENO.get(th, [0, 0, 0])
		if tab[ip] != 0:
			mods.append([terreno.nome_tipo(bersaglio.hex) + ", " + T.NOMI_POSTURA[bersaglio.postura], tab[ip]])
	var tot := base
	for m in mods:
		tot += int(m[1])
	return {"ok": true, "prob": clampi(tot, 0, 8), "base": base, "mods": mods, "dist": dist,
		"gittata": T.nome_gittata(tipo, dist)}

## Spiega la probabilità in forma leggibile.
func testo_probabilita(p: Dictionary) -> String:
	if not p.ok:
		return "impossibile: " + str(p.motivo)
	var parti: Array = ["base %d (%s)" % [p.base, p.gittata]]
	for m in p.mods:
		parti.append("%s %+d" % [m[0], m[1]])
	return "colpisce con 0–%d · %s" % [p.prob, ", ".join(parti)]

## Risolve un tiro. Usato da americani, tedeschi e cecchini.
func risolvi_tiro(tiratore: Dictionary, arma: Dictionary, bersaglio: Dictionary, mirato: bool, prob_forzata := -1) -> Dictionary:
	var tipo: String = arma.tipo
	var info: Dictionary = T.ARMI[tipo]
	var p: Dictionary
	if prob_forzata >= 0:
		p = {"ok": true, "prob": prob_forzata}
	else:
		p = probabilita_tiro(tiratore, arma, bersaglio, mirato)
		if not p.ok:
			return {"ok": false, "motivo": p.motivo}
	_rendi_consapevoli(bersaglio.hex)
	var modo := "mirato" if mirato else "rapido"
	_log("combattimento", "%s spara (%s, %s) a %s in %s." % [nome(tiratore), modo, info.nome.to_lower(), nome(bersaglio), bersaglio.hex])
	if fase_round() and tiratore.get("lato", "") == "de":
		s.round.sparato.append([tiratore.id, tipo])
		tiratore.bersagli_round.append(bersaglio.id)
	# 1. Inceppamento / colpo a vuoto.
	var limite_inc: int = info.inc[0 if mirato else 1]
	var pi := percentuale()
	if pi <= limite_inc:
		if tipo == "bazooka":
			_log("dado", "Percentuale %02d: razzo difettoso, nessun effetto." % pi)
			_consuma_bazooka(tiratore, arma)
		else:
			arma.inceppata = true
			_log("dado", "Percentuale %02d: l’arma si inceppa!" % pi)
		return {"ok": true, "colpito": false}
	# 2–5. Tiro per colpire.
	var r := d10()
	var colpito: bool = r == 0 or (r != 9 and r <= int(p.prob))
	_log("dado", "Per colpire: serve 0–%d, esce %d → %s." % [int(p.prob), r, "COLPITO" if colpito else "mancato"])
	if colpito:
		var rd := d10()
		var lettera := T.lettera_danno(info.danni, rd)
		_log("dado", "Danno: %d → %s" % [rd, _nome_danno(lettera)])
		_applica_danno(bersaglio, lettera, tiratore)
		if tipo == "bazooka":
			for altro in unita_in(bersaglio.hex, bersaglio.lato):
				if altro.id != bersaglio.id:
					_danno_esplosione(altro, T.GRANATA_DENTRO)
		elif mirato and info.get("auto", false) and rd > 0:
			_danni_multipli(bersaglio, info.danni, rd, tiratore)
	# 7. Munizioni.
	if tiratore.get("lato", "") == "us":
		if tipo == "bazooka":
			_consuma_bazooka(tiratore, arma)
		else:
			var pm := percentuale()
			if pm <= int(info.mun):
				tiratore.munizioni[tipo] = maxi(0, munizioni_arma(tiratore, tipo) - 1)
				_log("dado", "Percentuale %02d: consumato un caricatore (%s: ne restano %d)." % [pm, info.breve, munizioni_arma(tiratore, tipo)])
	return {"ok": true, "colpito": colpito}

func _consuma_bazooka(tiratore: Dictionary, arma: Dictionary) -> void:
	arma.preparata = false
	if tiratore.get("lato", "") == "us":
		tiratore.munizioni.bazooka = maxi(0, munizioni_arma(tiratore, "bazooka") - 1)

func _danni_multipli(primario: Dictionary, tabella: String, precedente: int, tiratore: Dictionary) -> void:
	var altri: Array = unita_in(primario.hex, primario.lato).filter(func(x): return x.id != primario.id)
	altri.sort_custom(func(a, b): return T.indice_postura(a.postura) < T.indice_postura(b.postura))
	var prec := precedente
	for x in altri:
		var r := d10()
		if r >= prec:
			_log("dado", "Raffica: %d non è inferiore a %d, si ferma." % [r, prec])
			return
		var l := T.lettera_danno(tabella, r)
		_log("dado", "Raffica: %d colpisce anche %s → %s" % [r, nome(x), _nome_danno(l)])
		_applica_danno(x, l, tiratore)
		prec = r
		if r == 0:
			return

func _nome_danno(l: String) -> String:
	return {"P": "panico", "W": "ferita", "I": "incapacitato", "K": "ucciso", "Q": "ferita (panico se prono)", "-": "nessun effetto", "C": "catturato"}.get(l, l)

func _rendi_consapevoli(h: String) -> void:
	if not fase_round():
		return
	for a in unita_in(h, "us"):
		if not a.consapevole:
			a.consapevole = true
			if a.slot == "inconsapevole":
				a.slot = "completo"
			_log("info", "%s, attaccato, diventa consapevole." % nome(a))

func _danno_esplosione(x: Dictionary, tabella: String) -> void:
	var r := d10()
	var l := T.lettera_danno(tabella, r)
	if l == "Q":
		l = "P" if x.postura == "prone" else "W"
	_log("dado", "Esplosione su %s: %d → %s" % [nome(x), r, _nome_danno(l)])
	_applica_danno(x, l, {})

func _applica_danno(x: Dictionary, l: String, fonte: Dictionary) -> void:
	if not attivo(x) and x.stato != "catturato":
		return
	match l:
		"P":
			if fase_round() and attivo(x):
				x.panico = true
				x.turni = 0
				x.slot = "panico"
				_log("danno", "%s è in preda al panico." % nome(x))
				if not s.turno.is_empty() and s.turno.id == x.id:
					s.turno = {}
			else:
				_log("danno", "%s si spaventa, ma senza conseguenze." % nome(x))
		"W":
			if x.ferito:
				_incapacita(x)
			else:
				_ferisci(x)
		"I":
			if x.stato == "incapacitato":
				_uccidi(x, "")
			else:
				_incapacita(x)
		"K":
			_uccidi(x, "")

func _cade_prono(x: Dictionary) -> void:
	if x.hex != "" and terreno.tipo(x.hex) == "stream" and not x.get("sul_ponte", false):
		_log("danno", "%s cade nel ruscello e annega." % nome(x))
		_uccidi(x, "")
		return
	x.postura = "prone"

func _ferisci(x: Dictionary) -> void:
	x.ferito = true
	_log("danno", "%s è FERITO." % nome(x))
	_cade_prono(x)
	if not attivo(x):
		return
	if fase_round():
		x.turni = 0
		if x.slot in ["turni", "panico"]:
			x.slot = "completo"
		if not s.turno.is_empty() and s.turno.id == x.id:
			s.turno = {}
	if x.lato == "us":
		# Una sola casella di porto: si lascia cadere il resto.
		while porte_usate(x) > 1:
			var lasciata: Dictionary = {}
			for a in x.armi:
				if int(T.ARMI.get(a.tipo, {}).get("porte", 1)) >= 2:
					lasciata = a
			if lasciata.is_empty():
				lasciata = x.armi[x.armi.size() - 1]
			x.armi.erase(lasciata)
			_lascia_oggetto(x.hex, lasciata)
			_log("info", "%s lascia cadere: %s." % [nome(x), T.ARMI[lasciata.tipo].nome])

func _incapacita(x: Dictionary) -> void:
	x.stato = "incapacitato"
	x.turni = 0
	x.slot = "inattivo"
	x.panico = false
	_log("danno", "%s è INCAPACITATO." % nome(x))
	_cade_prono(x)
	_dopo_perdita(x)

func _uccidi(x: Dictionary, come: String) -> void:
	if x.stato == "morto":
		return
	x.stato = "morto"
	x.turni = 0
	x.slot = "inattivo"
	x.panico = false
	x.postura = "prone"
	_log("danno", "%s è UCCISO%s." % [nome(x), "" if come == "" else " (" + come + ")"])
	_dopo_perdita(x)

func _dopo_perdita(x: Dictionary) -> void:
	if not s.turno.is_empty() and s.turno.id == x.id:
		s.turno = {}
	if x.lato == "de":
		if int(x.num) == 34:
			cambia_condizione(4)
	else:
		# Prigionieri liberati se la guardia cade (regola 11/2).
		for pid in x.prigionieri:
			var p := u(pid)
			if p.is_empty() or p.stato != "catturato":
				continue
			var altri: Array = unita_in(x.hex, "us")
			if not altri.is_empty():
				p.guardia = altri[0].id
				altri[0].prigionieri.append(pid)
		x.prigionieri = []

func _premio_cattura(g: Dictionary) -> void:
	if int(g.num) == 34:
		_pv(2, "cattura dell’ufficiale tedesco 34")
		cambia_condizione(4)

func tiro(id: String, tipo_arma: String, bersaglio_id: String, mirato: bool) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a)
	if e != "":
		return _errore(e)
	if s.fase != "round":
		return _errore("Nelle Operazioni non si combatte.")
	var arma := arma_di(a, tipo_arma)
	if arma.is_empty() or not (arma in armi_da_fuoco(a)):
		return _errore("Arma non disponibile.")
	var b := u(bersaglio_id)
	var t := _turno_di(a)
	if mirato:
		if t.azione != "":
			return _errore("Il tiro mirato è un’azione a sé.")
	else:
		if t.azione == "":
			t.azione = "rapido"
		elif t.azione == "muovi_spara":
			if int(t.spari) >= 1:
				return _errore("Con «muovi e spara» si fa un solo tiro rapido.")
		elif t.azione != "rapido":
			return _errore("Il tiro rapido richiede l’azione «due tiri rapidi» o «muovi e spara».")
	var p := probabilita_tiro(a, arma, b, mirato)
	if not p.ok:
		return _errore("Tiro impossibile: " + str(p.motivo))
	if mirato:
		t.azione = "mirato"
	t.spari = int(t.spari) + 1
	risolvi_tiro(a, arma, b, mirato)
	if attivo(a) and not s.turno.is_empty():
		if mirato or (t.azione == "rapido" and int(t.spari) >= 2):
			_termina_azione(a)
		elif t.azione == "muovi_spara" and int(t.mp) <= 0:
			_termina_azione(a)
	elif s.turno.is_empty() and fase_round():
		_flusso()
	_fine_comando()
	return OK

## Granata o carica da demolizione (regola 10).
func probabilita_lancio(lanciatore: Dictionary, tipo: String, h: String) -> Dictionary:
	if lanciatore.postura == "prone":
		return {"ok": false, "motivo": "da prono non si lancia"}
	if tipo == "satchel" and lanciatore.postura != "standing":
		return {"ok": false, "motivo": "la carica si lancia solo in piedi"}
	var dist := E.distanza(lanciatore.hex, h)
	if dist == 0:
		return {"ok": false, "motivo": "non nel proprio esagono"}
	var massimo := 3 if (tipo == "satchel" or lanciatore.postura == "crouching") else 6
	if dist > massimo:
		return {"ok": false, "motivo": "troppo lontano (massimo %d)" % massimo}
	if dist == 1 and terreno.tipo_lato(lanciatore.hex, h) == "wall":
		return {"ok": false, "motivo": "c’è un muro senza aperture"}
	var base := T.base_lancio(tipo, dist)
	if base < 0:
		return {"ok": false, "motivo": "fuori gittata"}
	var mods: Array = []
	if int(lanciatore.WS) != 0:
		mods.append(["abilità", int(lanciatore.WS)])
	if lanciatore.ferito:
		mods.append(["lanciatore ferito", -2])
	var in_vista := terreno.vede(lanciatore.hex, h, lanciatore.postura, "standing")
	if not in_vista:
		mods.append(["bersaglio non in vista", -3])
	if terreno.edificio(h) and dist > 1:
		mods.append(["apertura non adiacente", -3])
	var tot := base
	for m in mods:
		tot += int(m[1])
	return {"ok": true, "prob": clampi(tot, 0, 8), "base": base, "mods": mods, "dist": dist,
		"gittata": "adiacente" if dist == 1 else "%d esagoni" % dist}

func risolvi_lancio(lanciatore: Dictionary, tipo: String, h: String) -> void:
	var p := probabilita_lancio(lanciatore, tipo, h)
	if not p.ok:
		return
	var nome_arma := "una granata" if tipo == "granata" else "una carica da demolizione"
	_log("combattimento", "%s lancia %s in %s." % [nome(lanciatore), nome_arma, h])
	if tipo == "granata":
		lanciatore.munizioni.granata = maxi(0, int(lanciatore.munizioni.get("granata", 0)) - 1)
	else:
		var c := arma_di(lanciatore, "satchel")
		lanciatore.armi.erase(c)
	_rendi_consapevoli(h)
	var r := d10()
	var arrivo := h
	if r == 0 or (r != 9 and r <= int(p.prob)):
		_log("dado", "Lancio: serve 0–%d, esce %d → nell’esagono." % [int(p.prob), r])
	else:
		arrivo = _deviazione(lanciatore.hex, h)
		_log("dado", "Lancio: serve 0–%d, esce %d → devia in %s." % [int(p.prob), r, arrivo])
		_rendi_consapevoli(arrivo)
	var pd := percentuale()
	if pd <= 5:
		_log("dado", "Percentuale %02d: ordigno inesploso." % pd)
		return
	var presenti: Array = unita_in(arrivo, "", false).filter(func(x): return x.stato in ["attivo", "incapacitato", "catturato"])
	if presenti.is_empty():
		_log("info", "Esplode in %s senza colpire nessuno." % arrivo)
		return
	# 10/2: reazione dei soldati consapevoli.
	for x in presenti:
		if not attivo(x) or x.panico or (x.lato == "us" and fase_round() and not x.consapevole):
			continue
		if controllo_pc(x, 0, "reazione all’ordigno"):
			if fase_round() and int(x.turni) > 0 and x.postura != "prone":
				_log("combattimento", "%s rilancia l’ordigno fuori portata: esplode senza danni!" % nome(x))
				_consuma_turno(x)
				return
			elif not x.ferito and x.postura != "prone":
				x.postura = "prone"
				_log("info", "%s si butta a terra." % nome(x))
	var dentro := terreno.edificio(arrivo)
	var tab := (T.GRANATA_DENTRO if dentro else T.GRANATA_FUORI) if tipo == "granata" else (T.CARICA_DENTRO if dentro else T.CARICA_FUORI)
	for x in presenti:
		_danno_esplosione(x, tab)

## Deviazione (diagrammi A e B della regola 10/3).
func _deviazione(da_hex: String, bersaglio: String) -> String:
	var v := E.centro(bersaglio) - E.centro(da_hex)
	var ang := fposmod(rad_to_deg(atan2(v.y, v.x)), 360.0)
	# Direzioni dei lati: N 270°, NE 330°, SE 30°, S 90°, SO 150°, NO 210°.
	var dir_ang := [270.0, 330.0, 30.0, 90.0, 150.0, 210.0]
	var migliore := 0
	var dmin := 999.0
	for i in 6:
		var d := absf(angle_difference(deg_to_rad(ang), deg_to_rad(dir_ang[i])))
		if d < dmin:
			dmin = d
			migliore = i
	var r := d10()
	var rel := 0
	var su_vertice := rad_to_deg(dmin) > 25.0
	if not su_vertice:
		# Diagramma A: avanti 2–3, avanti-dx 4, dietro-dx 5, dietro 6–9, dietro-sx 0, avanti-sx 1.
		if r in [2, 3]: rel = 0
		elif r == 4: rel = 1
		elif r == 5: rel = 2
		elif r >= 6: rel = 3
		elif r == 0: rel = 4
		else: rel = 5
		var dest := E.vicino(bersaglio, (migliore + rel) % 6)
		if rel == 3 and dest == da_hex:
			return bersaglio
		return dest if dest != "" and dest != da_hex else bersaglio
	# Diagramma B: lancio lungo un vertice.
	var sinistra := migliore
	var destra := (migliore + 1) % 6
	var a_dx := fposmod(dir_ang[destra] - ang, 360.0) < 60.0
	if not a_dx:
		sinistra = (migliore + 5) % 6
		destra = migliore
	var tabella := {0: sinistra + 5, 1: sinistra, 2: sinistra, 3: destra, 4: destra, 5: destra + 1, 6: destra + 2, 7: destra + 2, 8: sinistra + 3, 9: sinistra + 3}
	var dest := E.vicino(bersaglio, int(tabella[r]) % 6)
	return dest if dest != "" and dest != da_hex else bersaglio

func lancia(id: String, tipo: String, h: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a)
	if e != "":
		return _errore(e)
	if s.fase != "round":
		return _errore("Nelle Operazioni non si combatte.")
	var t := _turno_di(a)
	if t.azione != "":
		return _errore("Non si può muovere e lanciare nello stesso turno.")
	if tipo == "granata" and int(a.munizioni.get("granata", 0)) <= 0:
		return _errore("Nessuna granata.")
	if tipo == "satchel":
		var c := arma_di(a, "satchel")
		if c.is_empty():
			return _errore("Nessuna carica da demolizione.")
		if not c.preparata:
			return _errore("La carica va prima preparata.")
	for x in unita_in(h, "us"):
		if x.id != a.id:
			pass  # si può lanciare anche dove ci sono amici: le regole non lo vietano
	var p := probabilita_lancio(a, tipo, h)
	if not p.ok:
		return _errore("Lancio impossibile: " + str(p.motivo))
	t.azione = "lancio"
	risolvi_lancio(a, tipo, h)
	if not s.turno.is_empty() and s.turno.id == a.id:
		_termina_azione(a)
	elif fase_round():
		_flusso()
	_fine_comando()
	return OK

## Assalto (regola 11).
func probabilita_assalto(att: Dictionary, dif: Dictionary, carica: bool) -> Dictionary:
	var mods: Array = []
	var ws := int(att.WS)
	var solo_catturate := true
	for a in att.armi:
		if not a.get("catturata", false):
			solo_catturate = false
	if att.armi.size() > 0 and solo_catturate:
		ws -= 1
	if ws != 0:
		mods.append(["abilità", ws])
	if carica:
		mods.append(["carica", -3])
	if att.ferito:
		mods.append(["attaccante ferito", -2])
	var ws_d := int(dif.WS)
	var difesa_valida: bool = ws_d >= 1 and not dif.panico and not dif.ferito
	if dif.lato == "us" and fase_round() and not dif.consapevole:
		difesa_valida = false
	if difesa_valida:
		mods.append(["abilità del difensore", -ws_d])
	var tot := 7
	for m in mods:
		tot += int(m[1])
	return {"ok": true, "prob": clampi(tot, 0, 8), "base": 7, "mods": mods, "gittata": "assalto"}

func risolvi_assalto(att: Dictionary, dif: Dictionary, intento: String, carica: bool) -> void:
	var p := probabilita_assalto(att, dif, carica)
	_log("combattimento", "%s %s %s per %s." % [nome(att), "carica" if carica else "assalta", nome(dif), "catturarlo" if intento == "cattura" else "ucciderlo"])
	_rendi_consapevoli(dif.hex)
	var r := d10()
	var colpito: bool = r == 0 or (r != 9 and r <= int(p.prob))
	_log("dado", "Assalto: serve 0–%d, esce %d → %s." % [int(p.prob), r, "riuscito" if colpito else "fallito"])
	if not colpito:
		return
	var rd := d10()
	var tab := T.ASSALTO_CATTURARE if intento == "cattura" else T.ASSALTO_UCCIDERE
	var l := T.lettera_danno(tab, rd)
	if l == "X":
		l = "C" if (dif.ferito or dif.panico or dif.postura == "prone") else "W"
	_log("dado", "Esito: %d → %s" % [rd, _nome_danno(l)])
	if l == "-":
		return
	if l == "C":
		_cattura(att, dif)
	else:
		_applica_danno(dif, l, att)

func _cattura(guardia: Dictionary, g: Dictionary) -> void:
	g.stato = "catturato"
	g.postura = "prone"
	g.turni = 0
	g.slot = "inattivo"
	g.guardia = guardia.id
	guardia.prigionieri.append(g.id)
	_log("danno", "%s è CATTURATO da %s." % [nome(g), nome(guardia)])
	_premio_cattura(g)

func assalta(id: String, bersaglio_id: String, intento: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a)
	if e != "":
		return _errore(e)
	if s.fase != "round":
		return _errore("Nelle Operazioni non si combatte.")
	var b := u(bersaglio_id)
	if b.is_empty() or not attivo(b) or b.hex != a.hex:
		return _errore("Il bersaglio deve essere nello stesso esagono.")
	var t := _turno_di(a)
	var carica: bool = t.azione == "carica"
	if not carica and t.azione != "":
		return _errore("L’assalto è un’azione a sé.")
	if a.postura != "standing":
		return _errore("Per assaltare bisogna essere in piedi.")
	t.azione = "assalto"
	risolvi_assalto(a, b, intento, carica)
	if not s.turno.is_empty() and s.turno.id == a.id:
		_termina_azione(a)
	elif fase_round():
		_flusso()
	_fine_comando()
	return OK

# ------------------------------------------------------------------- azioni varie
func _azione_semplice(a: Dictionary) -> String:
	var e := puo_agire(a)
	if e != "":
		return e
	if a.hex == "":
		return "Il soldato non è ancora sulla mappa."
	if s.fase == "round":
		var t := _turno_di(a)
		if t.azione != "":
			return "Hai già scelto un’azione in questo turno."
	return ""

func _chiudi_azione_semplice(a: Dictionary) -> void:
	if s.fase == "round" and not s.turno.is_empty() and s.turno.id == a.id:
		_termina_azione(a)

func prepara(id: String, tipo: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	if a.postura == "prone":
		return _errore("Da prono non si prepara un’arma.")
	var arma := arma_di(a, tipo)
	if arma.is_empty():
		# Il bazooka può essere caricato da un compagno nello stesso esagono.
		for x in unita_in(a.hex, "us"):
			if x.id != a.id and not arma_di(x, tipo).is_empty():
				arma = arma_di(x, tipo)
				break
	if arma.is_empty():
		return _errore("Arma non disponibile.")
	if arma.preparata:
		return _errore("È già pronta.")
	if tipo == "bazooka" and munizioni_arma(a, "bazooka") <= 0:
		return _errore("Nessun razzo per il bazooka.")
	arma.preparata = true
	_log("azione", "%s prepara: %s." % [nome(a), T.ARMI[tipo].nome])
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

func disinceppa(id: String, tipo: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	if a.postura == "prone":
		return _errore("Da prono non si disinceppa.")
	var arma := arma_di(a, tipo)
	if arma.is_empty() or not arma.inceppata:
		return _errore("L’arma non è inceppata.")
	var ws := clampi(int(a.WS) - (1 if arma.catturata else 0), -3, 2)
	var r := d10()
	var l: String = T.DISINCEPPA[ws].substr(r, 1)
	if l == "C":
		arma.inceppata = false
		_log("dado", "%s disinceppa l’arma: %d → liberata." % [nome(a), r])
	elif l == "B":
		arma.inceppata = false
		arma.rotta = true
		_log("dado", "%s prova a disinceppare: %d → l’arma si ROMPE." % [nome(a), r])
	else:
		_log("dado", "%s prova a disinceppare: %d → ancora inceppata." % [nome(a), r])
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

## Oggetti trasferibili nell’esagono: a terra e da soldati inattivi o compagni.
func oggetti_disponibili(id: String) -> Array:
	var a := u(id)
	var out: Array = []
	if a.is_empty() or a.hex == "":
		return out
	for i in s.oggetti.get(a.hex, []).size():
		var o: Dictionary = s.oggetti[a.hex][i]
		out.append({"da": "terra", "indice": i, "tipo": o.tipo, "testo": T.ARMI.get(o.tipo, {}).get("nome", o.tipo) + (" (inceppata)" if o.get("inceppata", false) else "")})
	for x in unita_in(a.hex, "", false):
		if x.id == a.id:
			continue
		if x.lato == "us" or x.stato in ["morto", "incapacitato", "catturato", "arreso"]:
			for arma in x.armi:
				out.append({"da": x.id, "tipo": arma.tipo, "testo": "%s di %s" % [T.ARMI.get(arma.tipo, {}).get("nome", arma.tipo), nome(x)]})
			for k in x.munizioni:
				if int(x.munizioni[k]) > 0:
					var etichetta: String = "granata" if k == "granata" else ("munizioni " + T.ARMI.get(k, {}).get("breve", k))
					out.append({"da": x.id, "tipo": "mun:" + k, "testo": "%s di %s (%d)" % [etichetta, nome(x), int(x.munizioni[k])]})
	return out

func prendi(id: String, voce: Dictionary) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	if a.postura == "prone":
		return _errore("Da prono non si raccoglie nulla.")
	var tipo: String = voce.tipo
	if voce.da != "terra":
		var x := u(str(voce.da))
		if x.is_empty() or x.hex != a.hex:
			return _errore("Il soldato non è qui.")
		if not attivo(x) and a.postura != "crouching":
			return _errore("Per prendere qualcosa da un caduto bisogna essere accovacciati.")
	if tipo.begins_with("mun:"):
		var k := tipo.substr(4)
		if scatole_munizioni(a) >= 6:
			return _errore("Le caselle delle munizioni sono piene.")
		var x := u(str(voce.da))
		x.munizioni[k] = int(x.munizioni[k]) - 1
		a.munizioni[k] = munizioni_arma(a, k) + 1
		_log("azione", "%s prende: %s da %s." % [nome(a), "una granata" if k == "granata" else "un caricatore", nome(x)])
	else:
		var arma: Dictionary
		if voce.da == "terra":
			arma = s.oggetti[a.hex][int(voce.indice)]
		else:
			arma = arma_di(u(str(voce.da)), tipo)
		if arma.is_empty():
			return _errore("Oggetto non trovato.")
		var p := int(T.ARMI.get(tipo, {}).get("porte", 1))
		if tipo == "pistol":
			if scatole_munizioni(a) >= 6:
				return _errore("Caselle piene.")
		elif porte_usate(a) + p > porte_massime(a):
			return _errore("Le caselle di porto sono piene: lascia prima qualcosa.")
		if voce.da == "terra":
			s.oggetti[a.hex].remove_at(int(voce.indice))
		else:
			var x := u(str(voce.da))
			x.armi.erase(arma)
			if x.lato == "de":
				arma.catturata = true
				var colpi := 0 if arma.get("scarica", false) else 1
				if colpi > 0 and tipo != "pistol":
					a.munizioni[tipo] = munizioni_arma(a, tipo) + colpi
				elif colpi > 0:
					a.munizioni["pistol"] = munizioni_arma(a, "pistol") + 1
		a.armi.append(arma)
		_log("azione", "%s prende: %s." % [nome(a), T.ARMI.get(tipo, {}).get("nome", tipo)])
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

func lascia(id: String, tipo: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	var arma := arma_di(a, tipo)
	if arma.is_empty():
		return _errore("Non ha quest’arma.")
	a.armi.erase(arma)
	_lascia_oggetto(a.hex, arma)
	_log("azione", "%s lascia a terra: %s." % [nome(a), T.ARMI.get(tipo, {}).get("nome", tipo)])
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

## Trascina un soldato inattivo nell’esagono adiacente (regole 5/3 e 6/7).
func trascina(id: String, ferito_id: String, verso: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	var f := u(ferito_id)
	if f.is_empty() or f.hex != a.hex or attivo(f) or not (f.stato in ["incapacitato", "morto"]):
		return _errore("Si trascina solo un soldato inattivo nello stesso esagono.")
	if a.postura != "standing":
		return _errore("Per trascinare bisogna essere in piedi.")
	if porte_usate(a) >= porte_massime(a):
		return _errore("Serve una casella di porto libera.")
	var uscita := verso == "USCITA"
	if uscita:
		if not (E.riga(a.hex) == 1 and E.colonna(a.hex) <= 9):
			return _errore("Si esce solo dal margine nord, tra A1 e J1.")
	elif terreno.costo_movimento(a.hex, verso) < 0:
		return _errore("Non si passa da quella parte.")
	if f.stato == "incapacitato":
		var r := d10()
		if r == 0:
			_log("dado", "Trascinamento: %d → %s muore." % [r, nome(f)])
			_uccidi(f, "durante il trasporto")
		else:
			_log("dado", "Trascinamento: %d → sopravvive." % r)
	if uscita:
		a.stato = "uscito"
		a.hex = ""
		f.hex = ""
		f.uscito = true
		_log("azione", "%s esce dalla mappa trascinando %s." % [nome(a), nome(f)])
		_chiudi_azione_semplice(a)
		_fine_comando()
		return OK
	a.hex = verso
	f.hex = verso
	_log("azione", "%s trascina %s in %s." % [nome(a), nome(f), verso])
	if s.fase == "round":
		_turno_di(a).azione = "trascina"
	_ingresso(verso, [a.id], false)
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

## Esce dalla mappa dal margine nord (fine della missione n. 2).
func esci(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	if not (E.riga(a.hex) == 1 and E.colonna(a.hex) <= 9):
		return _errore("Si esce solo dal margine nord, tra A1 e J1.")
	if a.postura == "prone":
		return _errore("Un soldato prono non si muove.")
	for pid in a.prigionieri:
		var p := u(pid)
		if not p.is_empty() and p.stato == "catturato":
			p.hex = ""
			p.stato = "rimosso"
	a.stato = "uscito"
	a.hex = ""
	_log("azione", "%s esce dalla mappa." % nome(a))
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

func cedi_turno(id: String, altro_id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	if s.fase != "round" or not a.comandante or a.panico:
		return _errore("Solo un comandante può cedere un turno.")
	var b := u(altro_id)
	if b.is_empty() or not in_mappa(b) or E.distanza(a.hex, b.hex) > 2:
		return _errore("Il soldato deve essere entro 2 esagoni.")
	if b.ferito or not (b.slot in ["completo", "turni"]) or int(b.turni) >= 2 or not b.consapevole:
		return _errore("Quel soldato non può ricevere un turno.")
	b.turni = int(b.turni) + 1
	b.slot = "turni"
	_log("azione", "%s cede il suo turno a %s." % [nome(a), nome(b)])
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

func sveglia(id: String, altro_id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	if s.fase != "round" or not a.comandante or a.panico:
		return _errore("Solo un comandante può allertare un soldato.")
	var b := u(altro_id)
	if b.is_empty() or b.consapevole or b.ferito or b.hex == "" or E.distanza(a.hex, b.hex) > 2:
		return _errore("Serve un soldato inconsapevole, non ferito, entro 2 esagoni.")
	b.consapevole = true
	b.slot = "completo"
	_log("azione", "%s scuote %s: ora è consapevole." % [nome(a), nome(b)])
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

func libera_pilota(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a)
	if e != "":
		return _errore(e)
	if a.hex != "R15" or s.pilota != "intrappolato":
		return _errore("Il pilota è intrappolato nel relitto in R15.")
	if a.ferito:
		return _errore("Serve un soldato non ferito.")
	if s.fase == "operazioni":
		_log("azione", "%s forza il montante dell’ala per liberare il pilota." % nome(a))
		evento_casuale({"hex": "R15", "ids": [a.id]})
		if s.pilota == "intrappolato" and attivo(a):
			leggi("454", {"hex": "R15", "ids": [a.id]})
	else:
		var t := _turno_di(a)
		if t.azione != "":
			return _errore("Hai già scelto un’azione.")
		s.pilota_lavoro = int(s.get("pilota_lavoro", 0)) + 1
		_log("azione", "%s lavora per liberare il pilota (%d/2)." % [nome(a), int(s.pilota_lavoro)])
		if int(s.pilota_lavoro) >= 2:
			leggi("454", {"hex": "R15", "ids": [a.id]})
		_termina_azione(a)
	_fine_comando()
	return OK

func _op_pilota() -> void:
	if s.pilota == "libero":
		return
	s.pilota = "libero"
	_pv(2, "pilota britannico liberato")
	var d := {"id": "J", "nome": "Pilota", "IN": 2, "PC": 5, "WS": -1, "DS": 2, "MPA": 2, "comandante": false,
		"porte": ["pistol"], "munizioni": {"pistol": 1}}
	var p := _nuovo_americano(d)
	p.stato = "attivo"
	p.hex = "R15"
	p.ferito = true
	p.postura = "prone"
	p.pilota = true
	p.consapevole = fase_round()
	p.slot = "completo" if fase_round() else ""
	s.unita["J"] = p
	_log("info", "Il pilota britannico (J) si unisce alla squadra: è già ferito.")

func _op_soldato_k() -> void:
	if not u("K").is_empty():
		return
	var d := {"id": "K", "nome": "Superstite", "IN": 0, "PC": 0, "WS": 0, "DS": 0, "MPA": 0, "comandante": false,
		"porte": [], "munizioni": {"smg": 2, "granata": 1}}
	var k := _nuovo_americano(d)
	k.stato = "incapacitato"
	k.hex = "G10"
	k.postura = "prone"
	k.senza_carta = true
	k.ferito = true
	s.unita["K"] = k
	_log("info", "Il soldato K giace incapacitato in G10. Portalo al sicuro per guadagnare 3 PV.")

func _op_cecchino(ctx: Dictionary) -> void:
	var candidati: Array = []
	for id in ctx.get("ids", []):
		var a := u(str(id))
		if attivo(a):
			candidati.append(a)
	if candidati.is_empty():
		candidati = unita_in(ctx.get("hex", ""), "us")
	if candidati.is_empty():
		candidati = americani_attivi_in_mappa()
	if candidati.is_empty():
		return
	candidati.sort_custom(func(a, b): return T.indice_postura(a.postura) < T.indice_postura(b.postura))
	var migliore_post: String = candidati[0].postura
	var pari: Array = candidati.filter(func(x): return x.postura == migliore_post)
	var bersaglio: Dictionary = pari[rng.randi_range(0, pari.size() - 1)]
	var arma := {"tipo": "scoped", "inceppata": false}
	var base := 5
	var mods := 0
	if terreno.edificio(bersaglio.hex):
		mods += T.MOD_INTERNO_LONTANO[T.indice_postura(bersaglio.postura)] if bersaglio.postura != "prone" else -9
	else:
		var th := terreno.tipo(bersaglio.hex)
		if th == "stream" and terreno.ponte(bersaglio.hex):
			th = "bridge"
		mods += int(T.MOD_TERRENO.get(th, [0, 0, 0])[T.indice_postura(bersaglio.postura)])
	var prob := clampi(base + mods, 0, 8)
	risolvi_tiro({"lato": "cecchino", "WS": 0}, arma, bersaglio, true, prob)

func _op_campo_minato(ctx: Dictionary) -> void:
	var h: String = ctx.get("hex", "")
	if h == "":
		return
	s.mine[h] = true
	for id in ctx.get("ids", []):
		var a := u(str(id))
		if not attivo(a):
			continue
		if not controllo_pc(a, 0, "campo minato"):
			_log("combattimento", "Una mina esplode sotto %s!" % nome(a))
			_danno_esplosione(a, T.GRANATA_DENTRO)

func _op_artiglieria() -> void:
	var a1 := d10()
	var a2 := d10()
	var primo := mini(a1, a2) * 10 + maxi(a1, a2)
	_log("dado", "Artiglieria, primo tiro: %d e %d → %02d" % [a1, a2, primo])
	if primo > 25:
		_log("info", "Il colpo cade fuori mappa: un’esplosione lontana.")
		return
	var b1 := d10()
	var b2 := d10()
	var secondo := mini(b1, b2) * 10 + maxi(b1, b2)
	_log("dado", "Artiglieria, secondo tiro: %d e %d → %02d" % [b1, b2, secondo])
	if secondo > 19 or primo < 1 or secondo < 1:
		_log("info", "Il colpo cade fuori mappa: un’esplosione lontana.")
		return
	var h := E.da(primo - 1, secondo)
	if h == "":
		_log("info", "Il colpo cade fuori mappa.")
		return
	_log("combattimento", "Un colpo d’artiglieria si abbatte su %s!" % h)
	if terreno.edificio(h):
		s.modifiche[h] = "rubble"
	else:
		s.modifiche[h] = "crater"
	terreno.imposta_modifiche(s.modifiche)
	for x in unita_in(h, "", false):
		if x.stato in ["attivo", "incapacitato", "catturato", "arreso"]:
			_uccidi(x, "artiglieria")

func _op_granata_difettosa() -> void:
	var portatori: Array = []
	for a in americani_attivi_in_mappa():
		if int(a.munizioni.get("granata", 0)) > 0:
			portatori.append(a)
	if portatori.is_empty():
		_log("info", "Nessun soldato in mappa porta granate.")
		return
	var a: Dictionary = portatori[rng.randi_range(0, portatori.size() - 1)]
	a.munizioni.granata = int(a.munizioni.granata) - 1
	_log("combattimento", "La granata di %s è difettosa!" % nome(a))
	if controllo_pc(a, 0):
		var libero := ""
		for v in E.vicini(a.hex):
			if unita_in(v, "", false).is_empty() and terreno.tipo_lato(a.hex, v) != "wall":
				libero = v
				break
		_log("info", "%s la getta in %s, dove esplode senza danni." % [nome(a), libero if libero != "" else "un fosso vicino"])
	else:
		for x in unita_in(a.hex, "", false):
			if x.stato in ["attivo", "incapacitato"]:
				_danno_esplosione(x, T.GRANATA_DENTRO)

func _op_munizioni_finite() -> void:
	var lista: Array = s.round.get("sparato_prec", []) if not s.round.is_empty() else []
	if lista.is_empty():
		_log("info", "Nessuna arma tedesca ha sparato nel Round precedente.")
		return
	var scelta: Array = lista[rng.randi_range(0, lista.size() - 1)]
	var g := u(str(scelta[0]))
	var arma := arma_di(g, str(scelta[1]))
	if arma.is_empty():
		return
	arma.scarica = true
	_log("info", "L’arma (%s) del %s è senza munizioni." % [T.ARMI[arma.tipo].nome.to_lower(), nome(g)])

# =================================================================== fine missione
var _alture_cache: Array = []

## Esagoni delle alture di sud-est (livello 3) da cui si vede tutta la strada.
## Se nessun esagono soddisfa la regola alla lettera, si applica il buon senso (regola 8/3):
## valgono gli esagoni con la vista più ampia sulla strada.
func alture_obiettivo() -> Array:
	if not _alture_cache.is_empty():
		return _alture_cache
	if not terreno.alture.is_empty():
		return terreno.alture
	var strade := esagoni_strada()
	var migliori: Array = []
	var massimo := -1
	for h in E.tutti():
		if terreno.quota(h) < 3:
			continue
		var n := 0
		for r in strade:
			if terreno.vede(h, r):
				n += 1
		if n > massimo:
			massimo = n
			migliori = [h]
		elif n == massimo:
			migliori.append(h)
	_alture_cache = migliori
	return migliori

func condizioni_vittoria() -> Dictionary:
	var t8 := false
	var kl := false
	var altura := ""
	for a in americani():
		if a.hex == "T8" and attivo(a):
			t8 = true
		if a.hex in ["K13", "L13"] and a.stato in ["attivo", "incapacitato"]:
			kl = true
	var obiettivo := alture_obiettivo()
	for a in americani_attivi_in_mappa():
		if a.hex in obiettivo:
			altura = a.hex
			break
	return {"t8": t8, "kl": kl, "altura": altura, "nessun_tedesco": tedeschi_attivi().is_empty(),
		"ok": t8 and kl and altura != "" and tedeschi_attivi().is_empty() and s.fase == "operazioni"}

func termina_missione(modo: String) -> Dictionary:
	_inizio_comando()
	if s.fase == "fine":
		return _errore("La missione è già terminata.")
	if modo == "obiettivo":
		if not condizioni_vittoria().ok:
			return _errore("Gli obiettivi non sono ancora raggiunti.")
	_calcola_fine(modo)
	_fine_comando()
	return OK

func _controlla_fine_automatica() -> void:
	if s.fase == "fine":
		return
	var vivi_in_mappa := americani_attivi_in_mappa().filter(func(x): return not x.get("pilota", false))
	var da_entrare := americani().filter(func(x): return x.stato == "fuori")
	if vivi_in_mappa.is_empty() and da_entrare.is_empty():
		var usciti := americani().filter(func(x): return x.stato == "uscito")
		_calcola_fine("ritirata" if not usciti.is_empty() else "annientata")

func _calcola_fine(modo: String) -> void:
	s.fase = "fine"
	s.pausa = ""
	var righe: Array = []
	var tot := pv_totali()
	var bonus := 0
	if modo == "obiettivo":
		bonus = 4
		righe.append(["Obiettivo raggiunto: strada di Saint-Michaux sotto controllo", 4])
	var perdite := 0
	for a in americani():
		if a.id in ["J", "K"]:
			continue
		if a.stato == "morto":
			perdite -= 2
			righe.append(["%s ucciso" % nome(a), -2])
		elif a.stato == "incapacitato":
			var salvo: bool = a.get("uscito", false) or (modo == "obiettivo" and terreno.edificio(a.hex))
			if not salvo:
				perdite -= 2
				righe.append(["%s incapacitato e non messo in salvo" % nome(a), -2])
	var k := u("K")
	if not k.is_empty() and k.stato != "morto":
		var salvo_k: bool = k.get("uscito", false) or (modo == "obiettivo" and terreno.edificio(k.hex))
		if salvo_k:
			bonus += 3
			righe.append(["Soldato K portato in salvo", 3])
	var j := u("J")
	if not j.is_empty() and j.stato in ["attivo", "uscito"]:
		bonus += 2
		righe.append(["Pilota britannico attivo alla fine", 2])
	var finale := tot + bonus + perdite
	var vinta := finale >= int(missione.vittoria_pv)
	s.fine = {"modo": modo, "pv_partita": tot, "righe": righe, "totale": finale, "vinta": vinta}
	_log("fine", "MISSIONE CONCLUSA — %d PV: %s." % [finale, "VITTORIA" if vinta else "SCONFITTA"])
