extends RefCounted
## Silver Star, Missione 21 «Sorpresa, sorpresa!»: difesa della baia presso Gela. I tedeschi arrivano per evento casuale con un
## Jagdpanther (21) e un Panzer (30) con i granatieri sopra (reazione speciale T), due tedeschi nascosti fra le case (reazione H),
## il cannone navale americano (US 03, serventi J e K), lo Sherman di soccorso (US 04) o la motovedetta (US 05) che porta via la
## squadra. Gli Sherman e la motovedetta seguono i riferimenti neri delle carte. Stato in p.s.ss.

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

const SQUADRA_ESCLUSI := ["J", "K", "AA", "PB"]

var p  # Partita
var ss  # missioni_ss.gd

func _init(partita, modulo) -> void:
	p = partita
	ss = modulo

func attiva() -> bool:
	return ss.attiva() and int(p.missione.get("id", 0)) == 21

func _st() -> Dictionary:
	return ss._st()

# ------------------------------------------------------------------ terreno
func regole_terreno() -> void:
	if not attiva():
		return
	for h in ["K12", "T7"]:
		var d: Dictionary = p.terreno.esagoni.get(h, {}).duplicate()
		d.ponte = true
		p.terreno.esagoni[h] = d
	if _st().get("guado_h11", false):
		var g: Dictionary = p.terreno.esagoni.get("H11", {}).duplicate()
		g.guado = true
		p.terreno.esagoni["H11"] = g

func _squadra() -> Array:
	return p.americani().filter(func(a): return not (a.id in SQUADRA_ESCLUSI))

# ------------------------------------------------------------------ carri tedeschi e granatieri a bordo (reazione T)
## I granatieri in reazione speciale T sul carro si muovono con lui.
func dopo_sposta(veic: Dictionary, verso: String) -> Array:
	if not attiva() or veic.lato != "de":
		return []
	var ids: Array = []
	for g in p.tedeschi():
		if p.attivo(g) and str(g.get("su_carro", "")) == veic.id and str(g.get("reazione", "")) == "T":
			g.hex = verso
			ids.append(g.id)
	return ids

func _carro_di(g: Dictionary) -> Dictionary:
	return p.veicoli.v(str(g.get("su_carro", "")))

## 425, 426, 584, 585: il granatiere sul carro. true se gestito.
func turno_granatiere(t, g: Dictionary, n: int) -> bool:
	var carro := _carro_di(g)
	var num := int(p.s.round.get("numero_azione", 0))
	if carro.is_empty() or not p.veicoli.attivo(carro) or carro.get("immobilizzato", false) or carro.get("cingolo", false) or carro.get("colpito_ss", false):
		g.reazione = ""
		g.erase("su_carro")
		p._log("tedesco", "Il %s salta giù dal carro: toglie la reazione speciale T." % p.nome(g))
		t._ritira_e_esegui()
		return true
	if g.hex == carro.hex:
		var dispari := num % 2 == 1
		match n:
			425, 584:
				t.esegui(840 if dispari else 868)
			426:
				t.esegui(868 if dispari else 800)
			585:
				t.esegui(868 if dispari else 800)
		return true
	var tab: Array = [[0, 3, 803], [4, 5, 809], [6, 8, 868], [9, 9, 800]] if n in [425, 584] else [[0, 2, 862], [3, 4, 863], [5, 6, 864], [7, 9, 858]]
	for r in tab:
		if num >= int(r[0]) and num <= int(r[1]):
			t.esegui(int(r[2]))
			break
	return true

## 583, 586: reazione speciale H (i tedeschi nascosti fra le case).
func turno_h(t, g: Dictionary, n: int) -> void:
	var qui: Array = p.unita_in(g.hex, "us")
	if not qui.is_empty():
		t._assalta(t._bersaglio_assalto())
		return
	var vicini: Array = p.americani_attivi_in_mappa().filter(func(a): return E.distanza(a.hex, g.hex) == 1)
	if not vicini.is_empty():
		if int(g.munizioni.get("granata", 0)) > 0:
			t._accovacciati()
			if t._lancia_granata(1):
				t._prono_se_libero()
				return
		if n == 586:
			t._assalta(vicini[0], true)
		else:
			t._accovacciati()
			t._miglior_tiro("facile")
			t._prono_se_libero()
		return
	var visti: Array = t.bersagli(g)
	if not visti.is_empty():
		t._corri_verso(visti[0].hex)
		t._prono_se_libero()
		return
	if n == 583 and g.hex == "I13":
		g.reazione = ""
		p.s.round.numero_azione = p.d10()
		t._ritira_e_esegui()
		return
	# Verso il bordo in alto (sud) finché la carta non dà un riferimento di movimento.
	if p.movimento_rosso(g.hex) != "":
		g.reazione = ""
		t._ritira_e_esegui()
		return
	var su := E.da(E.colonna(g.hex), maxi(1, E.riga(g.hex) - 1))
	t._corri_verso(su)

# ------------------------------------------------------------------ unità americane indipendenti
func _nuovo_us(id: String, nome: String, riga: Dictionary, h: String, porte: Array, mun: Dictionary) -> Dictionary:
	var d := {"id": id, "nome": nome, "IN": int(riga.IN), "PC": int(riga.PC), "WS": int(riga.WS), "DS": int(riga.get("DS", 4)),
		"MPA": int(riga.get("MPA", 4)), "comandante": false, "porte": porte, "munizioni": mun}
	var z: Dictionary = p._nuovo_americano(d)
	z.stato = "attivo"
	z.hex = h
	z.ia_ss = true
	z.consapevole = true
	z.postura = "crouching"
	for a in z.armi:
		a.preparata = true
	p.s.unita[id] = z
	p._fx("compare", {"id": id, "a": h, "amico": true})
	return z

## 473: il cannone navale in D2 con i serventi J e K.
func cannone_navale() -> void:
	if not p.u("J").is_empty():
		return
	var j := _nuovo_us("J", "Servente J", {"IN": 3, "PC": 6, "WS": 1, "MPA": 4}, "D2", ["carbine"], {"carbine": 1})
	var k := _nuovo_us("K", "Servente K", {"IN": 2, "PC": 4, "WS": 0, "MPA": 4}, "D2", ["carbine"], {"carbine": 3, "granata": 1})
	j.atg_ss = 0
	k.atg_ss = 1
	j.fuori_conto = true
	k.fuori_conto = true
	_st().atg = {"carico": true, "caricato": -1, "sparato": -1, "hex": "D2", "distrutto": false}
	p._log("info", "Il cannone navale in D2 (copre D3, E3, E2) entra in gioco con i serventi J e K: agiscono da soli.")

func _turno_corrente() -> int:
	return int(p.s.round.get("n", 0)) * 1000 + int(p.s.round.get("progressivo", 0)) * 10 + int(p.s.get("turno", {}).get("n", 0))

func _atg_spara(a: Dictionary, criterio: String) -> bool:
	var atg: Dictionary = _st().get("atg", {})
	if atg.is_empty() or atg.get("distrutto", false) or not atg.carico or int(atg.caricato) == int(p.s.round.get("n", 0)) * 100 + int(a.get("turni", 0)):
		return false
	var carri: Array = p.tedeschi_attivi().filter(func(g): return p.veicoli.attivo(p.veicoli.di(g)) and p.vede_unita(a, g))
	if carri.is_empty():
		return false
	carri.sort_custom(func(x, y): return E.distanza(x.hex, a.hex) < E.distanza(y.hex, a.hex))
	a.postura = "crouching"
	atg.carico = false
	atg.sparato = int(p.s.round.get("n", 0)) * 100 + int(a.get("turni", 0))
	p._log("info", "%s spara con il cannone navale contro il %s." % [p.nome(a), p.veicoli.di(carri[0]).nome])
	p.risolvi_tiro(a, {"tipo": "cannone", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "scarica": false}, carri[0], true)
	return true

func _atg_carica(a: Dictionary) -> bool:
	var atg: Dictionary = _st().get("atg", {})
	if atg.is_empty() or atg.get("distrutto", false) or atg.carico or int(atg.sparato) == int(p.s.round.get("n", 0)) * 100 + int(a.get("turni", 0)):
		return false
	a.postura = "crouching"
	atg.carico = true
	atg.caricato = int(p.s.round.get("n", 0)) * 100 + int(a.get("turni", 0))
	p._log("info", "%s carica il cannone navale." % p.nome(a))
	return true

func _tiro_us(a: Dictionary, criterio: String, entro := 99) -> void:
	var lista: Array = p.tedeschi_attivi().filter(func(g): return p.attivo(g) and p.in_mappa(g) and p.vede_unita(a, g) and E.distanza(a.hex, g.hex) <= entro)
	if lista.is_empty():
		return
	var arma: Dictionary = {}
	for w in a.armi:
		if not w.rotta and not w.inceppata and T.ARMI.get(w.tipo, {}).has("gittate"):
			arma = w
			break
	if arma.is_empty():
		return
	var migliore := {}
	var prob := -1
	for g in lista:
		var pr: Dictionary = p.probabilita_tiro(a, arma, g, true)
		if not pr.ok:
			continue
		var chiave: int = int(pr.prob) if criterio == "facile" else -E.distanza(a.hex, g.hex)
		if migliore.is_empty() or chiave > prob:
			migliore = g
			prob = chiave
	if migliore.is_empty():
		return
	a.postura = "crouching"
	p.risolvi_tiro(a, arma, migliore, true)

func _granata_us(a: Dictionary, raggio: int) -> bool:
	if int(a.munizioni.get("granata", 0)) <= 0:
		return false
	var lista: Array = p.tedeschi_attivi().filter(func(g): return p.attivo(g) and p.in_mappa(g) and g.hex != a.hex and E.distanza(g.hex, a.hex) <= raggio)
	if lista.is_empty():
		return false
	var conti := {}
	for g in lista:
		conti[g.hex] = int(conti.get(g.hex, 0)) + 1
	var h := ""
	for x in conti:
		if h == "" or int(conti[x]) > int(conti[h]):
			h = x
	if not p.probabilita_lancio(a, "granata", h).ok:
		return false
	p.risolvi_lancio(a, "granata", h)
	return true

## Turno di un’unità americana che agisce da sola (serventi del cannone, Sherman, motovedetta).
func turno_americano(a: Dictionary) -> void:
	if a.id in ["J", "K"]:
		_turno_servente(a)
	elif a.id == "AA":
		var v: Dictionary = p.veicoli.di(a)
		if p.veicoli.attivo(v):
			if int(p.s.round.get("numero_azione", -1)) < 0:
				p.s.round.numero_azione = p.d10()
			p.veicoli.turno_carro(p.ia, a, v)
	elif a.id == "PB":
		_turno_motovedetta(a)

func _turno_servente(a: Dictionary) -> void:
	var num := int(p.s.round.get("numero_azione", -1))
	if num < 0:
		num = p.d10()
		p.s.round.numero_azione = num
	var tab: Array = [477, 476, 474] if a.id == "J" else [474, 477, 476]
	var par: int = tab[0 if num <= 2 else (1 if num <= 7 else 2)]
	p._log("info", "Turno del %s: numero d’azione %d → paragrafo %d." % [p.nome(a), num, par])
	if p.paragrafi.has(str(par)):
		p._log("par", p.paragrafi[str(par)].it, {"id": str(par)})
	var qui: Array = p.unita_in(a.hex, "de")
	if not qui.is_empty():
		p.risolvi_assalto(a, qui[0], "uccidi", false)
		return
	var vicini: Array = p.tedeschi_attivi().filter(func(g): return p.attivo(g) and E.distanza(g.hex, a.hex) == 1)
	match par:
		474:
			if _granata_us(a, 3):
				return
			if _atg_spara(a, "vicino") or _atg_carica(a):
				return
			_tiro_us(a, "facile", 6)
		476:
			if not vicini.is_empty() and _granata_us(a, 1):
				return
			if _atg_carica(a) or _atg_spara(a, "facile"):
				return
			_tiro_us(a, "vicino")
		477:
			if not vicini.is_empty():
				_tiro_us(a, "facile", 1)
				return
			if _atg_carica(a) or _atg_spara(a, "vicino"):
				return
			if _granata_us(a, 3):
				return
			_tiro_us(a, "facile")

## 582: lo Sherman di soccorso (US 04) entra in A11 o in Y4.
func sherman() -> void:
	if not p.u("AA").is_empty():
		return
	var r: int = p.d10()
	var h := "A11" if r % 2 == 1 else "Y4"
	var verso := "B11" if r % 2 == 1 else "X3"
	var riga: Dictionary = p.missione.get("carri_us", {}).get("4", {}).get("carro", {}).get("righe", {}).get("5", {})
	var z := _nuovo_us("AA", "Sherman", riga, h, ["cannone", "mmg"], {"cannone": 20, "mmg": 10})
	z.num = 4
	z.carro_us = true
	var v: Dictionary = p.veicoli.crea("vsh4", "sherman", h, "us")
	v.nome = "Sherman"
	v.equipaggio = 5
	v.chiuso = false
	v.cannone_pronto = true
	v.fronte = E.direzione(h, verso)
	v.pv_distrutto_us = 3
	z.veicolo = v.id
	v.occupanti.append("AA")
	p._log("dado", "Dado %d: lo Sherman entra in %s." % [r, h])

## 587: la motovedetta (US 05) entra in A1.
func motovedetta() -> void:
	if not p.u("PB").is_empty():
		return
	var z := _nuovo_us("PB", "Motovedetta", {"IN": 5, "PC": 8, "WS": 2, "DS": 8}, "A1", ["hmg"], {"hmg": 99})
	z.num = 5
	z.carro_us = true
	var v: Dictionary = p.veicoli.crea("vpb", "motovedetta", "A1", "us")
	v.nome = "Motovedetta"
	v.equipaggio = 6
	v.fronte = E.direzione("A1", "B1")
	z.veicolo = v.id
	v.occupanti.append("PB")
	p._log("info", "La motovedetta entra in A1: raccoglie la squadra e la porta via (si sale da un esagono adiacente o dal suo).")

const RIGHE_PB := {6: [5, 8, 2, 8, [704, 705, 337, 705]], 5: [5, 8, 2, 8, [704, 705, 337, 705]], 4: [4, 6, 1, 6, [337, 704, 705, 704]],
	3: [4, 6, 1, 6, [337, 704, 705, 704]], 2: [2, 3, -1, 4, [705, 337, 704, 337]], 1: [2, 3, -1, 4, [705, 337, 704, 337]]}

func _turno_motovedetta(a: Dictionary) -> void:
	var v: Dictionary = p.veicoli.di(a)
	if not p.veicoli.attivo(v):
		return
	var cp := int(v.equipaggio)
	var riga: Array = RIGHE_PB.get(cp, RIGHE_PB[1])
	a.IN = int(riga[0])
	a.PC = int(riga[1])
	a.WS = int(riga[2])
	var num := int(p.s.round.get("numero_azione", -1))
	if num < 0:
		num = p.d10()
		p.s.round.numero_azione = num
	var par: int = riga[4][0 if num <= 3 else (1 if num == 4 else (2 if num <= 8 else 3))]
	if v.hex == "P1":
		par = 255
	p._log("info", "Turno della motovedetta (equipaggio %d): numero d’azione %d → paragrafo %d." % [cp, num, par])
	if p.paragrafi.has(str(par)):
		p._log("par", p.paragrafi[str(par)].it, {"id": str(par)})
	var tutti_a_bordo := _tutti_a_bordo()
	if tutti_a_bordo:
		if p.controllo_pc(a, 0, "la motovedetta riparte"):
			_esce_motovedetta(v)
			return
	match par:
		704:
			_guida_pb(v, true)
			_hmg(a, "facile")
			_carica_squadra(v)
		705:
			_carica_squadra(v)
			_guida_pb(v, false)
			_hmg(a, "vicino")
		337:
			_hmg(a, "facile")
			_carica_squadra(v)
			_guida_pb(v, true)
		255:
			_carica_squadra(v)
			_hmg(a, "vicino")
			_hmg(a, "vicino")

func _vicino_alla_squadra(v: Dictionary) -> bool:
	for x in _squadra():
		if p.attivo(x) and p.in_mappa(x) and str(x.get("veicolo", "")) != v.id and E.distanza(x.hex, v.hex) <= 2:
			return true
	return false

func _guida_pb(v: Dictionary, veloce: bool) -> void:
	if _vicino_alla_squadra(v):
		return
	var passi := 6 if veloce else 3
	for i in passi:
		if _vicino_alla_squadra(v):
			return
		var rif: String = p.movimento_veicolo(v, v.hex)
		if rif == "" or rif == "USCITA" or not E.valido(rif):
			return
		p.veicoli.sposta(v, rif)
		p._log("info", "La motovedetta va in %s." % rif)

func _hmg(a: Dictionary, criterio: String) -> void:
	_tiro_us(a, criterio)

func _carica_squadra(v: Dictionary) -> void:
	for x in _squadra():
		if str(x.get("veicolo", "")) == v.id or not (x.stato in ["attivo", "incapacitato"]) or not p.in_mappa(x):
			continue
		if E.distanza(x.hex, v.hex) <= 1:
			if x.stato == "incapacitato" and p.d10() == 0:
				x.stato = "morto"
				p._log("danno", "%s muore mentre lo issano a bordo." % p.nome(x))
				continue
			p.veicoli.scendi(x)
			x.hex = v.hex
			x.veicolo = v.id
			v.occupanti.append(x.id)
			x.postura = "crouching"
			p._log("info", "%s viene issato a bordo della motovedetta." % p.nome(x))

func _tutti_a_bordo() -> bool:
	var v: Dictionary = p.veicoli.v("vpb")
	if v.is_empty():
		return false
	var alcuni := false
	for x in _squadra():
		if p.attivo(x) and p.in_mappa(x):
			alcuni = true
			if str(x.get("veicolo", "")) != v.id:
				return false
	return alcuni

func _esce_motovedetta(v: Dictionary) -> void:
	var da: String = v.hex
	var ids: Array = []
	for x in p.veicoli.occupanti(v):
		x.stato = "uscito"
		x.hex = ""
		ids.append(x.id)
	v.stato = "uscito"
	v.hex = ""
	p._log("azione", "La motovedetta esce dal bordo sud con la squadra a bordo.")
	p._fx("sparisce", {"ids": ids + [v.id], "da": da, "motivo": "uscito"})
	_st().fine21 = "barca"

## Sali sulla motovedetta (dallo stesso esagono o da uno adiacente): comando del giocatore.
func puo_salire_pb(a: Dictionary) -> bool:
	var v: Dictionary = p.veicoli.v("vpb")
	return attiva() and p.veicoli.attivo(v) and p.attivo(a) and str(a.get("veicolo", "")) != "vpb" and not (a.id in SQUADRA_ESCLUSI) \
		and E.distanza(a.hex, v.hex) <= 1

func sali_pb(a: Dictionary) -> String:
	if not puo_salire_pb(a):
		return "Serve la motovedetta nello stesso esagono o in uno adiacente."
	var v: Dictionary = p.veicoli.v("vpb")
	p.veicoli.scendi(a)
	a.hex = v.hex
	a.veicolo = v.id
	v.occupanti.append(a.id)
	a.postura = "crouching"
	p._log("azione", "%s sale sulla motovedetta." % p.nome(a))
	return ""

# ------------------------------------------------------------------ fine
## −2 PV se il cannone navale è distrutto o senza serventi.
func righe_fine(righe: Array) -> int:
	if not attiva():
		return 0
	var atg: Dictionary = _st().get("atg", {})
	if atg.is_empty():
		return 0
	var serventi: Array = ["J", "K"].map(func(id): return p.u(id)).filter(func(x): return not x.is_empty() and p.attivo(x))
	if atg.get("distrutto", false) or serventi.is_empty():
		righe.append(["Cannone navale distrutto o senza serventi", -2])
		return -2
	return 0

func controlla() -> void:
	if not attiva() or p.s.fase == "fine":
		return
	var modo: String = str(_st().get("modo21", ""))
	if modo == "":
		return
	if str(_st().get("fine21", "")) == "barca":
		p._calcola_fine("ritirata")
		return
	var de: Array = p.tedeschi().filter(func(g): return p.attivo(g) and p.in_mappa(g))
	if de.is_empty():
		p._log("info", "Non ci sono più tedeschi attivi in mappa: la missione termina.")
		p._calcola_fine("obiettivo")

func blocca_fine() -> bool:
	return attiva() and str(_st().get("modo21", "")) == "" and not p.americani_attivi_in_mappa().is_empty()

func uscita_ammessa(h: String) -> bool:
	return str(_st().get("modo21", "")) == "barca" and _st().get("barca_affondata", false) and h in ["W1", "X1", "Y1"]

func inizio_round() -> void:
	if not attiva():
		return
	if _st().get("aspetta_471", false) and p.radio_presidiata():
		_st().aspetta_471 = false
		p.leggi("471", {})
	if _st().get("leggi_690", false) and not bool(p.s.avvistamenti[8]):
		_st().leggi_690 = false
		p.leggi("690", {})

# ------------------------------------------------------------------ operazioni e test
func _attiva_carro(num: int, h: String, riders: Array, reazione_riders: String, due: Array) -> void:
	var coppie: Array = [[num, h]]
	for r in riders:
		coppie.append([int(r), h])
	p._op({"op": "activate", "g": coppie, "stance": "crouching", "adv": null, "two": due, "us_two": false, "aware": false,
		"reaction": "", "rounds": true}, {})
	var carro: Dictionary = p.veicoli.v("v%d" % num)
	if not carro.is_empty():
		carro.piano_finche_colpito = true
	for r in riders:
		var g: Dictionary = p.u("g%d" % int(r))
		if g.is_empty():
			continue
		g.reazione = reazione_riders
		g.su_carro = "v%d" % num
		g.postura = "crouching"

func _consapevolezza(h: String) -> void:
	for a in p.americani_attivi_in_mappa():
		if not a.get("consapevole", false) and E.distanza(a.hex, h) < 6:
			if p.controllo_pc(a, 2, "per il rumore dei cingoli"):
				a.consapevole = true

func _primo_libero(lista: Array) -> String:
	for h in lista:
		if p.unita_in(str(h), "us").is_empty():
			return str(h)
	return str(lista[-1])

func op(o: Dictionary, ctx: Dictionary) -> bool:
	if not attiva():
		return false
	return op_comune(o, ctx)

## Operazioni usate anche dalle altre missioni Silver Star (eventi 116, 117, 212, 221, 222, attivazioni nel primo esagono libero).
func op_comune(o: Dictionary, ctx: Dictionary) -> bool:
	match str(o.op):
		"ss_jagd":
			var h: String = _primo_libero(o.hex) if o.hex is Array else str(o.hex)
			_attiva_carro(21, h, [31, 32], "T", [31, 32] + ([21] if bool(o.get("due", false)) else []))
			_consapevolezza(h)
		"ss_panzer":
			var r: int = p.d10()
			var h2: String = ["B19", "B19", "B19", "P19", "P19", "P19", "Y16", "Y16", "Y16", "Y10"][r]
			p._log("dado", "Dado %d: il Panzer entra in %s." % [r, h2])
			_attiva_carro(30, h2, [22, 23], "T", [])
			var posti: Array = ["H19", "Y17", "S19"]
			var h24: String = posti[p.rng.randi_range(0, 2)]
			posti.erase(h24)
			var h25: String = posti[p.rng.randi_range(0, 1)]
			p._op({"op": "activate", "g": [[24, h24], [25, h25]], "stance": "standing", "adv": null, "two": [], "us_two": false,
				"aware": false, "reaction": "", "rounds": true}, {})
			_consapevolezza(h2)
		"ss_nascosto":
			var h3 := _primo_libero(o.hex)
			p._op({"op": "activate", "g": [[int(o.g), h3]], "stance": "standing", "adv": null, "two": [], "us_two": false,
				"aware": false, "reaction": "H", "rounds": true}, {})
			var g3: Dictionary = p.u("g%d" % int(o.g))
			var riusciti: Array = []
			for a in p.americani_attivi_in_mappa():
				if not g3.is_empty() and p.vede_unita(a, g3) and p.controllo_pc(a, 0, "accorgersi del tedesco nascosto"):
					riusciti.append(a)
			if p.s.has("round") and not p.s.round.is_empty():
				p.s.round.vantaggio_forzato = "us" if not riusciti.is_empty() else "de"
			p._log("info", "Vantaggio %s." % ("americano" if not riusciti.is_empty() else "tedesco"))
		"ss_cannone_navale":
			cannone_navale()
		"ss_sherman":
			sherman()
			_modo("tenere")
		"ss_motovedetta":
			motovedetta()
			_modo("barca")
		"ss_togli_d":
			for g in p.tedeschi():
				if str(g.get("reazione", "")) == "D":
					g.reazione = ""
		"ss_guado_h11":
			_st().guado_h11 = true
			regole_terreno()
			p._log("info", "C’è un guado in H11, fra H10 e H12.")
		"ss_690_al_round":
			_st().leggi_690 = true
		"ss_cingolo":
			if _st().get("cingolo21", false):
				p._log("info", "È già successo: nessun evento.")
				return true
			var lista: Array = []
			var prec := str(int(p.s.get("round", {}).get("n", 0)) - 1)
			for vid in ["v21", "v30"]:
				var v: Dictionary = p.veicoli.v(vid)
				if p.veicoli.attivo(v) and int(v.get("mossi", {}).get(prec, 0)) >= 4:
					lista.append(v)
			if lista.is_empty():
				p._log("info", "Nessun carro si è mosso di 4 esagoni nel Round precedente: nessun evento.")
				return true
			_st().cingolo21 = true
			var vc: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
			vc.immobilizzato = true
			p._log("danno", "Il %s perde un cingolo: non si muoverà più." % vc.nome)
		"ss_250":
			var g5: Dictionary = p.u(str(ctx.get("g", "")))
			var v5: Dictionary = p.veicoli.di(g5) if not g5.is_empty() else {}
			if not v5.is_empty():
				v5.fermo_sempre = true
				p._log("tedesco", "Il %s si ferma e bombarda gli edifici." % v5.nome)
		"ss_granata_difettosa":
			_granata_difettosa()
		"ss_panico_us":
			if _st().get("p117", false) or not p.fase_round():
				return true
			var l2: Array = _squadra().filter(func(a): return p.attivo(a) and p.in_mappa(a) and not a.comandante)
			if l2.is_empty():
				return true
			_st().p117 = true
			var x: Dictionary = l2[p.rng.randi_range(0, l2.size() - 1)]
			x.panico = true
			x.postura = "prone"
			x.turni = 0
			x.slot = "panico"
			p._log("danno", "%s va nel panico e si butta a terra: si riprende quando un compagno lo raggiunge e spende un’azione." % p.nome(x))
		"ss_calcio_rotto":
			if _st().get("c222", false):
				return true
			_st().c222 = true
			var da_us: bool = p.tedeschi_attivi().is_empty() or p.d10() % 2 == 1
			var l3: Array = (p.americani_attivi_in_mappa() if da_us else p.tedeschi_attivi()).filter(func(x): return p.attivo(x) and \
				not x.armi.filter(func(w): return w.tipo in ["bolt", "scoped", "carbine", "sar", "ar", "smg", "mp", "lmg"]).is_empty())
			if l3.is_empty():
				return true
			var y: Dictionary = l3[p.rng.randi_range(0, l3.size() - 1)]
			y.calcio_rotto = true
			p._log("danno", "Il calcio dell’arma di %s si spezza: −1 per colpire." % p.nome(y))
		"ss_berserk_de":
			p.ph.berserk.tedesco(_st())
		"ss_berserk_us":
			p.ph.berserk.americano(_st())
		"ss_701":
			_st().letto701 = true
			if p.radio_presidiata():
				p.leggi("471", {})
			else:
				_st().aspetta_471 = true
		"ss_caduta_21":
			ss.m20._caduta()
		"ss_bottino_699":
			var h: String = str(ctx.get("hex", ""))
			if h != "":
				p._lascia_oggetto(h, {"tipo": "bazooka", "inceppata": false, "rotta": false, "preparata": false, "catturata": true, "munizioni": 2})
				p._lascia_oggetto(h, {"tipo": "satchel", "inceppata": false, "rotta": false, "preparata": false, "catturata": true})
		"ss_barca_affondata":
			_st().barca_affondata = true
		"ss_due_in_libero":
			var h4 := _primo_libero(o.hex)
			p._op({"op": "activate", "g": o.g.map(func(x): return [int(x), h4]), "stance": "crouching", "adv": o.get("adv", null), "two": [],
				"us_two": false, "aware": false, "reaction": str(o.get("reaction", "")), "rounds": true}, ctx)
		"ss_vantaggio_consapevoli":
			if p.s.has("round") and not p.s.round.is_empty():
				var tutti: bool = p.americani_attivi_in_mappa().all(func(a): return a.get("consapevole", false))
				p.s.round.vantaggio_forzato = "us" if tutti else "de"
		"ss_inizia_round":
			if not p.fase_round() and p.s.fase == "operazioni":
				p._inizia_round_da_attivazione([], {"adv": null, "two": [], "us_two": false}, "")
		"ss_scelte_via":
			for k in ["582", "587"]:
				p.s.get("scelte", {}).erase(k)
		_:
			return false
	return true

func _modo(m: String) -> void:
	_st().modo21 = m
	if m == "tenere":
		p.missione.vittoria_pv = 8
	else:
		p.missione.vittoria_pv = 8

func _granata_difettosa() -> void:
	if _st().get("g212", false):
		return
	var americano: bool = not p.fase_round() or p.d10() % 2 == 1
	var lista: Array = (p.americani_attivi_in_mappa() if americano else p.tedeschi_attivi()).filter(func(x): return p.attivo(x) and p.in_mappa(x) \
		and int(x.munizioni.get("granata", 0)) > 0)
	if lista.is_empty():
		p._log("info", "Nessuno porta granate: nessun evento.")
		return
	_st().g212 = true
	var x: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	x.munizioni.granata = int(x.munizioni.granata) - 1
	p._log("info", "La granata di %s è difettosa e sta per esplodere!" % p.nome(x))
	if p.controllo_pc(x, 0, "per liberarsi della granata"):
		p._log("info", "%s la lancia in un esagono vuoto: esplode senza danni." % p.nome(x))
		return
	p._fx("esplosione", {"a": x.hex})
	for y in p.unita_in(x.hex, "us") + p.unita_in(x.hex, "de"):
		if p.attivo(y):
			p._danno_esplosione(y, T.GRANATA_DENTRO if y == x else T.GRANATA_FUORI)

func test(t: Dictionary, ctx: Dictionary):
	if not attiva():
		return null
	if t.has("ss_tedesco_a_sud"):
		for g in p.tedeschi():
			if p.attivo(g) and p.in_mappa(g) and _a_sud_del_fiume(g.hex):
				return true
		return false
	if t.has("ss_us_a_est"):
		var g: Dictionary = p.u(str(ctx.get("g", "")))
		for a in p.americani_attivi_in_mappa():
			if not g.is_empty() and E.riga(a.hex) < E.riga(g.hex):
				return true
		return false
	if t.has("ss_barca_us_vista"):
		var v: Dictionary = p.veicoli.v("vpb")
		var g2: Dictionary = p.u(str(ctx.get("g", "")))
		return p.veicoli.attivo(v) and not g2.is_empty() and p.terreno.vede(g2.hex, v.hex, g2.postura, "standing")
	if t.has("ss_mezzo_us_visto"):
		var g3: Dictionary = p.u(str(ctx.get("g", "")))
		for vid in ["vsh4", "vpb"]:
			var v2: Dictionary = p.veicoli.v(vid)
			if p.veicoli.attivo(v2) and not g3.is_empty() and p.terreno.vede(g3.hex, v2.hex, g3.postura, "standing"):
				return true
		return false
	if t.has("ss_us_in_edificio"):
		for a in p.americani_attivi_in_mappa():
			if a.hex in t.ss_us_in_edificio:
				return true
		return false
	if t.has("ss_piu_in"):
		return p.unita_in(str(t.ss_piu_in[0]), "de").size() > p.unita_in(str(t.ss_piu_in[1]), "de").size()
	if t.has("ss_dispari"):
		return (int(p.s.get("round", {}).get("numero_azione", p.d10())) % 2 == 1) == bool(t.ss_dispari)
	if t.has("ss_letto_701"):
		return bool(_st().get("letto701", false))
	return null

## Il fiume va da Y6 ad A12: è «a sud» (verso l’alto della mappa) chi sta nelle righe sopra il fiume.
func _a_sud_del_fiume(h: String) -> bool:
	var c := E.colonna(h)
	var riga_fiume := 12.0 - 6.0 * float(c) / 24.0
	return float(E.riga(h)) < riga_fiume
