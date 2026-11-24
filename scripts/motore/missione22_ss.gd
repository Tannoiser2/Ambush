extends RefCounted
## Silver Star, Missione 22 «Un altro ponte di troppo?»: la squadra (con un semicingolato con mitragliatrice media e una jeep)
## cerca un ponte intatto per i carri. Ponti di pietra in O4 e V14, il grande ponte di tre esagoni I15–J14–K14 (da H15 a L14)
## che si scopre al 483; tre livelli per esagono di ponte (sopra, sotto fra i sostegni, sotto a terra: qui solo «sopra» e
## «sotto», flag `sotto_ponte`); esplosivi sotto i ponti (lato 2 = innescato, lato 1 = mezzo disinnescato); i genieri tedeschi
## (40–45) con il semicingolato provano a minare il ponte; il cecchino 26 col detonatore del ponte V14 (reazione B).
## Stato in p.s.ss.

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

const PONTE3 := ["I15", "J14", "K14"]
const STRADA_PONTE := ["H15", "I15", "J14", "K14", "L14", "L13"]
const ESAGONI_PV := ["O4", "W8", "V14", "K14", "J14", "I15"]
const GENIERI := [42, 43, 44, 45]

var p  # Partita
var ss  # missioni_ss.gd

func _init(partita, modulo) -> void:
	p = partita
	ss = modulo

func attiva() -> bool:
	return ss.attiva() and int(p.missione.get("id", 0)) == 22

func _st() -> Dictionary:
	var st: Dictionary = ss._st()
	if not st.has("m22"):
		st.m22 = {"esplosivi": {}, "distrutti": {}, "ponte3": false, "crollato": false, "pv_esagoni": [], "modo": ""}
	return st.m22

# ------------------------------------------------------------------ terreno e ponti
func regole_terreno() -> void:
	if not attiva():
		return
	var st := _st()
	for h in ["O4", "V14"]:
		if st.distrutti.has(h):
			var d: Dictionary = p.terreno.esagoni.get(h, {}).duplicate()
			d.erase("ponte")
			p.terreno.esagoni[h] = d
	if st.ponte3:
		for h in PONTE3:
			var d2: Dictionary = p.terreno.esagoni.get(h, {}).duplicate()
			if st.crollato or st.distrutti.has(h):
				d2.t = "rubble"
				d2.erase("ponte22")
			else:
				d2.t = "road"
				d2.ponte22 = true
			p.terreno.esagoni[h] = d2

## Esagono di ponte intatto (anche il grande ponte, una volta scoperto).
func ponte_intatto(h: String) -> bool:
	if not attiva() or _st().distrutti.has(h):
		return false
	if h in ["O4", "V14"]:
		return true
	return h in PONTE3 and _st().ponte3 and not _st().crollato

func sotto(x: Dictionary) -> bool:
	return attiva() and bool(x.get("sotto_ponte", false)) and ponte_intatto(str(x.get("hex", "")))

func esplosivo(h: String) -> int:
	return int(_st().esplosivi.get(h, 0))

## 1 PV per ogni esagono indicato in cui entra un americano (una volta sola).
func dopo_movimento(ids: Array) -> void:
	if not attiva():
		return
	for id in ids:
		var a: Dictionary = p.u(str(id))
		if a.is_empty() or a.lato != "us":
			continue
		var h: String = str(a.hex)
		if h in ESAGONI_PV and not (h in _st().pv_esagoni) and (not (h in PONTE3) or _st().ponte3):
			_st().pv_esagoni.append(h)
			p._pv(1, "squadra in %s" % h)
		if a.get("sotto_ponte", false) and str(a.get("hex_sotto", "")) != h:
			a.sotto_ponte = false

## Sotto il ponte ci si muove solo da sostegno a sostegno: per uscire si risale.
func verifica_passo(a: Dictionary, verso: String) -> String:
	if not attiva():
		return ""
	if sotto(a) and not (ponte_intatto(verso) and esplosivo(verso) >= 0 and _stesso_ponte(a.hex, verso)):
		return "%s è sotto il ponte: prima deve risalire (un’azione)." % p.nome(a)
	return ""

func _stesso_ponte(a: String, b: String) -> bool:
	return a in PONTE3 and b in PONTE3 and E.distanza(a, b) == 1

## Scendere sotto il ponte o risalire: un’azione (comando del giocatore e dei genieri).
func puo_scendere(a: Dictionary) -> bool:
	return attiva() and p.attivo(a) and str(a.get("veicolo", "")) == "" and ponte_intatto(str(a.hex)) and not sotto(a)

func puo_risalire(a: Dictionary) -> bool:
	return attiva() and p.attivo(a) and sotto(a)

func scendi_sotto(a: Dictionary) -> String:
	if not puo_scendere(a):
		return "Si scende fra i sostegni solo da un esagono di ponte intatto."
	a.sotto_ponte = true
	a.hex_sotto = a.hex
	a.postura = "crouching"
	p._log("azione", "%s scende fra i sostegni sotto il ponte in %s." % [p.nome(a), a.hex])
	if a.lato == "us" and esplosivo(a.hex) > 0 and not _st().get("visti", {}).has(a.hex):
		_st().get_or_add("visti", {})[a.hex] = true
		p._log("info", "Sotto il ponte in %s c’è un esplosivo innescato (lato %d)." % [a.hex, esplosivo(a.hex)])
	return ""

func risali(a: Dictionary) -> String:
	if not puo_risalire(a):
		return "Non è sotto un ponte."
	a.sotto_ponte = false
	p._log("azione", "%s risale sul ponte in %s." % [p.nome(a), a.hex])
	return ""

## 202: due azioni per disinnescare (la prima gira il segnalino sul lato 1); +1 PV.
func puo_disinnescare(a: Dictionary) -> bool:
	return sotto(a) and a.lato == "us" and esplosivo(a.hex) > 0

func disinnesca(a: Dictionary, bonus := 1) -> String:
	if not puo_disinnescare(a):
		return "Serve un esplosivo sotto il ponte in questo esagono."
	var h: String = a.hex
	if esplosivo(h) == 2 and bonus == 1:
		_st().esplosivi[h] = 1
		p._log("azione", "%s comincia a disinnescare l’esplosivo in %s (segnalino sul lato 1): serve un’altra azione." % [p.nome(a), h])
		return ""
	_st().esplosivi.erase(h)
	p._pv(bonus, "esplosivo disinnescato in %s" % h)
	p._log("azione", "%s disinnesca l’esplosivo sotto il ponte in %s." % [p.nome(a), h])
	if h == "V14":
		var g26: Dictionary = p.u("g26")
		if not g26.is_empty() and str(g26.get("reazione", "")) == "B":
			g26.reazione = ""
			p._log("tedesco", "Il tedesco 26 non può più far saltare il ponte: toglie la reazione speciale B.")
	return ""

# ------------------------------------------------------------------ esplosioni (181, 598)
func esplodi(h: String) -> void:
	var st := _st()
	st.esplosivi.erase(h)
	p._fx("esplosione", {"a": h})
	if h == "V14" or h == "O4":
		_salta_ponte_piccolo(h)
		return
	if not (h in PONTE3) or st.crollato:
		return
	var gia: int = PONTE3.filter(func(x): return st.distrutti.has(x)).size()
	if gia == 0:
		st.distrutti[h] = true
		p._log("danno", "L’esplosivo salta sotto il ponte in %s: quel tratto è distrutto (i mezzi non passano, a piedi 2 PM)." % h)
		for x in _unita_in(h):
			if sotto(x) or x.get("sotto_ponte", false):
				x.sotto_ponte = false
				p._danno_esplosione(x, T.CARICA_DENTRO)
			else:
				p._danno_esplosione(x, T.CARICA_FUORI)
				if p.attivo(x) and p.d10() >= 8:
					p._log("danno", "%s perde l’appoggio e cade dal ponte." % p.nome(x))
					p._danno_esplosione(x, T.ARMI.mmg.danni)
		for v in p.veicoli.tutti():
			if v.hex == h and p.veicoli.attivo(v):
				p.veicoli.disabilita(v, "esplosione sul ponte")
		regole_terreno()
		return
	st.crollato = true
	p._log("danno", "Seconda esplosione: il grande ponte crolla! I tre esagoni diventano macerie.")
	for hh in PONTE3:
		for x in _unita_in(hh):
			x.sotto_ponte = false
			p._danno_esplosione(x, T.ARMI.mmg.danni)
		for v in p.veicoli.tutti():
			if v.hex == hh and p.veicoli.attivo(v):
				p.veicoli.disabilita(v, "crollo del ponte")
	regole_terreno()
	p.leggi("260", {})

func _salta_ponte_piccolo(h: String) -> void:
	var st := _st()
	if st.distrutti.has(h):
		return
	st.distrutti[h] = true
	p._log("danno", "Il ponte in %s salta in aria: i mezzi non passano più." % h)
	for x in _unita_in(h):
		x.sotto_ponte = false
		p._danno_esplosione(x, T.CARICA_FUORI)
	for v in p.veicoli.tutti():
		if v.hex == h and p.veicoli.attivo(v):
			p.veicoli.disabilita(v, "ponte saltato")
	if h == "V14":
		p._pv(-1, "ponte in V14 distrutto")
	regole_terreno()

func _unita_in(h: String) -> Array:
	return (p.americani() + p.tedeschi()).filter(func(x): return x.hex == h and p.attivo(x))

func _esplosivo_a_caso(con_americano: bool) -> String:
	var lista: Array = []
	for h in _st().esplosivi:
		if not con_americano or not p.americani_attivi_in_mappa().filter(func(a): return a.hex == h and sotto(a)).is_empty():
			if int(_st().esplosivi[h]) == 2 or not con_americano:
				lista.append(h)
	if lista.is_empty():
		return ""
	return str(lista[p.rng.randi_range(0, lista.size() - 1)])

# ------------------------------------------------------------------ semicingolato e jeep della squadra
func dopo_ingresso(esagoni: Array) -> void:
	if not attiva() or not p.veicoli.v("vht").is_empty() or esagoni.is_empty():
		return
	var h: String = str(esagoni[0])
	var squadra: Array = p.americani().filter(func(a): return p.attivo(a) and a.hex in esagoni)
	p.s.imbarco = true
	var ht: Dictionary = p.veicoli.crea("vht", "halftrack", h, "us")
	ht.nome = "Semicingolato"
	ht.posti = 10
	ht.pv_distrutto = 0
	ht.mg = {"tipo": "mmg", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "scarica": false,
		"montata": true, "solo_passeggero1": true}
	ht.mg_munizioni = 1
	var jp: Dictionary = p.veicoli.crea("vjeep", "jeep", h, "us")
	jp.nome = "Jeep"
	jp.posti = 4
	jp.pv_distrutto = 0
	var j := 0
	for x in squadra:
		p.veicoli.sali(x, ht if j < 5 else jp)
		j += 1
	p.s.imbarco = false
	p._log("info", "La squadra entra in %s: semicingolato (mitragliatrice media al passeggero 1, una cassetta) e jeep." % h)

# ------------------------------------------------------------------ tedeschi: genieri e semicingolato (reazioni T, E, G, H)
func semicingolato() -> Dictionary:
	return p.veicoli.v("vhtde")

func genieri_attivi(h := "") -> Array:
	return p.tedeschi().filter(func(g): return p.attivo(g) and int(g.get("esplosivi_g", 0)) > 0 and (h == "" or g.hex == h))

## Esagono di ponte senza esplosivo e senza un tedesco con esplosivo, il più vicino a h.
func ponte_libero(h: String) -> String:
	var migliore := ""
	for x in PONTE3:
		if not ponte_intatto(x) or esplosivo(x) > 0:
			continue
		if not genieri_attivi(x).filter(func(g): return g.get("reazione", "") == "E" or g.get("sotto_ponte", false)).is_empty():
			continue
		if migliore == "" or E.distanza(h, x) < E.distanza(h, migliore):
			migliore = x
	return migliore

## 617/723: il semicingolato dei genieri entra in H15 (verso I15) o in L13 (verso K14).
func arrivano_genieri(h: String, verso: String, adv: String, due: Array) -> void:
	if not semicingolato().is_empty():
		return
	var nums := [40, 41, 42, 43, 44, 45]
	p._op({"op": "activate", "g": nums.map(func(n): return [n, h]), "stance": "crouching", "adv": adv if adv != "" else null,
		"two": due, "us_two": false, "aware": false, "reaction": "T", "rounds": true}, {})
	var v: Dictionary = p.veicoli.crea("vhtde", "halftrack", h, "de")
	v.nome = "Semicingolato tedesco"
	v.pv_distrutto = 3
	v.fronte = E.direzione(h, verso)
	v.mg = {"tipo": "lmg", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "scarica": false, "montata": true}
	for n in [41, 40, 42, 43, 44, 45]:
		var g: Dictionary = p.u("g%d" % n)
		if g.is_empty() or not p.attivo(g):
			continue
		g.veicolo = v.id
		v.occupanti.append(g.id)
		g.postura = "crouching"
		if n in GENIERI:
			g.esplosivi_g = 1
	_st().verso_ht = 1 if h == "H15" else -1
	p._log("attivazione", "Il semicingolato dei genieri tedeschi entra in %s: 41 alla guida, 40 accanto, i genieri 42–45 dietro con gli esplosivi." % h)

func _in_dietro(v: Dictionary) -> Array:
	return p.veicoli.occupanti(v).filter(func(g): return p.attivo(g) and int(g.num) in GENIERI)

## 216 (GE 41, reazione T): porta i genieri sul ponte e li fa scendere uno per esagono senza esplosivo.
func turno_autista(t, g: Dictionary) -> void:
	var v := semicingolato()
	if not p.veicoli.attivo(v) or v.get("immobilizzato", false) or str(g.get("veicolo", "")) != v.id:
		g.reazione = ""
		t._ritira_e_esegui()
		return
	var con_esp: Array = _in_dietro(v).filter(func(x): return int(x.get("esplosivi_g", 0)) > 0)
	if con_esp.is_empty():
		if ponte_libero(v.hex) == "":
			g.reazione = "G"
			p._log("tedesco", "Tutto il ponte è minato: il %s aspetta i genieri (reazione speciale G)." % p.nome(g))
		else:
			g.reazione = "G"
		t._miglior_tiro("facile")
		return
	var dest := ponte_libero(v.hex)
	if dest == "":
		t._miglior_tiro("vicino")
		return
	var passi := 0
	while v.hex != dest and passi < 3:
		var i := STRADA_PONTE.find(str(v.hex))
		var j := STRADA_PONTE.find(dest)
		var prossimo: String
		if i < 0:
			prossimo = "H15" if E.distanza(v.hex, "H15") < E.distanza(v.hex, "L13") else "L13"
			var linea: Array = E.linea(v.hex, prossimo)
			prossimo = str(linea[1]) if linea.size() > 1 else prossimo
		else:
			prossimo = STRADA_PONTE[i + (1 if j > i else -1)]
		if p.veicoli.costo(v, v.hex, prossimo) < 0:
			break
		p.veicoli.sposta(v, prossimo)
		p._log("tedesco", "Il semicingolato tedesco avanza piano in %s." % prossimo)
		passi += 1
	if v.hex == dest:
		con_esp.sort_custom(func(a, b): return int(a.num) > int(b.num))
		var x: Dictionary = con_esp[0]
		p.veicoli.scendi(x)
		x.hex = dest
		x.postura = "crouching"
		x.reazione = "E"
		x.turni = maxi(0, int(x.get("turni", 0)) - 1)
		p._log("tedesco", "Il %s scende dal semicingolato sul ponte in %s con l’esplosivo (reazione speciale E)." % [p.nome(x), dest])

## 217 (GE 40): spara dal mezzo finché c’è; se è fermo o distrutto toglie la T.
func turno_secondo(t, g: Dictionary) -> void:
	var v := semicingolato()
	if not p.veicoli.attivo(v) or v.get("immobilizzato", false):
		g.reazione = ""
		t._ritira_e_esegui()
		return
	t._miglior_tiro("vicino")

## 218 (genieri, reazione T): a bordo aspettano; se il mezzo non c’è più scendono e vanno a minare il ponte.
func turno_geniere(t, g: Dictionary) -> void:
	var v := semicingolato()
	if p.veicoli.attivo(v) and not v.get("immobilizzato", false) and str(g.get("veicolo", "")) == v.id:
		if not t.bersagli(g).is_empty() and p.d10() <= 3:
			t._miglior_tiro("vicino")
		return
	g.reazione = ""
	if str(g.get("veicolo", "")) != "":
		p.veicoli.scendi(g)
	if int(g.get("esplosivi_g", 0)) > 0 and ponte_libero(g.hex) != "":
		g.reazione = "E"
		turno_e(t, g)
	else:
		t._ritira_e_esegui()

## 261 (reazione E): sotto il ponte, mina l’esagono, poi risale.
func turno_e(t, g: Dictionary) -> void:
	var h: String = g.hex
	if not (h in PONTE3) or not ponte_intatto(h):
		var dest := ponte_libero(h)
		if dest == "" or int(g.get("esplosivi_g", 0)) <= 0:
			g.reazione = ""
			g.sotto_ponte = false
			t._ritira_e_esegui()
			return
		t._corri_verso(dest)
		return
	if esplosivo(h) == 0:
		if not g.get("sotto_ponte", false):
			scendi_sotto(g)
		elif int(g.get("esplosivi_g", 0)) > 0:
			_st().esplosivi[h] = 2
			g.esplosivi_g = 0
			p._log("tedesco", "Il %s innesca l’esplosivo sotto il ponte in %s." % [p.nome(g), h])
		else:
			t._miglior_tiro("vicino")
		return
	if g.get("sotto_ponte", false):
		var qui: Array = p.unita_in(h, "us").filter(func(a): return sotto(a))
		if not qui.is_empty():
			t._assalta(qui[0])
			return
		var sotto_visti: Array = t.bersagli(g).filter(func(a): return sotto(a))
		if not sotto_visti.is_empty():
			t._accovacciati()
			t._miglior_tiro("vicino")
			return
		risali(g)
		return
	g.reazione = "H" if int(g.num) in [40, 41] else ""
	p._log("tedesco", "Il %s ha finito sul ponte in %s." % [p.nome(g), h])

## 153 (reazione H di 40 e 41): torna al mezzo se c’è, altrimenti segue la carta.
func turno_h(t, g: Dictionary) -> void:
	var v := semicingolato()
	if p.veicoli.attivo(v) and not v.get("immobilizzato", false):
		if g.hex != v.hex:
			t._corri_verso(v.hex)
			return
		p.veicoli.sali(g, v)
		g.reazione = "T"
		return
	g.reazione = ""
	t._ritira_e_esegui()

## 158 (40 in G) e 481 (41 in G): aspettano i genieri e sparano; poi riprendono la T.
func turno_g(t, g: Dictionary) -> void:
	var v := semicingolato()
	var fuori: Array = p.tedeschi().filter(func(x): return p.attivo(x) and int(x.num) in GENIERI and str(x.get("veicolo", "")) != v.get("id", "-"))
	if fuori.is_empty() and p.veicoli.attivo(v):
		g.reazione = "T"
	t._accovacciati()
	t._miglior_tiro("facile")

# ------------------------------------------------------------------ cecchino 26 (reazione B) e cannone anticarro
## 599: il cecchino col detonatore del ponte V14.
func turno_b(t, g: Dictionary) -> void:
	var qui: Array = p.unita_in(g.hex, "us")
	if not qui.is_empty():
		t._assalta(t._bersaglio_assalto())
		return
	if esplosivo("V14") == 0 or _st().distrutti.has("V14"):
		g.reazione = ""
		t._ritira_e_esegui()
		return
	var vicini: Array = p.americani_attivi_in_mappa().filter(func(a): return E.distanza(a.hex, "V14") <= 1)
	if not vicini.is_empty():
		t._accovacciati()
		p._log("tedesco", "Il %s aziona il detonatore: il ponte in V14 salta!" % p.nome(g))
		g.reazione = ""
		esplodi("V14")
		t._prono_se_libero()
		return
	t._accovacciati()
	t._miglior_tiro("vicino")
	t._prono_se_libero()

func cannone_anticarro(h: String, arco: Array, adv: String) -> void:
	if not p.u("g371").is_empty() and p.attivo(p.u("g371")):
		return
	p._op({"op": "activate", "g": [[371, h], [372, h]], "stance": "crouching", "adv": adv, "two": [], "us_two": false,
		"aware": false, "reaction": "", "rounds": true}, {})
	_st().atg = {"hex": h, "arco": arco, "carico": true, "sparato": -1, "caricato": -1, "distrutto": false}
	var v: Dictionary = p.veicoli.crea("vatg", "atg", h, "de")
	v.nome = "Cannone anticarro"
	v.pv_distrutto = 2
	p._log("info", "Il cannone anticarro tedesco è in %s, carico; spara solo verso %s." % [h, ", ".join(arco)])

func _turno_id() -> int:
	return int(p.s.round.get("n", 0)) * 1000 + int(p.s.round.get("progressivo", 0))

## 265–268: i serventi del cannone anticarro.
func turno_atg(t, g: Dictionary) -> void:
	var qui: Array = p.unita_in(g.hex, "us")
	if not qui.is_empty():
		t._assalta(t._bersaglio_assalto())
		return
	var vicini: Array = p.americani_attivi_in_mappa().filter(func(a): return E.distanza(a.hex, g.hex) == 1)
	if not vicini.is_empty():
		t._accovacciati()
		if int(g.munizioni.get("granata", 0)) > 0 and t._lancia_granata(1):
			t._prono_se_libero()
			return
		t._miglior_tiro("facile")
		t._prono_se_libero()
		return
	var atg: Dictionary = _st().get("atg", {})
	var v: Dictionary = p.veicoli.v("vatg")
	if atg.is_empty() or not p.veicoli.attivo(v):
		t._miglior_tiro("vicino")
		return
	var turno := _turno_id()
	if not atg.carico and int(atg.sparato) != turno:
		atg.carico = true
		atg.caricato = turno
		g.postura = "crouching"
		p._log("tedesco", "Il %s carica il cannone anticarro." % p.nome(g))
		return
	if atg.carico and int(atg.caricato) != turno:
		var bers := _bersagli_atg(g, atg)
		if not bers.is_empty():
			atg.carico = false
			atg.sparato = turno
			g.postura = "crouching"
			var vt: Dictionary = bers[0]
			var chi: Dictionary = p.veicoli.autista(vt)
			if chi.is_empty():
				var occ: Array = p.veicoli.occupanti(vt)
				chi = occ[0] if not occ.is_empty() else {}
			p._log("tedesco", "Il %s spara col cannone anticarro contro %s." % [p.nome(g), str(vt.nome).to_lower()])
			if chi.is_empty():
				p.veicoli.disabilita(vt, "cannone anticarro")
			else:
				p.risolvi_tiro(g, {"tipo": "cannone", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "scarica": false}, chi, true)
			return
	t._accovacciati()
	t._prono_se_libero()

func _bersagli_atg(g: Dictionary, atg: Dictionary) -> Array:
	var out: Array = []
	for v in p.veicoli.tutti():
		if v.lato != "us" or not p.veicoli.attivo(v) or str(v.hex) == "":
			continue
		if not p.terreno.vede(g.hex, v.hex, "crouching", "standing"):
			continue
		var linea: Array = E.linea(str(atg.hex), str(v.hex))
		if linea.size() < 2 or not (str(linea[1]) in atg.arco):
			continue
		out.append(v)
	out.sort_custom(func(a, b): return E.distanza(a.hex, "J14") < E.distanza(b.hex, "J14"))
	return out

## 415: il Panzer nascosto avvia il motore; gli americani entro 3 esagoni diventano consapevoli.
func accendi_motore(g: Dictionary, veic: Dictionary) -> bool:
	if p.paragrafi.has("415"):
		p._log("par", p.paragrafi["415"].it, {"id": "415", "tedesco": g.id})
	p._log("tedesco", "Il %s accende il motore con un boato." % veic.nome)
	for a in p.americani_attivi_in_mappa():
		if E.distanza(a.hex, veic.hex) <= 3:
			a.consapevole = true
	return true

# ------------------------------------------------------------------ fine
func controlla() -> void:
	if not attiva() or p.s.fase == "fine":
		return
	var modo: String = str(_st().modo)
	var de: Array = p.tedeschi().filter(func(g): return p.attivo(g) and p.in_mappa(g))
	if modo == "ritirata":
		var sq: Array = p.americani().filter(func(a): return p.attivo(a) and p.in_mappa(a))
		if sq.is_empty():
			p._calcola_fine("ritirata")
		return
	if not _st().get("letto269", false) and modo == "":
		return
	if de.is_empty() and _st().esplosivi.is_empty():
		p._log("info", "Nessun tedesco attivo e nessun esplosivo innescato: la missione termina.")
		p._calcola_fine("obiettivo")

func blocca_fine() -> bool:
	return attiva() and str(_st().modo) != "ritirata" and not p.americani_attivi_in_mappa().is_empty()

func uscita_ammessa(h: String) -> bool:
	return str(_st().modo) == "ritirata" and h in ["W1", "X1", "Y1"]

func niente_pv_incapacitati() -> bool:
	if not attiva():
		return false
	if str(_st().modo) == "inseguire":
		return p.tedeschi().filter(func(g): return p.attivo(g) and p.in_mappa(g)).is_empty()
	return bool(_st().get("letto269", false)) and str(_st().modo) == ""

func inizio_round() -> void:
	pass

# ------------------------------------------------------------------ operazioni e test
func op(o: Dictionary, ctx: Dictionary) -> bool:
	if not attiva():
		return false
	match str(o.op):
		"ss22_ponte3":
			_st().ponte3 = true
			regole_terreno()
			p._log("info", "Il grande ponte I15–J14–K14 (da H15 a L14) è intatto: va controllato e difeso.")
		"ss22_genieri":
			arrivano_genieri(str(o.hex), str(o.verso), str(o.get("adv", "")), o.get("two", []))
		"ss22_atg":
			var h: String = str(o.hex)
			var arco: Array = o.arco
			if o.has("dado"):
				var r: int = p.d10()
				while r == 9:
					r = p.d10()
				var scelta: Array = o.dado[0] if r <= 2 else (o.dado[1] if r <= 5 else o.dado[2])
				h = str(scelta[0])
				arco = scelta[1]
				p._log("dado", "Dado %d: il cannone anticarro è in %s." % [r, h])
			cannone_anticarro(h, arco, str(o.get("adv", "")))
		"ss22_esplosivo_qui":
			var h2: String = str(ctx.get("hex", ""))
			if h2 != "" and not _st().esplosivi.has(h2):
				_st().esplosivi[h2] = 2
				p._log("info", "Sotto il ponte in %s c’è un esplosivo innescato (segnalino sul lato 2)." % h2)
		"ss22_esplodi_americano":
			var h3 := _esplosivo_a_caso(true)
			if h3 != "":
				esplodi(h3)
		"ss22_esplodi_caso":
			if _st().get("e225", false):
				return true
			var h4 := _esplosivo_a_caso(false)
			if h4 == "":
				p._log("info", "Nessun esplosivo innescato: nessun evento.")
				return true
			_st().e225 = true
			esplodi(h4)
		"ss22_esplodi_qui":
			var h5: String = str(ctx.get("hex", ""))
			if h5 != "":
				esplodi(h5)
		"ss22_disinnesco_191":
			var sotto_qui: Array = p.americani_attivi_in_mappa().filter(func(a): return sotto(a) and esplosivo(a.hex) == 1)
			if sotto_qui.is_empty():
				return true
			sotto_qui.sort_custom(func(a, b): return int(a.PC) > int(b.PC))
			var x: Dictionary = sotto_qui[0]
			if p.controllo_pc(x, 0, "per disinnescare in tempo"):
				disinnesca(x, 2)
			else:
				esplodi(x.hex)
		"ss22_letto269":
			_st().letto269 = true
		"ss22_modo":
			_st().modo = str(o.modo)
			p.missione.vittoria_pv = int(o.pv)
		"ss22_gomma_ht":
			var v: Dictionary = semicingolato()
			if _st().get("gomma211", false) or not p.veicoli.attivo(v):
				p._log("info", "Nessun evento.")
				return true
			_st().gomma211 = true
			v.gomme = false
			p._log("info", "Il semicingolato tedesco fora una gomma: d’ora in poi va solo piano.")
		"ss22_gomma_us":
			if _st().get("gomma229", false):
				return true
			var lista: Array = ["vht", "vjeep"].map(func(id): return p.veicoli.v(id)).filter(func(v): return p.veicoli.attivo(v))
			if lista.is_empty():
				p._log("info", "Nessun mezzo americano in gioco: nessun evento.")
				return true
			_st().gomma229 = true
			var v2: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
			v2.gomme = false
			p._log("info", "%s fora una gomma: d’ora in poi va solo piano." % v2.nome)
		"ss22_torrente_scivola":
			if _st().get("s370", false):
				return true
			var l: Array = (p.americani() + p.tedeschi()).filter(func(x): return p.attivo(x) and p.in_mappa(x) and p.terreno.tipo(x.hex) == "stream")
			if l.is_empty():
				p._log("info", "Nessuno è nel torrente: nessun evento.")
				return true
			_st().s370 = true
			var y: Dictionary = l[p.rng.randi_range(0, l.size() - 1)]
			if not p.controllo_pc(y, 0, "scivola sui sassi del torrente") and int(y.munizioni.get("granata", 0)) > 0:
				y.munizioni.granata = int(y.munizioni.granata) - 1
				p._log("info", "%s perde una granata nel torrente." % p.nome(y))
		"ss22_rientra":
			var g: Dictionary = p.u("g%d" % int(o.g))
			if g.is_empty() or not (str(g.stato) in ["rimosso", "uscito"]):
				return true
			var h6: String = str(o.hex) if o.has("hex") else str(ctx.get("hex", ""))
			g.stato = "attivo"
			g.hex = h6
			g.postura = str(o.get("stance", "standing"))
			g.reazione = ""
			p._log("attivazione", "Il %s rientra in mappa in %s." % [p.nome(g), h6])
		"ss22_mortaio":
			ss.m20.attiva_mortaio(str(o.hex), str(o.get("adv", "")))
		"ss22_ponte_debole":
			_st().ponte_debole = true
		"ss22_182":
			var tipo := 0
			for a in p.americani_attivi_in_mappa():
				if sotto(a) and esplosivo(a.hex) == 1:
					tipo = 1
					break
				if sotto(a) and esplosivo(a.hex) == 2:
					tipo = 2
			p.leggi("191" if tipo == 1 else ("204" if tipo == 2 else "194"), ctx)
		"ss22_esce":
			var ge: Dictionary = p.u(str(ctx.get("g", "")))
			if not ge.is_empty():
				ss.m20._togli(ge, 0, "")
				p._log("tedesco", "Il %s esce dalla mappa." % p.nome(ge))
		"ss_scelte_22":
			for k in ["330", "994"]:
				p.s.get("scelte", {}).erase(k)
		"event_check_ops":
			if not p.fase_round():
				p.evento_casuale(ctx)
		"ss_granata_difettosa_c":
			ss.m21._granata_difettosa()
		_:
			return ss.m21.op_comune(o, ctx)
	return true

func test(t: Dictionary, ctx: Dictionary):
	if not attiva():
		return null
	if t.has("ss22_ponte_intatto"):
		return ponte_intatto(str(ctx.get("hex", "")))
	if t.has("ss22_uscito"):
		var g: Dictionary = p.u("g%d" % int(t.ss22_uscito))
		return not g.is_empty() and str(g.stato) in ["rimosso", "uscito"]
	if t.has("ss_veicolo_modello"):
		for id in ctx.get("ids", []):
			var v: Dictionary = p.veicoli.di(p.u(str(id)))
			if not v.is_empty():
				return str(v.modello) == str(t.ss_veicolo_modello)
		return false
	if t.has("ss22_letto269"):
		return bool(_st().get("letto269", false))
	if t.has("ss22_con_esplosivo"):
		var g2: Dictionary = p.u(str(ctx.get("g", "")))
		return not g2.is_empty() and int(g2.get("esplosivi_g", 0)) > 0
	if t.has("ss22_esplosivo_qui"):
		return esplosivo(str(ctx.get("hex", ""))) > 0
	if t.has("ss_dispari"):
		return (int(p.s.get("round", {}).get("numero_azione", p.d10())) % 2 == 1) == bool(t.ss_dispari)
	if t.has("ss22_us_nord_est"):
		for a in p.americani_attivi_in_mappa():
			if E.colonna(a.hex) >= E.colonna("O1") and E.riga(a.hex) >= 10:
				return true
		return false
	if t.has("ss22_us_ovest_diagonale"):
		for a in p.americani_attivi_in_mappa():
			# Diagonale P1–Y5: a ovest (in basso a sinistra della mappa, in alto è est) chi sta sotto la retta.
			var c := E.colonna(a.hex)
			var r := E.riga(a.hex)
			if r > 1 + (c - E.colonna("P1")) * 4.0 / 9.0 + 0.01:
				return true
		return false
	return null
