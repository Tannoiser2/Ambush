class_name Partita
extends RefCounted
## Motore delle missioni: Operazioni, Round, paragrafi, combattimento e punteggio.
## Tutto lo stato è in `s` (dizionario serializzabile in JSON).

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")
const TerrenoScript = preload("res://scripts/motore/terreno.gd")
const TedeschiScript = preload("res://scripts/motore/tedeschi.gd")
const VeicoliScript = preload("res://scripts/motore/veicoli.gd")
const MissioniMOScript = preload("res://scripts/motore/missioni_mo.gd")
const MissioniPHScript = preload("res://scripts/motore/missioni_ph.gd")
const MissioniSSScript = preload("res://scripts/motore/missioni_ss.gd")

signal aggiornata

var s: Dictionary = {}
var missione: Dictionary
var paragrafi: Dictionary
var terreno: Terreno
var ia: RefCounted
var veicoli: RefCounted
## Regole delle missioni di Move Out! (9–12).
var mo: RefCounted
var ph: RefCounted
var ss: RefCounted
var _paragrafi_base: Dictionary
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
	_paragrafi_base = JSON.parse_string(FileAccess.get_file_as_string("res://data/paragrafi.json"))
	paragrafi = _paragrafi_base
	mo = MissioniMOScript.new(self)
	ph = MissioniPHScript.new(self)
	ss = MissioniSSScript.new(self)
	ia = TedeschiScript.new(self)
	veicoli = VeicoliScript.new(self)
	imposta_missione(n)

## Missioni con i dati pronti (le altre compaiono nel menu come «in preparazione»).
static func disponibili() -> Array:
	var out: Array = []
	for n in range(1, 25):
		if FileAccess.file_exists("res://data/missione%d.json" % n):
			out.append(n)
	return out

## Carica i dati della missione n (carte, tedeschi, mappa) se non sono già quelli in uso.
func imposta_missione(n: int) -> void:
	if n == numero and not missione.is_empty():
		return
	numero = n
	missione = JSON.parse_string(FileAccess.get_file_as_string("res://data/missione%d.json" % n))
	if str(missione.get("libro", "")) == "ph":
		# Purple Heart ha un libretto suo (300–999): i suoi paragrafi prendono il posto di quelli base con lo stesso numero.
		paragrafi = _paragrafi_base.duplicate()
		paragrafi.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/paragrafi_ph.json")), true)
	elif str(missione.get("libro", "")) == "mo":
		# Move Out! ha un libretto suo (400–1000): i suoi paragrafi prendono il posto di quelli base con lo stesso numero.
		paragrafi = _paragrafi_base.duplicate()
		paragrafi.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/paragrafi_mo.json")), true)
	elif str(missione.get("libro", "")) == "ss":
		# Silver Star: libretto proprio; i paragrafi d’azione tedeschi 800–869 restano quelli del gioco base.
		paragrafi = _paragrafi_base.duplicate()
		paragrafi.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/paragrafi_ss%d.json" % int(missione.id))), true)
	else:
		paragrafi = _paragrafi_base
	terreno = TerrenoScript.new("res://data/mappa_%s.json" % str(missione.get("mappa", "A")).to_lower())
	_alture_cache = []
	_applica_regole_terreno()

## Lettera della mappa in uso: quella della missione, o quella su cui la missione è passata (Move Out! 9 e 10).
func lettera_mappa() -> String:
	return str(s.get("mappa", missione.get("mappa", "A")))

## Passa a un’altra mappa a metà missione: nuovo terreno, nessun segnalino della mappa precedente.
func cambia_mappa(l: String) -> void:
	s.mappa = l
	s.modifiche = {}
	s.guadi = []
	s.erase("blocchi")
	terreno = TerrenoScript.new("res://data/mappa_%s.json" % l.to_lower())
	terreno.imposta_modifiche(s.modifiche)
	_alture_cache = []
	_applica_regole_terreno()
	_log("info", "Si passa alla mappa %s." % l)

## Rilegge il terreno della mappa in uso (dopo una correzione nell'editor delle mappe), stato invariato.
func ricarica_terreno() -> void:
	terreno = TerrenoScript.new("res://data/mappa_%s.json" % lettera_mappa().to_lower())
	terreno.imposta_modifiche(s.get("modifiche", {}) if not s.is_empty() else {})
	_alture_cache = []
	_applica_regole_terreno()

func regola(k: String, def = null):
	return missione.get("regole", {}).get(k, def)

## Visibilità e fiume secondo le regole della missione e lo stato (nebbia dei paragrafi).
func _applica_regole_terreno() -> void:
	if terreno == null:
		return
	var vista := int(regola("vista", 0))
	if not s.is_empty() and s.has("vista"):
		vista = int(s.vista)
	terreno.limite_vista = vista
	terreno.fiume = bool(regola("fiume", false))
	terreno.illuminati = {}
	terreno.guadi = {}
	terreno.bunker = s.get("bunker", {}) if not s.is_empty() else {}
	if not s.is_empty():
		for hg in s.get("guadi", []):
			terreno.guadi[str(hg)] = true
	if not s.is_empty():
		for c in s.get("razzi", []):
			for h in E.tutti():
				if E.distanza(h, str(c)) <= 3:
					terreno.illuminati[h] = true
	terreno.accessi = {}
	terreno.muri_sfondati = s.get("muri_sfondati", []) if not s.is_empty() else []
	if ph != null and not s.is_empty():
		ph.regole_terreno()
	if ss != null and not s.is_empty():
		ss.regole_terreno()
	terreno._cache_los.clear()

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
	mo.dopo_nuova()
	ph.dopo_nuova()
	ss.dopo_nuova()
	for hm in missione.get("modifiche_iniziali", {}):
		s.modifiche[hm] = missione.modifiche_iniziali[hm]
	terreno.imposta_modifiche(s.modifiche)
	_applica_regole_terreno()
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
	if ph != null and ph.m18.uscita_vietata(h):
		return false
	if ss != null and not ss.uscita_ammessa(h):
		return false
	if str(regola("uscita_mappa", "")) != "" and lettera_mappa() != str(regola("uscita_mappa", "")):
		return false
	if bool(regola("uscita_bordo", false)):
		return E.colonna(h) == 0 or E.colonna(h) == E.COLONNE - 1 or E.riga(h) == 1 or E.riga(h) == E.RIGHE
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
	if h != "" and bool(regola("sentinella", false)):
		for x in americani():
			if x.hex != "" and not (x.id in ids.map(func(y): return str(y))):
				return {"ok": false, "errore": "Solo la sentinella è sveglia: %s è già in %s." % [nome(x), x.hex]}
		if ids.size() > 1:
			return {"ok": false, "errore": "Solo la sentinella è sveglia: schiera un soldato solo."}
	if h != "" and bool(regola("uno_per_esagono", false)):
		if ids.size() > 1:
			return {"ok": false, "errore": "Nel lancio si mette un solo soldato per esagono."}
		for x in americani():
			if x.hex == h and not (x.id in ids.map(func(y): return str(y))):
				return {"ok": false, "errore": "In %s c’è già %s: un soldato per esagono." % [h, nome(x)]}
	var max_hex := int(regola("max_per_esagono", 0))
	if h != "" and max_hex > 0:
		var gia: int = americani().filter(func(x): return x.hex == h and not (x.id in ids.map(func(y): return str(y)))).size()
		if gia + ids.size() > max_hex:
			return {"ok": false, "errore": "Al massimo %d soldati per esagono." % max_hex}
	var sezioni: Array = regola("sezioni", [])
	if h != "" and not sezioni.is_empty():
		for sez in sezioni:
			if h in sez.esagoni:
				var nella: int = americani().filter(func(x): return x.hex in sez.esagoni and not (x.id in ids.map(func(y): return str(y)))).size()
				if nella + ids.size() > int(sez.n):
					return {"ok": false, "errore": "In %s vanno %d soldati: %s." % [str(sez.nome), int(sez.n), ", ".join(sez.esagoni)]}
	var max_ed := int(regola("max_edifici", 0))
	if h != "" and max_ed > 0:
		var occupati := {}
		for a in americani():
			if a.hex != "" and not (a.id in ids.map(func(x): return str(x))):
				occupati[a.hex] = true
		occupati[h] = true
		if occupati.size() > max_ed:
			return {"ok": false, "errore": "Puoi schierare la squadra al massimo in %d edifici." % max_ed}
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
	if mo.sbarramento():
		mo.inizia_sbarramento()
		return {"ok": true}
	var gruppi := {}
	for a in americani():
		if a.stato == "attivo" and a.hex != "":
			if not gruppi.has(a.hex):
				gruppi[a.hex] = []
			gruppi[a.hex].append(a.id)
	if gruppi.is_empty():
		return {"ok": false, "errore": "Schiera almeno un soldato %s." % testo_ingresso()}
	var e_ph: String = ph.verifica_schieramento()
	if e_ph != "":
		return {"ok": false, "errore": e_ph}
	_inizio_comando()
	s.fase = "operazioni"
	if bool(regola("sentinella", false)):
		for a in americani():
			if a.stato == "fuori":
				a.stato = "dorme"
	var esagoni: Array = gruppi.keys()
	esagoni.sort()
	var parti: Array = []
	for h in esagoni:
		parti.append("%s in %s" % [", ".join(gruppi[h]), h])
	_log("azione", "La squadra entra in mappa: %s." % "; ".join(parti))
	if bool(regola("jeep", false)) and not s.get("veicoli", {}).has("vjeep"):
		_jeep_di_squadra(esagoni)
	ph.dopo_ingresso(esagoni)
	ss.m20.dopo_ingresso(esagoni)
	if int(regola("mine_anticarro", 0)) > 0 and not s.has("mine_at"):
		_piazza_mine_anticarro(esagoni)
	if bool(regola("bazooka_pronti", false)):
		for a in americani():
			var bz := arma_di(a, "bazooka")
			if not bz.is_empty():
				bz.preparata = true
	if int(regola("canoe", 0)) > 0 and not s.get("veicoli", {}).has("canoa1"):
		_imbarca_canoe()
		ss.dopo_imbarco()
	if bool(regola("radio", false)) and s.get("radio_hex", "") == "":
		s.radio_hex = esagoni[0]
		for a in americani():
			if a.get("comandante", false) and a.hex != "":
				s.radio_hex = a.hex
		_log("info", "La radio della squadra è in %s: è presidiata finché lì resta un soldato attivo." % s.radio_hex)
	if bool(regola("eventi_continui", false)):
		for h in esagoni:
			var presenti_e: Array = gruppi[h].filter(func(id): return attivo(u(str(id))))
			if not presenti_e.is_empty():
				_ingresso(h, presenti_e, false)
		if s.fase == "operazioni":
			aspetta_tedeschi(false)
		if fase_round() and s.turno.is_empty() and s.pausa == "":
			_flusso()
		_fine_comando()
		return {"ok": true}
	if bool(regola("lancio", false)):
		_lancio(esagoni)
		if fase_round() and s.turno.is_empty() and s.pausa == "":
			_flusso()
		_fine_comando()
		return {"ok": true}
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
	if s.has("mappa") and str(s.mappa) != str(missione.get("mappa", "A")):
		terreno = TerrenoScript.new("res://data/mappa_%s.json" % str(s.mappa).to_lower())
		_alture_cache = []
	rng.seed = int(s.seme)
	if s.has("rng_stato"):
		rng.state = int(s.rng_stato)
	terreno.imposta_modifiche(s.modifiche)
	_applica_regole_terreno()
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
	# Purple Heart 18: i mezzi fuori mappa non vedono e non si vedono; il Jagdpanther non è mai un bersaglio.
	if osservatore.get("fuori_mappa_ph", false) or bersaglio.get("fuori_mappa_ph", false):
		return false
	# Silver Star: chi è sott’acqua vede ed è visto solo nello stesso esagono o in uno adiacente.
	var vss: int = ss.vista(osservatore, bersaglio)
	if vss >= 0:
		return vss == 1
	if bersaglio.get("in_jagd", false) and osservatore.get("lato", "") == "de":
		return false
	# Purple Heart 17: chi è sotto il ponte si vede come accovacciato sul ponte; dal ponte, nello stesso esagono, lo vede solo chi
	# è in piedi (o chi è sotto con lui).
	if bersaglio.get("sotto_ponte", false) or osservatore.get("sotto_ponte", false):
		if osservatore.hex == bersaglio.hex:
			if bersaglio.get("sotto_ponte", false) and not osservatore.get("sotto_ponte", false) and osservatore.postura != "standing":
				return false
			if osservatore.get("sotto_ponte", false) and not bersaglio.get("sotto_ponte", false) and bersaglio.postura != "standing":
				return false
			return true
		var pb: String = "crouching" if bersaglio.get("sotto_ponte", false) else bersaglio.postura
		var po: String = "crouching" if osservatore.get("sotto_ponte", false) else osservatore.postura
		return terreno.vede(osservatore.hex, bersaglio.hex, po, pb, piano(osservatore), piano(bersaglio))
	if osservatore.get("galleria", false) or bersaglio.get("galleria", false):
		return osservatore.get("galleria", false) and bersaglio.get("galleria", false) and osservatore.hex == bersaglio.hex
	return terreno.vede(osservatore.hex, bersaglio.hex, osservatore.postura, bersaglio.postura, piano(osservatore), piano(bersaglio))

## Piano su cui si trova un soldato: 0 a terra, 1 al piano superiore (campanile di S13, mappa B).
func piano(x: Dictionary) -> int:
	return int(x.get("piano", 0)) if terreno.ha_piani(str(x.get("hex", ""))) else 0

## Vero se due soldati sono davvero nello stesso posto (stesso esagono e stesso piano).
func stesso_posto(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("hex", "")) == str(b.get("hex", "")) and piano(a) == piano(b)

## Sale o scende la scala del campanile: nelle Operazioni è libero, nei Round costa 1 PM a un soldato in piedi.
func cambia_piano(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a)
	if e != "":
		return _errore(e)
	if not terreno.ha_piani(a.hex):
		return _errore("Qui non ci sono scale.")
	if veicoli.attivo(veicoli.di(a)):
		return _errore("Prima bisogna scendere dal veicolo.")
	if fase_round():
		if a.postura != "standing":
			return _errore("Per salire o scendere le scale bisogna essere in piedi.")
		var t := _turno_di(a)
		if t.azione == "":
			t.azione = "muovi"
			_log("azione", "%s: movimento." % nome(a))
		elif not (t.azione in ["muovi", "muovi_spara"]):
			return _errore("Le scale fanno parte del movimento.")
		if int(t.mp) < 1:
			return _errore("Non restano punti movimento.")
		t.mp = int(t.mp) - 1
		t.mosso = true
	else:
		a.postura = "standing" if a.postura == "prone" else a.postura
	a.piano = 0 if piano(a) > 0 else 1
	_log("azione", "%s %s in %s." % [nome(a), "sale al piano superiore" if a.piano == 1 else "scende al pianterreno", a.hex])
	_fx("postura", {"id": a.id, "a": a.hex})
	_fine_comando()
	return OK

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
	if bool(veic.mg.get("solo_passeggero1", false)):
		# Purple Heart 14: la spara solo il passeggero 1 (il secondo a bordo), mai l’autista.
		return veic.mg if veic.occupanti.size() > 1 and str(veic.occupanti[1]) == str(un.id) else {}
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
	if veicoli.di(un).get("modello", "") == "scialuppa" and not veicoli.spiaggiata(veicoli.di(un)):
		# 718: dalla scialuppa solo armi personali (niente bazooka, cariche o mitragliatrici).
		tutte = tutte.filter(func(w): return not (w.tipo in ["bazooka", "satchel", "lmg", "mmg", "hmg", "cannone"]))
	var mg := _mg_montata(un)
	if not mg.is_empty():
		tutte.append(mg)
	for a in tutte:
		if a.tipo in ["satchel", "tanica"] or a.rotta or a.inceppata:
			continue
		if un.lato == "us":
			if a.tipo == "bazooka":
				if not a.preparata:
					continue
			elif a.get("jagd", false) and a.tipo == "cannone":
				if not a.preparata or munizioni_arma(un, a.tipo) <= 0:
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

## Silver Star: i mezzi americani indipendenti seguono i riferimenti neri della carta (se ci sono).
func movimento_veicolo(veic: Dictionary, h: String) -> String:
	if str(veic.get("lato", "")) == "us":
		var c: Dictionary = missione.condizioni[str(int(s.condizione))]
		if c.has("neri"):
			return str(c.neri.get(h, ""))
	return movimento_rosso(h)

func movimento_rosso(h: String) -> String:
	var c: Dictionary = missione.condizioni[str(int(s.condizione))]
	return str(c.movimenti.get(h, ""))

## Risolve un riferimento delle carte (con eventuale prefisso di avvistamento).
func _risolvi_riferimento(rif: String, ctx: Dictionary) -> void:
	if rif == "NONE" or rif == "":
		return
	if ss.m20.riferimento_t(rif, ctx):
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
				if str(o.name) == "kubelwagen" and veicoli.v("vk").is_empty():
					veicoli.crea("vk", "kubelwagen", hl, "de")
					s.punti.erase(hl)
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
		"al_piano":
			# Tedeschi attivati al piano superiore di un edificio con le scale (campanile di S13).
			for num in o.g:
				var gp := u("g%d" % int(num))
				if not gp.is_empty() and terreno.ha_piani(gp.hex):
					gp.piano = int(o.get("piano", 1))
					_log("info", "%s è al piano superiore di %s." % [nome(gp), gp.hex])
		"scala_tedesco":
			ia.scala(ctx, str(o.altrimenti))
		"g_pianterreno":
			var gt := u(str(ctx.get("g", "")))
			if not gt.is_empty() and piano(gt) > 0:
				gt.piano = 0
				_log("tedesco", "Il %s scende al pianterreno." % nome(gt))
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
		"artiglieria_esagoni":
			_op_artiglieria_esagoni(o.esagoni)
		"jeep_tire":
			_op_gomma_jeep()
		"vista":
			s.vista = int(o.n)
			s.nebbia_veicoli = int(o.get("veicoli", 0))
			_applica_regole_terreno()
			_log("info", "Visibilità ora %d esagoni." % int(o.n))
		"pc_sequenza":
			_op_pc_sequenza(o, ctx)
		"pc_entro":
			_op_pc_entro(o, ctx)
		"consapevolezza_libera":
			if fase_round():
				s.round.consapevolezza_libera = true
		"offensiva":
			_op_offensiva()
		"controlla_ponte":
			_op_controlla_ponte(ctx)
		"g_reroll":
			ia.rilancia_azione(ctx)
		"cingolo_55":
			_op_cingolo_55()
		"staffetta":
			_op_staffetta(int(o.carta))
		"staffetta_spia":
			s.staffetta_spia = true
		"staffetta_smascherata":
			_op_staffetta_smascherata()
		"tiro_invisibile":
			_op_tiro_invisibile(ctx)
		"guado":
			if not s.has("guadi"):
				s.guadi = []
			for hg in o.hexes:
				var hh: String = ctx.get("hex", "") if str(hg) == "@hex" else str(hg)
				if hh != "" and not (hh in s.guadi):
					s.guadi.append(hh)
					s.punti[hh] = "guado"
					_log("info", "Guado in %s: da qui si può attraversare il fiume." % hh)
			_applica_regole_terreno()
		"installazione":
			var hi: String = ctx.get("hex", "") if str(o.hex) == "@hex" else str(o.hex)
			if hi != "":
				if not s.has("installazioni"):
					s.installazioni = {}
				if not s.installazioni.has(hi):
					s.installazioni[hi] = {"nome": str(o.nome), "pv": int(o.pv), "par": str(o.get("par", "")), "distrutta": false}
					_log("info", "%s in %s: distruggerla con una carica da demolizione vale %d PV." % [NOMI_INSTALLAZIONI.get(str(o.nome), str(o.nome)), hi, int(o.pv)])
		"reazione_gruppo":
			for num in o.g:
				var gr := u("g%d" % int(num))
				if not gr.is_empty() and in_mappa(gr):
					gr.reazione = str(o.r)
					if bool(o.get("no_auto", false)):
						gr.no_auto = true
					_log("info", "Reazione speciale %s in vigore per il %s." % [str(o.r), nome(gr)])
		"documenti":
			var sd := _soldato_pc(ctx)
			if bool(regola("documenti", false)) and not sd.is_empty():
				sd.documenti = int(sd.get("documenti", 0)) + int(o.n)
				_log("info", "%s prende i documenti: valgono %d PV se esce dalla mappa con lui." % [nome(sd), int(o.n)])
			else:
				_pv(int(o.n), "documenti importanti")
		"caduta_fiume":
			_op_caduta_fiume()
		"caduta_accidentato":
			_op_caduta_accidentato()
		"morte_incapacitato":
			_op_una_volta(str(o.chiave), func(): return _op_morte_incapacitato(str(o.lato)))
		"dissanguamento":
			_op_una_volta(str(o.chiave), func(): return _op_dissanguamento(str(o.lato)))
		"avviso_mine":
			var hm: String = ctx.get("hex", "")
			for dd in o.dirs:
				var v := E.vicino(hm, int(dd)) if hm != "" else ""
				if v != "":
					s.punti[v] = "avviso_mine"
					_log("info", "Cartello: campo minato in %s." % v)
		"esplosione_v2":
			_op_esplosione_v2()
		"tutti_due_turni":
			pass
		"lista_vista":
			for hl in o.hexes:
				if qualcuno_vede_hex(str(hl)) and unita_in(str(hl), "us").is_empty():
					ctx.indicato = str(hl)
					_esegui(o.ok, ctx)
					break
		"adv_pc":
			var gp: Dictionary = missione.tedeschi[str(int(o.g))]
			var r := d10("Controllo di percezione del tedesco %d" % int(o.g))
			var ok := r == 0 or (r != 9 and r <= int(gp.PC))
			ctx.adv_pc = "de" if ok else "us"
			_log("info", "Il tedesco %d %s: vantaggio %s." % [int(o.g), "se ne accorge" if ok else "non se ne accorge", "tedesco" if ok else "americano"])
		"consapevoli_vede":
			if fase_round():
				s.round.consapevoli_vede = str(o.hex)
			elif s.has("atterraggio"):
				pass
		"razzo_illuminante":
			var hr := _esagono_dadi("Razzo illuminante")
			if hr != "":
				if not s.has("razzi"):
					s.razzi = []
				s.razzi.append(hr)
				_applica_regole_terreno()
				_fx("esplosione", {"a": hr})
				_log("info", "Un razzo illuminante si accende sopra %s: gli esagoni entro 3 sono illuminati." % hr)
		"spegni_razzo":
			var rz: Array = s.get("razzi", [])
			if rz.is_empty():
				_log("info", "Nessun razzo in cielo.")
			else:
				var hs: String = rz.pop_at(rng.randi_range(0, rz.size() - 1))
				_applica_regole_terreno()
				_log("info", "Il razzo sopra %s si spegne." % hs)
		"artiglieria_dadi":
			var ha := _esagono_dadi("Artiglieria")
			if ha != "":
				_op_artiglieria_esagoni([ha])
		"sopravvissuto_aliante":
			_op_sopravvissuto()
		"morte_lancio":
			_op_morte_lancio()
		"bunker":
			_crea_bunker(str(o.hex), str(o.porta))
		"entra_bunker":
			var gb: Dictionary = u(ctx.get("g", ""))
			var hb := str(o.hex)
			if not gb.is_empty() and in_mappa(gb) and gb.hex != hb:
				var porta: String = s.get("bunker", {}).get(hb, {}).get("porta", "")
				if porta != "" and gb.hex == porta:
					ia.entra_da_paragrafo(ctx, hb)
				elif porta != "":
					ia.entra_da_paragrafo(ctx, porta)
		"cratere":
			s.modifiche[str(o.hex)] = "crater"
			terreno.imposta_modifiche(s.modifiche)
		"scelta_attiva":
			if not s.has("scelte"):
				s.scelte = {}
			s.scelte[str(o.par)] = str(o.testo)
			_log("info", "Annotato: «%s» (paragrafo %s), quando vuoi." % [str(o.testo), str(o.par)])
		"linea_mine":
			for hl in E.linea(str(o.da), str(o.a)):
				s.punti[str(hl)] = "avviso_mine"
		"togli_reazioni":
			for x in tedeschi():
				if str(x.get("reazione", "")) in o.r:
					x.reazione = ""
			_log("info", "Le reazioni speciali %s sono tolte." % ", ".join(o.r))
		"g_enter_dir":
			var gd: Dictionary = u(ctx.get("g", ""))
			if not gd.is_empty() and in_mappa(gd):
				var vd := E.vicino(gd.hex, int(o.dir))
				if vd != "":
					ia.entra_da_paragrafo(ctx, vd)
		"rapide":
			_op_rapide(ctx)
		"act_terreno":
			var sd2 := _soldato_pc(ctx)
			var mod_t := int(o.si) if (not sd2.is_empty() and terreno.tipo(sd2.hex) in o.tipi) else int(o.no)
			_op_controllo({"kind": "act", "mod": mod_t, "ok": o.ok, "ko": o.ko}, ctx)
		"ponte_disinnescato":
			ponte_stato("M12").catturato = true
			_log("info", "Il ponte in M12 non può più saltare.")
		"ponte_salta_m8":
			_op_ponte_salta_m8()
		"sherman_disponibile":
			s.sherman_pronto = int(s.round.get("n", 0)) + 1 if fase_round() else 0
			_log("info", "Lo Sherman è disponibile: entra in A6 quando vuoi (bottone «Fai entrare lo Sherman»).")
		"blocco":
			if not s.has("blocchi"):
				s.blocchi = []
			for hb2 in o.hexes:
				if not (hb2 in s.blocchi):
					s.blocchi.append(hb2)
		"riattiva_evasi":
			var coppie: Array = []
			for num in o.g:
				var ge2 := u("g%d" % int(num))
				if not ge2.is_empty() and ge2.stato == "rimosso":
					coppie.append([int(num), str(o.hex)])
			if not coppie.is_empty():
				_op_attiva({"g": coppie, "stance": "crouching", "adv": null, "two": [], "us_two": false, "aware": false, "reaction": null}, ctx)
		"g_exit":
			if ctx.get("veicolo", false):
				var ve: Dictionary = veicoli.v(str(ctx.get("veicolo_id", "")))
				if not ve.is_empty():
					veicoli._esce(ve)
					ctx.verso_veicolo = ""
			else:
				var ge: Dictionary = u(ctx.get("g", ""))
				if not ge.is_empty() and in_mappa(ge):
					var da_g: String = ge.hex
					ge.stato = "uscito"
					ge.hex = ""
					ge.turni = 0
					ge.slot = "inattivo"
					ia.ferma()
					_log("tedesco", "Il %s esce dalla mappa." % nome(ge))
					_fx("sparisce", {"ids": [ge.id], "da": da_g, "motivo": "uscito"})
		"no_autoconservazione":
			var gn: Dictionary = u(ctx.get("g", ""))
			if not gn.is_empty():
				gn.no_auto = true
		_:
			if not mo.op(o, ctx) and not ph.op(o, ctx) and not ss.op(o, ctx):
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
	if t.has("radio"):
		return radio_presidiata()
	if t.has("sherman_in_mappa"):
		var vs: Dictionary = veicoli.v("vsherman")
		return not vs.is_empty() and veicoli.attivo(vs) and vs.hex != ""
	if t.has("evaso_uno"):
		for num in t.evaso_uno:
			if u("g%d" % int(num)).get("stato", "") == "rimosso":
				return true
		return false
	if t.has("m8_220"):
		var h220: String = ctx.get("hex", "")
		var vs2: Dictionary = veicoli.v("vsherman")
		if not vs2.is_empty() and vs2.hex == h220:
			return true
		if not bool(s.avvistamenti[6]):
			return true
		for a in unita_in(h220, "us"):
			for g in tedeschi_attivi():
				if attivo(g) and vede_unita(g, a):
					return true
		return false
	if t.has("m8_670"):
		var fuori := func(num): return u("g%d" % num).get("stato", "") in ["catturato", "incapacitato", "morto"]
		if not (fuori.call(45) and fuori.call(11)):
			return false
		var altri := 0
		for g in tedeschi():
			if not (int(g.num) in [45, 11]) and g.stato in ["catturato", "incapacitato", "morto"]:
				altri += 1
		return altri >= 2
	if t.has("g_vede_entro") or t.has("g_vede_almeno"):
		var gw: Dictionary = u(ctx.get("g", ""))
		if gw.is_empty() or not in_mappa(gw):
			return false
		var vis: Array = ia.bersagli(gw)
		if t.has("g_vede_entro"):
			vis = vis.filter(func(a): return E.distanza(a.hex, gw.hex) <= int(t.g_vede_entro))
		return vis.size() >= int(t.get("g_vede_almeno", 1))
	if t.has("inattivo_uno"):
		for num in t.inattivo_uno:
			var gi2 := u("g%d" % int(num))
			if not gi2.is_empty() and not attivo(gi2):
				return true
		return false
	if t.has("us_lato"):
		for a in americani_attivi_in_mappa():
			if lato_fiume(a.hex) == str(t.us_lato):
				return true
		return false
	if t.has("us_strada"):
		for a in americani_attivi_in_mappa():
			if rispetto_strada(a.hex, str(t.us_strada[0])) in (["sud", "su"] if str(t.us_strada[1]) == "sud" else ["nord", "su"]):
				return true
		return false
	if t.has("us_entro"):
		for a in americani_attivi_in_mappa():
			if E.distanza(a.hex, str(t.us_entro[0])) <= int(t.us_entro[1]):
				return true
		return false
	if t.has("g_da"):
		var gg2: Dictionary = u(ctx.get("g", ""))
		return not gg2.is_empty() and str(gg2.get("hex_prec", "")) in t.g_da
	if t.has("bunker_intatto"):
		var hbk := _hex_test(t.bunker_intatto, ctx)
		return s.get("bunker", {}).has(hbk) and not s.bunker[hbk].distrutto
	if t.has("bunker_qui"):
		return s.get("bunker", {}).has(str(ctx.get("hex", "")))
	if t.has("inattivi"):
		for num in t.inattivi:
			var gi := u("g%d" % int(num))
			if gi.is_empty() or attivo(gi):
				return false
		return true
	if t.has("attivo_uno"):
		for num in t.attivo_uno:
			var ga2 := u("g%d" % int(num))
			if not ga2.is_empty() and attivo(ga2):
				return true
		return false
	if t.has("tedeschi_attivati"):
		return not s.attivati.is_empty()
	if t.has("g_vede_us"):
		var gv: Dictionary = u(ctx.get("g", ""))
		return not gv.is_empty() and in_mappa(gv) and not ia.bersagli(gv).is_empty()
	if t.has("us_in"):
		return not unita_in(str(t.us_in), "us").is_empty()
	if t.has("indicato"):
		return str(ctx.get("indicato", "")) == str(t.indicato)
	if t.has("bridge_intact"):
		return ponte_intatto(_hex_test(t.bridge_intact, ctx))
	if t.has("bridge_ok"):
		var hb := _hex_test(t.bridge_ok, ctx)
		return ponte_intatto(hb) and not ponte_stato(hb).get("attraversato", false)
	if t.has("any_bridge_ok"):
		for hb in t.any_bridge_ok:
			if ponte_intatto(str(hb)) and not ponte_stato(str(hb)).get("attraversato", false):
				return true
		return false
	if t.has("bridge_checked"):
		return int(ponte_stato(_hex_test(t.bridge_checked, ctx)).get("controlli", 0)) >= 4
	if t.has("g_is") or t.has("g_le") or t.has("g_ge"):
		var gg: Dictionary = u(ctx.get("g", ""))
		if gg.is_empty():
			return false
		var num := int(gg.num)
		if t.has("g_is"):
			return num in t.g_is.map(func(x): return int(x))
		if t.has("g_le"):
			return num <= int(t.g_le)
		return num >= int(t.g_ge)
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
	var tsx = ss.test(t, ctx)
	if tsx != null:
		return tsx
	var tp = ph.test(t, ctx)
	if tp != null:
		return bool(tp)
	return mo.test(t, ctx)

func _hex_test(v, ctx: Dictionary) -> String:
	return str(ctx.get("hex", "")) if str(v) == "@hex" else str(v)

# =================================================================== Missione 8: Sherman, blocchi stradali, ponte minato
func _op_ponte_salta_m8() -> void:
	var st := ponte_stato("M12")
	if st.get("catturato", false) or not ponte_intatto("M12"):
		_log("info", "Il ponte non può più saltare.")
		return
	st.distrutto = true
	s.modifiche["M12"] = "stream"
	terreno.imposta_modifiche(s.modifiche)
	_fx("esplosione", {"a": "M12", "grande": true})
	_log("combattimento", "Il ponte in M12 salta in aria!")
	for x in unita_in("M12", "", false):
		if x.stato in ["attivo", "incapacitato"]:
			var rd := d10()
			var l := T.lettera_danno(T.ARMI.ar.danni, rd)
			_log("dado", "Esplosione su %s: %d → %s" % [nome(x), rd, _nome_danno(l)])
			_applica_danno(x, l, {})
			if x.stato != "morto":
				x.hex = "L11" if x.lato == "us" else "N12"
	for vid in s.get("veicoli", {}):
		var vv: Dictionary = s.veicoli[vid]
		if vv.hex == "M12" and vv.stato == "attivo":
			veicoli.disabilita(vv, "crollo del ponte")

func sherman_entrabile() -> bool:
	if not s.has("sherman_pronto") or not veicoli.v("vsherman").is_empty():
		return false
	if fase_round():
		return int(s.round.get("n", 0)) >= int(s.sherman_pronto)
	return true

## Lo Sherman entra in A6: equipaggio «Z» (carta americana 04) guidato dal giocatore.
func entra_sherman() -> Dictionary:
	_inizio_comando()
	if not sherman_entrabile():
		return _errore("Lo Sherman non può ancora entrare.")
	var d := {"id": "Z", "nome": "Sherman", "IN": 3, "PC": 6, "WS": 1, "DS": 8, "MPA": 6, "comandante": false,
		"porte": ["cannone", "mmg"], "munizioni": {"cannone": 20, "mmg": 10}}
	var hz: String = str(s.get("sherman_hex", "A6"))
	var z := _nuovo_americano(d)
	z.stato = "attivo"
	z.hex = hz
	z.postura = "crouching"
	z.carro_us = true
	z.consapevole = true
	s.unita["Z"] = z
	var v: Dictionary = veicoli.crea("vsherman", "sherman", hz, "us")
	v.equipaggio = 5
	v.chiuso = false
	v.cannone_pronto = true
	v.fronte = 2
	s.imbarco = true
	veicoli.sali(z, v)
	s.imbarco = false
	for a in z.armi:
		a.preparata = true
	_log("info", "Lo Sherman entra in %s. Lo comandi come un soldato (Z): guida, cannone e mitragliatrice." % hz)
	_fx("compare", {"id": "Z", "a": hz, "amico": true})
	_fine_comando()
	return OK

## Blocco stradale: nelle Operazioni, tre soldati attivi nell’esagono e un controllo Evento.
func sgombra_blocco(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	if s.fase != "operazioni":
		return _errore("Il blocco si sposta solo nelle Operazioni.")
	if not (a.hex in s.get("blocchi", [])):
		return _errore("Qui non c’è un blocco stradale.")
	if unita_in(a.hex, "us").filter(func(x): return not x.get("carro_us", false)).size() < 3:
		return _errore("Servono almeno tre soldati attivi nell’esagono.")
	_log("azione", "La squadra sposta i tronchi del blocco stradale in %s." % a.hex)
	s.blocchi.erase(a.hex)
	evento_casuale({"hex": a.hex, "ids": [a.id]})
	_fine_comando()
	return OK

# =================================================================== Missione 7: mine anticarro, eventi continui
func _piazza_mine_anticarro(esagoni_squadra: Array) -> void:
	var area: Array = esagoni_ingresso()
	var strade: Array = area.filter(func(h): return terreno.tipo(h) == "road" and not (h in esagoni_squadra))
	strade.sort_custom(func(a, b): return E.colonna(a) < E.colonna(b) or (E.colonna(a) == E.colonna(b) and E.riga(a) < E.riga(b)))
	s.mine_at = []
	for h in strade:
		if s.mine_at.size() >= int(regola("mine_anticarro", 0)):
			break
		if terreno.tipo(h) == "woods" or ponti().has(h):
			continue
		s.mine_at.append(h)
	_log("info", "Mine anticarro piazzate in %s: esplodono solo sotto un veicolo." % ", ".join(s.mine_at))

## Un veicolo entra in un esagono con una mina anticarro.
func mina_anticarro(veic: Dictionary, h: String) -> void:
	if not (h in s.get("mine_at", [])) or veic.stato != "attivo":
		return
	s.mine_at.erase(h)
	_fx("esplosione", {"a": h, "grande": true})
	if bool(veicoli.MODELLI[veic.modello].get("carro", false)):
		veic.immobilizzato = true
		veic.cingolo = true
		_log("combattimento", "%s salta su una mina anticarro in %s: è immobilizzato, ma può ancora sparare." % [veicoli.nome_art(veic), h])
		return
	_log("combattimento", "%s salta su una mina anticarro in %s!" % [veicoli.nome_art(veic), h])
	var a_bordo: Array = veicoli.occupanti(veic)
	veicoli.disabilita(veic, "mina anticarro")
	for x in a_bordo:
		if attivo(x):
			var rd := d10()
			var l := T.lettera_danno(T.ARMI.bazooka.danni, rd)
			_log("dado", "Esplosione su %s: %d → %s" % [nome(x), rd, _nome_danno(l)])
			_applica_danno(x, l, {})

## Si tirano eventi casuali finché un tedesco entra in gioco (Missione 7).
func aspetta_tedeschi(da_comando := true) -> Dictionary:
	if da_comando:
		_inizio_comando()
	if s.fase != "operazioni":
		return _errore("Si aspetta solo nelle Operazioni.")
	var prove := 0
	while s.fase == "operazioni" and prove < 40:
		prove += 1
		evento_casuale({"hex": "", "ids": []})
	if da_comando:
		if fase_round() and s.turno.is_empty() and s.pausa == "":
			_flusso()
		_fine_comando()
	return OK

## Un tedesco o un veicolo tedesco esce dal bordo ovest: perdi il doppio del suo valore in PV.
func tedesco_uscito(x: Dictionary, h: String) -> void:
	mo.tedesco_uscito(x, h)
	ph.tedesco_uscito(x, h)
	var lato := str(regola("uscita_tedeschi", ""))
	if lato == "" or h == "" or h.substr(0, 1) != lato:
		return
	var d: Dictionary = missione.tedeschi.get(str(int(x.get("num", 0))), {})
	var valore := int(d.get("pv", 0)) + int(d.get("pv_cattura", 0))
	if valore > 0:
		_pv(-2 * valore, "%s esce dal bordo ovest" % nome(x))

# =================================================================== Missione 6: canoe e bunker
## Lato del fiume (mappa A, fiume H1–O19): "est", "ovest" o "fiume".
func lato_fiume(h: String) -> String:
	var r := E.riga(h)
	var cols: Array = []
	for x in terreno.esagoni:
		if E.riga(x) == r and terreno.esagoni[x].get("t", "") == "stream":
			cols.append(E.colonna(x))
	if cols.is_empty():
		return "est"
	var c := E.colonna(h)
	if c > cols.max():
		return "est"
	if c < cols.min():
		return "ovest"
	return "fiume"

## Posizione rispetto alla strada che parte da «da» (N12: N12–Y8, A6: A6–L11): "nord", "su" o "sud".
func rispetto_strada(h: String, da: String) -> String:
	var strada: Array = []
	for x in terreno.esagoni:
		if terreno.esagoni[x].get("t", "") == "road":
			var c := E.colonna(x)
			if (da == "N12" and c >= 13) or (da == "A6" and c <= 11):
				strada.append(x)
	if strada.is_empty():
		return "sud"
	if h in strada:
		return "su"
	var c := clampi(E.colonna(h), 13 if da == "N12" else 0, 24 if da == "N12" else 11)
	var righe: Array = strada.filter(func(x): return E.colonna(x) == c).map(func(x): return E.riga(x))
	if righe.is_empty():
		return "sud"
	return "nord" if E.riga(h) < righe.min() else "sud"

func _imbarca_canoe() -> void:
	s.imbarco = true
	var gruppi: Dictionary = {}
	for a in americani():
		if a.hex != "" and attivo(a):
			if not gruppi.has(a.hex):
				gruppi[a.hex] = []
			gruppi[a.hex].append(a)
	var n := 0
	for h in gruppi:
		var lista: Array = gruppi[h]
		var i := 0
		while i < lista.size() and n < int(regola("canoe", 4)):
			n += 1
			var c: Dictionary = veicoli.crea("canoa%d" % n, "canoa", h, "us")
			c.nome = "Canoa %d" % n
			for j in 2:
				if i < lista.size():
					veicoli.sali(lista[i], c)
					lista[i].postura = "crouching"
					i += 1
	s.imbarco = false
	_log("info", "La squadra parte in %d canoe, due soldati per canoa." % n)

## Una canoa può muoversi solo con due soldati attivi a bordo.
func canoa_pronta(veic: Dictionary) -> bool:
	return veicoli.occupanti(veic).filter(func(x): return attivo(x)).size() >= 2

func _canoe_forate() -> void:
	for v in veicoli.tutti():
		if veicoli.e_canoa(v) and v.stato == "attivo" and v.get("forata", false) and not veicoli.spiaggiata(v):
			if v.get("forata_round", -1) == -1:
				v.forata_round = int(s.round.get("n", 0))
			else:
				_affonda_canoa(v, "la canoa forata imbarca acqua e affonda")
		elif veicoli.e_canoa(v) and veicoli.spiaggiata(v):
			v.forata_round = -1

func _affonda_canoa(v: Dictionary, motivo: String) -> void:
	var h: String = v.hex
	var riva := ""
	for x in E.vicini(h):
		if terreno.esagoni.get(x, {}).get("t", "") != "stream" and not terreno.edificio(x):
			riva = x
			break
	_log("danno", "%s: %s." % [v.nome, motivo])
	for a in veicoli.occupanti(v):
		veicoli.scendi(a)
		if riva != "":
			a.hex = riva
			a.postura = "prone"
	v.stato = "distrutto"
	v.hex = ""
	if riva != "":
		_ingresso(riva, americani().filter(func(a): return a.hex == riva and attivo(a)).map(func(a): return a.id), false)

func _op_rapide(ctx: Dictionary) -> void:
	for v in veicoli.tutti():
		if not veicoli.e_canoa(v) or v.stato != "attivo" or v.hex != ctx.get("hex", v.hex):
			continue
		var occ: Array = veicoli.occupanti(v).filter(func(x): return attivo(x))
		if occ.is_empty():
			continue
		occ.sort_custom(func(a, b): return int(a.DS) > int(b.DS))
		var timoniere: Dictionary = occ[0]
		if controllo_pc(timoniere, 0, "rapide"):
			_log("info", "%s supera le rapide." % v.nome)
			continue
		_log("par", paragrafi["872"].it, {"id": "872"})
		var r := d10("Controllo d’incidente di %s (guida %d)" % [nome(timoniere), int(timoniere.DS)])
		if r == 0 or (r != 9 and r <= int(timoniere.DS)):
			_log("info", "%s riprende il controllo della canoa." % nome(timoniere))
		else:
			_affonda_canoa(v, "si capovolge nelle rapide")

func _crea_bunker(h: String, porta: String) -> void:
	if not s.has("bunker"):
		s.bunker = {}
	if s.bunker.has(h):
		return
	s.bunker[h] = {"porta": porta, "sfondata": false, "distrutto": false, "carica": false, "occupanti": [], "pv_dati": false}
	s.modifiche[h] = "bunker"
	terreno.imposta_modifiche(s.modifiche)
	_applica_regole_terreno()
	_log("info", "Un bunker in %s, con la porta verso %s." % [h, porta])

## Gli occupanti iniziali vengono annotati quando si attivano nell’esagono del bunker.
func _annota_occupanti_bunker() -> void:
	for h in s.get("bunker", {}):
		var b: Dictionary = s.bunker[h]
		for g in unita_in(h, "de", false):
			if not (g.id in b.occupanti) and b.occupanti.size() < 2 and str(g.hex_attivazione) == h:
				b.occupanti.append(g.id)

## Scelte lasciate al giocatore da un paragrafo (575, 713): si leggono quando si vuole.
func esegui_scelta(par: String) -> Dictionary:
	_inizio_comando()
	if not s.get("scelte", {}).has(par):
		return _errore("Scelta non disponibile.")
	s.scelte.erase(par)
	leggi(par, {"hex": "", "ids": []})
	if fase_round() and s.turno.is_empty() and s.pausa == "":
		_flusso()
	_fine_comando()
	return OK

func bunker_in_vista(a: Dictionary) -> Array:
	var out: Array = []
	for h in s.get("bunker", {}):
		if not s.bunker[h].distrutto and a.hex != "" and terreno.vede(a.hex, h, a.postura if a.postura != "prone" else "crouching", "standing"):
			out.append(h)
	return out

func controlla_bunker() -> void:
	_annota_occupanti_bunker()
	for h in s.get("bunker", {}):
		var b: Dictionary = s.bunker[h]
		if b.pv_dati or b.occupanti.is_empty():
			continue
		var fuori := true
		for id in b.occupanti:
			if u(str(id)).stato in ["attivo"]:
				fuori = false
		if fuori and (b.distrutto or b.carica or s.modifiche.get(h, "") == "rubble"):
			b.pv_dati = true
			_pv(6, "bunker in %s messo fuori combattimento" % h)

## Tiro contro il bunker (regole della Missione 6): +2 per colpire, poi tabella dei colpi.
func tiro_bunker(id: String, tipo_arma: String, h: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a)
	if e != "":
		return _errore(e)
	if s.fase != "round":
		return _errore("Nelle Operazioni non si combatte.")
	var b: Dictionary = s.get("bunker", {}).get(h, {})
	if b.is_empty() or b.distrutto:
		return _errore("Nessun bunker intatto in %s." % h)
	var arma := arma_di(a, tipo_arma)
	if arma.is_empty() or not (arma in armi_da_fuoco(a)):
		return _errore("Arma non disponibile.")
	if a.postura == "prone":
		return _errore("Da prono non si spara.")
	if not terreno.vede(a.hex, h, a.postura, "standing"):
		return _errore("Il bunker non è in vista.")
	var t := _turno_di(a)
	if t.azione != "":
		return _errore("Il tiro al bunker è un tiro mirato: un’azione a sé.")
	var base := T.base_per_distanza(tipo_arma, E.distanza(a.hex, h))
	if base < 0:
		return _errore("Fuori gittata.")
	t.azione = "mirato"
	var prob := clampi(base + 2 + int(a.WS) - (1 if a.ferito else 0), 0, 8)
	_log("combattimento", "%s spara al bunker in %s (serve 0–%d)." % [nome(a), h, prob])
	_fx("tiro", {"da": a.hex, "a": h, "tiratore": a.id, "bersaglio": "", "arma": tipo_arma, "mirato": true, "esito": "mancato", "prob": prob})
	_rendi_consapevoli(h)
	var r := d10()
	if r == 0 or (r != 9 and r <= prob):
		_colpo_bunker(a, arma, h, b)
	else:
		_log("dado", "Mancato (%d)." % r)
	if tipo_arma == "bazooka":
		_consuma_bazooka(a, arma)
	else:
		var pm := percentuale()
		if pm <= int(T.ARMI[tipo_arma].mun):
			a.munizioni[tipo_arma] = maxi(0, munizioni_arma(a, tipo_arma) - 1)
	controlla_bunker()
	if attivo(a) and not s.turno.is_empty():
		_termina_azione(a)
	_fine_comando()
	return OK

## Purple Heart 548: tiro al faro (+1 per colpirlo, niente modificatori di terreno); con penetrazione leggera o migliore si spegne.
func tiro_faro(id: String, tipo_arma: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a)
	if e != "":
		return _errore(e)
	if s.fase != "round":
		return _errore("Nelle Operazioni non si combatte.")
	var h: String = ph.faro_hex()
	if h == "":
		return _errore("Il faro è già spento.")
	var arma := arma_di(a, tipo_arma)
	if arma.is_empty() or not (arma in armi_da_fuoco(a)):
		return _errore("Arma non disponibile.")
	if a.postura == "prone":
		return _errore("Da prono non si spara.")
	if not terreno.vede(a.hex, h, a.postura, "standing"):
		return _errore("Il faro non è in vista.")
	var t := _turno_di(a)
	if t.azione != "":
		return _errore("Il tiro al faro è un tiro mirato: un’azione a sé.")
	var base := T.base_per_distanza(tipo_arma, E.distanza(a.hex, h))
	if base < 0:
		return _errore("Fuori gittata.")
	t.azione = "mirato"
	var prob := clampi(base + 1 + int(a.WS) - (1 if a.ferito else 0), 0, 8)
	_log("combattimento", "%s spara al faro in %s (serve 0–%d)." % [nome(a), h, prob])
	_fx("tiro", {"da": a.hex, "a": h, "tiratore": a.id, "bersaglio": "", "arma": tipo_arma, "mirato": true, "esito": "mancato", "prob": prob})
	_rendi_consapevoli(a.hex)
	var r := d10()
	if r == 0 or (r != 9 and r <= prob):
		var rd := d10()
		var pen := T.penetrazione(tipo_arma, rd)
		_log("dado", "Faro colpito (%d): penetrazione %d → %s." % [r, rd, {"-": "nessuna", "L": "leggera", "M": "media", "H": "pesante"}[pen]])
		if pen != "-":
			ph.spegni_faro("colpito da %s" % nome(a))
	else:
		_log("dado", "Mancato (%d)." % r)
	if tipo_arma == "bazooka":
		_consuma_bazooka(a, arma)
	else:
		var pm := percentuale()
		if pm <= int(T.ARMI[tipo_arma].mun):
			a.munizioni[tipo_arma] = maxi(0, munizioni_arma(a, tipo_arma) - 1)
	if attivo(a) and not s.turno.is_empty():
		_termina_azione(a)
	_fine_comando()
	return OK

func _colpo_bunker(a: Dictionary, arma: Dictionary, h: String, b: Dictionary) -> void:
	var dalla_porta: bool = a.hex == str(b.porta) or (E.direzione(h, a.hex) == E.direzione(h, str(b.porta)) and E.direzione(h, a.hex) >= 0)
	var r := d10("Bunker colpito: lato %s" % ("della porta" if dalla_porta else "frontale"))
	var parte := ""
	if dalla_porta:
		parte = "muro" if r <= 4 else ("porta" if r <= 7 else "equipaggio")
	else:
		parte = "muro" if r <= 7 else ("feritoia" if r == 8 else "equipaggio")
	if parte == "equipaggio" and arma.tipo == "bazooka":
		parte = "porta" if dalla_porta else "feritoia"
	if parte == "equipaggio":
		var esposti: Array = unita_in(h, "de").filter(func(x): return x.postura != "prone" or (dalla_porta and b.sfondata))
		if esposti.is_empty():
			_log("info", "Colpo nell’apertura, ma l’equipaggio è a terra: nessun effetto.")
			return
		var x: Dictionary = esposti[rng.randi_range(0, esposti.size() - 1)]
		var rd := d10()
		var l := T.lettera_danno(T.ARMI[arma.tipo].danni, rd)
		_log("dado", "Colpito %s: %d → %s" % [nome(x), rd, _nome_danno(l)])
		_applica_danno(x, l, a)
		return
	var dp := d10()
	var pen := T.penetrazione(arma.tipo, dp)
	_log("dado", "Colpo su %s: penetrazione %d → %s." % [parte, dp, {"L": "leggera", "M": "media", "H": "pesante"}.get(pen, "nessuna")])
	var distrutto := (parte == "muro" and pen == "H") or (parte in ["feritoia", "porta"] and pen in ["H", "M"])
	if distrutto:
		b.distrutto = true
		s.modifiche[h] = "rubble"
		terreno.imposta_modifiche(s.modifiche)
		_fx("esplosione", {"a": h, "grande": true})
		_log("combattimento", "Il bunker in %s è distrutto!" % h)
		for x in unita_in(h, "", false):
			if x.stato in ["attivo", "incapacitato", "catturato", "arreso"]:
				_uccidi(x, "nel bunker")
	elif parte == "porta" and pen == "L" and not b.sfondata:
		b.sfondata = true
		_applica_regole_terreno()
		_log("combattimento", "La porta del bunker in %s è sfondata: da lì si può entrare." % h)
	else:
		_log("info", "Il bunker regge.")

# =================================================================== Missione 5: guadi, installazioni, documenti
const NOMI_INSTALLAZIONI := {"antenna": "Un’antenna", "radar": "Una stazione radar", "rampa": "La rampa di lancio", "v2": "Il razzo V-2"}

func _colpisci_installazione(h: String) -> void:
	var inst: Dictionary = s.get("installazioni", {}).get(h, {})
	if inst.is_empty() or inst.distrutta:
		return
	inst.distrutta = true
	_fx("esplosione", {"a": h, "grande": true})
	_log("combattimento", "%s in %s salta in aria!" % [NOMI_INSTALLAZIONI.get(str(inst.nome), str(inst.nome)), h])
	_pv(int(inst.pv), "installazione distrutta in %s" % h)
	if str(inst.par) != "":
		leggi(str(inst.par), {"hex": h, "ids": []})

## Nelle Operazioni la carica si piazza a mano su un’installazione nel proprio esagono o accanto.
func demolisci(id: String, h: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	var c := arma_di(a, "satchel")
	if c.is_empty():
		return _errore("Serve una carica da demolizione.")
	var inst: Dictionary = s.get("installazioni", {}).get(h, {})
	if inst.is_empty() or inst.distrutta or E.distanza(a.hex, h) > 1:
		return _errore("Nessuna installazione da distruggere qui o accanto.")
	a.armi.erase(c)
	_log("azione", "%s piazza una carica da demolizione e si allontana." % nome(a))
	_colpisci_installazione(h)
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

func installazioni_vicine(a: Dictionary) -> Array:
	var out: Array = []
	if a.hex == "" or arma_di(a, "satchel").is_empty():
		return out
	for h in s.get("installazioni", {}):
		if not s.installazioni[h].distrutta and E.distanza(a.hex, h) <= 1:
			out.append(h)
	return out

func _op_una_volta(chiave: String, f: Callable) -> void:
	if not s.has("una_volta"):
		s.una_volta = []
	if chiave in s.una_volta:
		_log("info", "Questo paragrafo si applica una sola volta: nessun effetto.")
		return
	if f.call():
		s.una_volta.append(chiave)

func _op_morte_incapacitato(lato: String) -> bool:
	var lista: Array = s.unita.values().filter(func(x): return x.lato == lato and x.stato == "incapacitato" and x.hex != "")
	if lista.is_empty():
		_log("info", "Nessun incapacitato: nessun effetto.")
		return false
	_uccidi(lista[rng.randi_range(0, lista.size() - 1)], "ferite")
	return true

func _op_dissanguamento(lato: String) -> bool:
	var lista: Array = s.unita.values().filter(func(x): return x.lato == lato and attivo(x) and x.ferito and x.hex != "")
	if lista.is_empty():
		_log("info", "Nessun ferito: nessun effetto.")
		return false
	var x: Dictionary = lista[rng.randi_range(0, lista.size() - 1)]
	_log("danno", "%s perde troppo sangue." % nome(x))
	_applica_danno(x, "I", {})
	return true

func _op_caduta_fiume() -> void:
	if "045" in s.get("una_volta", []):
		_log("info", "Paragrafo già applicato: nessun effetto.")
		return
	var lista: Array = americani_attivi_in_mappa().filter(func(a):
		for v in E.vicini(a.hex):
			if terreno.tipo(v) == "stream":
				return true
		return false)
	if lista.is_empty():
		_log("info", "Nessun soldato accanto al fiume: nessun effetto.")
		return
	if not s.has("una_volta"):
		s.una_volta = []
	s.una_volta.append("045")
	var a: Dictionary = lista[rng.randi_range(0, lista.size() - 1)]
	var r := d10("%s scivola nel fiume" % nome(a))
	if r % 2 == 0:
		_log("info", "%s riesce a uscire dall’acqua e torna al suo posto." % nome(a))
	else:
		a.armi.clear()
		_uccidi(a, "trascinato via dalla corrente")

func _op_caduta_accidentato() -> void:
	if "645" in s.get("una_volta", []):
		_log("info", "Paragrafo già applicato: nessun effetto.")
		return
	var lista: Array = americani_attivi_in_mappa().filter(func(a): return terreno.tipo(a.hex) == "rough")
	if lista.is_empty():
		_log("info", "Nessun soldato in terreno accidentato: nessun effetto.")
		return
	if not s.has("una_volta"):
		s.una_volta = []
	s.una_volta.append("645")
	var a: Dictionary = lista[rng.randi_range(0, lista.size() - 1)]
	if controllo_pc(a, 0, "caduta"):
		_log("info", "%s cade ma è illeso." % nome(a))
	else:
		var rd := d10()
		var l := T.lettera_danno(T.ARMI.pistol.danni, rd)
		_log("dado", "Caduta di %s: %d → %s" % [nome(a), rd, _nome_danno(l)])
		_applica_danno(a, l, {})

func _op_esplosione_v2() -> void:
	_fx("esplosione", {"a": "S13", "grande": true})
	for x in unita_in("S13", "", false):
		if x.stato in ["attivo", "incapacitato", "catturato", "arreso"]:
			_uccidi(x, "esplosione del V-2")
	s.modifiche["S13"] = "rubble"
	s.modifiche["S14"] = "rubble"
	terreno.imposta_modifiche(s.modifiche)
	for x in s.unita.values():
		if x.hex == "" or x.hex == "S13" or not attivo(x):
			continue
		var d := E.distanza(x.hex, "S13")
		if d <= 2:
			_danno_esplosione(x, T.GRANATA_FUORI)
		if fase_round() and d <= 3 and attivo(x):
			_applica_danno(x, "P", {})

# =================================================================== Missione 4: lancio col paracadute
## Esagono da due dadi: colonna 1 = A … 9 = I, 0 = J; riga = secondo dado + 10 (paragrafi 086, 556).
func _esagono_dadi(motivo: String) -> String:
	var a := d10()
	var b := d10()
	var col := 9 if a == 0 else a - 1
	var h := E.da(col, b + 10)
	_log("dado", "%s: colonna %d, riga %d + 10 → %s" % [motivo, a, b, h])
	return h

func _lancio(occupati: Array) -> void:
	s.atterraggio = true
	s.attivazioni_lancio = []
	s.sparati_lancio = false
	s.incapacitati_lancio = []
	_passo("lancio")
	# La cassa delle armi occupa il primo esagono libero.
	var libero := ""
	for h in esagoni_ingresso():
		if not (h in occupati):
			libero = h
			break
	var c: Dictionary = missione.get("cassa", {})
	s.cassa = {"hex": libero, "stato": "in volo", "armi": c.get("armi", []).duplicate(), "munizioni": c.get("munizioni", {}).duplicate()}
	_log("titolo", "Il lancio")
	var ordine: Array = americani().filter(func(x): return x.hex != "")
	ordine.sort_custom(func(x, y): return str(x.id) < str(y.id))
	for a in ordine:
		_scendi(a)
	if libero != "":
		_scendi({})
	s.atterraggio = false
	var nuova := 3 if s.sparati_lancio else 2
	_log("info", "Tutti a terra. %s" % ("Qualcuno è stato bersagliato durante la discesa: Condizione 3." if nuova == 3 else "Condizione 2."))
	s.atterraggio = true
	cambia_condizione(nuova)
	s.atterraggio = false
	var lista: Array = s.attivazioni_lancio
	if lista.is_empty():
		for a in americani():
			a.paracadute = 0
		_log("info", "Nessun tedesco in vista: iniziano le Operazioni e i paracadute vengono tolti.")
		return
	var punti := func(x): return (2 if str(x.adv) == "us" else (-2 if str(x.adv) == "de" else 0)) + (1 if x.us_two else 0) - (1 if not x.two.is_empty() else 0)
	var scelta: Dictionary = lista[0]
	for x in lista:
		if (int(s.condizione) == 2 and punti.call(x) > punti.call(scelta)) or (int(s.condizione) != 2 and punti.call(x) < punti.call(scelta)):
			scelta = x
	var nuovi: Array = []
	var due: Array = []
	for x in lista:
		for id in x.ids:
			nuovi.append(u(str(id)))
	for x in lista:
		if x == scelta:
			for id in x.ids:
				if int(u(str(id)).num) in x.two:
					due.append(int(u(str(id)).num))
	_log("info", "Si usa l’attivazione %s per il vantaggio (Condizione %d)." % ["più favorevole agli americani" if int(s.condizione) == 2 else "più favorevole ai tedeschi", int(s.condizione)])
	_inizia_round_da_attivazione(nuovi, {"adv": scelta.adv, "two": due, "us_two": scelta.us_two}, "")
	s.round.tutti_consapevoli = true

## Discesa di un soldato (o della cassa, se a è vuoto) finché la carta della Condizione 1 non dice «Atterra».
func _scendi(a: Dictionary) -> void:
	var cassa := a.is_empty()
	var h: String = s.cassa.hex if cassa else a.hex
	var chi := "La cassa delle armi" if cassa else nome(a)
	var percorso: Array = [h]
	for i in 40:
		var r := d10()
		var verso := E.vicino(h, 5 if r % 2 == 0 else 4)
		if verso == "":
			_log("info", "%s arriva al bordo della mappa e atterra in %s." % [chi, h])
			break
		var da := h
		h = verso
		percorso.append(h)
		if cassa:
			s.cassa.hex = h
		else:
			a.hex = h
		_fx("muovi", {"ids": [] if cassa else [a.id], "da": da, "a": h, "paracadute": true, "passo": i})
		var rif := riferimento(h, 1)
		if rif == "LAND":
			if terreno.edificio(h) and not cassa:
				var esito := _atterra(a, h)
				if esito == "ancora":
					continue
				break
			if not cassa:
				_atterra(a, h)
			else:
				_atterra_cassa(h)
			break
		if not cassa and rif != "NONE" and rif != "EVENT":
			_log("info", "%s scende su %s." % [chi, h])
			_risolvi_riferimento(rif, {"hex": h, "ids": [a.id]})
			if not attivo(a):
				break
	if not cassa:
		_fx("atterra", {"id": a.id, "a": h})
	_log("azione", "%s scende col paracadute: %s." % [chi, " → ".join(percorso)])

func _atterra_cassa(h: String) -> void:
	if terreno.tipo(h) == "stream":
		var r := d10("La cassa cade nel fiume")
		if r <= 1:
			var nord := E.vicino(h, 0)
			if nord != "" and terreno.tipo(nord) != "stream":
				h = nord
		else:
			s.cassa.stato = "persa"
			s.cassa.hex = ""
			_log("danno", "La cassa delle armi affonda nel fiume: è persa.")
			return
	s.cassa.hex = h
	s.cassa.stato = "chiusa"
	_log("info", "La cassa delle armi atterra in %s, chiusa." % h)

func _vicino_scoperto(h: String, a_caso: bool) -> String:
	var lista: Array = E.vicini(h).filter(func(v): return terreno.tipo(v) in ["clear", "road"] and not ponti().has(v))
	if lista.is_empty():
		lista = E.vicini(h).filter(func(v): return terreno.tipo(v) != "stream" and not terreno.edificio(v))
	if lista.is_empty():
		return h
	return lista[rng.randi_range(0, lista.size() - 1)] if a_caso else lista[0]

## Esito dell’atterraggio secondo il terreno; "ancora" se il soldato manca l’edificio e continua a scendere.
func _atterra(a: Dictionary, h: String) -> String:
	var tipo := terreno.tipo(h)
	a.postura = "prone"
	a.consapevole = true
	a.paracadute = 2
	var r := d10("Atterraggio di %s (%s)" % [nome(a), terreno.nome_tipo(h)])
	var esito := "buono"
	var dove := h
	if tipo == "stream":
		if r <= 1:
			var nord := E.vicino(h, 0)
			dove = nord if nord != "" and terreno.tipo(nord) != "stream" else _vicino_scoperto(h, true)
			_log("info", "%s manca il fiume per un soffio." % nome(a))
		elif r <= 5:
			dove = _vicino_scoperto(h, true)
			a.armi.clear()
			a.munizioni = {}
			a.postura = "crouching"
			a.paracadute = 0
			_log("danno", "%s finisce nel fiume: si libera dell’imbracatura e raggiunge la riva, ma perde armi e munizioni." % nome(a))
		else:
			a.hex = ""
			a.armi.clear()
			_uccidi(a, "annegato nel fiume")
			return "morto"
	elif tipo in ["clear", "road"]:
		if r == 9:
			esito = "ferito"
	elif tipo in ["cover", "brush"]:
		if r == 9:
			esito = "ferito" if d10() <= 4 else "incapacitato"
	elif terreno.edificio(h):
		if r <= 3:
			_log("info", "%s manca il tetto per un soffio e continua a scendere." % nome(a))
			return "ancora"
		var r2 := d10()
		if r <= 7:
			esito = "buono" if r2 <= 4 else "ferito"
			dove = _vicino_scoperto(h, false)
		elif r == 8:
			esito = "ferito" if r2 <= 4 else "incapacitato"
			dove = _vicino_scoperto(h, r2 > 4)
		else:
			esito = "incapacitato" if r2 <= 4 else "ucciso"
			dove = _vicino_scoperto(h, true)
	else:
		if r >= 5 and r <= 8:
			esito = "ferito" if d10() >= 6 else "buono"
		elif r == 9:
			var r3 := d10()
			esito = "ferito" if r3 <= 4 else "incapacitato"
			dove = _vicino_scoperto(h, r3 > 4)
	a.hex = dove
	match esito:
		"buono":
			_log("info", "%s atterra bene in %s." % [nome(a), dove])
		"ferito":
			_log("danno", "%s atterra male in %s ed è ferito." % [nome(a), dove])
			_applica_danno(a, "W", {})
		"incapacitato":
			_log("danno", "%s atterra male in %s ed è incapacitato." % [nome(a), dove])
			_applica_danno(a, "I", {})
			s.incapacitati_lancio.append(a.id)
		"ucciso":
			_uccidi(a, "atterraggio")
	return esito

func _op_tiro_invisibile(ctx: Dictionary) -> void:
	var a := u(str(ctx.get("ids", [""])[0])) if not ctx.get("ids", []).is_empty() else {}
	if a.is_empty() or not attivo(a):
		return
	s.sparati_lancio = true
	var base := T.base_per_distanza("bolt", 15)
	var mod := int(T.MOD_TERRENO.get("clear", [0, 0, 0])[T.indice_postura("crouching")])
	var prob := clampi(base - 2 + mod, 0, 8)
	var vera: String = a.postura
	a.postura = "crouching"
	risolvi_tiro({"lato": "cecchino", "WS": 0}, {"tipo": "bolt", "inceppata": false}, a, false, prob)
	if attivo(a):
		a.postura = vera

func _op_sopravvissuto() -> void:
	if s.unita.has("J"):
		_log("info", "Il sopravvissuto dell’aliante è già in gioco.")
		return
	var d := {"id": "J", "nome": "Sopravvissuto dell’aliante", "IN": 2, "PC": 4, "WS": 0, "DS": 2, "MPA": 2, "comandante": false,
		"porte": ["carbine"], "munizioni": {"carbine": 2, "pistol": 1}}
	var j := _nuovo_americano(d)
	j.stato = "attivo"
	j.hex = "A5"
	j.postura = "crouching"
	j.ferito = true
	j.consapevole = fase_round()
	j.pv_attivo_fine = 2
	s.unita["J"] = j
	_log("info", "Il sopravvissuto dell’aliante (J, già ferito) entra in A5: vale 2 PV se è attivo alla fine.")
	_fx("compare", {"id": "J", "a": "A5", "amico": true})

func _op_morte_lancio() -> void:
	if s.get("morte_lancio_fatta", false):
		_log("info", "Paragrafo già applicato: nessun effetto.")
		return
	var lista: Array = s.get("incapacitati_lancio", []).filter(func(id): return u(str(id)).stato == "incapacitato")
	if lista.is_empty():
		_log("info", "Nessun soldato incapacitato nel lancio: nessun effetto.")
		return
	s.morte_lancio_fatta = true
	_uccidi(u(str(lista[rng.randi_range(0, lista.size() - 1)])), "ferite del lancio")

## Togliere il paracadute: due azioni, accovacciati o in piedi.
func togli_paracadute(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a, true)
	if e != "":
		return _errore(e)
	if int(a.get("paracadute", 0)) <= 0:
		return _errore("Non ha il paracadute addosso.")
	if a.postura == "prone":
		return _errore("Per togliere il paracadute bisogna essere accovacciati o in piedi.")
	if a.panico:
		return _errore("Un soldato in preda al panico non riesce a togliersi il paracadute.")
	var t := _turno_di(a)
	if t.azione != "":
		return _errore("Hai già scelto un’azione.")
	a.paracadute = int(a.paracadute) - 1
	_log("azione", "%s armeggia con le cinghie del paracadute (%s)." % [nome(a), "tolto" if int(a.paracadute) == 0 else "ancora un’azione"])
	_termina_azione(a)
	_fine_comando()
	return OK

func apri_cassa(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	if not s.has("cassa") or s.cassa.stato != "chiusa" or s.cassa.hex != a.hex:
		return _errore("Nel suo esagono non c’è una cassa chiusa.")
	if a.postura != "crouching":
		return _errore("Per aprire la cassa bisogna essere accovacciati.")
	s.cassa.stato = "aperta"
	for tipo in s.cassa.armi:
		_lascia_oggetto(a.hex, {"tipo": tipo, "inceppata": false, "rotta": false, "preparata": false, "catturata": false})
	for k in s.cassa.munizioni:
		for i in int(s.cassa.munizioni[k]):
			_lascia_oggetto(a.hex, {"tipo": "mun:" + k})
	_log("azione", "%s apre la cassa delle armi: il contenuto si può prendere con «Equipaggiamento»." % nome(a))
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

## Disinnesco delle cariche di un ponte (Missione 4): quattro turni in tutto, anche di soldati diversi.
func disinnesca_ponte(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	if not ponti().has(a.hex) or not ponte_intatto(a.hex):
		return _errore("Bisogna essere su un ponte intatto.")
	var st := ponte_stato(a.hex)
	if st.get("catturato", false):
		return _errore("Il ponte è già stato catturato.")
	if s.fase == "operazioni":
		_log("azione", "%s stacca i fili delle cariche sotto il ponte in %s." % [nome(a), a.hex])
		evento_casuale({"hex": a.hex, "ids": [a.id]})
		st.disinnesco = 4
	else:
		st.disinnesco = int(st.get("disinnesco", 0)) + 1
		_log("azione", "%s lavora alle cariche del ponte in %s (%d/4)." % [nome(a), a.hex, int(st.disinnesco)])
	if int(st.get("disinnesco", 0)) >= 4 and ponte_intatto(a.hex):
		st.catturato = true
		_log("info", "Il ponte in %s è catturato intatto: i tedeschi non possono più farlo saltare." % a.hex)
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

## Purple Heart, Missione 13: prendere o piazzare esplosivi al plastico, far saltare un cannone costiero (un’azione).
func azione_ph(id: String, tipo: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	match tipo:
		"prendi":
			if not ph.nel_deposito_navale(a):
				return _errore("Gli esplosivi si prendono nel deposito della marina.")
			ph.prendi_esplosivi(a)
		"piazza":
			if int(a.get("esplosivi_ph", 0)) <= 0:
				return _errore("Non hai esplosivi al plastico.")
			ph.piazza_esplosivo_us(a)
		"cannone":
			var err: String = ph.fai_saltare_cannone(a)
			if err != "":
				return _errore(err)
		"chiuse":
			var err2: String = ph.apri_chiuse(a)
			if err2 != "":
				return _errore(err2)
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

func sgombra_blocco_ss(id: String) -> Dictionary:
	return azione_ss(id, "sgombra")

## Silver Star: esplosivo a tempo sulla chiatta, salita sulla chiatta, bazooka contro la chiatta.
func azione_ss(id: String, tipo: String, arg := "") -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	var err := ""
	match tipo:
		"esplosivo":
			err = ss.piazza_esplosivo(a)
		"chiatta":
			err = ss.sali_chiatta(a)
		"bazooka_chiatta":
			err = ss.bazooka_chiatta(a, arg)
		"sgombra":
			err = ss.m20.sgombra(a)
		"trasferisci":
			var parti := arg.split(">")
			err = ss.m20.trasferisci(a, parti[0], parti[1]) if parti.size() == 2 else "Trasferimento non valido."
		"bazooka_blocco":
			err = ss.m20.bazooka_blocco(a, arg)
		"motovedetta":
			err = ss.m21.sali_pb(a)
	if err != "":
		return _errore(err)
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

## Purple Heart: disinnesco di un esplosivo dei commando (due azioni; nelle Operazioni in un colpo solo, con un controllo Evento).
func disinnesca_esplosivo(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	if ph.esplosivo(a.hex) == 0:
		return _errore("Qui non c’è un esplosivo.")
	if s.fase == "operazioni":
		evento_casuale({"hex": a.hex, "ids": [a.id]})
		while ph.esplosivo(a.hex) > 0 and attivo(a):
			ph.disinnesca(a)
	else:
		ph.disinnesca(a)
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

# =================================================================== Missione 3: ponti, radio, staffette
func ponte_stato(h: String) -> Dictionary:
	if not s.has("ponti"):
		s.ponti = {}
	if not s.ponti.has(h):
		s.ponti[h] = {"distrutto": false, "attraversato": false, "controlli": 0, "cariche": 0, "carburante": false, "fuoco": false}
	return s.ponti[h]

func ponte_intatto(h: String) -> bool:
	return bool(terreno.esagoni.get(h, {}).get("ponte", false)) and not ponte_stato(h).distrutto

func ponti() -> Array:
	var out: Array = []
	for h in terreno.esagoni:
		if terreno.esagoni[h].get("ponte", false):
			out.append(h)
	out.sort()
	return out

func ponte_di_pietra(h: String) -> bool:
	if h in regola("ponti_pietra", []):
		return true
	return terreno.tipo(h) == "road" or terreno.esagoni.get(h, {}).get("t", "") == "road"

## Un tedesco che lascia un ponte dal lato opposto lo ha «attraversato» (paragrafi 251, 260, 275, 280).
func segna_passaggio_ponte(da: String, a: String) -> void:
	if ponti().has(da) and not ponti().has(a):
		var st := ponte_stato(da)
		if not st.attraversato:
			st.attraversato = true
			_log("info", "Un tedesco ha attraversato il ponte in %s." % da)

func distruggi_ponte(h: String, come: String) -> void:
	var st := ponte_stato(h)
	if st.distrutto:
		return
	st.distrutto = true
	s.modifiche[h] = "stream"
	terreno.imposta_modifiche(s.modifiche)
	_fx("esplosione", {"a": h, "grande": true})
	_log("combattimento", "Il ponte %s in %s è distrutto (%s)!" % ["di pietra" if ponte_di_pietra(h) else "di legno", h, come])
	for x in unita_in(h, "", false):
		if x.stato in ["attivo", "incapacitato", "catturato", "arreso"]:
			_uccidi(x, "crollo del ponte")
	for vid in s.get("veicoli", {}):
		var vv: Dictionary = s.veicoli[vid]
		if vv.hex == h and vv.stato == "attivo":
			veicoli.disabilita(vv, "precipitato nel fiume")

## La radio resta nell’edificio dove si è schierato il comandante: è presidiata se c’è un americano attivo.
func radio_presidiata() -> bool:
	if mo.radio_portata():
		return mo.radio_funziona()
	if ph.radio_portata():
		return ph.radio_funziona()
	if not bool(regola("radio", false)):
		return false
	var h: String = s.get("radio_hex", "")
	return h != "" and not unita_in(h, "us").is_empty()

func _jeep_di_squadra(esagoni_squadra: Array) -> void:
	var n: int = int(regola("jeep_n", 1))
	if n > 1 and not esagoni_squadra.is_empty():
		# Purple Heart 16: due jeep, ciascuna accanto a un gruppo diverso della squadra (si possono poi guidare dove si vuole).
		var gruppi: Array = []
		for h in esagoni_squadra:
			if gruppi.is_empty() or gruppi.all(func(x): return E.distanza(str(x), str(h)) > 6):
				gruppi.append(str(h))
		for i in n:
			_una_jeep([gruppi[i % gruppi.size()]], "vjeep" if i == 0 else "vjeep%d" % (i + 1), i + 1)
		return
	_una_jeep(esagoni_squadra, "vjeep", 1)

func _una_jeep(esagoni_squadra: Array, vid: String, k: int) -> void:
	var migliore := ""
	var dmin := 999
	var area: Array = esagoni_ingresso() if int(regola("schieramento_ruscello", 0)) > 0 else []
	for h in terreno.esagoni:
		if terreno.tipo(h) != "clear" or ponti().has(h):
			continue
		if not area.is_empty() and not (h in area):
			continue
		var accanto_strada := false
		for v in E.vicini(h):
			if terreno.tipo(v) == "road":
				accanto_strada = true
		if not accanto_strada:
			continue
		for hs in esagoni_squadra:
			var d := E.distanza(h, str(hs))
			if d < dmin:
				dmin = d
				migliore = h
	if migliore == "":
		return
	var vj: Dictionary = veicoli.crea(vid, "jeep", migliore, "us")
	if k > 1 or int(regola("jeep_n", 1)) > 1:
		vj.nome = "Jeep %d" % k
	_log("info", "La %s della squadra è parcheggiata in %s, accanto alla strada." % ["jeep" if int(regola("jeep_n", 1)) == 1 else vj.nome, migliore])

func _op_offensiva() -> void:
	if s.get("offensiva", false):
		return
	s.offensiva = true
	_log("info", "Paragrafo 178 annotato sulla scheda: ora conta l’uscita da A13–A19 e la distruzione dei ponti.")

## Il tedesco controlla le cariche sul ponte: quattro turni in tutto.
func _op_controlla_ponte(ctx: Dictionary) -> void:
	var g: Dictionary = u(ctx.get("g", ""))
	var h: String = ctx.get("hex", "")
	if g.is_empty() or h == "" or not ponte_intatto(h):
		return
	var st := ponte_stato(h)
	st.controlli = int(st.controlli) + 1
	g.postura = "crouching"
	ia.ferma()
	_log("tedesco", "Il %s controlla il ponte in %s in cerca di cariche (%d/4)." % [nome(g), h, int(st.controlli)])
	if int(st.controlli) >= 4:
		st.cariche = 0
		_log("tedesco", "Il ponte in %s è stato controllato: eventuali cariche sono state disinnescate." % h)

func _op_artiglieria_esagoni(lista: Array) -> void:
	var h := str(lista[0])
	if lista.size() > 1:
		h = str(lista[d10("Esagono colpito dall’artiglieria")])
	_log("combattimento", "Un colpo d’artiglieria si abbatte su %s!" % h)
	_fx("esplosione", {"a": h, "grande": true})
	if ponti().has(h):
		distruggi_ponte(h, "artiglieria")
		return
	s.modifiche[h] = "rubble" if terreno.edificio(h) else "crater"
	terreno.imposta_modifiche(s.modifiche)
	for x in unita_in(h, "", false):
		if x.stato in ["attivo", "incapacitato", "catturato", "arreso"]:
			_uccidi(x, "artiglieria")
	for vid in s.get("veicoli", {}):
		var vv: Dictionary = s.veicoli[vid]
		if vv.hex == h and vv.stato == "attivo":
			veicoli.disabilita(vv, "artiglieria")

func _op_gomma_jeep() -> void:
	var jeep: Array = veicoli.tutti().filter(func(v): return v.lato == "us" and v.modello == "jeep" and v.stato == "attivo")
	if jeep.is_empty():
		_log("info", "Nessuna jeep in gioco: nessun effetto.")
		return
	var v: Dictionary = jeep[rng.randi_range(0, jeep.size() - 1)]
	if int(v.get("forature", 0)) >= 1:
		v.forature = 2
		v.gomme = false
		_log("combattimento", "La %s fora di nuovo: non c’è più la ruota di scorta, resta ferma." % v.nome)
		return
	v.forature = 1
	v.gomme = false
	v.ruota_azioni = 0
	_log("combattimento", "La %s fora una gomma! Per montare la scorta serve un soldato nel suo esagono: «Cambia la ruota» (10 azioni nei Round, due controlli Evento nelle Operazioni)." % v.nome)

func ruota_da_cambiare(a: Dictionary) -> bool:
	for x in veicoli.tutti():
		if x.hex == a.hex and x.lato == "us" and x.modello == "jeep" and not x.gomme and int(x.get("forature", 0)) == 1:
			return true
	return false

## Lavoro sulla ruota: nelle Operazioni costa due controlli Evento, nei Round un turno vale le azioni del soldato.
func cambia_ruota(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var err := _azione_semplice(a)
	if err != "":
		return _errore(err)
	var v: Dictionary = {}
	for x in veicoli.tutti():
		if x.hex == a.hex and x.modello == "jeep" and not x.gomme and int(x.get("forature", 0)) == 1:
			v = x
	if v.is_empty():
		return {"ok": false, "errore": "Nessuna jeep con la gomma a terra in questo esagono."}
	if fase_round():
		v.ruota_azioni = int(v.get("ruota_azioni", 0)) + effettivo_mpa(a)
		_log("azione", "%s lavora alla ruota della jeep (%d/10 azioni)." % [nome(a), int(v.ruota_azioni)])
	else:
		v.ruota_azioni = 10
		_log("azione", "%s monta la ruota di scorta della jeep." % nome(a))
		evento_casuale({"hex": a.hex, "ids": [a.id]})
		evento_casuale({"hex": a.hex, "ids": [a.id]})
	if int(v.ruota_azioni) >= 10:
		v.gomme = true
		_log("info", "La ruota di scorta è montata: la jeep può ripartire.")
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

func _op_pc_sequenza(o: Dictionary, ctx: Dictionary) -> void:
	var fatto := false
	for passo in o.passi:
		var h := str(passo[0])
		var visti: Array = americani_attivi_in_mappa().filter(func(a): return terreno.vede(a.hex, h, a.postura, "standing"))
		if visti.is_empty():
			continue
		fatto = true
		for a in visti:
			if controllo_pc(a, int(o.mod), "esagono " + h):
				ctx.indicato = h
				ctx.ultimo_pc = a.id
				_esegui(passo[1], ctx)
				return
	if not fatto:
		_log("info", "Nessun soldato vede gli esagoni da controllare.")
	_esegui(o.nessuno, ctx)

func _op_pc_entro(o: Dictionary, ctx: Dictionary) -> void:
	for a in americani_attivi_in_mappa():
		if E.distanza(a.hex, str(o.hex)) <= int(o.dist) and controllo_pc(a, int(o.mod)):
			ctx.ultimo_pc = a.id
			_esegui(o.any, ctx)
			return

## Paragrafo 258: il Panzer IV perde un cingolo se nel Round precedente si è mosso di 4+ esagoni.
func _op_cingolo_55() -> void:
	var g := u("g55")
	if g.is_empty() or not attivo(g):
		_log("info", "Il carro 55 non è in gioco: nessun effetto.")
		return
	var v: Dictionary = veicoli.di(g)
	var prec := str(int(s.get("ultimo_round", 0)) if not fase_round() else int(s.round.get("n", 0)) - 1)
	if not v.is_empty() and int(v.get("mossi", {}).get(prec, 0)) >= 4:
		v.cingolo = true
		_log("combattimento", "Il Panzer IV perde un cingolo: non si muoverà più.")
	else:
		_log("info", "Il Panzer IV non si è mosso abbastanza: nessun effetto.")

## Staffette del comando di battaglione (266: carta 01 «J», 271: carta 08 «K»).
const STAFFETTE := {
	1: {"id": "J", "nome": "Staffetta", "IN": 3, "PC": 5, "WS": -1, "DS": 2, "MPA": 3, "comandante": false,
		"porte": ["sar"], "munizioni": {"sar": 2}},
	8: {"id": "K", "nome": "Staffetta", "IN": 1, "PC": 2, "WS": -2, "DS": 0, "MPA": 3, "comandante": false,
		"porte": ["pistol"], "munizioni": {"pistol": 1}},
}

func _op_staffetta(carta: int) -> void:
	var d: Dictionary = STAFFETTE[carta]
	if s.unita.has(d.id):
		_log("info", "La staffetta è già in gioco.")
		return
	var st := _nuovo_americano(d)
	st.stato = "attivo"
	st.hex = "A17"
	st.staffetta = carta
	if fase_round():
		st.consapevole = true
	s.unita[d.id] = st
	_log("info", "Una staffetta del comando di battaglione (%s) entra in A17." % d.id)
	_fx("compare", {"id": d.id, "a": "A17", "amico": true})
	_controlla_staffette()

## Effetti delle carte americane 01 e 08 (solo Missione 3).
func _controlla_staffette() -> void:
	if numero != 3 or s.fase == "fine":
		return
	var j := u("J")
	if not j.is_empty() and attivo(j) and in_mappa(j) and not j.get("verificata", false):
		for a in unita_in(j.hex, "us"):
			if a.get("comandante", false) and a.id != "J":
				j.verificata = true
				_log("info", "La staffetta J raggiunge %s con il messaggio del battaglione." % nome(a))
				leggi("178", {"hex": j.hex, "ids": ["J"]})
				break
	var k := u("K")
	if k.is_empty() or k.get("verificata", false):
		return
	if k.stato in ["morto", "incapacitato", "uscito"]:
		k.verificata = true
		leggi("263", {"hex": "", "ids": []})
		return
	if not attivo(k):
		return
	for a in unita_in(k.hex, "us"):
		if a.get("comandante", false) and a.id != "K":
			k.verificata = true
			_log("info", "La staffetta K raggiunge %s: i soldati nell’esagono la squadrano." % nome(a))
			var ok := false
			for x in unita_in(k.hex, "us"):
				if x.id != "K" and controllo_pc(x, 0, "staffetta sospetta"):
					ok = true
			leggi("276" if ok else "281", {"hex": k.hex, "ids": [a.id]})
			return

func _op_staffetta_smascherata() -> void:
	var st := u("K")
	if st.is_empty():
		return
	st.stato = "rimosso"
	st.hex = ""
	_log("combattimento", "La falsa staffetta si toglie la vita.")

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
	if mo.in_galleria(ids) and not (rif.split(":")[-1] in mo.paragrafi_galleria()):
		_log("info", "%s: nella galleria si leggono solo i paragrafi T." % h)
		return
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
	if str(o.get("adv", "")) == "pc":
		o.adv = ctx.get("adv_pc", null)
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
		if missione.tedeschi[str(num)].has("carro"):
			veicoli.imbarca_carro(g, missione.tedeschi[str(num)].carro)
		elif missione.tedeschi[str(num)].has("veicolo"):
			var va: Dictionary = veicoli.crea("v%d" % num, str(missione.tedeschi[str(num)].veicolo), h, "de")
			va.pv_distrutto = int(missione.tedeschi[str(num)].get("pv_veicolo", 0))
			veicoli.sali(g, va)
			s.ingresso_auto = h
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
	if s.get("atterraggio", false):
		# Lancio (Missione 4): si annotano le attivazioni; i Round iniziano dopo tutti i controlli.
		s.attivazioni_lancio.append({"ids": nuovi.map(func(x): return x.id), "adv": o.adv, "two": o.two, "us_two": bool(o.us_two)})
	elif s.fase == "operazioni":
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
	if int(d.get("esplosivi", 0)) > 0:
		g.esplosivi = int(d.esplosivi)
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
			if ph.m18.decisione_pendente():
				s.pausa = p
				_log("info", "Prima di proseguire devi prendere la decisione: tenere la posizione (992) o ripiegare (994).")
				aggiornata.emit()
				return
			_avvia_round()
		"azioni_tedesche", "azioni_sherman", "":
			_flusso()
		"fine_round":
			_fine_round()
	terreno.imposta_modifiche(s.modifiche)
	_controlla_fine_automatica()
	aggiornata.emit()

func _avvia_round() -> void:
	var r: Dictionary = s.round
	r.n = int(r.n) + 1
	s.round_tot = int(s.get("round_tot", 0)) + 1
	mo.inizio_round()
	ph.inizio_round()
	ss.inizio_round()
	r.sparato_prec = r.get("sparato", [])
	r.sparato = []
	r.turni_avviati = []
	r.treno_mosso = []
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
	s.erase("mo_consapevoli")
	# 2. Evento (non nel Round 1).
	if r.n >= 2 and not mo.salta_evento() and not ph.salta_evento():
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
		if a.get("artiglieria", false) or (s.get("mo_consapevoli", false) and (attivo(a) or a.stato == "fuori")) \
				or (r.n == 2 and bool(regola("allerta", false))):
			a.consapevole = true
			righe.append({"id": a.id, "esito": "auto"})
			continue
		if a.stato == "fuori" and r.n == 1 and not bool(regola("sveglia", false)):
			righe.append({"id": a.id, "esito": "fuori"})
			continue  # 6/10: fuori mappa durante il Round 1
		if r.n == 1 and (r.get("tutti_consapevoli", false) or (str(r.get("consapevoli_vede", "")) != "" and attivo(a) and terreno.vede(a.hex, str(r.consapevoli_vede), a.postura, "standing"))):
			a.consapevole = true
			righe.append({"id": a.id, "esito": "auto"})
			continue
		if a.id == auto_id and r.n == 1:
			a.consapevole = true
			_log("info", "%s è automaticamente consapevole." % nome(a))
			righe.append({"id": a.id, "esito": "auto"})
			continue
		if a.id == str(r.get("inconsapevole_auto", "")) and r.n == 1:
			_log("info", "%s è automaticamente inconsapevole in questo Round." % nome(a))
			righe.append({"id": a.id, "esito": "auto_no"})
			continue
		if a.stato == "attivo" and a.hex == "" :
			continue
		if r.n == 1 and not r.get("consapevolezza_libera", false):
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
	# Purple Heart 16 «In allerta»: nel primo Round è in comando chi è consapevole, nel secondo tutti.
	if bool(regola("allerta", false)) and fase_round():
		var nr := int(s.round.get("n", 0))
		if nr == 1 and un.get("consapevole", false):
			return true
		if nr == 2:
			return true
	if un.get("comando_r1", false) and fase_round() and int(s.round.get("n", 0)) == 1:
		return true
	var tot := 0
	for o in americani():
		if not (attivo(o) or o.stato == "fuori") or o.get("carro_us", false):
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
		var comando: bool = in_comando(a) or bool(a.get("carro_us", false))
		var es: Dictionary = ph.berserk.turni(a, mo.turni_artiglieria(a, T.esito_turni(int(a.IN), du, true, comando, a.ferito)))
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
		var es: Dictionary = ph.turni_tedesco(g, mo.turni_tedesco(g, T.esito_turni(int(g.IN), dt, false, true, g.ferito)))
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
		if int(a.turni) == c[0] and a.slot == "turni" and (attivo(a) or a.stato == "fuori") and not ph.agisce_da_solo(a) and not ss.agisce_da_solo(a):
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
		_avvia_turni(int(c[0]))
		if s.fase != "round" or s.pausa != "":
			return
		c = casella_attuale()
		if not c.is_empty():
			ph.casella_treno(c)
			if s.fase != "round" or s.pausa != "":
				return
			c = casella_attuale()
		if c.is_empty():
			continue
		if c[1] == "us":
			# Missione 18: gli Sherman non ancora ai tuoi ordini agiscono da soli, all’inizio della casella.
			if ph.turni_automatici(c[0]) or ss.turni_automatici(c[0]):
				if s.fase == "round" and s.pausa == "":
					s.pausa = "azioni_sherman"
				return
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

## Inizio dei turni del Round (la pista ha il turno «2» e poi il turno «1»): effetti che avvengono prima di ogni azione.
func _avvia_turni(fino_a: int) -> void:
	if not s.has("round") or s.round.is_empty():
		return
	if not s.round.has("turni_avviati"):
		s.round.turni_avviati = []
	for tn in [2, 1]:
		if tn < fino_a or tn in s.round.turni_avviati:
			continue
		s.round.turni_avviati.append(tn)
		ph.inizio_turno(tn)

func _consuma_turno(x: Dictionary) -> void:
	x.turni = maxi(0, int(x.turni) - 1)
	if x.turni == 0 and x.slot == "turni":
		x.slot = "completo"

func _fine_round() -> void:
	_avvia_turni(0)
	ph.casella_treno([])
	_canoe_forate()
	ss.fine_round()
	_passo("fine_round", {"n": int(s.round.n)})
	s.ultimo_round = int(s.round.n)
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
	if tedeschi_attivi().is_empty() and not ph.round_obbligati():
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
		a.paracadute = 0
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
	_controlla_staffette()
	if s.has("bunker"):
		controlla_bunker()
	_controlla_fine_automatica()
	aggiornata.emit()

func puo_agire(a: Dictionary, consenti_paracadute := false) -> String:
	if s.fase == "fine":
		return "La missione è terminata."
	if s.pausa != "":
		return "Premi «Continua»."
	if a.is_empty():
		return "Nessun soldato scelto."
	if not (attivo(a) or a.stato == "fuori"):
		return "%s non può agire." % nome(a)
	if ph.m18.sherman_ia(a):
		return "Lo Sherman %s non è ai tuoi ordini: muove e spara secondo i suoi paragrafi." % a.id
	if ss.agisce_da_solo(a):
		return "%s non è ai tuoi ordini: agisce secondo i suoi paragrafi." % nome(a)
	if a.get("berserk", false) and attivo(a):
		return "%s è fuori di testa: agisce da solo finché un compagno non lo placca." % nome(a)
	if a.get("legato", false):
		return "%s è legato: un compagno nello stesso esagono deve slegarlo." % nome(a)
	if s.fase == "round":
		if _azione_in_corso(a):
			return ""  # regola 6/6: chi ha attivato un tedesco con la propria azione la porta a termine
		if not (a in americani_di_turno()):
			return "Non è il turno di %s." % nome(a)
		var t: Dictionary = s.turno
		if not t.is_empty() and t.id != a.id:
			return "%s sta ancora agendo." % nome(u(t.id))
		if int(a.get("paracadute", 0)) > 0 and not consenti_paracadute:
			return "%s deve prima togliersi il paracadute." % nome(a)
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
	var e := puo_agire(a, true)
	if e != "":
		return _errore(e)
	if a.hex == "":
		return _errore("Il soldato non è ancora sulla mappa.")
	if a.get("carro_us", false):
		return _errore("Lo Sherman non cambia postura.")
	if a.postura == postura:
		return _errore("È già %s." % T.NOMI_POSTURA[postura])
	var e_acqua: String = ss.cambia_postura(a, postura)
	if e_acqua != "-":
		if e_acqua != "":
			return _errore(e_acqua)
		_fine_comando()
		return OK
	if postura == "prone" and terreno.tipo(a.hex) == "stream" and not a.sul_ponte:
		return _errore("Nel ruscello non ci si può sdraiare.")
	if postura == "crouching" and terreno.tipo(a.hex) == "stream" and not a.sul_ponte:
		return _errore("Nel ruscello si sta soltanto in piedi.")
	if terreno.tipo(a.hex) == "cliff" and postura != "crouching":
		return _errore("Nel dirupo si sta soltanto accovacciati.")
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
		return _costo_ingresso(verso) + mo.costo_extra(a, verso)
	var c := terreno.costo_movimento(da_hex, verso)
	c = ss.costo_passo(a, da_hex, verso, c)
	return c + mo.costo_extra(a, verso) if c >= 0 else c

func _costo_ingresso(h: String) -> int:
	match terreno.tipo(h):
		"rough", "brush", "woods", "rubble", "stream", "ford":
			return 2
	return 1

func _verifica_passo(a: Dictionary, verso: String, silenzioso := false) -> String:
	if piano(a) > 0 and verso != a.hex:
		return "%s è al piano superiore: prima deve scendere le scale." % nome(a)
	if a.get("sotto_ponte", false):
		return "%s è sotto il ponte: prima deve risalire (2 PM)." % nome(a)
	if ph != null and ph.pezzo_treno_in(verso) >= 0:
		return "Non si entra in un esagono occupato dal treno."
	var e_mo: String = mo.verifica_passo(a, verso)
	if e_mo != "":
		return e_mo
	var e_ss: String = ss.verifica_passo(a, verso)
	if e_ss != "":
		return e_ss
	if bool(regola("xxx", false)) and riferimento(verso) == "XXX":
		return "Esagono vietato (XXX sulla carta)."
	var veic: Dictionary = veicoli.di(a)
	if veicoli.attivo(veic):
		if not veicoli.e_autista(a):
			return "Per muoversi a piedi bisogna prima scendere dal veicolo."
		if not E.adiacenti(a.hex, verso):
			return "Si può entrare solo in un esagono adiacente."
		if veic.get("immobilizzato", false):
			return "Il veicolo è immobilizzato."
		var cv: int = veicoli.costo(veic, a.hex, verso)
		if cv < 0:
			return "Il veicolo non può entrare in quell’esagono."
		if veicoli.e_canoa(veic) and not canoa_pronta(veic) and terreno.esagoni.get(verso, {}).get("t", "") == "stream":
			return "Con un solo soldato attivo a bordo la canoa può solo andare a riva (un esagono di terra accanto)."
		if veicoli.e_canoa(veic) and veic.hex != a.hex:
			return "La canoa non è nell’esagono del soldato."
		if s.fase == "round":
			var tv: Dictionary = s.turno if (not s.turno.is_empty() and s.turno.id == a.id) else {}
			if tv.is_empty() or tv.azione != "muovi":
				return "" if silenzioso else "Scegli prima «Guida»."
			if cv > int(tv.mp):
				return "Punti movimento del veicolo insufficienti (servono %d, restano %d)." % [cv, int(tv.mp)]
		return ""
	if a.postura == "prone" and not ss.nuota(a):
		return "Un soldato prono non può muoversi."
	var da_hex: String = a.hex
	if da_hex != "" and not E.adiacenti(da_hex, verso):
		return "Si può entrare solo in un esagono adiacente."
	if da_hex == "" and not e_ingresso(verso):
		return "Si entra %s." % testo_ingresso()
	var costo := _costo_passo(a, da_hex, verso)
	if costo < 0:
		return "Non si può attraversare un muro senza aperture."
	if terreno.tipo(verso) == "cliff" and a.postura != "crouching":
		return "Nei dirupi si entra solo accovacciati."
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
	if veicoli.attivo(veic_m) and not veicoli.e_autista(primo):
		# Nel gruppo c’è chi guida: il gruppo segue lui.
		for id in ids:
			if veicoli.e_autista(u(str(id))):
				primo = u(str(id))
				veic_m = veicoli.di(primo)
				break
	if veicoli.e_canoa(veic_m) and not veicoli.e_autista(primo):
		return _errore("La canoa la muove il primo soldato a bordo; per andare a terra bisogna prima spiaggiarla e scendere.")
	for id in ids:
		var ax := u(str(id))
		if str(ax.get("veicolo", "")) != str(primo.get("veicolo", "")) and veicoli.attivo(veicoli.di(ax)) and not veicoli.e_autista(primo):
			return _errore("%s è a bordo della %s: si muove con il suo mezzo, non insieme a chi va a piedi." % [nome(ax), veicoli.di(ax).nome])
	if s.get("bunker", {}).has(verso) and not s.bunker[verso].sfondata and not veicoli.attivo(veic_m):
		return _errore("Nel bunker si entra solo dalla porta sfondata.")
	var altri_mezzi: Array = []
	if veicoli.attivo(veic_m) and veicoli.e_autista(primo):
		# Nelle Operazioni più canoe (o mezzi) nello stesso esagono si muovono insieme se si sposta il gruppo.
		var nuovi_ids: Array = veicoli.occupanti(veic_m).map(func(x): return x.id)
		if s.fase != "round":
			for id in ids:
				var ax := u(str(id))
				var vx: Dictionary = veicoli.di(ax)
				if veicoli.attivo(vx) and vx.id != veic_m.id and not (vx in altri_mezzi) and vx.hex == veic_m.hex:
					if veicoli.e_canoa(vx) and not canoa_pronta(vx):
						continue
					if veicoli.costo(vx, vx.hex, verso) < 0:
						continue
					altri_mezzi.append(vx)
					for x in veicoli.occupanti(vx):
						nuovi_ids.append(x.id)
		ids = nuovi_ids
	elif s.fase == "round" and ids.size() > 1:
		return _errore("Nei Round ogni soldato si muove con la propria azione.")
	var e2 := _verifica_passo(primo, verso)
	if e2 != "":
		return _errore(e2)
	var da_hex: String = primo.hex
	if mo.impigliato(ids):
		if fase_round() and not s.turno.is_empty():
			_termina_azione(primo)
		_fine_comando()
		return OK
	var costo := _costo_passo(primo, da_hex, verso)
	var controllo_veicolo := false
	if s.fase == "round" and veic_m.get("modello", "") == "scialuppa" and not _turno_di(primo).has("rematore"):
		# 718: la scialuppa si rema in due che agiscono insieme.
		var c_r: Array = casella_attuale()
		var secondo := {}
		for x in veicoli.occupanti(veic_m):
			if x.id != primo.id and attivo(x) and not c_r.is_empty() and int(x.turni) == int(c_r[0]) and x.slot == "turni":
				secondo = x
				break
		if secondo.is_empty():
			return _errore("Per remare serve un secondo soldato a bordo che possa agire ora.")
		_consuma_turno(secondo)
		_turno_di(primo).rematore = secondo.id
		_log("azione", "%s e %s remano insieme." % [nome(primo), nome(secondo)])
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
		_controlla_tanica(a, da_hex, verso)
		a.hex_prec = a.hex
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
		mina_anticarro(veic_m, verso)
		for vx in altri_mezzi:
			if dv >= 0:
				vx.fronte = dv
			vx.hex = verso
		if altri_mezzi.is_empty():
			_log("azione", "La %s, guidata da %s, entra in %s (%s)." % [veic_m.nome, nome(primo), verso, terreno.nome_tipo(verso)])
		else:
			var nomi_m: Array = [veic_m.nome] + altri_mezzi.map(func(x): return x.nome)
			_log("azione", "%s entrano insieme in %s (%s)." % [", ".join(nomi_m), verso, terreno.nome_tipo(verso)])
	else:
		_log("azione", "%s %s in %s (%s)." % [", ".join(nomi), "entra" if nomi.size() == 1 else "entrano", verso, terreno.nome_tipo(verso)])
	_fx("muovi", {"ids": mossi, "da": da_hex, "a": verso})
	if veicoli.attivo(veic_m) and not veicoli.e_canoa(veic_m):
		veicoli.investimento(veic_m, verso)
		if not veicoli.attivo(veic_m) or veic_m.get("fermo", false):
			veic_m.fermo = false
			if not s.turno.is_empty():
				s.turno.mp = 0
	if controllo_veicolo and veicoli.attivo(veic_m):
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
	if s.fase == "round" and not s.turno.is_empty() and not unita_in(verso, "de").is_empty():
		s.turno.fermo = true
	mo.dopo_ingresso(ids, verso)
	if terreno.dirupi == "ripidi" and (terreno.tipo(verso) == "cliff" or (da_hex != "" and terreno.tipo(da_hex) == "cliff")):
		for id in ids:
			if attivo(u(str(id))) and veicoli.di(u(str(id))).is_empty():
				controllo_appiglio(u(str(id)))
	if ph.in_fiamme(verso):
		# 414.2: il deposito in fiamme si attraversa con un controllo di percezione e si finisce proni oltre.
		for id in ids:
			var af := u(str(id))
			if attivo(af) and veicoli.di(af).is_empty():
				ph.attraversa_fiamme(af, da_hex, "")
		if not s.turno.is_empty():
			s.turno.mp = 0
			s.turno.cambio_libero = false
		var oltre: Array = ids.filter(func(i): return attivo(u(str(i))))
		if not oltre.is_empty():
			_ingresso(u(str(oltre[0])).hex, oltre, false)
	else:
		_ingresso(verso, ids, sul_ponte)
	for id in ids:
		ss.dopo_ingresso_acqua(u(str(id)))
	ss.dopo_mossa_operazioni()
	ss.m20.dopo_movimento(ids)
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
	for bx in unita_in(h, "us"):
		if bx.get("berserk", false):
			for id in vivi:
				if ph.berserk.placca(u(str(id)), bx):
					break
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
	if azione == "muovi" and (mo.prepara(a) or mo.esci_bloccato(a)):
		_termina_azione(a)
		_fine_comando()
		return OK
	match azione:
		"muovi":
			if veicoli.e_autista(a):
				var veic: Dictionary = veicoli.di(a)
				if veic.get("fermo", false):
					return _errore("Il veicolo è fermo per un incidente in questo turno.")
				var m: Dictionary = veicoli.MODELLI[veic.modello]
				t.azione = "muovi"
				t.mp = int(m.veloce) if veic.gomme and not ss.m20.solo_piano(veic) else int(m.lenta)
				if int(veic.get("forature", 0)) > 0 and not veic.gomme:
					return _errore("La jeep ha una gomma a terra: prima va montata la ruota di scorta.")
				t.mp_lenta = int(m.lenta)
				t.spesi = 0
				_log("azione", "%s guida la %s (lenta %d PM, veloce %d PM: oltre la lenta si rischia l’incidente)." % [nome(a), veic.nome, int(m.lenta), int(t.mp)])
				_fine_comando()
				return OK
			if a.postura == "prone":
				return _errore("Prima alzati: un soldato prono non si muove.")
			t.azione = "muovi"
		"muovi_spara":
			if veicoli.attivo(veicoli.di(a)):
				return _errore("A bordo di un mezzo: prima scendi (o guida).")
			if armi_da_fuoco(a).filter(func(x): return x.tipo != "bazooka").is_empty():
				return _errore("Nessuna arma pronta al tiro.")
			t.azione = "muovi_spara"
			t.mp = mini(int(t.mp), int(effettivo_mpa(a)) / 2)
		"carica":
			if veicoli.attivo(veicoli.di(a)):
				return _errore("A bordo di un mezzo: prima scendi (o guida).")
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
	if veicoli.e_canoa(veic) and not veicoli.spiaggiata(veic):
		return _errore("Si scende solo da una canoa spiaggiata: prima portala a riva.")
	if a.get("autista_camion", false) and veicoli.attivo(veic):
		return _errore("L’autista del camion non può scendere.")
	var e_conv: String = ss.m20.verifica_scendi(a)
	if e_conv != "":
		return _errore(e_conv)
	if s.fase == "round":
		var t := _turno_di(a)
		if t.azione == "":
			# Scendere è l’inizio di un’azione di movimento a piedi.
			t.azione = "muovi"
			t.mp = int(effettivo_mpa(a))
			_log("azione", "%s: movimento." % nome(a))
		elif not (t.azione in ["muovi", "muovi_spara"]):
			return _errore("Nei Round si scende durante un’azione di movimento (costa 1 PM).")
		elif int(t.mp) < 1 and not veicoli.e_autista(a):
			return _errore("Servono ancora 1 punto movimento per scendere.")
		if veicoli.e_autista(a):
			# Chi guidava prosegue a piedi con i suoi PM, meno quelli già spesi col mezzo.
			t.mp = maxi(0, mini(int(t.mp), int(effettivo_mpa(a)) - int(t.get("spesi", 0))))
			t.erase("mp_lenta")
		t.mp = maxi(0, int(t.mp) - 1)
	veicoli.scendi(a)
	a.postura = "crouching"
	_log("azione", "%s scende dalla %s." % [nome(a), veic.nome])
	_fine_comando()
	return OK

func passa(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a, true)
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
		return {"ok": false, "motivo": "sott’acqua non si spara" if ss.sott_acqua(tiratore) else "da prono non si spara"}
	var dist := E.distanza(tiratore.hex, bersaglio.hex)
	if dist > 0 and not vede_unita(tiratore, bersaglio):
		return {"ok": false, "motivo": terreno.vista(tiratore.hex, bersaglio.hex, tiratore.postura, bersaglio.postura, piano(tiratore), piano(bersaglio)).motivo}
	if dist == 0 and piano(tiratore) != piano(bersaglio):
		return {"ok": false, "motivo": "è su un altro piano"}
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
	var e_ss: String = ss.blocca_tiro(tiratore, tipo, mirato)
	if e_ss != "":
		return {"ok": false, "motivo": e_ss}
	if arma.get("jagd", false):
		# Purple Heart 599: cannone e mitragliatrice del Jagdpanther, armi di squadra verso il fronte (est).
		if not ph.m18.fronte_jagd(tiratore, bersaglio.hex):
			return {"ok": false, "motivo": "fuori dall’arco frontale del Jagdpanther"}
		if ph.m18.jagd().get("equipaggio", []).size() < 2:
			return {"ok": false, "motivo": "servono due serventi a bordo"}
	if mirato and tiratore.get("lato", "") == "us" and bool(T.ARMI[tipo].get("squadra", false)) and not tiratore.get("carro_us", false):
		var compagni := unita_in(tiratore.hex, "us").filter(func(x): return x.id != tiratore.id and not x.panico)
		if arma.get("solo_passeggero1", false):
			var vj: Dictionary = veicoli.di(tiratore)
			compagni = veicoli.occupanti(vj).filter(func(x): return x.id != tiratore.id and not x.panico and attivo(x) and str(vj.occupanti[0]) != x.id)
		if compagni.is_empty():
			return {"ok": false, "motivo": "da solo la mitragliatrice spara solo di rapido"}
	var mods: Array = []
	var ws := int(tiratore.WS) - (1 if arma.get("catturata", false) else 0)
	if arma.get("jagd", false):
		ws = -1
	if ws != 0:
		mods.append(["abilità", ws])
	if not mirato:
		mods.append(["tiro rapido", -2])
	if tiratore.ferito:
		mods.append(["tiratore ferito", -1])
	ss.mod_tiro(tiratore, bersaglio, mods)
	if veicoli.attivo(veicoli.di(tiratore)) and not tiratore.get("carro_us", false) and not veicoli.e_canoa(veicoli.di(tiratore)):
		mods.append(["tiratore in auto", -2])
	if mirato and T.ARMI[tipo].get("auto", false):
		var extra := unita_in(bersaglio.hex, bersaglio.lato).size() - 1
		if extra > 0:
			mods.append(["bersagli multipli", extra])
	var ip := T.indice_postura(bersaglio.postura)
	var th := terreno.tipo(bersaglio.hex)
	var veic_b: Dictionary = veicoli.di(bersaglio)
	if str(tiratore.get("barca", "")) != "":
		mods.append(["dal battello d’assalto", -2])
	if bersaglio.get("sotto_ponte", false):
		# Purple Heart 17: sotto il ponte si conta accovacciato all’interno (apertura non adiacente; adiacente se si spara dal ponte
		# dello stesso esagono; allo scoperto se si è sotto lo stesso ponte).
		var ipc := T.indice_postura("crouching")
		if tiratore.get("sotto_ponte", false) and tiratore.hex == bersaglio.hex:
			var mcs: int = int(T.MOD_TERRENO.get("clear", [0, 0, 0])[ipc])
			if mcs != 0:
				mods.append(["sotto lo stesso ponte (accovacciato allo scoperto)", mcs])
		else:
			var mi: int = (T.MOD_INTERNO_VICINO if tiratore.hex == bersaglio.hex else T.MOD_INTERNO_LONTANO)[ipc]
			mods.append(["sotto il ponte (come in un interno)", mi])
	elif bersaglio.get("cane", false):
		# Purple Heart 391: −3 a chi spara a un cane, qualunque sia il terreno.
		mods.append(["cane da guardia", -3])
	elif str(bersaglio.get("barca", "")) != "" and tipo == "bazooka":
		# 432.6: il bazooka spara al battello, mezzo piccolo allo scoperto.
		mods.append(["battello d’assalto, mezzo piccolo allo scoperto", int(T.MOD_VEICOLO.get("clear", [2, 3])[0])])
	elif str(bersaglio.get("barca", "")) != "":
		# 432.5: chi è nel battello conta accovacciato allo scoperto.
		ip = T.indice_postura("crouching")
		var mb: int = int(T.MOD_TERRENO.get("clear", [0, 0, 0])[ip])
		if mb != 0:
			mods.append(["nel battello (accovacciato allo scoperto)", mb])
	elif veic_b.get("modello", "") == "scialuppa" and veicoli.attivo(veic_b):
		# Purple Heart 718: nella scialuppa si è accovacciati in copertura.
		ip = T.indice_postura("crouching")
		var msc: int = int(T.MOD_TERRENO.get("cover", [0, 0, 0])[ip])
		if msc != 0:
			mods.append(["nella scialuppa (accovacciato in copertura)", msc])
	elif veicoli.e_canoa(veic_b):
		# In canoa si conta accovacciati in terreno scoperto.
		ip = T.indice_postura("crouching")
		var mc: int = int(T.MOD_TERRENO.get("clear", [0, 0, 0])[ip])
		if mc != 0:
			mods.append(["in canoa (accovacciato allo scoperto)", mc])
	elif veicoli.attivo(veic_b):
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
	var veic_b: Dictionary = veicoli.di(bersaglio)
	if not veic_b.is_empty():
		veic_b.colpito_ss = true
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
	if not colpito:
		ph.tiro_mancato(bersaglio)
	if not colpito and str(tiratore.get("lato", "")) == "us" and str(bersaglio.get("barca", "")) != "" and tipo != "bazooka":
		ph.tiro_mancato_barca(bersaglio, tipo)
	fx.dado = r
	_log("dado", "Per colpire: serve 0–%d, esce %d → %s." % [int(p.prob), r, "COLPITO" if colpito else "mancato"])
	if not colpito and tiratore.get("lato", "") == "de" and veicoli.di(bersaglio).get("modello", "") == "scialuppa" and not veicoli.spiaggiata(veicoli.di(bersaglio)):
		# Purple Heart 718: un colpo che manca chi è nella scialuppa può forarla.
		var rp := d10()
		var pen := T.penetrazione(tipo, rp)
		var vsc: Dictionary = veicoli.di(bersaglio)
		_log("dado", "Il colpo finisce nella scialuppa: penetrazione %d → %s." % [rp, {"-": "nessuna", "L": "leggera", "M": "media", "H": "pesante"}[pen]])
		if pen == "L":
			var abordo: Array = veicoli.occupanti(vsc).filter(func(x): return attivo(x))
			if not abordo.is_empty():
				var ferito: Dictionary = abordo[rng.randi_range(0, abordo.size() - 1)]
				_applica_danno(ferito, "W", tiratore)
		elif pen != "-":
			_log("danno", "La scialuppa colpita affonda: chi è a bordo annega.")
			for x in veicoli.occupanti(vsc):
				veicoli.scendi(x)
				if attivo(x):
					_uccidi(x, "annegato con la scialuppa")
			vsc.stato = "distrutto"
			vsc.hex = ""
	elif not colpito and tiratore.get("lato", "") == "de" and veicoli.e_canoa(veicoli.di(bersaglio)) and not (veicoli.di(bersaglio).modello in ["chiatta", "scialuppa"]):
		var rc := d10()
		if rc % 2 == 0:
			var vc: Dictionary = veicoli.di(bersaglio)
			if not vc.get("forata", false):
				vc.forata = true
				_log("danno", "Il colpo buca la %s (%d): deve spiaggiare entro il Round o affonda." % [vc.nome.to_lower(), rc])
	if colpito and ss.colpito(tiratore, tipo, bersaglio, fx):
		pass
	elif colpito and tipo == "bazooka" and str(bersaglio.get("barca", "")) != "":
		ph.bazooka_su_barca(str(bersaglio.barca))
	elif colpito and veicoli.attivo(veicoli.di(bersaglio)) and not veicoli.e_canoa(veicoli.di(bersaglio)):
		veicoli.colpito(veicoli.di(bersaglio), tipo, tiratore, mirato, fx)
	elif colpito:
		var rd := d10()
		var lettera := T.lettera_danno(info.danni, rd)
		fx.dado_danno = rd
		fx.danno = _nome_danno(lettera)
		_log("dado", "Danno: %d → %s" % [rd, _nome_danno(lettera)])
		_applica_danno(bersaglio, lettera, tiratore)
		ss.dopo_danno(bersaglio, lettera)
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
		elif arma.get("jagd", false) and tipo == "cannone":
			ph.m18.sparato_jagd(arma)
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
	ss.dopo_danno(x, l)

func _applica_danno(x: Dictionary, l: String, fonte: Dictionary) -> void:
	if not attivo(x) and x.stato != "catturato":
		return
	if ph != null:
		ph.radio_colpita(x, l)
	if ph != null and x.get("sotto_ponte", false):
		ph.sotto_ponte_colpito(x, l)
		if not attivo(x):
			return
	if l == "P" and (x.get("cane", false) or x.get("berserk", false)):
		_log("danno", "%s non va nel panico." % nome(x))
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

## Silver Star 6.1: controllo dell'appiglio salendo o scendendo un dirupo ripido. Con 9 (8–9 se ferito) un
## controllo di PC; se fallisce il soldato cade in un esagono vicino più basso, va nel panico e subisce un colpo di
## pistola; se cade in un altro dirupo ripete il controllo.
func controllo_appiglio(x: Dictionary) -> void:
	var r := d10()
	var soglia := 8 if x.ferito else 9
	_log("dado", "Appiglio di %s sul dirupo: %d%s" % [nome(x), r, " (sicuro)" if r < soglia else ""])
	if r < soglia:
		return
	for _i in 6:
		if controllo_pc(x, 0, "appiglio"):
			_log("info", "%s si riprende in tempo." % nome(x))
			return
		var q := terreno.quota(x.hex)
		var bassi: Array = E.vicini(x.hex).filter(func(v): return terreno.quota(v) < q and terreno.tipo(v) != "water" and terreno.costo_movimento(x.hex, v) >= 0)
		if bassi.is_empty():
			bassi = E.vicini(x.hex).filter(func(v): return terreno.quota(v) <= q and terreno.tipo(v) != "water")
		if bassi.is_empty():
			return
		var dove: String = bassi[d10() % bassi.size()]
		_log("danno", "%s perde l'appiglio e cade in %s." % [nome(x), dove])
		x.hex_prec = x.hex
		x.hex = dove
		_fx("muovi", {"ids": [x.id], "a": dove})
		_applica_danno(x, "P", {})
		var l := T.lettera_danno(T.ARMI.pistol.danni, d10())
		if l == "Q":
			l = "W"
		_applica_danno(x, l, {})
		if not attivo(x) or terreno.tipo(dove) != "cliff":
			return

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
	mo.colpito(x)
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
	mo.colpito(x)
	x.stato = "incapacitato"
	x.turni = 0
	x.slot = "inattivo"
	x.panico = false
	_log("danno", "%s è INCAPACITATO." % nome(x))
	_cade_prono(x)
	_fx("danno", {"id": x.id, "tipo": "incapacitato"})
	_dopo_perdita(x)

func _uccidi(x: Dictionary, come: String) -> void:
	mo.colpito(x)
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
	if int(x.get("documenti", 0)) > 0 and x.hex != "":
		_lascia_oggetto(x.hex, {"tipo": "documenti", "n": int(x.documenti)})
		_log("info", "I documenti che portava %s restano a terra in %s." % [nome(x), x.hex])
		x.documenti = 0
	if x.lato == "de":
		if int(x.num) == 34 and not mo.attiva() and not ss.attiva():
			cambia_condizione(4)
		if numero == 8 and int(x.num) in [3, 11] and int(s.condizione) == 1:
			cambia_condizione(2)
		var dx: Dictionary = missione.tedeschi.get(str(int(x.num)), {})
		if dx.has("pv_eliminato") and not x.get("pv_eliminato_dato", false):
			x.pv_eliminato_dato = true
			_pv(int(dx.pv_eliminato), "%s fuori combattimento" % nome(x))
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
	var dati: Dictionary = missione.tedeschi.get(str(int(g.num)), {})
	if dati.has("pv_cattura") and not (numero == 1 and int(g.num) == 34):
		_pv(int(dati.pv_cattura), "cattura del tedesco %d" % int(g.num))
	if int(g.num) == 34 and numero == 1:
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
	mo.dopo_tiro(a, arma, b)
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
	if veicoli.di(lanciatore).get("modello", "") == "scialuppa":
		return {"ok": false, "motivo": "dalla scialuppa non si lanciano granate o cariche"}
	if lanciatore.postura == "prone":
		return {"ok": false, "motivo": "da prono non si lancia"}
	if tipo == "satchel" and lanciatore.postura != "standing":
		return {"ok": false, "motivo": "la carica si lancia solo in piedi"}
	var dist := E.distanza(lanciatore.hex, h)
	if dist == 0 and terreno.ha_piani(h):
		dist = 1  # al piano di sopra o di sotto: conta come adiacente
	elif dist == 0:
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
	mo.esplosione(tipo, arrivo)
	ph.esplosione(tipo, arrivo)
	ss.esplosione(tipo, arrivo)
	if tipo == "satchel":
		_colpisci_installazione(arrivo)
		if s.get("bunker", {}).has(arrivo):
			s.bunker[arrivo].carica = true
			_log("combattimento", "La carica esplode dentro il bunker in %s." % arrivo)
	var presenti: Array = unita_in(arrivo, "", false).filter(func(x): return x.stato in ["attivo", "incapacitato", "catturato"])
	if terreno.ha_piani(arrivo):
		# Nel campanile esplode su un piano solo: quello dell’altro piano se lanciata dall’interno, altrimenti il pianterreno.
		var piano_scoppio: int = (1 - piano(lanciatore)) if arrivo == lanciatore.hex else 0
		presenti = presenti.filter(func(x): return piano(x) == piano_scoppio)
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
	if att.get("berserk", false):
		ws += 2
	ws = ss.mod_assalto(att, ws)
	if ws != 0:
		mods.append(["abilità", ws])
	if carica:
		mods.append(["carica", -3])
	if att.ferito:
		mods.append(["attaccante ferito", -2])
	var ws_d := int(dif.WS) + (2 if dif.get("berserk", false) else 0)
	var difesa_valida: bool = ws_d >= 1 and not dif.panico and (not dif.ferito or dif.get("berserk", false))
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
	if piano(b) != piano(a):
		return _errore("Il bersaglio è su un altro piano: prima bisogna salire o scendere le scale.")
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

## 717: un’azione di carico del camion in U14.
func carica_camion(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	var err: String = ph.carica_camion(a)
	if err != "":
		return _errore(err)
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

## 689: un compagno nello stesso esagono placca il soldato fuori di testa (un’azione).
func placca(id: String, bid: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	var b := u(bid)
	if b.is_empty() or not b.get("berserk", false) or b.hex != a.hex:
		return _errore("Qui non c’è nessuno da placcare.")
	ph.berserk.placca(a, b)
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

## Missione 18 (599): sale sul Jagdpanther da servire o ne scende (nei Round è un’azione).
func jagd_sali(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	var err: String = ph.m18.sali_jagd(a)
	if err != "":
		return _errore(err)
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

func jagd_scendi(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	ph.m18.scendi_jagd(a)
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
		var testo_o: String = T.ARMI.get(o.tipo, {}).get("nome", o.tipo) + (" (inceppata)" if o.get("inceppata", false) else "")
		if str(o.tipo) == "documenti":
			testo_o = "Documenti segreti"
		if str(o.tipo).begins_with("mun:"):
			var km := str(o.tipo).substr(4)
			testo_o = "Granata" if km == "granata" else ("Razzo per bazooka" if km == "bazooka" else "Caricatore: " + str(T.ARMI.get(km, {}).get("breve", km)))
		out.append({"da": "terra", "indice": i, "tipo": o.tipo, "testo": testo_o})
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
	if tipo == "documenti" and voce.da == "terra":
		var dv: Dictionary = s.oggetti[a.hex][int(voce.indice)]
		s.oggetti[a.hex].remove_at(int(voce.indice))
		a.documenti = int(a.get("documenti", 0)) + int(dv.get("n", 1))
		_log("azione", "%s raccoglie i documenti." % nome(a))
		if str(dv.get("par", "")) != "":
			leggi(str(dv.par), {"hex": a.hex, "ids": [a.id]})
		_chiudi_azione_semplice(a)
		_fine_comando()
		return OK
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
		if voce.da == "terra":
			s.oggetti[a.hex].remove_at(int(voce.indice))
			a.munizioni[k] = int(a.munizioni.get(k, 0)) + 1
			_log("azione", "%s prende: %s." % [nome(a), "una granata" if k == "granata" else "un caricatore (" + str(T.ARMI.get(k, {}).get("breve", k)) + ")"])
			_chiudi_azione_semplice(a)
			_fine_comando()
			return OK
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
		ph.uscita(a, da_u)
		a.stato = "uscito"
		a.hex = ""
		f.hex = ""
		_fx("sparisce", {"ids": [a.id, f.id], "da": da_u, "motivo": "uscito"})
		f.uscito = true
		a.uscito_offensiva = bool(s.get("offensiva", false))
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

## Purple Heart 718: la scialuppa a terra si porta con quattro uomini in piedi che agiscono insieme (2 esagoni per turno).
func portatori_scialuppa(a: Dictionary) -> Array:
	var v: Dictionary = veicoli.v("vscialuppa")
	if v.is_empty() or not veicoli.attivo(v) or a.hex != str(v.hex) or not veicoli.spiaggiata(v) or not veicoli.occupanti(v).is_empty():
		return []
	var c: Array = casella_attuale() if fase_round() else []
	var l: Array = [a]
	for x in unita_in(a.hex, "us"):
		if x.id == a.id or x.postura != "standing" or not veicoli.di(x).is_empty() or x.get("carro_us", false):
			continue
		if fase_round() and not (int(x.turni) == int(c[0]) and x.slot == "turni") and not (str(s.turno.get("id", "")) == a.id and x.id in s.turno.get("portatori", [])):
			continue
		l.append(x)
	return l.slice(0, 4) if l.size() >= 4 else []

func porta_scialuppa(id: String, verso: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := puo_agire(a)
	if e != "":
		return _errore(e)
	if a.postura != "standing":
		return _errore("Per portare la scialuppa bisogna essere in piedi.")
	var v: Dictionary = veicoli.v("vscialuppa")
	var port: Array = portatori_scialuppa(a)
	if port.is_empty():
		return _errore("Servono quattro uomini in piedi nell’esagono della scialuppa a terra%s." % (" che possano agire ora" if fase_round() else ""))
	if not E.adiacenti(str(v.hex), verso) or terreno.tipo(verso) in ["water", "stream"] or terreno.edificio(verso) or terreno.costo_movimento(str(v.hex), verso) < 0:
		return _errore("La scialuppa si porta solo in un esagono di terra adiacente (non in un edificio).")
	if s.fase == "round":
		var t := _turno_di(a)
		if t.azione == "":
			t.azione = "scialuppa"
			t.mp = 2
			t.portatori = port.map(func(x): return x.id)
			for x in port:
				if x.id != a.id:
					_consuma_turno(x)
			_log("azione", "%s porta la scialuppa insieme a %s." % [nome(a), ", ".join(port.filter(func(x): return x.id != a.id).map(func(x): return x.lettera))])
		elif t.azione != "scialuppa" or int(t.mp) <= 0:
			return _errore("In questo turno non si può più portare la scialuppa.")
		t.mp = int(t.mp) - 1
	var da: String = str(v.hex)
	v.hex = verso
	var ids: Array = port.map(func(x): return x.id)
	for x in port:
		x.hex = verso
	_log("azione", "La scialuppa è portata in %s." % verso)
	_fx("muovi", {"ids": ids, "da": da, "a": verso, "veicolo": v.id})
	_ingresso(verso, ids, false)
	if s.fase == "round" and not s.turno.is_empty() and s.turno.id == a.id and int(s.turno.mp) <= 0:
		_termina_azione(a)
	_fine_comando()
	return OK

## Esce dalla mappa dal margine nord (fine della missione n. 2).
func esci(id: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	var e_ss: String = ss.m20.esci(a)
	if e_ss != "-":
		if e_ss != "":
			return _errore(e_ss)
		_fine_comando()
		return OK
	var camion: bool = not ph.camion_di(a).is_empty()
	if camion and a.hex != "A3":
		return _errore("Il camion esce soltanto da A3.")
	if not camion and not e_uscita(a.hex):
		return _errore("Si esce solo da %s." % str(missione.get("uscita_breve", "margine nord, tra A1 e J1")))
	if a.postura == "prone":
		return _errore("Un soldato prono non si muove.")
	if camion:
		ph.camion_uscito(a)
	for pid in a.prigionieri:
		var p := u(pid)
		if not p.is_empty() and p.stato == "catturato":
			p.hex = ""
			p.stato = "rimosso"
			var dp: Dictionary = missione.tedeschi.get(str(int(p.num)), {})
			if dp.has("pv_uscita_prigioniero"):
				_pv(int(dp.pv_uscita_prigioniero), "%s portato fuori mappa prigioniero" % nome(p))
	mo.uscita(a, a.hex)
	ph.uscita(a, a.hex)
	var pvu: Dictionary = regola("pv_uscita", {})
	if pvu.has(a.hex) and not a.get("carro_us", false):
		_pv(int(pvu[a.hex]), "%s esce da %s" % [nome(a), a.hex])
	if int(a.get("documenti", 0)) > 0:
		_pv(int(a.documenti), "documenti portati fuori mappa")
		a.documenti = 0
	var da_e: String = a.hex
	a.uscito_offensiva = bool(s.get("offensiva", false))
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

# ------------------------------------------------------------------ distruzione dei ponti (paragrafo 1000)
## Azioni disponibili contro i ponti per un soldato: [{azione, hex, testo}].
func azioni_ponte(a: Dictionary) -> Array:
	var out: Array = []
	if not bool(regola("fiume", false)) or not attivo(a) or a.hex == "":
		return out
	for h in ponti():
		if not ponte_intatto(h):
			continue
		var st := ponte_stato(h)
		var nome_p := "di pietra" if ponte_di_pietra(h) else "di legno"
		var baz := arma_di(a, "bazooka")
		if not baz.is_empty() and baz.preparata and munizioni_arma(a, "bazooka") > 0 and E.distanza(a.hex, h) <= 14 \
				and a.postura != "prone" and terreno.vede(a.hex, h, a.postura, "standing") and fase_round():
			out.append({"azione": "bazooka", "hex": h, "testo": "Bazooka sul ponte %s (%s)" % [nome_p, h]})
		var carica := arma_di(a, "satchel")
		var sotto: bool = a.get("sotto_ponte", false)
		var timer: bool = bool(regola("ponti_timer", false))
		if timer and a.hex == h:
			# Purple Heart 17: le cariche si piazzano sui sostegni, sotto il ponte (2 PM per scendere o risalire).
			if sotto:
				out.append({"azione": "sopra", "hex": h, "testo": "Risali sul ponte (%s)" % h})
			elif a.postura != "prone":
				out.append({"azione": "sotto", "hex": h, "testo": "Scendi sotto il ponte (%s)" % h})
		if a.hex == h and not carica.is_empty() and carica.preparata and (sotto or not timer):
			out.append({"azione": "carica", "hex": h, "testo": "Piazza una carica sotto il ponte (%s)" % h if timer else "Piazza una carica sul ponte (%s)" % h})
		var servono := 2 if ponte_di_pietra(h) else 1
		if timer:
			# Purple Heart 17: con le cariche piazzate si regola la spoletta (1–4 turni; nelle Operazioni si innesca).
			if a.hex == h and sotto and int(st.cariche) >= servono and not ph.ponte_armato(h):
				if fase_round():
					for k in [1, 2, 3, 4]:
						out.append({"azione": "timer%d" % k, "hex": h, "testo": "Spoletta: salta tra %d turn%s (%s)" % [k, "o" if k == 1 else "i", h]})
				else:
					out.append({"azione": "timer0", "hex": h, "testo": "Innesca le cariche del ponte (%s)" % h})
		elif int(st.cariche) >= servono and (E.distanza(a.hex, h) <= 1 or terreno.vede(a.hex, h, a.postura, "standing")):
			out.append({"azione": "brilla", "hex": h, "testo": "Fai saltare il ponte %s (%s)" % [nome_p, h]})
		if not ponte_di_pietra(h) and st.carburante and E.distanza(a.hex, h) == 1:
			out.append({"azione": "fuoco", "hex": h, "testo": "Dai fuoco al ponte di legno (%s)" % h})
	# Purple Heart 17 (503/504): carica sul binario con la spoletta, bazooka contro il treno.
	var binario: Array = regola("binario", [])
	if not binario.is_empty():
		var carica_b := arma_di(a, "satchel")
		if a.hex in binario and not carica_b.is_empty() and carica_b.preparata and ph.pezzo_treno_in(a.hex) < 0 \
				and not ph._st().get("cariche_binario", {}).has(a.hex):
			if fase_round():
				for k in [1, 2, 3, 4]:
					out.append({"azione": "binario%d" % k, "hex": a.hex, "testo": "Carica sul binario: salta tra %d turn%s" % [k, "o" if k == 1 else "i"]})
			else:
				out.append({"azione": "binario0", "hex": a.hex, "testo": "Innesca una carica sul binario (%s)" % a.hex})
		var bz := arma_di(a, "bazooka")
		if not bz.is_empty() and bz.preparata and munizioni_arma(a, "bazooka") > 0 and fase_round() and a.postura != "prone":
			for ht in ph._posizioni_treno() if str(ph._st().get("treno", {}).get("stato", "")) == "attivo" else []:
				if str(ht) != "" and E.distanza(a.hex, str(ht)) <= 14 and terreno.vede(a.hex, str(ht), a.postura, "standing"):
					var ip: int = ph.pezzo_treno_in(str(ht))
					out.append({"azione": "treno", "hex": str(ht), "testo": "Bazooka sul%s in %s" % [" la locomotiva" if ip == 0 else " vagone", ht]})
	var dep := str(regola("deposito", ""))
	if dep != "" and a.hex == dep and porte_usate(a) < porte_massime(a):
		out.append({"azione": "tanica", "hex": dep, "testo": "Prendi una tanica di carburante"})
	return out

func azione_ponte(id: String, azione: String, h: String) -> Dictionary:
	_inizio_comando()
	var a := u(id)
	var e := _azione_semplice(a)
	if e != "":
		return _errore(e)
	var valida := false
	for x in azioni_ponte(a):
		if x.azione == azione and x.hex == h:
			valida = true
	if not valida:
		return _errore("Azione non possibile qui.")
	var st := ponte_stato(h) if ponti().has(h) else {}
	match azione:
		"tanica":
			a.armi.append({"tipo": "tanica", "inceppata": false, "rotta": false, "preparata": false, "catturata": false})
			_log("azione", "%s prende una tanica di carburante dal deposito." % nome(a))
		"carica":
			var c := arma_di(a, "satchel")
			a.armi.erase(c)
			st.cariche = int(st.cariche) + 1
			_log("azione", "%s piazza una carica da demolizione sul ponte in %s (%d)." % [nome(a), h, int(st.cariche)])
		"timer0", "timer1", "timer2", "timer3", "timer4":
			ph.arma_ponte(h, int(azione.substr(5)))
		"binario0", "binario1", "binario2", "binario3", "binario4":
			var cb := arma_di(a, "satchel")
			a.armi.erase(cb)
			ph.arma_binario(h, int(azione.substr(7)))
		"treno":
			var bzt := arma_di(a, "bazooka")
			var it: int = ph.pezzo_treno_in(h)
			var baset := T.base_per_distanza("bazooka", E.distanza(a.hex, h))
			var probt := clampi(baset + int(T.MOD_VEICOLO.get("clear", [2, 3])[1]) + int(a.WS) - (1 if a.ferito else 0), 0, 8)
			_log("combattimento", "%s spara col bazooka contro il treno in %s (serve 0–%d)." % [nome(a), h, probt])
			_fx("tiro", {"da": a.hex, "a": h, "tiratore": a.id, "bersaglio": "", "arma": "bazooka", "mirato": true, "esito": "mancato", "prob": probt})
			var rt := d10()
			if it >= 0 and (rt == 0 or (rt != 9 and rt <= probt)):
				var dpt := d10()
				var pent := T.penetrazione("bazooka", dpt)
				_log("dado", "Colpito (%d). Penetrazione: %d → %s." % [rt, dpt, {"L": "leggera", "M": "media", "H": "pesante"}.get(pent, "nessuna")])
				ph.colpo_treno(it, pent)
			else:
				_log("dado", "Mancato (%d)." % rt)
			_consuma_bazooka(a, bzt)
		"sotto", "sopra":
			if s.fase == "round" and int(_turno_di(a).mp) < 2:
				return _errore("Servono 2 punti movimento per scendere o risalire.")
			if azione == "sotto":
				a.sotto_ponte = true
				a.postura = "crouching"
				_log("azione", "%s scende sui sostegni sotto il ponte in %s." % [nome(a), h])
			else:
				a.erase("sotto_ponte")
				_log("azione", "%s risale sul ponte in %s." % [nome(a), h])
		"brilla":
			_log("azione", "%s fa brillare le cariche." % nome(a))
			distruggi_ponte(h, "cariche da demolizione")
		"fuoco":
			_log("azione", "%s dà fuoco al ponte imbevuto di carburante." % nome(a))
			st.fuoco = true
			distruggi_ponte(h, "incendio")
		"bazooka":
			var baz := arma_di(a, "bazooka")
			var base := T.base_per_distanza("bazooka", E.distanza(a.hex, h))
			var prob := clampi(base + 4 + int(a.WS) - (1 if a.ferito else 0), 0, 8)
			_log("combattimento", "%s spara col bazooka al ponte in %s (serve 0–%d)." % [nome(a), h, prob])
			_fx("tiro", {"da": a.hex, "a": h, "tiratore": a.id, "bersaglio": "", "arma": "bazooka", "mirato": true, "esito": "mancato", "prob": prob})
			var r := d10()
			if r == 0 or (r != 9 and r <= prob):
				var dp := d10()
				var pen := T.penetrazione("bazooka", dp)
				_log("dado", "Colpito (%d). Penetrazione: %d → %s." % [r, dp, {"L": "leggera", "M": "media", "H": "pesante"}.get(pen, "nessuna")])
				if pen == "H":
					distruggi_ponte(h, "bazooka")
				else:
					_log("info", "Il ponte regge.")
			else:
				_log("dado", "Mancato (%d)." % r)
			_consuma_bazooka(a, baz)
	if s.fase == "operazioni" and azione in ["carica", "brilla", "fuoco"]:
		pass  # automatico nelle Operazioni
	_chiudi_azione_semplice(a)
	_fine_comando()
	return OK

## Chi porta una tanica e attraversa il ponte di legno lo prepara per l’incendio.
func _controlla_tanica(a: Dictionary, da: String, verso: String) -> void:
	if arma_di(a, "tanica").is_empty():
		return
	if ponti().has(da) and not ponti().has(verso) and not ponte_di_pietra(da) and ponte_intatto(da):
		var st := ponte_stato(da)
		if not st.carburante:
			st.carburante = true
			a.armi.erase(arma_di(a, "tanica"))
			_log("azione", "%s attraversa il ponte di legno spargendo il carburante: ora si può appiccare il fuoco." % nome(a))

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
			for pp in pid.split(","):
				_log("info", "In %s ci sono solo i tuoi soldati: si legge il paragrafo annotato %s." % [h, pp])
				leggi(pp, {"hex": h, "ids": unita_in(h, "us").map(func(x): return x.id)})

func _niente_controlli_round() -> bool:
	return s.fase == "round" and (bool(missione.get("regole", {}).get("niente_controlli_round", false)) or ph.niente_controlli_round())

## Missione 2: 1 PV per ogni esagono di edificio in cui entra un soldato.
func _edificio_raggiunto(h: String) -> void:
	var lista: Array = regola("pv_esagoni", [])
	if h in lista:
		if not s.has("edifici_entrati"):
			s.edifici_entrati = []
		if not (h in s.edifici_entrati):
			s.edifici_entrati.append(h)
			_pv(1, "esagono %s raggiunto" % h)
		return
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
	if numero == 1 or bool(regola("salvi_in_edificio", false)):
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
		4:
			var r4: Array = []
			for h in ponti():
				var st := ponte_stato(h)
				var stato_p := "catturato" if st.get("catturato", false) and ponte_intatto(h) else ("saltato" if not ponte_intatto(h) else "disinnesco %d/4" % int(st.get("disinnesco", 0)))
				r4.append([st.get("catturato", false) and ponte_intatto(h), "Ponte %s: %s" % [h, stato_p], "Quattro turni sul ponte per staccare le cariche: 4 PV, entrambi 10 PV"])
			var cassa: Dictionary = s.get("cassa", {})
			if not cassa.is_empty():
				r4.append([cassa.stato == "aperta", "Cassa %s" % {"in volo": "in volo", "chiusa": "chiusa in " + str(cassa.hex), "aperta": "aperta", "persa": "persa"}.get(cassa.stato, ""), "Fucile automatico, bazooka e razzi sono nella cassa"])
			r4.append([pv >= int(missione.vittoria_pv), "%d PV (ora %d)" % [int(missione.vittoria_pv), pv], "Punti vittoria necessari"])
			return r4
		3:
			var entrati: Array = s.get("edifici_entrati", [])
			var lista: Array = regola("pv_esagoni", [])
			var righe := [
				[entrati.size() >= lista.size(), "Esagoni %d/%d" % [entrati.size(), lista.size()], "1 PV per ciascuno: " + ", ".join(lista)],
				[radio_presidiata(), "Radio presidiata", "La radio in %s, con un soldato attivo accanto" % str(s.get("radio_hex", "—"))],
			]
			if s.get("offensiva", false):
				var distrutti: Array = ponti().filter(func(h): return ponte_stato(h).distrutto)
				righe.append([not distrutti.is_empty(), "Ponti distrutti %d/2" % distrutti.size(), "Legno 2 PV, pietra 4 PV, entrambi 10 PV"])
				righe.append([false, "Ritirata da A13–A19", "2 PV per ogni soldato attivo che esce"])
			righe.append([pv >= int(missione.vittoria_pv), "%d PV (ora %d)" % [int(missione.vittoria_pv), pv], "Punti vittoria necessari"])
			return righe
	if numero != 1:
		var rg: Array = []
		var inst: Dictionary = s.get("installazioni", {})
		if not inst.is_empty():
			var fatte: Array = inst.keys().filter(func(h): return inst[h].distrutta)
			rg.append([fatte.size() == inst.size(), "Installazioni %d/%d" % [fatte.size(), inst.size()], "2 PV ciascuna: si distruggono con una carica da demolizione"])
		var doc := 0
		for a in americani():
			doc += int(a.get("documenti", 0))
		if doc > 0:
			rg.append([false, "Documenti da portare fuori: %d" % doc, "Valgono solo se escono dalla mappa"])
		if bool(regola("fine_uscita", false)):
			rg.append([false, "Uscita: %s" % str(missione.get("uscita_breve", "")), "La missione termina quando tutti i soldati attivi sono usciti"])
		rg.append([pv >= int(missione.vittoria_pv), "%d PV (ora %d)" % [int(missione.vittoria_pv), pv], "Punti vittoria necessari"])
		return rg
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
	mo.controlla()
	ph.controlla()
	ss.controlla()
	if s.fase == "fine" or mo.blocca_fine() or ph.blocca_fine() or ss.blocca_fine():
		return
	if bool(regola("fine_ponti", false)) and int(s.condizione) >= 4 and tedeschi_attivi().filter(func(g): return attivo(g)).is_empty() \
			and not americani_attivi_in_mappa().is_empty():
		var tutti := true
		for h in ponti():
			if ponte_intatto(h) and not ponte_stato(h).get("catturato", false):
				tutti = false
		if tutti:
			_log("info", "Nessun tedesco attivo e tutti i ponti catturati o saltati: la missione termina.")
			_calcola_fine("obiettivo")
			return
	var vivi_in_mappa := americani_attivi_in_mappa().filter(func(x): return not x.get("pilota", false) and not x.get("carro_us", false))
	if int(regola("fine_condizione", 0)) > 0 and int(s.condizione) < int(regola("fine_condizione", 0)) and not vivi_in_mappa.is_empty():
		return
	var da_entrare := americani().filter(func(x): return x.stato == "fuori" and not x.get("carro_us", false))
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
		if (numero == 1 and a.id in ["J", "K"]) or (numero == 2 and a.id == "J") or a.get("carro_us", false) or a.has("autista_camion") or a.get("fuori_conto", false):
			continue
		if a.id == "K" and s.get("staffetta_spia", false):
			continue
		if a.stato == "rimosso":
			continue
		if a.stato == "morto":
			perdite -= 2
			righe.append(["%s ucciso" % nome(a), -2])
		elif a.stato == "incapacitato" and (bool(regola("niente_pv_incapacitati", false)) or ph.niente_pv_incapacitati() or ss.niente_pv_incapacitati()):
			continue
		elif a.stato == "incapacitato":
			var salvo: bool = a.get("uscito", false) or a.get("salvo_mo", false) or (modo == "obiettivo" and _salvo_a_fine(a.hex))
			if bool(regola("niente_salvataggio", false)):
				salvo = false
			if not salvo:
				perdite -= 2
				righe.append(["%s incapacitato e non messo in salvo" % nome(a), -2])
	if numero == 4:
		var catturati: Array = ponti().filter(func(h): return ponte_stato(h).get("catturato", false) and ponte_intatto(h))
		if catturati.size() >= 2:
			bonus += 10
			righe.append(["Entrambi i ponti catturati intatti", 10])
		elif catturati.size() == 1:
			bonus += 4
			righe.append(["Ponte %s catturato intatto" % catturati[0], 4])
	for a in americani():
		if int(a.get("pv_attivo_fine", 0)) > 0 and a.stato in ["attivo", "uscito"]:
			bonus += int(a.pv_attivo_fine)
			righe.append(["%s attivo alla fine" % nome(a), int(a.pv_attivo_fine)])
	bonus += mo.righe_fine(righe)
	bonus += ph.righe_fine(righe)
	bonus += ss.m20.righe_fine(righe)
	bonus += ss.m21.righe_fine(righe)
	if numero == 3:
		var usciti := 0
		for a in americani():
			if a.stato == "uscito" and a.get("uscito_offensiva", false) and not (a.id == "K" and s.get("staffetta_spia", false)):
				usciti += 1
		if usciti > 0:
			bonus += 2 * usciti
			righe.append(["%d soldati usciti da A13–A19 dopo l’ordine di ritirata" % usciti, 2 * usciti])
		if s.get("offensiva", false):
			var pietra := false
			var legno := false
			for h in ponti():
				if ponte_stato(h).distrutto:
					if ponte_di_pietra(h):
						pietra = true
					else:
						legno = true
			var pp := 10 if (pietra and legno) else (4 if pietra else (2 if legno else 0))
			if pp > 0:
				bonus += pp
				righe.append(["Ponti distrutti" if pietra and legno else ("Ponte di pietra distrutto" if pietra else "Ponte di legno distrutto"), pp])
	var k := u("K") if numero == 1 else {}
	if not k.is_empty() and k.stato != "morto":
		var salvo_k: bool = k.get("uscito", false) or (modo == "obiettivo" and terreno.edificio(k.hex))
		if salvo_k:
			bonus += 3
			righe.append(["Soldato K portato in salvo", 3])
	var j := u("J") if numero == 1 else {}
	if not j.is_empty() and j.stato in ["attivo", "uscito"]:
		bonus += 2
		righe.append(["Pilota britannico attivo alla fine", 2])
	var finale := tot + bonus + perdite
	var vinta := finale >= int(missione.vittoria_pv)
	s.fine = {"modo": modo, "pv_partita": tot, "righe": righe, "totale": finale, "vinta": vinta}
	_log("fine", "MISSIONE CONCLUSA — %d PV: %s." % [finale, "VITTORIA" if vinta else "SCONFITTA"])
