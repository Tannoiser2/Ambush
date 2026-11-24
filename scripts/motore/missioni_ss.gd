extends RefCounted
## Silver Star (Missioni 19–24): regole proprie del libretto. Per ora la Missione 19 «Fradici»:
## canoe e sommozzatori, nuoto in superficie e sott’acqua, esplosivi a tempo, chiatte, barche di guardia, camion di rinforzi.
## Lo stato è in p.s.ss.

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

const ACQUA := ["water", "stream"]
const PATTUGLIA := {60: "F5", 61: "K6"}

var p  # Partita
var m20: RefCounted
var m21: RefCounted
var m22: RefCounted
var m23: RefCounted
var m24: RefCounted

func _init(partita) -> void:
	p = partita
	m20 = preload("res://scripts/motore/missione20_ss.gd").new(partita, self)
	m21 = preload("res://scripts/motore/missione21_ss.gd").new(partita, self)
	m22 = preload("res://scripts/motore/missione22_ss.gd").new(partita, self)
	m23 = preload("res://scripts/motore/missione23_ss.gd").new(partita, self)
	m24 = preload("res://scripts/motore/missione24_ss.gd").new(partita, self)

func attiva() -> bool:
	return str(p.missione.get("libro", "")) == "ss"

func _st() -> Dictionary:
	if not p.s.has("ss"):
		p.s.ss = {"chiatte": [], "esplosivi": [], "sganciati": false, "fine_789": false, "senz_aria": false, "gomme_camion": 0,
			"chiatte_distrutte": 0}
	return p.s.ss

# ------------------------------------------------------------------ acqua
func m19() -> bool:
	return attiva() and int(p.missione.get("id", 0)) == 19

func in_acqua(x: Dictionary) -> bool:
	if not m19() or x.is_empty() or str(x.get("hex", "")) == "":
		return false
	if p.veicoli.attivo(p.veicoli.di(x)) and not x.get("aggrappato", false):
		return false
	if p.terreno.ponte(x.hex) and x.get("sul_ponte", false):
		return false
	return p.terreno.tipo(x.hex) in ACQUA

## Sott’acqua: un sommozzatore (con l’autorespiratore) prono in un esagono d’acqua.
func sott_acqua(x: Dictionary) -> bool:
	return in_acqua(x) and x.get("postura", "") == "prone" and not x.get("aggrappato", false)

func sommozzatore(x: Dictionary) -> bool:
	return bool(x.get("sub", false))

func acqua(h: String) -> bool:
	return p.terreno.tipo(h) in ACQUA and not p.terreno.ponte(h)

# ------------------------------------------------------------------ preparazione
func dopo_nuova() -> void:
	if not attiva():
		return
	_st()
	p.terreno.acqua_ammessa = int(p.missione.id) == 19
	for a in p.americani():
		if a.id in p.regola("sommozzatori", []):
			a.sub = true
			a.esplosivi_ss = 1
		if a.id in p.regola("coltelli", []):
			a.coltello_ss = true

func regole_terreno() -> void:
	if attiva():
		p.terreno.acqua_ammessa = int(p.missione.id) == 19
		m20.regole_terreno()
		m21.regole_terreno()
		m22.regole_terreno()
		m23.regole_terreno()

## Dopo l’imbarco: i sommozzatori si aggrappano ai fianchi delle canoe (due per canoa).
func dopo_imbarco() -> void:
	if not attiva():
		return
	var canoe: Array = p.veicoli.tutti().filter(func(v): return p.veicoli.e_canoa(v) and v.lato == "us")
	var sub: Array = p.americani().filter(func(a): return sommozzatore(a) and p.attivo(a) and str(a.get("veicolo", "")) == "")
	var i := 0
	for v in canoe:
		for k in 2:
			if i >= sub.size():
				break
			var a: Dictionary = sub[i]
			i += 1
			a.hex = v.hex
			a.veicolo = v.id
			a.aggrappato = true
			a.postura = "standing"
			v.occupanti.append(a.id)
	if i > 0:
		p._log("info", "I sommozzatori si aggrappano ai fianchi delle canoe: si muovono con loro finché il comandante non li sgancia (787).")
	# Almeno un comandante in canoa.
	var capo := false
	for v in canoe:
		for x in p.veicoli.occupanti(v):
			if x.get("comandante", false) and not x.get("aggrappato", false):
				capo = true
	if not capo and not canoe.is_empty():
		p._log("info", "Nessun comandante in canoa: il primo comandante prende il posto del primo rematore.")

# ------------------------------------------------------------------ movimento
func verifica_passo(a: Dictionary, verso: String) -> String:
	if m22.attiva():
		return m22.verifica_passo(a, verso)
	if not m19():
		return ""
	var veic: Dictionary = p.veicoli.di(a)
	if a.get("aggrappato", false):
		return "%s è aggrappato alla canoa: si muove con lei finché il comandante non sgancia i sommozzatori." % p.nome(a)
	if p.veicoli.e_canoa(veic) and veic.lato == "us" and not acqua(verso) and E.colonna(verso) <= 13:
		return "Le canoe non sbarcano a sud della colonna N (compresa)."
	if veic.is_empty() and sommozzatore(a) and not acqua(verso) and not _st().fine_789:
		return "I sommozzatori restano negli esagoni d’acqua (possono salire su una chiatta con un’azione)."
	if veic.is_empty() and in_acqua(a) and a.postura == "prone" and not sommozzatore(a):
		return "Solo i sommozzatori nuotano sott’acqua."
	return ""

## In acqua si nuota: 2 PM per esagono d’acqua; dall’acqua a terra 2 PM.
func limite_mpa(a: Dictionary, m: int) -> int:
	if not attiva():
		return m
	return m24.limite_mpa(a, m)

func costo_passo(a: Dictionary, da: String, verso: String, base: int) -> int:
	if m22.attiva():
		return m22.costo_passo(a, da, verso, base)
	if m23.attiva():
		return m23.costo_passo(a, verso, base)
	if not m19() or p.veicoli.attivo(p.veicoli.di(a)):
		return base
	if acqua(verso):
		return 2
	if da != "" and acqua(da):
		return -1 if base < 0 else 2
	return base

## Nuotando (o sott’acqua) ci si muove anche proni.
func nuota(a: Dictionary) -> bool:
	return in_acqua(a)

## Cambio di postura in acqua: in superficie (in piedi) o sott’acqua (prono, solo i sommozzatori); è gratuito.
func cambia_postura(a: Dictionary, postura: String) -> String:
	if not in_acqua(a):
		return "-"
	if a.get("aggrappato", false):
		return "Aggrappato alla canoa resta in superficie."
	if postura == "crouching":
		return "In acqua si nuota in superficie (in piedi) o sott’acqua (prono)."
	p._log("azione", "%s %s." % [p.nome(a), "si immerge" if postura == "prone" else "riemerge"])
	p.imposta_postura(a, postura)
	bagna_armi(a)
	return ""

## Silver Star 19: un’arma portata sott’acqua senza impermeabilizzazione si inceppa con 25 o meno finché non la si pulisce.
const NON_DA_PROTEGGERE := ["satchel", "coltello", "esplosivo"]

func bagna_armi(a: Dictionary) -> void:
	if not sott_acqua(a):
		return
	for w in a.get("armi", []):
		if not (str(w.tipo) in NON_DA_PROTEGGERE) and not w.get("impermeabile", false) and not w.get("jam25", false):
			w.jam25 = true
			p._log("info", "%s porta sott’acqua l’arma (%s) senza protezione: ora si inceppa con 25 o meno." % [p.nome(a), T.ARMI.get(w.tipo, {}).get("breve", w.tipo)])

func puo_impermeabilizzare(a: Dictionary) -> Array:
	if not m19() or not p.attivo(a) or a.lato != "us" or sott_acqua(a):
		return []
	return a.armi.filter(func(w): return not (str(w.tipo) in NON_DA_PROTEGGERE) and T.ARMI.has(w.tipo))

func impermeabilizza(a: Dictionary, tipo: String) -> String:
	var w: Dictionary = p.arma_di(a, tipo)
	if w.is_empty():
		return "Arma non trovata."
	w.impermeabile = not w.get("impermeabile", false)
	p._log("azione", "%s %s l’arma (%s)." % [p.nome(a), "impermeabilizza" if w.impermeabile else "toglie la protezione dal", T.ARMI[tipo].breve])
	return ""

func pulisci(a: Dictionary, tipo: String) -> String:
	var w: Dictionary = p.arma_di(a, tipo)
	if w.is_empty() or not w.get("jam25", false):
		return "L’arma non è bagnata."
	if w.get("impermeabile", false):
		return "Prima va tolta la protezione."
	w.jam25 = false
	p._log("azione", "%s pulisce e asciuga l’arma (%s)." % [p.nome(a), T.ARMI[tipo].breve])
	return ""

func dopo_ingresso_acqua(a: Dictionary) -> void:
	if not in_acqua(a):
		return
	if a.postura == "crouching":
		a.postura = "standing"
	bagna_armi(a)

# ------------------------------------------------------------------ vista e fuoco
## -1: nessuna regola speciale; 0 non vede; 1 vede.
func vista(oss: Dictionary, ber: Dictionary) -> int:
	if not attiva():
		return -1
	if m20.galleria_attiva():
		return m20.vista(oss, ber)
	if m22.attiva():
		return m22.vista(oss, ber)
	if sott_acqua(oss) or sott_acqua(ber):
		return 1 if E.distanza(oss.hex, ber.hex) <= 1 else 0
	return -1

## In acqua: niente tiro mirato (un solo tiro rapido per turno, restando a galla) e niente bazooka.
func blocca_tiro(tiratore: Dictionary, tipo: String, mirato: bool) -> String:
	if m24.attiva():
		return m24.blocca_tiro(tiratore, tipo, mirato)
	if m20.attiva():
		return m20.blocca_tiro(tiratore, mirato)
	if not attiva() or not in_acqua(tiratore) or tiratore.get("aggrappato", false):
		return ""
	if sott_acqua(tiratore):
		return "sott’acqua non si spara"
	if tipo == "bazooka":
		return "dall’acqua il bazooka non spara"
	if mirato:
		return "in acqua si spara solo di rapido"
	return ""

func mod_tiro(tiratore: Dictionary, bersaglio: Dictionary, mods: Array) -> void:
	if not attiva():
		return
	m23.mod_tiro(tiratore, bersaglio, mods)
	if tiratore.get("calcio_rotto", false):
		mods.append(["calcio dell’arma rotto", -1])
	if tiratore.get("esterno_ss", false) and str(tiratore.get("veicolo", "")) != "":
		mods.append(["aggrappato al camion", -2])
	if in_acqua(bersaglio):
		mods.append(["bersaglio in acqua (nuotatore)", -4])

func mod_assalto(att: Dictionary, ws: int) -> int:
	if attiva() and att.get("coltello_ss", false):
		return mini(ws + 1, maxi(ws, 2))
	return ws

## Un colpo a segno: true se l’ha gestito il modulo (barche di guardia).
func colpito(tiratore: Dictionary, tipo: String, bersaglio: Dictionary, fx: Dictionary) -> bool:
	if not attiva() or not bersaglio.get("barca_ss", false):
		return false
	_colpita_barca(bersaglio, tipo, tiratore, fx)
	return true

## Un sommozzatore colpito o in preda al panico torna in superficie (la ferita fa perdere una casella di porto).
func dopo_danno(x: Dictionary, l: String) -> void:
	m20.dopo_danno(x, l)
	if not attiva() or not sott_acqua(x) or not p.attivo(x):
		return
	if l in ["P", "W"] or x.panico:
		x.postura = "standing"
		p._log("info", "%s torna in superficie." % p.nome(x))

# ------------------------------------------------------------------ chiatte
func chiatte_attive() -> Array:
	return p.veicoli.tutti().filter(func(v): return v.get("chiatta_ss", false) and v.stato == "attivo")

func chiatta_in(h: String) -> Dictionary:
	for v in chiatte_attive():
		if v.hex == h:
			return v
	return {}

func _piazza_chiatte(lista: Array) -> void:
	for h in lista:
		if not chiatta_in(str(h)).is_empty():
			continue
		var n: int = p.veicoli.tutti().filter(func(v): return v.get("chiatta_ss", false)).size() + 1
		var v: Dictionary = p.veicoli.crea("chiatta%d" % n, "chiatta", str(h), "de")
		v.nome = "Chiatta %d" % n
		v.chiatta_ss = true
		v.ormeggiata = true
		p._log("info", "Una chiatta tedesca di rifornimento è ormeggiata in %s." % h)
		p._fx("compare", {"id": v.id, "a": str(h)})

func distruggi_chiatta(v: Dictionary, motivo: String) -> void:
	if v.stato != "attivo":
		return
	v.stato = "distrutto"
	_st().chiatte_distrutte = int(_st().chiatte_distrutte) + 1
	p._log("danno", "%s salta in aria (%s)!" % [v.nome, motivo])
	p._fx("esplosione", {"a": v.hex, "grande": true})
	p._pv(3, "%s distrutta" % v.nome.to_lower())
	for x in p.veicoli.occupanti(v):
		p.veicoli.scendi(x)
		if p.attivo(x):
			p._uccidi(x, "sulla chiatta che esplode")

## Sale su una chiatta dall’acqua (un’azione) o da un esagono di terra adiacente (2 PM).
func sali_esterno(un: Dictionary, veic: Dictionary) -> String:
	return m20.sali_esterno(un, veic) if attiva() else "-"

func sali_chiatta(a: Dictionary) -> String:
	var v := chiatta_in(a.hex)
	if v.is_empty():
		return "Non c’è una chiatta in questo esagono."
	if not _st().get("nota_237", false):
		return "Prima bisogna scoprire le chiatte."
	v.occupanti.append(a.id)
	a.veicolo = v.id
	a.postura = "crouching"
	p._log("azione", "%s sale sulla %s." % [p.nome(a), v.nome.to_lower()])
	return ""

func puo_salire_chiatta(a: Dictionary) -> bool:
	return attiva() and _st().get("nota_237", false) and not chiatta_in(a.hex).is_empty() and str(a.get("veicolo", "")) == "" and p.attivo(a)

## Chiatte attive in vista e in portata del bazooka.
func chiatte_per_bazooka(a: Dictionary) -> Array:
	if not attiva() or p.arma_di(a, "bazooka").is_empty() or in_acqua(a) or p.munizioni_arma(a, "bazooka") <= 0:
		return []
	return chiatte_attive().filter(func(v): return E.distanza(a.hex, v.hex) <= int(T.ARMI.bazooka.gittate[2]) and p.terreno.vede(a.hex, v.hex, a.postura, "standing"))

func puo_esplosivo(a: Dictionary) -> bool:
	return attiva() and int(a.get("esplosivi_ss", 0)) > 0 and not chiatta_in(a.hex).is_empty() and p.attivo(a)

## Esplosivo a tempo: un’azione nell’esagono della chiatta; salta alla fine del Round successivo (nelle Operazioni dopo due
## spostamenti della squadra). Ratés 05.
func piazza_esplosivo(a: Dictionary) -> String:
	if not puo_esplosivo(a):
		return "Serve un sommozzatore con un esplosivo a tempo nell’esagono di una chiatta."
	var v := chiatta_in(a.hex)
	a.esplosivi_ss = int(a.esplosivi_ss) - 1
	var e := {"chiatta": v.id, "hex": v.hex}
	if p.fase_round():
		e.round = int(p.s.round.get("n", 0)) + 1
	else:
		e.mosse = 2
	_st().esplosivi.append(e)
	p._log("azione", "%s applica un esplosivo a tempo alla %s (%s)." % [p.nome(a), v.nome.to_lower(),
		"salta alla fine del prossimo Round" if p.fase_round() else "salta tra poco"])
	return ""

func _scoppia(e: Dictionary, prematuro := false) -> void:
	_st().esplosivi.erase(e)
	var v: Dictionary = p.veicoli.v(str(e.chiatta))
	if not prematuro and p.percentuale() <= 5:
		p._log("dado", "L’esplosivo a tempo sulla %s fa cilecca." % str(v.get("nome", "chiatta")).to_lower())
		return
	if v.is_empty() or v.stato != "attivo":
		return
	distruggi_chiatta(v, "esplosivo a tempo")
	for x in p.unita_in(str(e.hex)):
		if p.attivo(x) and in_acqua(x):
			var prima: String = x.postura
			x.postura = "prone" if sott_acqua(x) else "standing"
			p._danno_esplosione(x, T.CARICA_FUORI)
			if p.attivo(x):
				x.postura = prima

func fine_round() -> void:
	if not attiva():
		return
	m23.fine_round()
	var n := int(p.s.round.get("n", 0))
	for e in _st().esplosivi.duplicate():
		if e.has("round") and int(e.round) <= n:
			_scoppia(e)
	for a in p.americani() + p.tedeschi():
		if (a.get("senz_aria", false) or not sommozzatore(a)) and sott_acqua(a):
			a.postura = "standing"
			p._log("info", "%s deve tornare in superficie a respirare." % p.nome(a))

func dopo_mossa_operazioni() -> void:
	if not attiva() or p.fase_round():
		return
	for e in _st().esplosivi.duplicate():
		if e.has("mosse"):
			e.mosse = int(e.mosse) - 1
			if int(e.mosse) <= 0:
				_scoppia(e)

func barca_in(h: String) -> bool:
	if not attiva():
		return false
	for g in p.tedeschi():
		if g.get("barca_ss", false) and p.in_mappa(g) and g.hex == h:
			return true
	return false

## Carica lanciata o granata che esplode nell’esagono di una chiatta o di una barca di guardia.
func esplosione(tipo: String, h: String) -> void:
	if not attiva():
		return
	m20.esplosione(tipo, h)
	var v := chiatta_in(h)
	if not v.is_empty():
		if tipo == "satchel":
			distruggi_chiatta(v, "carica da demolizione")
		elif tipo == "granata":
			var r: int = p.d10()
			var l := T.lettera_danno(T.GRANATA_DENTRO, r)
			p._log("dado", "Granata sulla %s: %d → %s." % [v.nome.to_lower(), r, p._nome_danno(l)])
			if l in ["I", "K"]:
				distruggi_chiatta(v, "granata")
	for g in p.tedeschi():
		if g.get("barca_ss", false) and p.in_mappa(g) and g.hex == h and tipo in ["granata", "satchel"]:
			# 674: lanciata dritta nella barca la distrugge; se ci arriva deviando, dado dispari dentro, pari in acqua.
			var ul: Dictionary = p.s.get("ultimo_lancio", {})
			var dentro := true
			if not (bool(ul.get("diretto", true)) and str(ul.get("bersaglio", h)) == h):
				var r2: int = p.d10()
				dentro = r2 % 2 == 1
				p._log("dado", "L’ordigno arriva deviando nell’esagono della barca (%d): %s." % [r2, "cade dentro" if dentro else "cade in acqua"])
			if dentro:
				p._log("danno", "L’ordigno cade dentro la barca di guardia: la barca è distrutta e l’equipaggio ucciso.")
				_elimina_barca(g, "ordigno a bordo")

## Bazooka contro una chiatta (bersaglio grande allo scoperto).
func bazooka_chiatta(a: Dictionary, vid: String) -> String:
	var v: Dictionary = p.veicoli.v(vid)
	var bz: Dictionary = p.arma_di(a, "bazooka")
	if v.is_empty() or v.stato != "attivo" or bz.is_empty():
		return "Serve un bazooka e una chiatta attiva."
	if p.munizioni_arma(a, "bazooka") <= 0:
		return "Il bazooka non ha più razzi."
	var d := E.distanza(a.hex, v.hex)
	var g: Array = T.ARMI.bazooka.gittate
	if d > int(g[2]) or not p.terreno.vede(a.hex, v.hex, a.postura, "standing"):
		return "La chiatta non è in vista o è fuori portata."
	# 237: la chiatta è un mezzo grande allo scoperto; valgono abilità, ferita e razzo difettoso come per ogni tiro.
	var prob: int = T.base_per_distanza("bazooka", d) + int(T.MOD_VEICOLO.get("clear", [2, 3])[1]) + int(a.WS) - (1 if a.ferito else 0)
	prob = clampi(prob, 0, 8)
	var pi: int = p.percentuale()
	if pi <= int(T.ARMI.bazooka.inc[0]):
		p._log("dado", "Percentuale %02d: razzo difettoso, nessun effetto." % pi)
		p._consuma_bazooka(a, bz)
		return ""
	var r: int = p.d10()
	var preso: bool = r == 0 or (r != 9 and r <= prob)
	p._log("combattimento", "%s spara col bazooka alla %s: serve 0–%d, esce %d → %s." % [p.nome(a), v.nome.to_lower(), prob, r, "COLPITA" if preso else "mancata"])
	p._fx("tiro", {"da": a.hex, "a": v.hex, "tiratore": a.id, "bersaglio": "", "arma": "bazooka", "esito": "colpito" if preso else "mancato", "mirato": true, "auto": false, "prob": prob})
	p._consuma_bazooka(a, bz)
	if preso:
		var rp: int = p.d10()
		var pen := T.penetrazione("bazooka", rp)
		p._log("dado", "Penetrazione: %d → %s." % [rp, pen])
		if pen in ["M", "H"]:
			distruggi_chiatta(v, "bazooka")
	return ""

# ------------------------------------------------------------------ barche di guardia
func _crea_barca(num: int, h: String) -> Dictionary:
	var gid := "g%d" % num
	if not p.u(gid).is_empty():
		return {}
	p._op({"op": "activate", "g": [[num, h]], "stance": "crouching", "adv": null, "two": [], "us_two": false, "aware": false,
		"reaction": "", "rounds": true}, {})
	var g: Dictionary = p.u(gid)
	if g.is_empty():
		return {}
	g.barca_ss = true
	g.equip_ss = 3
	g.munizioni.granata = 99
	g.no_auto = true
	_aggiorna_equipaggio(g)
	return g

func _aggiorna_equipaggio(g: Dictionary) -> void:
	var d: Dictionary = p.missione.tedeschi[str(int(g.num))].get("equipaggio", {})
	var r: Dictionary = d.get(str(int(g.equip_ss)), {})
	if not r.is_empty():
		g.IN = int(r.IN)
		g.PC = int(r.PC)
		g.WS = int(r.WS)

func _elimina_barca(g: Dictionary, motivo: String) -> void:
	if not p.attivo(g):
		return
	p._log("danno", "La barca di guardia %d è eliminata (%s)." % [int(g.num), motivo])
	var dati: Dictionary = p.missione.tedeschi[str(int(g.num))]
	if int(dati.get("pv_eliminata", 0)) > 0:
		p._pv(int(dati.pv_eliminata), "barca di guardia %d eliminata" % int(g.num))
	p._uccidi(g, "con la barca di guardia")

func _colpita_barca(g: Dictionary, tipo: String, tiratore: Dictionary, fx: Dictionary) -> void:
	var r: int = p.d10()
	if r % 2 == 1:
		var rd: int = p.d10()
		var l := T.lettera_danno(T.ARMI[tipo].danni, rd)
		fx.danno = p._nome_danno(l)
		p._log("dado", "Colpo sulla barca %d: %d (dispari) → colpito l’equipaggio: %d → %s." % [int(g.num), r, rd, p._nome_danno(l)])
		if l == "P":
			p._log("info", "L’equipaggio si spaventa ma resta ai suoi posti.")
			return
		var persi := 1
		if tipo == "bazooka":
			persi = int(g.equip_ss)
		g.equip_ss = int(g.equip_ss) - persi
		if int(g.equip_ss) <= 0:
			_elimina_barca(g, "senza equipaggio")
			return
		_aggiorna_equipaggio(g)
		p._log("danno", "La barca %d ha ora %d uomini di equipaggio." % [int(g.num), int(g.equip_ss)])
	else:
		var rp: int = p.d10()
		var pen := T.penetrazione(tipo, rp)
		p._log("dado", "Colpo sulla barca %d: %d (pari) → colpito lo scafo, penetrazione %d → %s." % [int(g.num), r, rp, {"-": "nessuna", "L": "leggera", "M": "media", "H": "pesante"}[pen]])
		if pen == "L":
			g.barca_lenta = true
			p._log("danno", "La barca %d d’ora in poi va solo piano." % int(g.num))
		elif pen in ["M", "H"]:
			_elimina_barca(g, "scafo sfondato")

## Turno di una barca di guardia (paragrafi 911–918): l’equipaggio spende i suoi punti (1 per esagono piano, 2 per due
## esagoni veloce, 1 per un tiro o una granata).
func turno_barca(ia, g: Dictionary) -> void:
	var col := 0
	var num := int(p.s.round.get("numero_azione", 0))
	var gruppi: Array = [[0, 2], [3, 3], [4, 7], [8, 9]] if int(g.num) == 60 else [[0, 0], [1, 2], [3, 7], [8, 9]]
	for i in gruppi.size():
		if num >= int(gruppi[i][0]) and num <= int(gruppi[i][1]):
			col = i
	var righe: Dictionary = p.missione.tedeschi[str(int(g.num))].get("equipaggio", {})
	var par: int = int(righe.get(str(int(g.equip_ss)), {}).get("par", [911, 912, 913, 914])[col])
	var base: int = 911 if int(g.num) == 60 else 915
	var variante: int = par - base
	p._log("tedesco", "Turno della barca di guardia %d (equipaggio %d): numero d’azione %d → paragrafo %d." % [int(g.num), int(g.equip_ss), num, par])
	var chiave := "%03d" % par
	if p.paragrafi.has(chiave):
		p._log("par", p.paragrafi[chiave].it, {"id": chiave, "tedesco": g.id})
	ia._g = g
	var punti := int(g.equip_ss)
	var meta: String = PATTUGLIA.get(int(g.num), "F5")
	var vicini: Array = ia.bersagli(g)
	vicini.sort_custom(func(a, b): return _prima_sub(a, b, g.hex))
	var stesso: Array = vicini.filter(func(a): return E.distanza(a.hex, g.hex) <= 1)
	match variante:
		0, 2:
			if not stesso.is_empty() and punti > 0:
				ia._miglior_tiro("vicino", 1)
				punti -= 1
			if punti > 0 and _granata_barca(ia, g, 2, 3):
				punti -= 1
			if punti > 0:
				punti -= _muovi_barca(g, vicini[0].hex if not vicini.is_empty() else meta, mini(punti, 1 if not vicini.is_empty() else 2))
		1:
			if punti > 0:
				punti -= _muovi_barca(g, vicini[0].hex if not vicini.is_empty() else meta, mini(punti, 2))
			if punti > 0:
				ia._tiri_rapidi()
				punti -= 1
		3:
			if punti > 0 and not vicini.is_empty():
				ia._miglior_tiro("vicino")
				punti -= 1
			if punti > 0:
				punti -= _muovi_barca(g, vicini[0].hex if not vicini.is_empty() else meta, mini(punti, 2 if not vicini.is_empty() else 1))
			if punti > 0 and _granata_barca(ia, g, 1, 4):
				punti -= 1
	if punti > 0 and p.attivo(g) and not ia.bersagli(g).is_empty():
		ia._miglior_tiro("facile")

func _prima_sub(a: Dictionary, b: Dictionary, h: String) -> bool:
	var sa := 0 if sommozzatore(a) else 1
	var sb := 0 if sommozzatore(b) else 1
	if sa != sb:
		return sa < sb
	return E.distanza(a.hex, h) < E.distanza(b.hex, h)

func _granata_barca(ia, g: Dictionary, da: int, a: int) -> bool:
	for x in ia.bersagli(g):
		var d := E.distanza(x.hex, g.hex)
		if d >= da and d <= a and p.probabilita_lancio(g, "granata", x.hex).ok:
			p.risolvi_lancio(g, "granata", x.hex)
			return true
	return false

## Muove la barca di n esagoni d’acqua verso h; restituisce i punti equipaggio spesi.
func _muovi_barca(g: Dictionary, h: String, n: int) -> int:
	if g.get("barca_lenta", false):
		n = mini(n, 1)
	var fatti := 0
	while fatti < n and g.hex != h and p.attivo(g):
		var migliore := ""
		for v in E.vicini(g.hex):
			if acqua(v) and E.distanza(v, h) < E.distanza(g.hex, h):
				migliore = v
				break
		if migliore == "":
			break
		var da: String = g.hex
		g.hex = migliore
		p._fx("muovi", {"ids": [g.id], "da": da, "a": migliore})
		fatti += 1
	if fatti > 0:
		p._log("tedesco", "La barca di guardia %d %s fino a %s." % [int(g.num), "corre" if fatti > 1 else "avanza", g.hex])
	return fatti

# ------------------------------------------------------------------ sommozzatori tedeschi
## Nuota verso h (2 PM per esagono); emerge prima se richiesto.
func nuota_verso(g: Dictionary, h: String, emergi := false) -> void:
	if emergi and sott_acqua(g):
		g.postura = "standing"
		p._log("tedesco", "Il %s riemerge." % p.nome(g))
	var passi: int = int(p.effettivo_mpa(g)) / 2
	var fatti := 0
	while fatti < passi and g.hex != h and p.attivo(g):
		var migliore := ""
		for v in E.vicini(g.hex):
			if acqua(v) and E.distanza(v, h) < E.distanza(g.hex, h):
				migliore = v
				break
		if migliore == "":
			break
		var da: String = g.hex
		g.hex = migliore
		p._fx("muovi", {"ids": [g.id], "da": da, "a": migliore})
		fatti += 1
	if fatti > 0:
		p._log("tedesco", "Il %s nuota fino a %s." % [p.nome(g), g.hex])

func sub_americani() -> Array:
	return p.americani_attivi_in_mappa().filter(func(a): return sommozzatore(a) and in_acqua(a))

# ------------------------------------------------------------------ inizio Round e controlli
func evento_sostitutivo() -> bool:
	if not attiva():
		return false
	return m20.evento_sostitutivo() or m21.evento_sostitutivo() or m23.evento_sostitutivo()

func inizio_round() -> void:
	if not attiva():
		return
	m20.inizio_round()
	m21.inizio_round()
	m22.inizio_round()
	m23.inizio_round()
	m24.inizio_round()
	for v in p.veicoli.tutti():
		if v.lato == "de" and m19():
			v.bersagliato = false

func controlla() -> void:
	if m20.attiva():
		m20.controlla()
		return
	if m21.attiva():
		m21.controlla()
		return
	if m22.attiva():
		m22.controlla()
		return
	if m23.attiva():
		m23.controlla()
		return
	if m24.attiva():
		m24.controlla()
		return
	if not attiva() or p.s.fase == "fine" or not _st().fine_789:
		return
	var vivi: Array = p.americani_attivi_in_mappa()
	var de_attivi: Array = p.tedeschi_attivi().filter(func(g): return p.attivo(g) and p.in_mappa(g))
	if vivi.is_empty():
		var usciti: Array = p.americani().filter(func(a): return a.stato == "uscito")
		if not usciti.is_empty() and not de_attivi.is_empty():
			_st().fine_modo = 1
			p._log("info", "Tutta la squadra è uscita da A1: la missione termina.")
			p._calcola_fine("ritirata")
		return
	if de_attivi.is_empty():
		var tutti := true
		for a in vivi:
			if not (acqua(a.hex) and E.riga(a.hex) <= 2 and E.colonna(a.hex) <= 6):
				tutti = false
		if tutti:
			_st().fine_modo = 2
			p._log("info", "Tutti gli americani sono in acqua a sud della colonna G, nelle righe 1–2, e non ci sono tedeschi attivi: la missione termina.")
			p._calcola_fine("obiettivo")

func niente_pv_incapacitati() -> bool:
	if m22.attiva():
		return m22.niente_pv_incapacitati()
	return attiva() and int(_st().get("fine_modo", 0)) == 2 and m19()

func blocca_fine() -> bool:
	if m20.attiva():
		return m20.blocca_fine()
	if m21.attiva():
		return m21.blocca_fine()
	if m22.attiva():
		return m22.blocca_fine()
	if m23.attiva():
		return m23.blocca_fine()
	if m24.attiva():
		return m24.blocca_fine()
	return attiva() and not _st().fine_789 and not p.americani_attivi_in_mappa().is_empty()

func uscita_ammessa(h: String) -> bool:
	if m20.attiva():
		return m20.uscita_ammessa(h)
	if m21.attiva():
		return m21.uscita_ammessa(h)
	if m22.attiva():
		return m22.uscita_ammessa(h)
	if m24.attiva():
		return m24.uscita_ammessa(h)
	return not attiva() or _st().fine_789

# ------------------------------------------------------------------ operazioni dei paragrafi
func op(o: Dictionary, ctx: Dictionary) -> bool:
	if not attiva() or not (str(o.op).begins_with("ss") or str(o.op) == "event_check_ops"):
		return false
	if m20.op(o, ctx) or m21.op(o, ctx) or m22.op(o, ctx) or m23.op(o, ctx) or m24.op(o, ctx):
		return true
	match str(o.op):
		"ss_magazzino":
			var h: String = str(ctx.get("hex", ""))
			for t in ["mp", "bolt"]:
				p._lascia_oggetto(h, {"tipo": t, "inceppata": false, "rotta": false, "preparata": true, "catturata": true, "munizioni": 3})
			p._lascia_oggetto(h, {"tipo": "satchel", "inceppata": false, "rotta": false, "preparata": false, "catturata": true})
			_st().magazzino = h
			for k in ["mp", "mp", "mp", "bolt", "bolt", "bolt", "granata", "granata", "granata"]:
				p.s.oggetti[h] = p.s.oggetti.get(h, []) + [{"tipo": "mun:" + k}]
			p._log("info", "Nel magazzino in %s ci sono una pistola mitragliatrice e un fucile con 3 caricatori ciascuno, 3 granate e una carica da demolizione da preparare: si raccolgono come le armi a terra." % h)
		"ss_camion":
			_camion(str(o.hex))
		"ss_nota_237":
			_st().nota_237 = true
		"ss_scende_camion":
			_scende_camion(ctx, "")
		"ss_scendono_tutti":
			_scende_camion(ctx, str(o.hex))
		"ss_sub_tedesco":
			p._op({"op": "activate", "g": [[int(o.g), str(o.hex)]], "stance": "standing", "adv": null, "two": [], "us_two": false,
				"aware": false, "reaction": "", "rounds": true}, ctx)
			var gs: Dictionary = p.u("g%d" % int(o.g))
			if not gs.is_empty():
				gs.sub = true
				gs.postura = "standing"
		"ss_trappola_sub":
			_trappola_sub(ctx, bool(o.superato))
		"ss_barca_guardia":
			var gb := _crea_barca(int(o.g), str(o.hex))
			if not gb.is_empty() and p.fase_round() and bool(o.get("two", false)):
				p.s.round.get("due_turni_de", []).append(gb.id)
			if o.has("adv") and p.s.has("round") and not p.s.round.is_empty() and int(p.s.round.get("n", 0)) == 0:
				p.s.round.vantaggio_forzato = str(o.adv)
		"ss_chiatte":
			var r: int = p.d10()
			var lista: Array = o.dispari if r % 2 == 1 else o.pari
			p._log("dado", "Dado %d: chiatte in %s." % [r, ", ".join(lista)])
			_piazza_chiatte(lista)
		"ss_torna_indietro":
			# Silver Star 480: torrente invalicabile; si torna nell’esagono di partenza (−2 PM se fallisce il controllo).
			var ids: Array = ctx.get("ids", [])
			if ids.is_empty() and str(ctx.get("g", "")) != "":
				ids = [str(ctx.g)]
			for id in ids:
				var x: Dictionary = p.u(str(id))
				var da: String = str(x.get("hex_prec", ""))
				if x.is_empty() or da == "" or da == x.hex:
					continue
				var v: Dictionary = p.veicoli.di(x)
				if not v.is_empty() and p.veicoli.e_autista(x):
					p.veicoli.sposta(v, da)
				elif v.is_empty():
					x.hex = da
				var ok_pc: bool = p.controllo_pc(x, 0, "sul torrente invalicabile")
				if not ok_pc and not p.s.turno.is_empty() and str(p.s.turno.get("id", "")) == x.id:
					p.s.turno.mp = maxi(0, int(p.s.turno.mp) - 2)
				p._log("info", "Il torrente qui è invalicabile: %s torna in %s%s." % [p.nome(x), da, "" if ok_pc else " e perde 2 PM"])
		"ss_vantaggio":
			if p.s.has("round") and not p.s.round.is_empty():
				p.s.round.vantaggio_forzato = str(o.lato)
				p._log("info", "Vantaggio %s." % ("americano" if str(o.lato) == "us" else "tedesco"))
		"ss_esplosivo_prematuro":
			var lista_e: Array = _st().esplosivi
			if lista_e.is_empty():
				p._log("info", "Nessun esplosivo a tempo innescato.")
			else:
				var e: Dictionary = lista_e[p.rng.randi_range(0, lista_e.size() - 1)]
				p._log("info", "Un esplosivo a tempo salta prima del previsto!")
				_scoppia(e, true)
		"ss_senz_aria":
			if _st().senz_aria:
				p._log("info", "È già successo: si tira un nuovo evento.")
				p.evento_casuale({"hex": "", "ids": []}, {})
				return true
			var sub: Array = (p.americani() + p.tedeschi()).filter(func(x): return sommozzatore(x) and p.attivo(x) and p.in_mappa(x))
			if sub.is_empty():
				return true
			_st().senz_aria = true
			var x: Dictionary = sub[p.rng.randi_range(0, sub.size() - 1)]
			x.senz_aria = true
			p._log("info", "%s resta senz’aria: dovrà finire ogni Round in superficie." % p.nome(x))
		"ss_gomma_camion":
			var cam := _camion_attivo()
			if cam.is_empty():
				p._log("info", "Il camion non è in gioco: si tira un nuovo evento.")
				p.evento_casuale({"hex": "", "ids": []}, {})
				return true
			if int(_st().gomme_camion) >= 1 and not cam.gomme:
				p._log("info", "Seconda gomma forata: il camion è immobilizzato e conta come distrutto.")
				p.veicoli.disabilita(cam, "due gomme forate")
			else:
				_st().gomme_camion = int(_st().gomme_camion) + 1
				cam.gomme = false
				p._log("info", "Il camion fora una gomma: d’ora in poi va solo piano.")
				p.veicoli.controllo_incidente(cam, "gomma forata")
		"ss_sgancia_sub":
			_sgancia()
		"ss_fine_789":
			_st().fine_789 = true
			p._log("info", "La missione finisce quando la squadra esce da A1 (con tedeschi ancora attivi) oppure è in acqua nelle righe 1–2 a sud della colonna G senza tedeschi attivi.")
		"ss_chiatta_mov":
			_chiatta_mov(o, ctx)
		_:
			return false
	return true

func test(t: Dictionary, ctx: Dictionary):
	if not attiva():
		return null
	var t20 = m20.test(t, ctx)
	if t20 != null:
		return t20
	var t21 = m21.test(t, ctx)
	if t21 != null:
		return t21
	var t22 = m22.test(t, ctx)
	if t22 != null:
		return t22
	var t23 = m23.test(t, ctx)
	if t23 != null:
		return t23
	var t24 = m24.test(t, ctx)
	if t24 != null:
		return t24
	if t.has("ss_sott_acqua"):
		var chi := _chi(ctx)
		return (not chi.is_empty() and sott_acqua(chi)) == bool(t.ss_sott_acqua)
	if t.has("ss_in_canoa"):
		var chi2 := _chi(ctx)
		return (not chi2.is_empty() and p.veicoli.e_canoa(p.veicoli.di(chi2)) and not chi2.get("aggrappato", false)) == bool(t.ss_in_canoa)
	if t.has("ss_avvistamento_tranne_9"):
		for i in 9:
			if bool(p.s.avvistamenti[i]):
				return true
		return false
	if t.has("ss_s1_o_s2"):
		return bool(p.s.avvistamenti[1]) or bool(p.s.avvistamenti[2])
	if t.has("ss_vista"):
		return int(p.regola("vista", 3)) == int(t.ss_vista) and int(p.s.get("vista", p.regola("vista", 3))) == int(t.ss_vista)
	if t.has("ss_chiatte_max"):
		return chiatte_attive().size() <= int(t.ss_chiatte_max)
	if t.has("ss_entrato_da"):
		var chi3 := _chi(ctx)
		return not chi3.is_empty() and str(chi3.get("hex_prec", "")) == str(t.ss_entrato_da)
	if t.has("ss_piu_tedeschi"):
		var a: String = str(t.ss_piu_tedeschi[0])
		var b: String = str(t.ss_piu_tedeschi[1])
		return p.unita_in(a, "de").size() > p.unita_in(b, "de").size()
	if t.has("ss_meno_a_sud"):
		var lim: int = "ABCDEFGHIJKLMNOPQRSTUVWXY".find(str(t.ss_meno_a_sud))
		var sud := 0
		var nord := 0
		for x in p.americani_attivi_in_mappa():
			if E.colonna(x.hex) <= lim:
				sud += 1
			else:
				nord += 1
		return sud < nord
	if t.has("ss_esplosivi_innescati"):
		return not _st().esplosivi.is_empty()
	return null

func _chi(ctx: Dictionary) -> Dictionary:
	for id in ctx.get("ids", []):
		var x: Dictionary = p.u(str(id))
		if not x.is_empty():
			return x
	return p._soldato_pc(ctx)

func _sgancia() -> void:
	_st().sganciati = true
	var n := 0
	for a in p.americani():
		if a.get("aggrappato", false):
			p.veicoli.scendi(a)
			a.erase("aggrappato")
			a.postura = "standing"
			n += 1
	if n > 0:
		p._log("info", "%d sommozzatori si staccano dalle canoe ed entrano nella cala." % n)

func _trappola_sub(ctx: Dictionary, superato: bool) -> void:
	var h: String = str(ctx.get("hex", ""))
	var chi: Array = p.unita_in(h, "us").filter(func(a): return in_acqua(a))
	if chi.is_empty():
		return
	var esposti: Array = []
	for a in chi:
		var ok: bool = superato and a == chi[0]
		if not ok:
			ok = p.controllo_pc(a, 0, "trappola subacquea")
		if ok and superato:
			var da: String = str(a.get("hex_prec", ""))
			if da != "" and acqua(da):
				a.hex = da
				p._log("info", "%s si accorge della trappola e torna in %s." % [p.nome(a), da])
				p._fx("muovi", {"ids": [a.id], "da": h, "a": da})
		else:
			esposti.append(a)
	if esposti.is_empty():
		return
	var r: int = p.d10()
	p._log("dado", "Trappola subacquea: %d." % r)
	if r <= 4:
		p._log("info", "La trappola non esplode.")
		return
	p._fx("esplosione", {"a": h})
	for a in esposti:
		p._danno_esplosione(a, T.GRANATA_FUORI)
	p.s.oggetti[h] = p.s.oggetti.get(h, []).filter(func(x): return x.get("tipo", "") != "trappola")
	p.leggi("560", {"hex": h})

# ------------------------------------------------------------------ camion dei rinforzi
func _camion_attivo() -> Dictionary:
	var v: Dictionary = p.veicoli.v("camion_ss")
	return v if p.veicoli.attivo(v) else {}

func _camion(h: String) -> void:
	if not p.veicoli.v("camion_ss").is_empty():
		return
	var nums := [10, 11, 12, 13, 14, 15]
	p._op({"op": "activate", "g": nums.map(func(n): return [n, h]), "stance": "crouching", "adv": "de", "two": [10], "us_two": false,
		"aware": false, "reaction": "T", "rounds": true}, {})
	var v: Dictionary = p.veicoli.crea("camion_ss", "camion", h, "de")
	v.nome = "Camion"
	v.pv_distrutto = 2
	for n in nums:
		var g: Dictionary = p.u("g%d" % n)
		if g.is_empty() or not p.attivo(g):
			continue
		g.veicolo = v.id
		v.occupanti.append(g.id)
		g.postura = "crouching"
	p._log("attivazione", "Il camion dei rinforzi entra in %s con i tedeschi 10–15 a bordo." % h)

func _scende_camion(ctx: Dictionary, h: String) -> void:
	var gid: String = str(ctx.get("g", ""))
	var lista: Array = []
	var v := _camion_attivo()
	if h != "" and not v.is_empty():
		lista = p.veicoli.occupanti(v)
	else:
		var g: Dictionary = p.u(gid)
		if not g.is_empty() and str(g.get("veicolo", "")) != "":
			lista = [g]
	for g in lista:
		p.veicoli.scendi(g)
		g.reazione = ""
		g.postura = "standing"
		if h != "":
			g.hex = h
		p._log("tedesco", "Il %s scende dal camion in %s." % [p.nome(g), g.hex])
	if h != "":
		ctx.verso_veicolo = ""

## Paragrafi 452–457, 919–930: il camion lascia un passeggero accanto a una chiatta libera, o un soldato ci sale.
func _chiatta_mov(o: Dictionary, ctx: Dictionary) -> void:
	var libera := {}
	for h in o.chiatte:
		var c := chiatta_in(str(h))
		if not c.is_empty() and p.veicoli.occupanti(c).filter(func(x): return p.attivo(x)).size() <= int(o.max):
			libera = c
			break
	if bool(ctx.get("veicolo", false)):
		var v: Dictionary = p.veicoli.v(str(ctx.get("veicolo_id", "")))
		if not libera.is_empty() and not v.is_empty() and str(o.scende) != "":
			var pass_: Array = p.veicoli.occupanti(v).filter(func(x): return p.attivo(x)).slice(1)
			if not pass_.is_empty():
				var x: Dictionary = pass_[p.rng.randi_range(0, pass_.size() - 1)]
				p.veicoli.scendi(x)
				x.hex = str(o.scende)
				x.postura = "standing"
				x.reazione = ""
				p._log("tedesco", "Il %s scende dal camion in %s." % [p.nome(x), x.hex])
				p._fx("muovi", {"ids": [x.id], "da": v.hex, "a": x.hex})
		ctx.verso_veicolo = str(o.v_entra if not libera.is_empty() else o.v_altrimenti)
		return
	var g: Dictionary = p.u(str(ctx.get("g", "")))
	if g.is_empty():
		return
	if not libera.is_empty() and E.distanza(g.hex, libera.hex) <= 1:
		var da: String = g.hex
		g.hex = libera.hex
		libera.occupanti.append(g.id)
		g.veicolo = libera.id
		g.postura = "crouching"
		g.reazione = "B"
		p._log("tedesco", "Il %s sale sulla %s in %s (reazione speciale B)." % [p.nome(g), libera.nome.to_lower(), libera.hex])
		p._fx("muovi", {"ids": [g.id], "da": da, "a": libera.hex})
		return
	p._op({"op": "g_enter", "hex": str(o.s_altrimenti)}, ctx)
	if str(o.s_reazione) != "":
		g.reazione = str(o.s_reazione)

# ------------------------------------------------------------------ carri di Silver Star (paragrafi 900–967, 706–707, 814–874)
## Bivi: [n bersagli minimo per chiudere, paragrafo se già chiuso, soglia «pochi», paragrafo «pochi» (chiude prima se chiudi_pochi),
## paragrafo se nessuno e già aperto]. Vedi esegui_carro.
const BIVI := {
	900: {"tanti": 3, "chiuso": 901, "pochi": 903, "aperto": 906, "bersagliato": true},
	902: {"tanti": 1, "chiuso": 901, "nessuno_diretto": 906},
	905: {"tanti": 2, "chiuso": 901, "pochi": 910, "aperto": 906},
	907: {"tanti": 3, "chiuso": 910, "pochi": 903, "aperto": 906},
	921: {"tanti": 3, "chiuso": 925, "pochi": 927, "aperto": 929, "bersagliato": true},
	928: {"tanti": 2, "chiuso": 933, "pochi": 924, "aperto": 922},
	936: {"tanti": 1, "chiuso": 933, "aperto": 935},
	939: {"tanti": 3, "chiuso": 943, "pochi_chiude": 944, "aperto": 944},
	946: {"tanti": 2, "chiuso": 949, "pochi_chiude": 951, "aperto": 953},
	956: {"tanti": 2, "chiuso": 958, "pochi_chiude": 965, "aperto": 967},
	707: {"tanti": 1, "chiuso": 934, "aperto": 935},
}

## Azioni: sequenze di passi. g = guida (piano/veloce/«bersagliato»), m = mitragliatrice (scafo/coax, mirato, quale), c = cannone o
## carica, k = carica, s = coax mirata/rapida al secondo se il cannone è pronto e non ha sparato.
const AZIONI := {
	901: [["m", "scafo", true, 0], ["c"], ["s", true]],
	910: [["m", "scafo", true, 0], ["c"], ["s", true]],
	927: [["m", "scafo", true, 0], ["c"], ["s", true]],
	943: [["m", "scafo", true, 0], ["c"], ["s", true]],
	949: [["m", "scafo", true, 0], ["c"], ["s", true]],
	903: [["g", false], ["c"], ["s", false], ["m", "scafo", false, 0]],
	944: [["g", false], ["c"], ["s", false], ["m", "scafo", false, 0]],
	906: [["g", true], ["m", "scafo", false, 0], ["k"]],
	908: [["m", "scafo", true, 0]],
	922: [["g", true], ["m", "scafo", false, 0], ["k"]],
	923: [["g", true], ["m", "coax", false, 0], ["k"], ["m", "scafo", false, 1]],
	924: [["m", "scafo", true, 0], ["c"]],
	958: [["m", "scafo", true, 0], ["c"]],
	925: [["g", false], ["m", "scafo", false, 0], ["c"]],
	934: [["m", "scafo", false, 0], ["c"]],
	933: [["g", false], ["m", "scafo", false, 0], ["c"]],
	951: [["m", "scafo", false, 0], ["c"]],
	965: [["m", "scafo", false, 0], ["c"]],
	953: [["g", true], ["c"], ["m", "coax", false, 1], ["m", "coax", false, 0]],
	929: [["g", true]],
	935: [["g", true]],
	967: [["g", true]],
	827: [["g", true]],
	814: [["g", false]],
	826: [["g", "bersagliato"]],
	706: [["m", "coax", true, 0]],
	708: [["g", true], ["c"], ["s", false]],
	709: [["g", true], ["c"], ["s", true]],
}

func esegui_carro(n: int, g: Dictionary, veic: Dictionary, vc) -> bool:
	if (m22.attiva() or m23.attiva() or m24.attiva()) and n == 415:
		return m22.accendi_motore(g, veic)
	if not attiva() or not (BIVI.has(n) or AZIONI.has(n) or n in [937, 874, 840, 800]):
		return false
	var chiave := str(n)
	if p.paragrafi.has(chiave):
		p._log("par", p.paragrafi[chiave].it, {"id": chiave, "tedesco": g.id})
	var b: Array = vc.bersagli_carro(g)
	if n in [800, 840]:
		return true
	if n == 874 or (n == 937 and not b.is_empty()):
		p._log("danno", "L’equipaggio del %s si arrende." % veic.nome)
		vc.disabilita(veic, "equipaggio arreso")
		g.stato = "arreso"
		return true
	if n == 937:
		return true
	if BIVI.has(n):
		var d: Dictionary = BIVI[n]
		var chiuso: bool = veic.get("chiuso", false)
		var tanti: bool = b.size() >= int(d.tanti) or (d.get("bersagliato", false) and bool(veic.get("colpito_ss", false)))
		if tanti:
			if chiuso:
				esegui_carro(int(d.chiuso), g, veic, vc)
			else:
				vc._apri_chiudi(veic, true)
		elif not b.is_empty() and (d.has("pochi") or d.has("pochi_chiude")):
			if d.has("pochi_chiude"):
				if chiuso:
					esegui_carro(int(d.pochi_chiude), g, veic, vc)
				else:
					vc._apri_chiudi(veic, true)
			else:
				esegui_carro(int(d.pochi), g, veic, vc)
		elif d.has("nessuno_diretto"):
			esegui_carro(int(d.nessuno_diretto), g, veic, vc)
		elif chiuso:
			vc._apri_chiudi(veic, false)
		else:
			esegui_carro(int(d.aperto), g, veic, vc)
		return true
	for passo in AZIONI[n]:
		if not vc.attivo(veic):
			break
		match str(passo[0]):
			"g":
				var veloce: bool = bool(veic.get("colpito_ss", false)) if str(passo[1]) == "bersagliato" else bool(passo[1])
				if veloce and veic.get("piano_finche_colpito", false) and not veic.get("colpito_ss", false):
					veloce = false
				vc._guida(veic, veloce, g)
			"m":
				vc._mg(g, veic, str(passo[1]), bool(passo[2]), int(passo[3]))
			"c":
				vc._cannone_o_carica(g, veic)
			"k":
				vc._carica(veic)
			"s":
				if veic.get("cannone_pronto", false) and not vc._sparato_cannone:
					vc._mg(g, veic, "coax", bool(passo[1]), 1)
	return true

# ------------------------------------------------------------------ unità americane indipendenti e moduli di missione
func agisce_da_solo(a: Dictionary) -> bool:
	return attiva() and (bool(a.get("ia_ss", false)) or (a.get("berserk", false) and p.attivo(a)))

func turni_automatici(n: int) -> bool:
	if not attiva():
		return false
	var agito := false
	for a in p.americani():
		if p.s.fase != "round":
			break
		if not agisce_da_solo(a) or int(a.turni) != n or a.slot != "turni" or not (p.attivo(a) or a.stato == "fuori"):
			continue
		if a.get("berserk", false):
			p.ph.berserk.turno_americano(a)
		else:
			m21.turno_americano(a)
		p._consuma_turno(a)
		agito = true
	return agito
