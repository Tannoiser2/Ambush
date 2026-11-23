extends RefCounted
## Regole e operazioni dei paragrafi delle missioni di Purple Heart (13–18).
## Per ora: Missione 16 «In guardia» (deposito di carburante, commando con esplosivi, battelli d’assalto).

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

var p  # Partita

func _init(partita) -> void:
	p = partita

func attiva() -> bool:
	return str(p.missione.get("libro", "")) == "ph"

func deposito() -> Array:
	return p.missione.get("regole", {}).get("deposito", [])

func _st() -> Dictionary:
	if not p.s.has("ph"):
		p.s.ph = {"esplosivi": {}, "barche": {}, "deposito_distrutto": [], "entrati": false, "fine_esplosivi": false, "difusi": 0}
	return p.s.ph

# ------------------------------------------------------------------ operazioni
func op(o: Dictionary, ctx: Dictionary) -> bool:
	if not attiva():
		return false
	match str(o.op):
		"imbarca":
			_imbarca(o)
		"barca":
			p.ia.ph.barca(o, ctx)
		"pianta_esplosivo":
			_pianta(ctx)
		"esplosivo_a_tempo":
			_esplosivo_a_tempo()
		"disinnesco_pc":
			_disinnesco_pc()
		"fine_esplosivi":
			_st().fine_esplosivi = true
			p._log("info", "D’ora in poi la missione finisce solo quando non restano tedeschi attivi e tutti gli esplosivi sono stati disinnescati o sono saltati.")
		"telefono":
			_st().telefono = int(p.s.condizione)
			p._log("info", "In J8 squilla un telefono: rispondi entrando in J8 durante questa Condizione.")
		"al_prossimo_round":
			var n := int(p.s.get("round", {}).get("n", 0)) if p.fase_round() else 0
			var st := _st()
			if not st.has("pendenti"):
				st.pendenti = []
			st.pendenti.append({"p": str(o.p), "round": n + (2 if n == 0 else 1)})
			p._log("info", "All’inizio del prossimo Round, prima del controllo degli eventi casuali, si legge il paragrafo %s." % o.p)
		"camion":
			p._log("info", "La colonna di camion è in arrivo, ma in questa versione i camion non entrano in mappa: la difesa del deposito resta il compito della squadra.")
		_:
			return false
	return true

func test(t: Dictionary, ctx: Dictionary) -> Variant:
	if not attiva():
		return null
	if t.has("g_esplosivo"):
		var g: Dictionary = p.u(ctx.get("g", ""))
		if g.is_empty() or int(g.get("esplosivi", 0)) <= 0 or _st().esplosivi.has(g.hex):
			return false
		for x in p.unita_in(g.hex, "de"):
			if x.id != g.id and p.attivo(x) and int(x.get("esplosivi", 0)) > 0:
				return false
		return true
	if t.has("deposito_entrati"):
		return bool(_st().entrati) == bool(t.deposito_entrati)
	if t.has("deposito_attivi_max"):
		return _attivi_nel_deposito() <= int(t.deposito_attivi_max)
	if t.has("esplosivo_mezzo_us"):
		return _esplosivo_mezzo_con_us() != ""
	if t.has("esplosivo_intero_edificio"):
		return _esplosivi_interi_in_edificio().size() > 0
	if t.has("barca_mossa"):
		var g2: Dictionary = p.u(ctx.get("g", ""))
		return not g2.is_empty() and p.ia.ph.barca_gia_mossa(g2)
	return null

func _attivi_nel_deposito() -> int:
	var n := 0
	for g in p.tedeschi_attivi():
		if p.in_mappa(g) and g.hex in deposito():
			n += 1
	return n

# ------------------------------------------------------------------ battelli
func _imbarca(o: Dictionary) -> void:
	var st := _st()
	var id := "b%d" % (st.barche.size() + 1)
	st.barche[id] = {"hex": str(o.hex), "mossa": ""}
	for n in o.g:
		var g: Dictionary = p.u("g%d" % int(n))
		if not g.is_empty() and p.in_mappa(g):
			g.barca = id
			g.hex = str(o.hex)
			g.postura = "crouching"
	p.s.oggetti[str(o.hex)] = p.s.oggetti.get(str(o.hex), []) + [{"tipo": "barca", "id": id}]
	p._log("info", "Un battello d’assalto tedesco è in %s." % o.hex)

func occupanti(id: String) -> Array:
	return p.tedeschi_attivi().filter(func(g): return str(g.get("barca", "")) == id and p.in_mappa(g))

func sposta_barca(id: String, h: String) -> void:
	var b: Dictionary = _st().barche[id]
	var da: String = b.hex
	var lista: Array = p.s.oggetti.get(da, [])
	lista = lista.filter(func(x): return not (x.get("tipo", "") == "barca" and x.get("id", "") == id))
	if lista.is_empty():
		p.s.oggetti.erase(da)
	else:
		p.s.oggetti[da] = lista
	b.hex = h
	p.s.oggetti[h] = p.s.oggetti.get(h, []) + [{"tipo": "barca", "id": id}]
	var ids: Array = []
	for g in occupanti(id):
		g.hex_prec = g.hex
		g.hex = h
		ids.append(g.id)
	p._log("tedesco", "Il battello d’assalto risale il fiume fino a %s." % h)
	p._fx("muovi", {"ids": ids, "da": da, "a": h})

# ------------------------------------------------------------------ esplosivi (619)
func _pianta(ctx: Dictionary) -> void:
	var g: Dictionary = p.u(ctx.get("g", ""))
	if g.is_empty():
		return
	if p.ia._mp < int(p.effettivo_mpa(g)):
		# 840: si è già mosso in questo turno; si ferma e piazzerà la carica al prossimo turno.
		p.ia.ferma()
		p._log("tedesco", "Il %s si ferma in %s: piazzerà l’esplosivo al prossimo turno." % [p.nome(g), g.hex])
		return
	g.esplosivi = int(g.get("esplosivi", 0)) - 1
	_st().esplosivi[g.hex] = 2
	g.postura = "crouching"
	p.ia.ferma()
	p.s.oggetti[g.hex] = p.s.oggetti.get(g.hex, []) + [{"tipo": "esplosivo"}]
	p._log("tedesco", "Il %s si accovaccia e piazza un esplosivo a tempo in %s!" % [p.nome(g), g.hex])
	if not _st().fine_esplosivi:
		op({"op": "fine_esplosivi"}, ctx)

func esplosivo(h: String) -> int:
	return int(_st().esplosivi.get(h, 0))

## Azione americana: un’azione gira l’esplosivo sul lato 1, la seconda lo toglie (+2 PV).
func disinnesca(a: Dictionary) -> String:
	var h: String = a.hex
	var lato := esplosivo(h)
	if lato == 0:
		return "Qui non c’è un esplosivo."
	if lato == 2:
		_st().esplosivi[h] = 1
		p._log("azione", "%s comincia a disinnescare l’esplosivo in %s (manca ancora un’azione)." % [p.nome(a), h])
	else:
		_togli_esplosivo(h)
		_st().difusi = int(_st().difusi) + 1
		p._pv(2, "esplosivo disinnescato in %s" % h)
		p._log("azione", "%s stacca il detonatore: l’esplosivo in %s è disinnescato." % [p.nome(a), h])
	return ""

func _togli_esplosivo(h: String) -> void:
	_st().esplosivi.erase(h)
	var lista: Array = p.s.oggetti.get(h, []).filter(func(x): return x.get("tipo", "") != "esplosivo")
	if lista.is_empty():
		p.s.oggetti.erase(h)
	else:
		p.s.oggetti[h] = lista

func _esplosivi_interi_in_edificio() -> Array:
	var out: Array = []
	for h in _st().esplosivi:
		if int(_st().esplosivi[h]) == 2 and p.terreno.edificio(h):
			out.append(h)
	return out

func _esplosivo_mezzo_con_us() -> String:
	for h in _st().esplosivi:
		if int(_st().esplosivi[h]) == 1 and p.terreno.edificio(h):
			for a in p.unita_in(h, "us"):
				if p.attivo(a):
					return h
	return ""

## 651: un esplosivo sul lato 2 salta.
func _esplosivo_a_tempo() -> void:
	var lista := _esplosivi_interi_in_edificio()
	if lista.is_empty():
		for h in _st().esplosivi:
			if int(_st().esplosivi[h]) == 2:
				lista.append(h)
	if lista.is_empty():
		return
	var h: String = lista[p.rng.randi_range(0, lista.size() - 1)]
	p._log("info", "La spoletta a tempo arriva a zero: l’esplosivo in %s salta!" % h)
	esplodi(h)

## 660: il soldato con la percezione più alta prova a staccare il detonatore.
func _disinnesco_pc() -> void:
	var h := _esplosivo_mezzo_con_us()
	if h == "":
		return
	var migliore: Dictionary = {}
	for a in p.unita_in(h, "us"):
		if p.attivo(a) and (migliore.is_empty() or int(a.PC) > int(migliore.PC)):
			migliore = a
	if p.controllo_pc(migliore, 0, "disinnescare l’esplosivo all’ultimo istante"):
		_togli_esplosivo(h)
		_st().difusi = int(_st().difusi) + 1
		p._pv(2, "esplosivo disinnescato in %s" % h)
		p._log("info", "%s stacca il detonatore un attimo prima che scatti!" % p.nome(migliore))
	else:
		p._log("info", "Troppo tardi: l’esplosivo in %s salta!" % h)
		esplodi(h)

## Esplosione di una carica (o del carburante): muore chi è nell’esagono, chi è accanto subisce danni da granata al chiuso.
func esplodi(h: String) -> void:
	_togli_esplosivo(h)
	p._fx("esplosione", {"a": h, "grande": true})
	for x in p.unita_in(h):
		if p.attivo(x) or x.stato in ["ferito", "incapacitato"]:
			p._uccidi(x, "nell’esplosione")
	if p.terreno.edificio(h) and not p.s.modifiche.has(h):
		p.s.modifiche[h] = "rubble"
		p.terreno.imposta_modifiche(p.s.modifiche)
		p.s.oggetti[h] = p.s.oggetti.get(h, []) + [{"tipo": "incendio"}]
		p._log("info", "L’edificio in %s brucia." % h)
	if h in deposito() and not (h in _st().deposito_distrutto):
		_st().deposito_distrutto.append(h)
		p._log("info", "Il carburante del deposito in %s prende fuoco!" % h)
	for v in E.vicini(h):
		for x in p.unita_in(v):
			if not p.attivo(x):
				continue
			if p.controllo_pc(x, 0, "buttarsi a terra per l’esplosione"):
				x.postura = "prone"
			p._danno_esplosione(x, T.GRANATA_DENTRO)
	if _st().esplosivi.has(h):
		_togli_esplosivo(h)

# ------------------------------------------------------------------ agganci della partita
## Ogni esplosione nel deposito fa saltare il carburante (414).
func esplosione(tipo: String, h: String) -> void:
	if attiva() and h in deposito() and not (h in _st().deposito_distrutto):
		esplodi(h)

## Un tiro americano mancato contro un tedesco nel deposito: 0–3 il carburante esplode (414).
func tiro_mancato(b: Dictionary) -> void:
	if not attiva() or b.is_empty() or not (str(b.get("hex", "")) in deposito()):
		return
	if str(b.hex) in _st().deposito_distrutto:
		return
	var d: int = p.d10()
	p._log("dado", "Colpo mancato nel deposito: dado %d (0–3 il carburante esplode)." % d)
	if d <= 3:
		esplodi(str(b.hex))

func inizio_round() -> void:
	if not attiva() or not _st().has("pendenti"):
		return
	var n := int(p.s.round.get("n", 0))
	var ora: Array = _st().pendenti.filter(func(x): return int(x.round) <= n)
	_st().pendenti = _st().pendenti.filter(func(x): return int(x.round) > n)
	for x in ora:
		p.leggi(str(x.p), {})

func controlla() -> void:
	if not attiva():
		return
	if not _st().entrati:
		for g in p.tedeschi_attivi():
			if p.in_mappa(g) and g.hex in deposito():
				_st().entrati = true
				p._log("info", "I commando sono entrati nel deposito.")
				break
	var tel = _st().get("telefono", null)
	if tel != null and int(tel) == int(p.s.condizione):
		for a in p.americani():
			if p.attivo(a) and a.hex == "J8":
				_st().erase("telefono")
				p.leggi("381", {"hex": "J8", "ids": [a.id]})
				break

func blocca_fine() -> bool:
	return attiva() and _st().fine_esplosivi and not _st().esplosivi.is_empty()

func righe_fine(righe: Array) -> int:
	if not attiva() or deposito().is_empty():
		return 0
	var distrutti: int = _st().deposito_distrutto.size()
	var intatti: int = deposito().size() - distrutti
	righe.append(["Esagoni del deposito intatti (%d)" % intatti, intatti])
	if distrutti > 0:
		righe.append(["Esagoni del deposito distrutti (%d)" % distrutti, -2 * distrutti])
	return intatti - 2 * distrutti

## Schieramento della Missione 16: almeno due uomini entro 10 esagoni da ogni angolo.
func verifica_schieramento() -> String:
	var angoli: Array = p.missione.get("regole", {}).get("angoli", [])
	for c in angoli:
		var n := 0
		for a in p.americani():
			if a.stato == "attivo" and a.hex != "" and E.distanza(a.hex, str(c)) <= 10:
				n += 1
		if n < 2:
			return "Servono almeno due soldati entro 10 esagoni dall’angolo %s." % c
	return ""
