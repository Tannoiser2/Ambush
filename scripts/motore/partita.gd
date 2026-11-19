class_name Partita
extends RefCounted
## Motore delle missioni: Operazioni, Round, paragrafi, combattimento e punteggio.
## Tutto lo stato è in `s` (dizionario serializzabile in JSON).

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")
const TerrenoScript = preload("res://scripts/motore/terreno.gd")
const TedeschiScript = preload("res://scripts/motore/tedeschi.gd")
const VeicoliScript = preload("res://scripts/motore/veicoli.gd")

signal aggiornata

var s: Dictionary = {}
var missione: Dictionary
var paragrafi: Dictionary
var terreno: Terreno
var ia: RefCounted
var veicoli: RefCounted
var rng := RandomNumberGenerator.new()
## Voci di cronaca prodotte dall’ultimo comando (per la scheda dei paragrafi).
var recenti: Array = []
## Posizioni e stati delle pedine all’inizio dell’ultimo comando (per la riproduzione animata).
var vista_iniziale: Dictionary = {}
## Stato dei pannelli (pista, scheda, fasi) all’inizio dell’ultimo comando.
var stato_iniziale: Dictionary = {}
## Ultimo dado tirato (per i riepiloghi delle fasi).
var ultimo_dado := 0
var _profondita := 0
var _stampa := OS.get_environment("AMBUSH_CRONACA") == "1"

var numero := 1

func _init(n := 1) -> void:
	paragrafi = JSON.parse_string(FileAccess.get_file_as_string("res://data/paragrafi.json"))
	ia = TedeschiScript.new(self)
	veicoli = VeicoliScript.new(self)
	imposta_missione(n)

## Missioni con i dati pronti (le altre compaiono nel menu come «in preparazione»).
static func disponibili() -> Array:
	var out: Array = []
	for n in range(1, 9):
		if FileAccess.file_exists("res://data/missione%d.json" % n):
			out.append(n)
	return out

## Carica i dati della missione n (carte, tedeschi, mappa) se non sono già quelli in uso.
func imposta_missione(n: int) -> void:
	if n == numero and not missione.is_empty():
		return
	numero = n
	missione = JSON.parse_string(FileAccess.get_file_as_string("res://data/missione%d.json" % n))
	terreno = TerrenoScript.new("res://data/mappa_%s.json" % str(missione.get("mappa", "A")).to_lower())
	_alture_cache = []

func titolo_missione() -> String:
	return "Missione %d · %s" % [numero, missione.titolo]

func testo_ingresso() -> String:
	return str(missione.get("ingresso_breve", "dal margine nord (A1–J1)"))

# =================================================================== stato
func nuova(seme := 0, con_schieramento := false) -> void:
	if seme == 0:
		seme = int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
	rng.seed = seme
	s = {
		"versione": 2, "missione": numero, "seme": seme, "fase": "operazioni", "condizione": 1,
		"avvistamenti": [false, false, false, false, false, false, false, false, false, false],
		"pv": [], "eventi": {}, "mine": {}, "modifiche": {}, "oggetti": {}, "punti": {},
		"unita": {}, "evasi": {}, "no_rientro": false, "pilota": "", "cronaca": [],
		"round": {}, "turno": {}, "pausa": "", "fine": {}, "nota_mine": false, "attivati": [],
	}
	for d in missione.squadra:
		var u := _nuovo_americano(d)
		s.unita[u.id] = u
	terreno.imposta_modifiche(s.modifiche)
	_log("titolo", titolo_missione())
	_log("info", missione.briefing)
	if con_schieramento:
		s.fase = "schieramento"
		_log("info", "Condizione 1. %s Schiera i soldati %s, poi dai il via alla missione." % [_testo_livello(), testo_ingresso()])
	else:
		_log("info", "Condizione 1. %s Entra con i soldati %s." % [_testo_livello(), testo_ingresso()])
	recenti.clear()
	aggiornata.emit()

# ------------------------------------------------------------------ schieramento iniziale
func _testo_livello() -> String:
	if missione.attivazione.has(str(int(s.condizione))):
		return "Livello di attivazione 0–%d." % livello_attivazione()
	return "Nessun controllo di attivazione in questa Condizione."

## Esagoni da cui la squadra entra (Missione 1: margine nord, A1–J1).
func esagoni_ingresso() -> Array:
	if missione.has("ingresso_esagoni"):
		return missione.ingresso_esagoni.duplicate()
	var out: Array = []
	for c in 10:
		out.append(E.da(c, 1))
	return out

func e_ingresso(h: String) -> bool:
	return h in esagoni_ingresso()

## Esagoni da cui si esce dalla mappa (di solito gli stessi dell’ingresso).
func e_uscita(h: String) -> bool:
	if missione.has("uscita_esagoni"):
		return h in missione.uscita_esagoni
	return e_ingresso(h)

## Dispone (o sposta) dei soldati su un esagono d’ingresso prima che la missione cominci.
## Con h vuoto li rimette fuori mappa. Nessuna carta viene letta finché non si dà il via.
func schiera(ids: Array, h: String) -> Dictionary:
	recenti.clear()
	if s.fase != "schieramento":
		return {"ok": false, "errore": "Lo schieramento è già concluso."}
	if h != "" and not (h in esagoni_ingresso()):
		return {"ok": false, "errore": "Si entra solo %s." % testo_ingresso()}
	for id in ids:
		var a := u(str(id))
		if a.is_empty() or a.lato != "us":
			continue
		a.hex = h
		a.stato = "attivo" if h != "" else "fuori"
		a.postura = "standing"
	aggiornata.emit()
	return {"ok": true}

## Fine dello schieramento: la squadra entra davvero e si controlla ogni esagono occupato.
func inizia_missione() -> Dictionary:
	if s.fase != "schieramento":
		return {"ok": false, "errore": "La missione è già cominciata."}
	var gruppi := {}
	for a in americani():
		if a.stato == "attivo" and a.hex != "":
			if not gruppi.has(a.hex):
				gruppi[a.hex] = []
			gruppi[a.hex].append(a.id)
	if gruppi.is_empty():
		return {"ok": false, "errore": "Schiera almeno un soldato %s." % testo_ingresso()}
	_inizio_comando()
	s.fase = "operazioni"
	var esagoni: Array = gruppi.keys()
	esagoni.sort()
	var parti: Array = []
	for h in esagoni:
		parti.append("%s in %s" % [", ".join(gruppi[h]), h])
	_log("azione", "La squadra entra in mappa: %s." % "; ".join(parti))
	for h in esagoni:
		if s.fase == "fine":
			break
		var presenti: Array = gruppi[h].filter(func(id): return attivo(u(str(id))) and u(str(id)).hex == h)
		if not presenti.is_empty():
			_ingresso(h, presenti, false)
	if fase_round() and s.turno.is_empty() and s.pausa == "":
		_flusso()
	_fine_comando()
	return {"ok": true}

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
	# Un salvataggio riletto dal JSON ha tutti i numeri come decimali (1.0 al posto di 1):
	# vanno riportati a interi, altrimenti le ricerche per Condizione e per numero falliscono.
	s = _interi(dati.duplicate(true))
	imposta_missione(int(s.get("missione", 1)))
	rng.seed = int(s.seme)
	if s.has("rng_stato"):
		rng.state = int(s.rng_stato)
	terreno.imposta_modifiche(s.modifiche)
	recenti.clear()
	aggiornata.emit()
	return true

## Riporta a interi i numeri senza parte decimale, in tutto lo stato.
func _interi(v):
	if v is float:
		return int(v) if v == floorf(v) and absf(v) < 9.0e15 else v
	if v is Dictionary:
		for k in v.keys():
			v[k] = _interi(v[k])
	elif v is Array:
		for i in v.size():
			v[i] = _interi(v[i])
	return v

# =================================================================== utilità
func d10(motivo := "") -> int:
	var r := rng.randi_range(0, 9)
	ultimo_dado = r
	if motivo != "":
		_log("dado", "%s: %d" % [motivo, r])
	return r

func percentuale() -> int:
	return rng.randi_range(0, 99)

## Istantanea dello stato visibile delle pedine (posizione, postura, condizioni).
func istantanea() -> Dictionary:
	var out := {}
	for k in s.get("unita", {}):
		var x: Dictionary = s.unita[k]
		if x.hex == "" or x.stato in ["fuori", "uscito", "rimosso"]:
			continue
		out[k] = {"hex": x.hex, "postura": x.postura, "stato": x.stato, "ferito": x.ferito, "panico": x.get("panico", false)}
	return out

## Effetto visivo da riprodurre sulla mappa, con l’istantanea dopo l’evento.
func _fx(tipo: String, dati := {}) -> Dictionary:
	var v := {"t": "fx", "fx": tipo, "vista": istantanea()}
	v.merge(dati)
	recenti.append(v)
	return v

func _aggiorna_fx(v: Dictionary, dati: Dictionary) -> void:
	v.merge(dati, true)
	v.vista = istantanea()

func _inizia_registrazione() -> void:
	recenti.clear()
	vista_iniziale = istantanea()
	stato_iniziale = stato_pannelli()

## Copia dello stato che i pannelli mostrano: serve a tenerli allineati alla riproduzione.
func stato_pannelli() -> Dictionary:
	return {"unita": s.get("unita", {}).duplicate(true), "round": s.get("round", {}).duplicate(true),
		"fase": s.get("fase", "operazioni"), "condizione": s.get("condizione", 1), "pausa": s.get("pausa", ""),
		"avvistamenti": s.get("avvistamenti", []).duplicate(), "pv_tot": pv_totali() if s.has("pv") else 0}

## Inizio di un passo della riproduzione: una fase del Round, il turno di un tedesco, un contatto…
## L’interfaccia si ferma a ogni passo e mostra la scheda dell’azione.
func _passo(tipo: String, dati := {}) -> Dictionary:
	var v := {"t": "passo", "tipo": tipo, "stato": stato_pannelli(), "vista": istantanea()}
	v.merge(dati)
	recenti.append(v)
	return v

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
	return int(missione.attivazione.get(str(int(s.condizione)), -1))

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
	var mg := _mg_montata(un)
	if not mg.is_empty() and mg.tipo == tipo:
		return mg
	return {}

## Mitragliatrice montata sul veicolo in cui si trova il soldato (l’autista la usa solo a veicolo fermo).
func _mg_montata(un: Dictionary) -> Dictionary:
	var veic: Dictionary = veicoli.di(un)
	if not veicoli.attivo(veic) or not veic.has("mg"):
		return {}
	if veicoli.e_autista(un) and fase_round() and not s.turno.is_empty() and s.turno.get("id", "") == un.id and s.turno.get("mosso", false):
		return {}
	return veic.mg

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
	var mg := _mg_montata(un)
	if not mg.is_empty() and mg.tipo == tipo and not un.munizioni.has(tipo):
		return int(veicoli.di(un).get("mg_munizioni", 10))
	return int(un.munizioni.get(tipo, 0))

## Armi da fuoco utilizzabili (non inceppate, non rotte, con munizioni).
func armi_da_fuoco(un: Dictionary) -> Array:
	var out: Array = []
	var tutte: Array = un.armi.duplicate()
	var mg := _mg_montata(un)
	if not mg.is_empty():
		tutte.append(mg)
	for a in tutte:
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
	var c: Dictionary = missione.condizioni[str(int(s.condizione) if cond < 0 else cond)]
	return str(c.esagoni.get(h, "NONE"))

func riferimento_evento(n: int) -> String:
	var c: Dictionary = missione.condizioni[str(int(s.condizione))]
	return str(c.evento.get(str(n), "NONE"))

func movimento_rosso(h: String) -> String:
	var c: Dictionary = missione.condizioni[str(int(s.condizione))]
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
			_op_munizioni_finite(int(o.get("mg_da_condizione", 0)))
		"typhoon_crash":
			s.punti["R15"] = "typhoon"
			_fx("esplosione", {"a": "R15", "grande": true})
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
			if ctx.get("veicolo", false):
				veicoli.entra_da_paragrafo(ctx, str(o.hex))
			else:
				ia.entra_da_paragrafo(ctx, str(o.hex))
		"g_reaction":
			ia.imposta_reazione(ctx, str(o.r))
		"g_reaction_num":
			var gx := u("g%d" % int(o.g))
			if not gx.is_empty() and in_mappa(gx):
				gx.reazione = str(o.r)
				_log("info", "Reazione speciale %s in vigore per il %s." % [str(o.r), nome(gx)])
		"vp":
			_pv(int(o.n), str(o.get("why", "paragrafo")))
		"landmark":
			var hl: String = ctx.get("hex", "") if str(o.hex) == "@hex" else str(o.hex)
			if hl != "":
				s.punti[hl] = str(o.name)
				_log("info", "Segnaposto «%s» in %s." % [NOMI_SEGNAPOSTO.get(str(o.name), str(o.name)), hl])
		"indica":
			ctx.indicato = str(o.hex)
		"forza_consapevole":
			if ctx.get("ultimo_pc", "") != "":
				ctx.forza_consapevole = ctx.ultimo_pc
			else:
				var sc := _soldato_pc(ctx)
				if not sc.is_empty():
					ctx.forza_consapevole = sc.id
		"forza_inconsapevole":
			var si := _soldato_pc(ctx)
			if not si.is_empty():
				ctx.forza_inconsapevole = si.id
		"catena":
			_op_catena(o, ctx)
		"note_par":
			if ctx.get("hex", "") != "":
				if not s.has("da_leggere"):
					s.da_leggere = {}
				s.da_leggere[ctx.hex] = str(o.p)
				_log("info", "Annotato sulla scheda: leggere il paragrafo %s quando in %s restano attivi solo i tuoi soldati." % [str(o.p), ctx.hex])
		"nota":
			if not s.has("note"):
				s.note = {}
			s.note[str(o.chiave)] = true
		"boobytrap":
			_op_trappola(ctx)
		"strafe":
			_op_mitragliamento()
		"jeep_reinforcement":
			_op_rinforzo_jeep(o)
		"activate_vehicle":
			veicoli.attiva_tedesco(int(o.g), str(o.hex), ctx)
		"kubel_surrender":
			veicoli.resa_kubelwagen(ctx)
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
	if t.has("mission"):
		return numero == int(t.mission)
	if t.has("cond_in"):
		return int(s.condizione) in t.cond_in.map(func(x): return int(x))
	if t.has("cond_seen"):
		return int(s.condizione) == int(t.cond_seen) or int(t.cond_seen) in s.get("condizioni_viste", [])
	if t.has("not_prone"):
		var sp := _soldato_pc(ctx)
		return not sp.is_empty() and sp.postura != "prone"
	if t.has("g_in_hex"):
		return not unita_in(ctx.get("hex", ""), "de").is_empty()
	if t.has("vehicle_moving"):
		return bool(ctx.get("veicolo", false))
	if t.has("no_mine_blast"):
		return not bool(ctx.get("mina_esplosa", false))
	if t.has("g_active"):
		var ga := u("g%d" % int(t.g_active))
		return not ga.is_empty() and attivo(ga)
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

const NOMI_SEGNAPOSTO := {"carro": "carro distrutto", "bunker": "bunker", "typhoon": "relitto del Typhoon",
	"trappola": "trappola esplosiva", "guado": "guado", "deposito": "deposito di carburante"}

## Catena di controlli: per ogni esagono, se un americano lo vede si tenta l’attivazione;
## al primo successo si eseguono le istruzioni di quel passo.
func _op_catena(o: Dictionary, ctx: Dictionary) -> void:
	for passo in o.passi:
		var h := str(passo[0])
		if not qualcuno_vede_hex(h):
			continue
		var r := d10()
		var liv := livello_attivazione()
		var ok := liv >= 0 and (r == 0 or (r != 9 and r <= liv))
		_log("dado", "Controllo di attivazione per l’esagono %s (livello %d): %d → %s" % [h, liv, r, "riuscito" if ok else "fallito"])
		if ok:
			_esegui(passo[1], ctx)
			return
	_log("info", "Nessun effetto.")

## Trappola esplosiva (12/1): il PC più alto dell’esagono fa il controllo; se fallisce, esplode su tutti.
func _op_trappola(ctx: Dictionary) -> void:
	var h: String = ctx.get("hex", "")
	if h == "":
		return
	var sold := _soldato_pc(ctx)
	if sold.is_empty():
		return
	var mod := 3 if (h == "S14" and s.get("note", {}).has("trappola_S14")) else 0
	s.punti[h] = "trappola"
	if controllo_pc(sold, mod, "trappola esplosiva"):
		_log("info", "%s scopre la trappola e la disinnesca." % nome(sold))
		return
	_log("combattimento", "La trappola esplode in %s!" % h)
	_fx("esplosione", {"a": h})
	for a in unita_in(h, "us"):
		_danno_esplosione(a, T.GRANATA_DENTRO)

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
	elif livello_attivazione() < 0:
		_log("info", "Controllo di attivazione: in questa Condizione non c’è livello di attivazione, il controllo fallisce.")
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

func evento_casuale(ctx: Dictionary, passo: Dictionary = {}) -> void:
	var a := d10()
	var b := d10()
	var somma := a + b
	var rif := riferimento_evento(somma)
	passo.merge({"a": a, "b": b, "somma": somma, "rif": rif}, true)
	_log("dado", "Controllo Evento: %d + %d = %d → %s" % [a, b, somma, "nessun evento" if rif == "NONE" else rif.replace(":", " ")])
	_risolvi_riferimento(rif, ctx)

func cambia_condizione(n: int) -> void:
	# Missione 1: la Condizione cresce soltanto. Nelle altre si segue il paragrafo alla lettera.
	if n == int(s.condizione) or (numero == 1 and n < int(s.condizione)):
		return
	if not missione.condizioni.has(str(n)):
		_log("errore", "La carta della Condizione %d non è disponibile: si resta nella Condizione %d." % [n, int(s.condizione)])
		return
	_passo("condizione", {"n": n})
	s.condizione = n
	if not s.has("condizioni_viste"):
		s.condizioni_viste = [1]
	if not (n in s.condizioni_viste):
		s.condizioni_viste.append(n)
	s.eventi.clear()
	_log("condizione", "Passa alla Condizione %d. %s Tutti i segnalini Evento sono rimossi." % [n, _testo_livello()])
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
		if nuovi.is_empty():
			_passo("attivazione")
		var g := _crea_tedesco(num, h, str(o.stance))
		if o.get("reaction") != null and str(o.reaction) != "":
			g.reazione = str(o.reaction)
		# Tabella dell’assalto, modificatore 4: un tedesco attivato da un americano che entra nel suo
		# esagono o in uno adiacente non usa la propria abilità con le armi in quel turno.
		if s.fase == "round" and not s.turno.is_empty() and str(ctx.get("hex", "")) != "" and E.distanza(str(ctx.hex), h) <= 1:
			g.senza_ws_per = str(s.turno.id)
		nuovi.append(g)
		if not (str(num) in s.attivati):
			s.attivati.append(str(num))
			var dati: Dictionary = missione.tedeschi[str(num)]
			if int(dati.pv) != 0:
				_pv(int(dati.pv), "attivazione del tedesco %d" % num)
		_log("attivazione", "Attivato il %s in %s, %s." % [nome(g), h, T.NOMI_POSTURA[g.postura]])
		_fx("compare", {"id": g.id, "a": h})
		# Americani attivi nello stesso esagono? Nessun effetto immediato; il Round lo deciderà.
	if nuovi.is_empty():
		return
	var aware_id: String = ctx.get("ultimo_pc", "") if o.get("aware", false) else ""
	if str(ctx.get("forza_consapevole", "")) != "":
		aware_id = str(ctx.forza_consapevole)
	if str(ctx.get("forza_inconsapevole", "")) != "":
		o._inconsapevole = str(ctx.forza_inconsapevole)
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
		"WS": d.WS, "MPA": d.MPA, "DS": int(d.get("DS", 0)), "comandante": d.get("comandante", false), "hex": h, "postura": postura,
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
		"due_turni_us": bool(o.us_two), "consapevole_auto": aware_id, "inconsapevole_auto": str(o.get("_inconsapevole", "")),
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
	_inizia_registrazione()
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
	var pc := _passo("consapevolezza", {"n": r.n, "righe": []})
	_log("round", "ROUND %d" % r.n)
	# 1. Consapevolezza (solo Round 1 e 2).
	if r.n <= 2:
		_fase_consapevolezza(r, pc.righe)
	else:
		for a in americani():
			if attivo(a) or a.stato == "fuori":
				a.consapevole = true
		_log("info", "Dal Round 3 tutti i soldati sono consapevoli.")
	# 2. Evento (non nel Round 1).
	if r.n >= 2:
		var pe := _passo("evento", {"n": r.n})
		_log("info", "Fase Evento.")
		evento_casuale({"hex": "", "ids": []}, pe)
		if s.fase != "round":
			return
	# 3. Iniziativa.
	_iniziativa(r)
	_flusso()

func _fase_consapevolezza(r: Dictionary, righe: Array = []) -> void:
	var auto_id: String = r.get("consapevole_auto", "")
	for a in americani():
		if not (attivo(a) or a.stato == "fuori"):
			continue
		if a.consapevole:
			righe.append({"id": a.id, "esito": "gia"})
			continue
		if a.stato == "fuori" and r.n == 1:
			righe.append({"id": a.id, "esito": "fuori"})
			continue  # 6/10: fuori mappa durante il Round 1
		if a.id == auto_id and r.n == 1:
			a.consapevole = true
			_log("info", "%s è automaticamente consapevole." % nome(a))
			righe.append({"id": a.id, "esito": "auto"})
			continue
		if a.id == str(r.get("inconsapevole_auto", "")) and r.n == 1:
			_log("info", "%s è automaticamente inconsapevole in questo Round." % nome(a))
			righe.append({"id": a.id, "esito": "no"})
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
				righe.append({"id": a.id, "esito": "non_vede"})
				continue
		a.consapevole = controllo_pc(a, 0, "consapevolezza")
		righe.append({"id": a.id, "esito": "si" if a.consapevole else "no", "dado": ultimo_dado, "pc": int(a.PC)})

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

## Vero se, spostando quei soldati nell’esagono h, resterebbero tutti in comando.
## Serve all’interfaccia per avvisare prima del movimento; lo stato non cambia.
func in_comando_se(ids: Array, h: String) -> bool:
	var prima := {}
	for id in ids:
		var a := u(str(id))
		if a.is_empty():
			continue
		prima[id] = [a.hex, a.stato]
		a.hex = h
		if a.stato == "fuori":
			a.stato = "attivo"
	var tutti := true
	for id in prima:
		if not in_comando(u(str(id))):
			tutti = false
	for id in prima:
		var a := u(str(id))
		a.hex = prima[id][0]
		a.stato = prima[id][1]
	return tutti

func _iniziativa(r: Dictionary) -> void:
	var du := d10()
	var dt := d10()
	var vant: String = "us" if du > dt else "de"
	if r.n == 1 and r.get("vantaggio_forzato", "") != "":
		vant = r.vantaggio_forzato
	var forzato: bool = r.n == 1 and r.get("vantaggio_forzato", "") != ""
	r.vantaggio = vant
	r.dado_us = du
	r.dado_de = dt
	var pi := _passo("iniziativa", {"n": r.n, "du": du, "dt": dt, "vant": vant, "forzato": forzato, "righe": []})
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
		var comando := in_comando(a)
		var es := T.esito_turni(int(a.IN), du, true, comando, a.ferito)
		if r.n == 1 and r.get("due_turni_us", false) and not es.panico:
			es.turni = 1 if a.ferito else 2
		pi.righe.append({"id": a.id, "turni": es.turni, "panico": es.panico, "rosso": es.rosso, "comando": comando, "ferito": a.ferito})
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
			es = {"turni": 1 if g.ferito else 2, "panico": false, "paragrafo": true}
		pi.righe.append({"id": g.id, "turni": es.turni, "panico": es.panico, "ferito": g.ferito, "paragrafo": es.get("paragrafo", false)})
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
## Vero se il soldato ha un’azione cominciata e non ancora conclusa (movimento, secondo tiro rapido…).
func _azione_in_corso(a: Dictionary) -> bool:
	return s.fase == "round" and s.pausa == "" and not s.turno.is_empty() and str(s.turno.id) == str(a.id) \
		and attivo(a) and a.slot == "turni" and int(a.turni) > 0

func americani_di_turno() -> Array:
	if s.fase != "round" or s.pausa != "":
		return []
	# Un’azione cominciata va conclusa anche se nel frattempo un tedesco appena attivato
	# è finito in una casella della pista che viene prima (regola 6/6).
	if not s.turno.is_empty():
		var in_corso := u(str(s.turno.id))
		if not in_corso.is_empty() and _azione_in_corso(in_corso):
			return [in_corso]
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
		var tirato := false
		if s.round.slot_azione != chiave:
			s.round.slot_azione = chiave
			s.round.numero_azione = d10()
			s.round.giri_casella = 0
			tirato = true
		# Sicurezza: la stessa casella tedesca non può ripetersi all’infinito (turni ceduti avanti e indietro).
		s.round.giri_casella = int(s.round.get("giri_casella", 0)) + 1
		if int(s.round.giri_casella) > 4:
			_log("info", "I tedeschi di questa casella hanno esaurito i turni.")
			for g in tedeschi():
				if int(g.turni) == c[0] and g.slot == "turni":
					_consuma_turno(g)
			continue
		var agiti := false
		for g in tedeschi():
			if s.fase != "round":
				return
			if int(g.turni) == c[0] and g.slot == "turni" and in_mappa(g):
				ia.turno(g, tirato, chiave)
				tirato = false
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
	_passo("fine_round", {"n": int(s.round.n)})
	_log("round", "Fine del Round %d." % int(s.round.n))
	_controlla_da_leggere()
	for x in s.unita.values():
		if x.panico and attivo(x):
			x.panico = false
			if x.hex != "" and x.postura != "prone":
				if terreno.tipo(x.hex) == "stream" and not (terreno.ponte(x.hex) and x.get("sul_ponte", false)):
					pass  # nel ruscello chi è in panico non si sdraia
				else:
					imposta_postura(x, "prone")
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
	_passo("operazioni")
	s.fase = "operazioni"
	s.round = {}
	s.turno = {}
	for a in americani():
		a.consapevole = false
		a.turni = 0
		a.slot = ""
		a.panico = false
	_log("round", "Nessun tedesco attivo sulla mappa: riprendono le Operazioni.")
	if s.get("jeep_in_arrivo", false):
		_arriva_jeep()
	_controlla_fine_automatica()

# =================================================================== azioni americane
func _errore(m: String) -> Dictionary:
	return {"ok": false, "errore": m}

const OK := {"ok": true}

func _inizio_comando() -> void:
	_inizia_registrazione()

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
		if _azione_in_corso(a):
			return ""  # regola 6/6: chi ha attivato un tedesco con la propria azione la porta a termine
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
	for g in tedeschi():
		if str(g.get("senza_ws_per", "")) == str(a.id):
			g.erase("senza_ws_per")
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
	_log("azione", "%s ora è %s." % [nome(a), T.NOMI_POSTURA[postura]])
	imposta_postura(a, postura)
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
		return esagoni_ingresso()
	for v in E.vicini(a.hex):
		if _verifica_passo(a, v, true) == "":
			out.append(v)
	return out

func _costo_passo(a: Dictionary, da_hex: String, verso: String) -> int:
	if veicoli.e_autista(a):
		return veicoli.costo(veicoli.di(a), da_hex, verso)
	if da_hex == "":
		return terreno.costo_movimento(verso, verso) if false else _costo_ingresso(verso)
	return terreno.costo_movimento(da_hex, verso)

func _costo_ingresso(h: String) -> int:
	match terreno.tipo(h):
		"rough", "brush", "woods", "rubble", "stream", "ford":
			return 2
	return 1

func _verifica_passo(a: Dictionary, verso: String, silenzioso := false) -> String:
	var veic: Dictionary = veicoli.di(a)
	if veicoli.attivo(veic):
		if not veicoli.e_autista(a):
			return "Per muoversi a piedi bisogna prima scendere dal veicolo."
		if not E.adiacenti(a.hex, verso):
			return "Si può entrare solo in un esagono adiacente."
		var cv: int = veicoli.costo(veic, a.hex, verso)
		if cv < 0:
			return "Il veicolo non può entrare in quell’esagono."
		if s.fase == "round":
			var tv: Dictionary = s.turno if (not s.turno.is_empty() and s.turno.id == a.id) else {}
			if tv.is_empty() or tv.azione != "muovi":
				return "" if silenzioso else "Scegli prima «Guida»."
			if cv > int(tv.mp):
				return "Punti movimento del veicolo insufficienti (servono %d, restano %d)." % [cv, int(tv.mp)]
		return ""
	if a.postura == "prone":
		return "Un soldato prono non può muoversi."
	var da_hex: String = a.hex
	if da_hex != "" and not E.adiacenti(da_hex, verso):
		return "Si può entrare solo in un esagono adiacente."
	if da_hex == "" and not e_ingresso(verso):
		return "Si entra %s." % testo_ingresso()
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
	var veic_m: Dictionary = veicoli.di(primo)
	if veicoli.attivo(veic_m) and veicoli.e_autista(primo):
		ids = veicoli.occupanti(veic_m).map(func(x): return x.id)
	elif s.fase == "round" and ids.size() > 1:
		return _errore("Nei Round ogni soldato si muove con la propria azione.")
	var e2 := _verifica_passo(primo, verso)
	if e2 != "":
		return _errore(e2)
	var da_hex: String = primo.hex
	var costo := _costo_passo(primo, da_hex, verso)
	var controllo_veicolo := false
	if s.fase == "round":
		var t := _turno_di(primo)
		if veicoli.attivo(veic_m):
			t.mp = int(t.mp) - costo
			t.spesi = int(t.get("spesi", 0)) + costo
			if int(t.spesi) > int(t.get("mp_lenta", 99)) and not t.get("incidente_fatto", false):
				t.incidente_fatto = true
				controllo_veicolo = true
		elif primo.postura == "crouching":
			t.mp = 0
		else:
			t.mp = int(t.mp) - costo
		t.mosso = true
	var sul_ponte := terreno.ponte(verso) and da_hex in terreno.capi_ponte(verso)
	var nomi: Array = []
	var mossi: Array = []
	for id in ids:
		var a := u(str(id))
		if a.stato == "fuori":
			a.stato = "attivo"
		a.hex = verso
		a.sul_ponte = sul_ponte
		nomi.append(a.lettera)
		mossi.append(a.id)
		for pid in a.prigionieri:
			var p := u(pid)
			if not p.is_empty() and p.stato == "catturato":
				p.hex = verso
	if veicoli.attivo(veic_m):
		var dv := E.direzione(da_hex, verso)
		if dv >= 0:
			veic_m.fronte = dv
		veic_m.hex = verso
		_log("azione", "La %s, guidata da %s, entra in %s (%s)." % [veic_m.nome, nome(primo), verso, terreno.nome_tipo(verso)])
	else:
		_log("azione", "%s %s in %s (%s)." % [", ".join(nomi), "entra" if nomi.size() == 1 else "entrano", verso, terreno.nome_tipo(verso)])
	_fx("muovi", {"ids": mossi, "da": da_hex, "a": verso})
	if controllo_veicolo:
		veicoli.controllo_incidente(veic_m, "guida veloce")
		if not veicoli.attivo(veic_m) or veic_m.get("fermo", false):
			veic_m.fermo = false
			if not s.turno.is_empty():
				s.turno.mp = 0
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
		var guida: bool = veicoli.e_autista(a)
		if not attivo(a) or (t.azione == "muovi" and ((a.postura == "crouching" and not guida) or int(t.mp) <= 0) and (not t.cambio_libero or guida)):
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
				_fx("esplosione", {"a": h})
				_danno_esplosione(a, T.GRANATA_DENTRO)
	if s.fase == "fine":
		return
	var vivi: Array = ids.filter(func(i): return attivo(u(str(i))))
	if vivi.is_empty():
		return
	_edificio_raggiunto(h)
	_controlla_da_leggere()
	if _niente_controlli_round():
		_log("info", "Nei Round di questa missione non si fanno controlli di paragrafo entrando negli esagoni.")
	else:
		controllo_paragrafo(h, vivi, {"sul_ponte": sul_ponte})
	if numero == 1 and h == "R15" and s.punti.get("R15", "") == "typhoon" and s.pilota == "":
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
			if veicoli.e_autista(a):
				var veic: Dictionary = veicoli.di(a)
				if veic.get("fermo", false):
					return _errore("Il veicolo è fermo per un incidente in questo turno.")
				var m: Dictionary = veicoli.MODELLI[veic.modello]
				t.azione = "muovi"
				t.mp = int(m.veloce) if veic.gomme else int(m.lenta)
				t.mp_lenta = int(m.lenta)
				t.spesi = 0
				_log("azione", "%s guida la %s (lenta %d PM, veloce %d PM: oltre la lenta si rischia l’incidente)." % [nome(a), veic.nome, int(m.lenta), int(t.mp)])
				_fine_comando()
				return OK
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

## Sale sul veicolo nello stesso esagono (nei Round costa un punto movimento di un’azione di movimento).
func sali_veicolo(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a)
	if e != "":
		return _errore(e)
	var lista: Array = veicoli.in_esagono(a.hex).filter(func(v): return veicoli.attivo(v) and v.lato == "us")
	if lista.is_empty():
		return _errore("Nessun veicolo in questo esagono.")
	if s.fase == "round":
		var t := _turno_di(a)
		if t.azione != "muovi" or int(t.mp) < 1:
			return _errore("Nei Round si sale spendendo 1 punto movimento: scegli prima «Muovi».")
		t.mp = int(t.mp) - 1
	var err: String = veicoli.sali(a, lista[0])
	if err != "":
		return _errore(err)
	_log("azione", "%s sale sulla %s%s." % [nome(a), lista[0].nome, " e la guida" if veicoli.e_autista(a) else ""])
	_fine_comando()
	return OK

func scendi_veicolo(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a)
	if e != "":
		return _errore(e)
	var veic: Dictionary = veicoli.di(a)
	if veic.is_empty():
		return _errore("Il soldato non è su un veicolo.")
	if s.fase == "round":
		var t := _turno_di(a)
		if veicoli.e_autista(a) and t.azione == "muovi":
			pass
		elif t.azione != "muovi" or int(t.mp) < 1:
			return _errore("Nei Round si scende spendendo 1 punto movimento: scegli prima «Muovi».")
		t.mp = maxi(0, int(t.mp) - 1)
	veicoli.scendi(a)
	a.postura = "crouching"
	_log("azione", "%s scende dalla %s." % [nome(a), veic.nome])
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
	if mirato and tiratore.get("lato", "") == "us" and bool(T.ARMI[tipo].get("squadra", false)):
		var compagni := unita_in(tiratore.hex, "us").filter(func(x): return x.id != tiratore.id and not x.panico)
		if compagni.is_empty():
			return {"ok": false, "motivo": "da solo la mitragliatrice spara solo di rapido"}
	var mods: Array = []
	var ws := int(tiratore.WS) - (1 if arma.get("catturata", false) else 0)
	if ws != 0:
		mods.append(["abilità", ws])
	if not mirato:
		mods.append(["tiro rapido", -2])
	if tiratore.ferito:
		mods.append(["tiratore ferito", -1])
	if veicoli.attivo(veicoli.di(tiratore)):
		mods.append(["tiratore in auto", -2])
	if mirato and T.ARMI[tipo].get("auto", false):
		var extra := unita_in(bersaglio.hex, bersaglio.lato).size() - 1
		if extra > 0:
			mods.append(["bersagli multipli", extra])
	var ip := T.indice_postura(bersaglio.postura)
	var th := terreno.tipo(bersaglio.hex)
	var veic_b: Dictionary = veicoli.di(bersaglio)
	if veicoli.attivo(veic_b):
		mods.append(["%s, veicolo piccolo" % terreno.nome_tipo(bersaglio.hex), veicoli.modificatore(veic_b)])
	elif terreno.edificio(bersaglio.hex) and not (terreno.edificio(tiratore.hex) and dist <= 1 and terreno.tipo_lato(tiratore.hex, bersaglio.hex) == ""):
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
	if bersaglio.get("lato", "") == "de":
		bersaglio.bersagliato = true
		if not bersaglio.has("bersagliato_da"):
			bersaglio.bersagliato_da = []
		if not (tiratore.get("id", "") in bersaglio.bersagliato_da):
			bersaglio.bersagliato_da.append(tiratore.get("id", ""))
	var modo := "mirato" if mirato else "rapido"
	_log("combattimento", "%s spara (%s, %s) a %s in %s." % [nome(tiratore), modo, info.nome.to_lower(), nome(bersaglio), bersaglio.hex])
	var fx := _fx("tiro", {"da": tiratore.get("hex", ""), "a": bersaglio.hex, "tiratore": tiratore.get("id", ""), "bersaglio": bersaglio.id,
		"auto": bool(info.get("auto", false)), "mirato": mirato, "arma": tipo, "esito": "mancato",
		"prob": int(p.prob), "base": int(p.get("base", -1)), "mods": p.get("mods", []), "gittata": str(p.get("gittata", ""))})
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
		fx.esito = "inceppata"
		return {"ok": true, "colpito": false}
	# 2–5. Tiro per colpire.
	var r := d10()
	var colpito: bool = r == 0 or (r != 9 and r <= int(p.prob))
	fx.esito = "colpito" if colpito else "mancato"
	fx.dado = r
	_log("dado", "Per colpire: serve 0–%d, esce %d → %s." % [int(p.prob), r, "COLPITO" if colpito else "mancato"])
	if colpito and veicoli.attivo(veicoli.di(bersaglio)):
		veicoli.colpito(veicoli.di(bersaglio), tipo, tiratore, mirato, fx)
	elif colpito:
		var rd := d10()
		var lettera := T.lettera_danno(info.danni, rd)
		fx.dado_danno = rd
		fx.danno = _nome_danno(lettera)
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
			if pm <= int(info.mun) and arma.get("montata", false):
				var vm: Dictionary = veicoli.di(tiratore)
				vm.mg_munizioni = maxi(0, int(vm.get("mg_munizioni", 10)) - 1)
				_log("dado", "Percentuale %02d: consumata una cassetta della mitragliatrice (ne restano %d)." % [pm, int(vm.mg_munizioni)])
			elif pm <= int(info.mun):
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
				_fx("danno", {"id": x.id, "tipo": "panico"})
				if not s.turno.is_empty() and s.turno.id == x.id:
					s.turno = {}
			else:
				_log("danno", "%s si spaventa, ma senza conseguenze." % nome(x))
				_fx("danno", {"id": x.id, "tipo": "spavento"})
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

## Cambio di postura registrato per la riproduzione.
func imposta_postura(x: Dictionary, postura: String) -> void:
	if x.postura == postura:
		return
	x.postura = postura
	_fx("postura", {"id": x.id})

func _ferisci(x: Dictionary) -> void:
	x.ferito = true
	_log("danno", "%s è FERITO." % nome(x))
	_cade_prono(x)
	_fx("danno", {"id": x.id, "tipo": "ferito"})
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
	_fx("danno", {"id": x.id, "tipo": "incapacitato"})
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
	_fx("danno", {"id": x.id, "tipo": "ucciso"})
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
	var fx := _fx("lancio", {"da": lanciatore.hex, "bersaglio": h, "a": arrivo, "tipo": tipo, "esito": "esplode", "id": lanciatore.id,
		"prob": int(p.prob), "dado": r})
	var pd := percentuale()
	if pd <= 5:
		_log("dado", "Percentuale %02d: ordigno inesploso." % pd)
		fx.esito = "inesploso"
		return
	var presenti: Array = unita_in(arrivo, "", false).filter(func(x): return x.stato in ["attivo", "incapacitato", "catturato"])
	for x in presenti:
		if x.lato == "de":
			x.granata_subita = true
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
				fx.esito = "rilanciato"
				return
			elif not x.ferito and x.postura != "prone":
				imposta_postura(x, "prone")
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
	if dif.lato == "de" and str(dif.get("senza_ws_per", "")) == str(att.id):
		difesa_valida = false
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
	var fx := _fx("assalto", {"id": att.id, "bersaglio": dif.id, "a": dif.hex, "esito": "fallito"})
	_rendi_consapevoli(dif.hex)
	var r := d10()
	var colpito: bool = r == 0 or (r != 9 and r <= int(p.prob))
	fx.prob = int(p.prob)
	fx.dado = r
	_log("dado", "Assalto: serve 0–%d, esce %d → %s." % [int(p.prob), r, "riuscito" if colpito else "fallito"])
	if colpito:
		fx.esito = "riuscito"
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
	_fx("danno", {"id": g.id, "tipo": "catturato"})
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
		if not e_uscita(a.hex):
			return _errore("Si esce solo da %s." % str(missione.get("uscita_breve", "margine nord, tra A1 e J1")))
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
		var da_u: String = a.hex
		a.stato = "uscito"
		a.hex = ""
		f.hex = ""
		_fx("sparisce", {"ids": [a.id, f.id], "da": da_u, "motivo": "uscito"})
		f.uscito = true
		_log("azione", "%s esce dalla mappa trascinando %s." % [nome(a), nome(f)])
		_chiudi_azione_semplice(a)
		_fine_comando()
		return OK
	var da_t: String = a.hex
	a.hex = verso
	f.hex = verso
	_log("azione", "%s trascina %s in %s." % [nome(a), nome(f), verso])
	_fx("muovi", {"ids": [a.id, f.id], "da": da_t, "a": verso})
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
	if not e_uscita(a.hex):
		return _errore("Si esce solo da %s." % str(missione.get("uscita_breve", "margine nord, tra A1 e J1")))
	if a.postura == "prone":
		return _errore("Un soldato prono non si muove.")
	for pid in a.prigionieri:
		var p := u(pid)
		if not p.is_empty() and p.stato == "catturato":
			p.hex = ""
			p.stato = "rimosso"
	var da_e: String = a.hex
	a.stato = "uscito"
	a.hex = ""
	_log("azione", "%s esce dalla mappa." % nome(a))
	_fx("sparisce", {"ids": [a.id], "da": da_e, "motivo": "uscito"})
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

## Paragrafo 304: rinforzi, una jeep con mitragliatrice media e l’autista (soldato americano 2).
func _op_rinforzo_jeep(o: Dictionary) -> void:
	if s.get("jeep_arrivata", false) or s.get("jeep_in_arrivo", false):
		_log("info", "La jeep dei rinforzi è già arrivata: l’evento non si ripete.")
		return
	s.jeep_ingressi = o.get("hexes", ["A5", "A17"])
	if fase_round():
		s.jeep_in_arrivo = true
		_log("info", "La jeep arriverà quando riprendono le Operazioni.")
	else:
		_arriva_jeep()

func _arriva_jeep() -> void:
	s.jeep_in_arrivo = false
	s.jeep_arrivata = true
	# Ingresso scelto: quello più vicino alla squadra.
	var ingressi: Array = s.get("jeep_ingressi", ["A5", "A17"])
	var h: String = ingressi[0]
	var migliore := 999
	for i in ingressi:
		var dmin := 999
		for a in americani_attivi_in_mappa():
			dmin = mini(dmin, E.distanza(a.hex, str(i)))
		if dmin < migliore:
			migliore = dmin
			h = str(i)
	var d := {"id": "J", "nome": "Autista della jeep", "IN": 2, "PC": 3, "WS": -2, "DS": 6, "MPA": 4, "comandante": false,
		"porte": ["pistol"], "munizioni": {"pistol": 1}}
	var autista := _nuovo_americano(d)
	autista.stato = "attivo"
	autista.hex = h
	autista.postura = "crouching"
	s.unita["J"] = autista
	var jeep: Dictionary = veicoli.crea("vjeep", "jeep", h, "us")
	jeep.mg = {"tipo": "mmg", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "montata": true}
	veicoli.sali(autista, jeep)
	_log("info", "Rinforzi! Una jeep con una mitragliatrice media entra in %s con l’autista (J)." % h)
	_fx("compare", {"id": "J", "a": h, "amico": true})

## Paragrafo 008: mitragliamento del Me-109.
func _op_mitragliamento() -> void:
	var r := d10()
	var rotte := [["C"], ["F"], ["I"], ["L"], ["Q"], ["U"], ["A9", "V19"], ["A4", "Y16"], ["C1", "Y12"], ["A15", "Y3"]]
	var rotta: Array = rotte[r]
	var esagoni: Array = []
	if rotta.size() == 1:
		for riga in range(1, 20):
			esagoni.append("%s%d" % [rotta[0], riga])
		_log("dado", "Rotta del Me-109: %d → colonna %s." % [r, rotta[0]])
	else:
		esagoni = E.linea(str(rotta[0]), str(rotta[1]))
		_log("dado", "Rotta del Me-109: %d → in diagonale da %s a %s." % [r, rotta[0], rotta[1]])
	_fx("aereo", {"esagoni": esagoni})
	# Tiri contro l’aereo: chi vede un esagono della rotta e supera il controllo di percezione.
	var abbattuto := false
	for a in americani_attivi_in_mappa():
		if abbattuto or a.postura == "prone":
			continue
		var vicino := ""
		for h in esagoni:
			if terreno.vede(a.hex, h, a.postura, "standing") and (vicino == "" or E.distanza(a.hex, h) < E.distanza(a.hex, vicino)):
				vicino = h
		if vicino == "" or not controllo_pc(a, 0, "tiro contro l’aereo"):
			continue
		var arma: Dictionary = {}
		for w in a.armi:
			if not w.rotta and not w.inceppata and T.ARMI[w.tipo].has("gittate") and munizioni_arma(a, w.tipo) > 0:
				arma = w
				break
		if arma.is_empty():
			continue
		var dist := E.distanza(a.hex, vicino) + 10
		var base := T.base_per_distanza(arma.tipo, dist)
		if base < 0:
			_log("info", "%s non ha la gittata per raggiungere l’aereo." % nome(a))
			continue
		var prob := clampi(base - 2 + 2 + int(a.WS), 0, 8)
		var dado := d10()
		var colpito: bool = dado == 0 or (dado != 9 and dado <= prob)
		_log("dado", "%s spara di rapido all’aereo (%s, %d esagoni con la quota): serve 0–%d, esce %d → %s." % [nome(a), T.ARMI[arma.tipo].breve, dist, prob, dado, "COLPITO" if colpito else "mancato"])
		if colpito:
			var rd := d10()
			var pen := T.penetrazione(arma.tipo, rd)
			_log("dado", "Danno all’aereo: %d → %s." % [rd, "penetrazione: l’aereo precipita in fiamme fuori mappa" if pen != "-" else "nessuna penetrazione"])
			if pen != "-":
				abbattuto = true
	if abbattuto:
		_log("info", "Il Me-109 è abbattuto prima di mitragliare la squadra.")
		if numero == 2:
			cambia_condizione(6)
		return
	for a in americani_attivi_in_mappa():
		var t := terreno.tipo(a.hex)
		if not (t in ["clear", "road", "brush", "stream"]) or veicoli.attivo(veicoli.di(a)) and false:
			continue
		var vicino_rotta := false
		for h in esagoni:
			if E.distanza(a.hex, h) <= 1:
				vicino_rotta = true
				break
		if vicino_rotta:
			var rd := d10()
			var l := T.lettera_danno(T.ARMI.hmg.danni, rd)
			_log("dado", "Mitragliamento su %s: %d → %s" % [nome(a), rd, _nome_danno(l)])
			_fx("esplosione", {"a": a.hex})
			_applica_danno(a, l, {})

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
	_fx("compare", {"id": "J", "a": "R15", "amico": true})

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
	_fx("compare", {"id": "K", "a": "G10", "amico": true})
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
			_fx("esplosione", {"a": h})
			_danno_esplosione(a, T.GRANATA_DENTRO)
			ctx.mina_esplosa = true

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
	_fx("esplosione", {"a": h, "grande": true})
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
		_fx("esplosione", {"a": a.hex})
		for x in unita_in(a.hex, "", false):
			if x.stato in ["attivo", "incapacitato"]:
				_danno_esplosione(x, T.GRANATA_DENTRO)

func _op_munizioni_finite(mg_da := 0) -> void:
	var lista: Array = s.round.get("sparato_prec", []) if not s.round.is_empty() else []
	if mg_da > 0 and int(s.condizione) < mg_da:
		lista = lista.filter(func(x): return not (str(x[1]) in ["lmg", "mmg", "hmg"]))
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

## Paragrafi annotati da leggere quando in un esagono restano attivi solo i soldati americani.
func _controlla_da_leggere() -> void:
	var dl: Dictionary = s.get("da_leggere", {})
	for h in dl.keys():
		if unita_in(h, "de").is_empty() and not unita_in(h, "us").is_empty():
			var pid := str(dl[h])
			dl.erase(h)
			_log("info", "In %s ci sono solo i tuoi soldati: si legge il paragrafo annotato %s." % [h, pid])
			leggi(pid, {"hex": h, "ids": unita_in(h, "us").map(func(x): return x.id)})

func _niente_controlli_round() -> bool:
	return s.fase == "round" and bool(missione.get("regole", {}).get("niente_controlli_round", false))

## Missione 2: 1 PV per ogni esagono di edificio in cui entra un soldato.
func _edificio_raggiunto(h: String) -> void:
	if not bool(missione.get("regole", {}).get("pv_edifici", false)) or not terreno.edificio(h):
		return
	if not s.has("edifici_entrati"):
		s.edifici_entrati = []
	if h in s.edifici_entrati:
		return
	s.edifici_entrati.append(h)
	_pv(1, "edificio %s raggiunto" % h)

func esagoni_edificio() -> Array:
	var out: Array = []
	for h in E.tutti():
		if terreno.edificio(h):
			out.append(h)
	return out

## Esagono in cui un incapacitato non costa PV se la missione finisce con l’obiettivo raggiunto.
func _salvo_a_fine(h: String) -> bool:
	if numero == 1:
		return terreno.edificio(h)
	return h in missione.get("obiettivi", [])

## Righe del pannello obiettivi: [fatto, etichetta, spiegazione].
func righe_obiettivi() -> Array:
	var v := condizioni_vittoria()
	var pv := pv_totali()
	match numero:
		2:
			return [
				[v.edifici >= v.edifici_tot, "Edifici %d/%d" % [v.edifici, v.edifici_tot], "1 PV per ogni esagono di edificio in cui entra un tuo soldato"],
				[v.stazione, "Tutti in stazione", "Tutti i soldati attivi nella stazione (O6, P5, Q5)"],
				[pv >= int(missione.vittoria_pv), "%d PV (ora %d)" % [int(missione.vittoria_pv), pv], "Punti vittoria necessari"],
			]
	var alt: Array = alture_obiettivo()
	return [
		[v.t8, "Edificio T8", "Un soldato attivo nell’edificio T8"],
		[v.kl, "Edifici K13–L13", "Un soldato negli edifici K13–L13"],
		[v.altura != "", "Altura %s" % ", ".join(alt), "Un soldato attivo sull’altura con vista sulla strada"],
		[v.nessun_tedesco, "Nessun tedesco attivo", "Nessun tedesco attivo sulla mappa"],
		[pv + (4 if v.ok else 0) >= 13, "13 PV (ora %d)" % pv, "Servono 13 punti vittoria; il primo finale ne dà 4 in più"],
	]

## Esagoni da evidenziare come obiettivi sulla mappa.
func obiettivi_mappa() -> Array:
	if numero == 1:
		return ["T8", "K13", "L13"] + alture_obiettivo()
	return missione.get("obiettivi", [])

func condizioni_vittoria() -> Dictionary:
	if numero == 2:
		var entrati: Array = s.get("edifici_entrati", [])
		var tutti := esagoni_edificio()
		var in_stazione := true
		var attivi := americani_attivi_in_mappa()
		for a in attivi:
			if not (a.hex in missione.obiettivi):
				in_stazione = false
		var completo := entrati.size() >= tutti.size()
		return {"edifici": entrati.size(), "edifici_tot": tutti.size(), "stazione": in_stazione and not attivi.is_empty(),
			"ok": completo and in_stazione and not attivi.is_empty() and s.fase == "operazioni"}
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
	if modo == "obiettivo" and numero == 1:
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
			var salvo: bool = a.get("uscito", false) or (modo == "obiettivo" and _salvo_a_fine(a.hex))
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
