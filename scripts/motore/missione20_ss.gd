extends RefCounted
## Silver Star, Missione 20 «Facile come bere un bicchier d’acqua»: il convoglio del pranzo di Natale (tre camion e una jeep con
## mitragliatrice), i carichi di pranzi, i blocchi stradali, la galleria W7–W9, il mortaio del tedesco 47 e la fine che si scopre
## in gioco (683 dalla Condizione 1 o 3, 685 dalla Condizione 2). Lo stato è in p.s.ss.

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")
const MO = preload("res://scripts/motore/missioni_mo.gd")

const ORDINE := ["vjeep", "vcamion1", "vcamion2", "vcamion3"]
const GALLERIA := ["W7", "W8", "W9"]
const MORTAIO := [471, 472, 473]
const MORTAIO_CASO := ["C18", "C18", "G16", "G16", "K14", "K14", "I18", "N18", "N15", "R16"]

var p  # Partita
var ss  # missioni_ss.gd

func _init(partita, modulo) -> void:
	p = partita
	ss = modulo

func attiva() -> bool:
	return ss.attiva() and int(p.missione.get("id", 0)) == 20

func _st() -> Dictionary:
	return ss._st()

# ------------------------------------------------------------------ terreno
## Ponte di pietra in O4, galleria W7–W9 (strada), relitto d’aereo in K10.
func regole_terreno() -> void:
	if not attiva():
		return
	var mod: Dictionary = p.regola("terreno_ss", {})
	for h in mod:
		var d: Dictionary = p.terreno.esagoni.get(h, {}).duplicate()
		for k in mod[h]:
			d[k] = mod[h][k]
		p.terreno.esagoni[h] = d

func in_galleria(x: Dictionary) -> bool:
	return attiva() and str(x.get("hex", "")) in GALLERIA

## Riferimenti «T» delle carte: valgono solo per chi si muove nella galleria.
func riferimento_t(rif: String, ctx: Dictionary) -> bool:
	if not rif.begins_with("T:"):
		return false
	var dentro: bool = str(ctx.get("hex", "")) in GALLERIA
	if dentro:
		p.leggi("T" + rif.substr(2), ctx)
	else:
		p._log("info", "%s: il paragrafo T%s vale solo per chi passa nella galleria." % [str(ctx.get("hex", "")), rif.substr(2)])
	return true

## Nella galleria è buio: da W6 o W10 si vede un solo esagono dentro.
func vista(oss: Dictionary, ber: Dictionary) -> int:
	if not attiva():
		return -1
	var hb: String = str(ber.get("hex", ""))
	var ho: String = str(oss.get("hex", ""))
	if hb in GALLERIA and not (ho in GALLERIA):
		if ho in ["W6", "W10"] and E.distanza(ho, hb) <= 1:
			return 1
		return 0
	if hb in GALLERIA and ho in GALLERIA:
		return 1
	if ho in GALLERIA and not (hb in GALLERIA):
		return 1 if (ho in ["W7", "W9"]) and p.terreno.vede(ho, hb, oss.postura, ber.postura) else 0
	return -1

# ------------------------------------------------------------------ convoglio
func mezzi() -> Array:
	var out: Array = []
	for vid in ORDINE:
		var v: Dictionary = p.veicoli.v(vid)
		if not v.is_empty():
			out.append(v)
	return out

func mezzi_attivi() -> Array:
	return mezzi().filter(func(v): return p.veicoli.attivo(v) and str(v.hex) != "" and v.get("stato", "") != "uscito")

func camion() -> Array:
	return mezzi().filter(func(v): return v.modello == "camion")

## La squadra entra sui mezzi: jeep (autista e tre passeggeri, mitragliatrice al passeggero 1) e tre camion (autista e un
## passeggero in cabina; nel cassone c’è il pranzo).
func dopo_ingresso(esagoni: Array) -> void:
	if not attiva() or not p.veicoli.v("vjeep").is_empty() or esagoni.is_empty():
		return
	var h: String = str(esagoni[0])
	_st().ingresso20 = h
	var squadra: Array = p.americani().filter(func(a): return p.attivo(a) and a.hex == h)
	p.s.imbarco = true
	var j := 0
	for vid in ORDINE:
		var mod := "jeep" if vid == "vjeep" else "camion"
		var v: Dictionary = p.veicoli.crea(vid, mod, h, "us")
		v.nome = "Jeep" if vid == "vjeep" else "Camion %s" % vid.substr(7)
		v.posti = 4 if vid == "vjeep" else 2
		v.carichi = 0 if vid == "vjeep" else 1
		v.convoglio = true
		v.pv_distrutto = 0
		if vid == "vjeep":
			v.mg = {"tipo": "mmg", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "scarica": false,
				"montata": true, "solo_passeggero1": true}
			v.mg_munizioni = 6
		for k in int(v.posti):
			if j < squadra.size():
				p.veicoli.sali(squadra[j], v)
				j += 1
		v.passati = [h]
	p.s.imbarco = false
	_st().pos_convoglio = {}
	for v in mezzi():
		_st().pos_convoglio[v.id] = v.hex
	p._log("info", "Il convoglio entra in %s: jeep in testa, poi i tre camion. Nelle Operazioni guidi la jeep e gli altri la seguono in fila." % h)
	if j < squadra.size():
		p._log("info", "Restano a piedi: %s." % ", ".join(squadra.slice(j).map(func(a): return a.id)))

## Nelle Operazioni gli altri mezzi seguono in fila quello che si è appena mosso (ognuno prende il posto lasciato da chi lo precede).
func dopo_movimento(ids: Array) -> void:
	if not attiva() or ids.is_empty():
		return
	var a: Dictionary = p.u(str(ids[0]))
	var v: Dictionary = p.veicoli.di(a)
	if v.is_empty() or not v.get("convoglio", false):
		return
	if not (str(v.hex) in v.get("passati", [])):
		v.passati = v.get("passati", []) + [str(v.hex)]
	var pos: Dictionary = _st().get("pos_convoglio", {})
	if p.s.fase == "operazioni" and str(pos.get(v.id, v.hex)) != str(v.hex):
		var lista: Array = mezzi_attivi()
		var i: int = lista.find(v)
		var libero: String = str(pos.get(v.id, ""))
		for k in range(i + 1, lista.size()):
			var w: Dictionary = lista[k]
			var prima: String = str(w.hex)
			if libero == "" or prima == libero or E.distanza(prima, libero) > 1:
				break
			p.veicoli.sposta(w, libero)
			w.passati = w.get("passati", []) + [libero]
			p._fx("muovi", {"ids": [w.id] + w.occupanti, "da": prima, "a": libero})
			libero = prima
	for w in mezzi():
		pos[w.id] = w.hex
	_st().pos_convoglio = pos
	_controlla_galleria()

func verifica_scendi(a: Dictionary) -> String:
	if not attiva():
		return ""
	var v: Dictionary = p.veicoli.di(a)
	if v.get("convoglio", false) and _nessun_avvistamento():
		return "Finché non avviene un avvistamento tutti restano sui mezzi del convoglio."
	return ""

func _nessun_avvistamento() -> bool:
	for x in p.s.avvistamenti:
		if bool(x):
			return false
	return true

## Ci si aggrappa ai lati di un camion (al massimo due) solo se un mezzo del convoglio è fuori uso.
func sali_esterno(un: Dictionary, veic: Dictionary) -> String:
	if not attiva() or veic.modello != "camion" or not veic.get("convoglio", false):
		return "-"
	if mezzi().filter(func(v): return not p.veicoli.attivo(v)).is_empty():
		return "-"
	var fuori: Array = p.veicoli.occupanti(veic).filter(func(x): return x.get("esterno_ss", false))
	if fuori.size() >= 2:
		return "Ai lati del camion ci sono già due uomini aggrappati."
	un.veicolo = veic.id
	un.esterno_ss = true
	veic.occupanti.append(un.id)
	un.postura = "crouching"
	p._log("azione", "%s si aggrappa al lato del %s." % [p.nome(un), veic.nome.to_lower()])
	return ""

func blocca_tiro(tiratore: Dictionary, mirato: bool) -> String:
	if not attiva() or not tiratore.get("esterno_ss", false) or str(tiratore.get("veicolo", "")) == "":
		return ""
	if tiratore.ferito:
		return "aggrappato e ferito, si tiene solo"
	if mirato:
		return "aggrappato al camion si spara solo di rapido"
	return ""

## Chi è aggrappato e viene ferito cade prono nell’esagono; in panico fa un controllo di percezione.
func dopo_danno(x: Dictionary, l: String) -> void:
	if not attiva() or not x.get("esterno_ss", false) or str(x.get("veicolo", "")) == "":
		return
	if l == "W" or (x.ferito and p.attivo(x)):
		p.veicoli.scendi(x)
		x.erase("esterno_ss")
		x.postura = "prone"
		p._log("danno", "%s, ferito, cade dal camion." % p.nome(x))
	elif l == "P" and p.attivo(x):
		if not p.controllo_pc(x, 0, "per restare aggrappato"):
			p.veicoli.scendi(x)
			x.erase("esterno_ss")
			x.postura = "crouching"
			p._log("danno", "%s cade dal camion." % p.nome(x))
	elif not p.attivo(x):
		x.erase("esterno_ss")

## Velocità: un camion con 3 carichi, o la jeep con un carico, va solo piano.
func solo_piano(v: Dictionary) -> bool:
	return attiva() and int(v.get("carichi", 0)) >= (1 if v.modello == "jeep" else 3)

## Trasferimento del carico da un camion fuori uso a un mezzo attivo nello stesso esagono: 2 controlli Evento nelle Operazioni,
## 4 azioni (anche divise) nei Round.
func trasferibili(a: Dictionary) -> Array:
	if not attiva() or not p.attivo(a) or a.postura == "prone":
		return []
	var out: Array = []
	for da in camion():
		if p.veicoli.attivo(da) or int(da.get("carichi", 0)) <= 0 or da.hex != a.hex:
			continue
		for verso in mezzi_attivi():
			if verso.hex != a.hex:
				continue
			if verso.modello == "camion" and int(verso.carichi) < 3:
				out.append([da, verso])
			elif verso.modello == "jeep" and int(verso.carichi) == 0 and p.veicoli.occupanti(verso).size() <= 1:
				out.append([da, verso])
	return out

func trasferisci(a: Dictionary, da_id: String, verso_id: String) -> String:
	var coppia: Array = []
	for c in trasferibili(a):
		if c[0].id == da_id and c[1].id == verso_id:
			coppia = c
	if coppia.is_empty():
		return "Serve un camion fuori uso con il suo carico e un mezzo attivo con spazio nello stesso esagono."
	var da: Dictionary = coppia[0]
	var verso: Dictionary = coppia[1]
	if p.fase_round():
		var k := "%s>%s" % [da.id, verso.id]
		var fatti: Dictionary = _st().get("trasferimenti", {})
		fatti[k] = int(fatti.get(k, 0)) + 1
		_st().trasferimenti = fatti
		if int(fatti[k]) < 4:
			p._log("azione", "%s lavora al trasbordo del carico (%d azioni su 4)." % [p.nome(a), int(fatti[k])])
			return ""
		fatti.erase(k)
	else:
		p._log("info", "Il trasbordo del carico richiede due controlli Evento.")
		p.evento_casuale({"hex": a.hex, "ids": [a.id]})
		p.evento_casuale({"hex": a.hex, "ids": [a.id]})
	da.carichi = int(da.carichi) - 1
	verso.carichi = int(verso.carichi) + 1
	p._log("azione", "Il carico di pranzi passa dal %s al%s %s (ora %d carichi)." % [da.nome.to_lower(), "la" if verso.modello == "jeep" else "",
		verso.nome.to_lower(), int(verso.carichi)])
	return ""

# ------------------------------------------------------------------ blocchi stradali
func blocco(h: String, trappola: bool) -> void:
	if not p.s.has("blocchi"):
		p.s.blocchi = []
	if not (h in p.s.blocchi):
		p.s.blocchi.append(h)
	var azioni: Dictionary = _st().get("blocchi_azioni", {})
	if trappola:
		_st().trappola_blocco = h
		var prima: int = p.s.cronaca.size()
		p._op_trappola({"hex": h, "ids": p.unita_in(h, "us").map(func(x): return x.id)})
		var esplosa := false
		for c in p.s.cronaca.slice(prima):
			if "trappola esplode" in str(c.get("x", "")):
				esplosa = true
		if esplosa:
			azioni[h] = 2
		else:
			_st().trappola_inesplosa = true
	_st().blocchi_azioni = azioni
	p._log("info", "Blocco stradale in %s: i mezzi non passano finché non viene sgombrato." % h)

func puo_sgombrare(a: Dictionary) -> bool:
	return attiva() and p.attivo(a) and a.hex in p.s.get("blocchi", []) and a.postura != "prone" and str(a.get("veicolo", "")) == ""

func sgombra(a: Dictionary) -> String:
	if not puo_sgombrare(a):
		return "Serve un soldato a piedi, non prono, nell’esagono del blocco."
	var h: String = a.hex
	if p.fase_round():
		var azioni: Dictionary = _st().get("blocchi_azioni", {})
		azioni[h] = int(azioni.get(h, 0)) + 1
		_st().blocchi_azioni = azioni
		if int(azioni[h]) < 3:
			p._log("azione", "%s lavora per sgombrare il blocco in %s (%d azioni su 3)." % [p.nome(a), h, int(azioni[h])])
			return ""
	else:
		p._log("info", "Sgombrare il blocco nelle Operazioni richiede due controlli Evento.")
		p.evento_casuale({"hex": h, "ids": [a.id]})
		p.evento_casuale({"hex": h, "ids": [a.id]})
	_sgombrato(h, "a mano")
	return ""

func _sgombrato(h: String, come: String) -> void:
	p.s.blocchi.erase(h)
	p._log("azione", "Il blocco stradale in %s è sgombrato (%s)." % [h, come])
	p._pv(1, "blocco stradale sgombrato")

func esplosione(tipo: String, h: String) -> void:
	if not attiva():
		return
	if tipo == "satchel" and h in p.s.get("blocchi", []):
		_sgombrato(h, "carica da demolizione")
	if tipo == "granata":
		for v in mezzi_attivi():
			if v.hex == h:
				var r: int = p.d10()
				var l := T.lettera_danno(T.GRANATA_FUORI, r)
				p._log("dado", "Granata sul mezzo %s: %d → %s." % [v.nome.to_lower(), r, p._nome_danno(l)])
				if l in ["I", "K"]:
					p.veicoli.disabilita(v, "granata")
					for x in p.veicoli.occupanti(v):
						if p.attivo(x):
							p._danno_esplosione(x, T.GRANATA_FUORI)

## Bazooka con penetrazione pesante sul blocco (+2 per colpire).
func bazooka_blocco(a: Dictionary, h: String) -> String:
	if not (h in p.s.get("blocchi", [])):
		return "Lì non c’è un blocco."
	var bz: Dictionary = p.arma_di(a, "bazooka")
	if bz.is_empty() or p.munizioni_arma(a, "bazooka") <= 0:
		return "Serve un bazooka carico."
	var d := E.distanza(a.hex, h)
	var g: Array = T.ARMI.bazooka.gittate
	if d > int(g[2]) or not p.terreno.vede(a.hex, h, a.postura, "standing"):
		return "Il blocco non è in vista o è fuori portata."
	var prob: int = (6 if d <= int(g[0]) else (4 if d <= int(g[1]) else 2)) + 2 + int(a.WS)
	var r: int = p.d10()
	var preso: bool = r == 0 or (r != 9 and r <= prob)
	p._log("combattimento", "%s spara col bazooka al blocco in %s: serve 0–%d, esce %d → %s." % [p.nome(a), h, prob, r, "COLPITO" if preso else "mancato"])
	p._consuma_bazooka(a, bz)
	if preso:
		var rp: int = p.d10()
		var pen := T.penetrazione("bazooka", rp)
		p._log("dado", "Penetrazione: %d → %s." % [rp, pen])
		if pen == "H":
			_sgombrato(h, "bazooka")
	return ""

# ------------------------------------------------------------------ galleria (358, 464), 794, 795
func _controlla_galleria() -> void:
	if _st().get("g358", false) and not _st().get("g464", false):
		var attivi: Array = mezzi_attivi()
		var tutti := not attivi.is_empty()
		for v in attivi:
			if not ("W7" in v.get("passati", [])):
				tutti = false
		if tutti:
			_st().g464 = true
			p.leggi("464", {})

func rimuovi_bonus(nums: Array) -> void:
	for n in nums:
		var g: Dictionary = p.u("g%d" % int(n))
		if not g.is_empty() and p.attivo(g) and p.in_mappa(g):
			_togli(g, 1, "tedesco %d tolto dalla mappa" % int(n))

func _togli(g: Dictionary, pv: int, motivo: String) -> void:
	var da: String = g.hex
	g.stato = "rimosso"
	g.hex = ""
	g.slot = "inattivo"
	g.turni = 0
	p._log("tedesco", "Il %s esce dalla mappa." % p.nome(g))
	p._fx("sparisce", {"ids": [g.id], "da": da, "motivo": "dileguato"})
	if pv != 0:
		p._pv(pv, motivo)

func passati_tutti(varco: String) -> bool:
	var attivi: Array = mezzi_attivi()
	for v in attivi:
		if not (varco in v.get("passati", [])):
			return false
	return true

func vede_un_mezzo(g: Dictionary) -> bool:
	for v in mezzi_attivi():
		var x: Dictionary = p.veicoli.autista(v)
		if not x.is_empty() and p.vede_unita(g, x):
			return true
	return false

## Controlli dopo ogni comando: 794 (i tedeschi che non vedono più un mezzo escono), 795 (il mortaio se ne va), fine missione.
func controlla() -> void:
	if not attiva() or p.s.fase == "fine":
		return
	if _st().get("g794", false):
		for g in p.tedeschi():
			if p.attivo(g) and p.in_mappa(g) and not vede_un_mezzo(g):
				var pv := 0
				if int(g.num) in MORTAIO:
					pv = 1
				_togli(g, pv, "servente del mortaio ancora attivo")
	if _st().get("g795", false) and not _st().get("mortaio_via", false):
		var ok := true
		for a in p.americani_attivi_in_mappa():
			if not (E.colonna(a.hex) >= 11 and E.riga(a.hex) <= 14):
				ok = false
		if ok and not p.americani_attivi_in_mappa().is_empty():
			_st().mortaio_via = true
			var restanti: int = p.tedeschi().filter(func(g): return p.attivo(g) and p.in_mappa(g)).size()
			for n in MORTAIO:
				var g2: Dictionary = p.u("g%d" % n)
				if not g2.is_empty() and p.attivo(g2):
					_togli(g2, 0, "")
			if restanti > 0:
				p._pv(restanti, "tedeschi attivi quando il mortaio lascia la mappa")
	var fine: Dictionary = _st().get("fine20", {})
	if not fine.is_empty() and p.americani_attivi_in_mappa().is_empty():
		var usciti: Array = p.americani().filter(func(a): return a.stato == "uscito")
		p._calcola_fine("obiettivo" if not usciti.is_empty() else "annientata")

func blocca_fine() -> bool:
	return attiva() and _st().get("fine20", {}).is_empty() and not p.americani_attivi_in_mappa().is_empty()

func uscita_ammessa(h: String) -> bool:
	var fine: Dictionary = _st().get("fine20", {})
	return not fine.is_empty() and h in fine.get("soldati", [])

## Un autista esce dalla mappa con il suo mezzo e chi è a bordo (+1 PV per camion, +2 per carico).
func esci(a: Dictionary) -> String:
	if not attiva():
		return "-"
	var v: Dictionary = p.veicoli.di(a)
	if v.is_empty() or not v.get("convoglio", false):
		return "-"
	var fine: Dictionary = _st().get("fine20", {})
	if not p.veicoli.e_autista(a):
		return "Esce l’autista con il mezzo e chi è a bordo; per uscire a piedi bisogna scendere."
	if fine.is_empty() or not (a.hex in fine.get("mezzi", [])):
		return "I mezzi escono solo da %s, quando la missione lo dice." % ", ".join(fine.get("mezzi", ["(da scoprire)"]))
	if not p.veicoli.attivo(v):
		return "Il mezzo è fuori uso."
	var da: String = v.hex
	if v.modello == "camion":
		p._pv(1, "%s uscito" % v.nome.to_lower())
	if int(v.get("carichi", 0)) > 0:
		p._pv(2 * int(v.carichi), "%d carichi di pranzi portati fuori" % int(v.carichi))
	var ids: Array = []
	for x in p.veicoli.occupanti(v):
		x.stato = "uscito"
		x.hex = ""
		ids.append(x.id)
	v.stato = "uscito"
	v.hex = ""
	p._log("azione", "%s esce dalla mappa con %s." % [v.nome, ", ".join(ids)])
	p._fx("sparisce", {"ids": ids + [v.id], "da": da, "motivo": "uscito"})
	return ""

func righe_fine(righe: Array) -> int:
	if not attiva():
		return 0
	var n: int = p.tedeschi().filter(func(g): return p.attivo(g) and p.in_mappa(g)).size()
	if n > 0:
		righe.append(["Tedeschi attivi rimasti in mappa", n])
	return n

# ------------------------------------------------------------------ mortaio del tedesco 47
func attiva_mortaio(h: String, adv: String) -> void:
	p._op({"op": "activate", "g": MORTAIO.map(func(n): return [n, h]), "stance": "crouching", "adv": adv, "two": [], "us_two": false,
		"aware": false, "reaction": "", "rounds": true}, {})
	_st().mortaio = {"hex": h, "pronto": true, "sparato": -1, "preparato": -1, "marcatore": ""}
	p._log("info", "Il mortaio tedesco è in %s, con il colpo pronto." % h)

func _turno_id() -> int:
	return int(p.s.round.get("n", 0)) * 100 + int(p.s.round.get("progressivo", 0))

## 502–504: prepara o spara.
func mortaio_azione(g: Dictionary, n: int) -> void:
	var m: Dictionary = _st().get("mortaio", {})
	if m.is_empty():
		return
	var turno := int(p.s.round.get("n", 0))
	var spar: bool = int(m.sparato) == turno
	var prep: bool = int(m.preparato) == turno
	match n:
		502:
			if not m.pronto:
				_prepara(g, m, turno)
			elif not spar:
				_spara(g, m, turno)
			else:
				g.postura = "crouching"
		503:
			if spar and not prep and not m.pronto:
				_prepara(g, m, turno)
			elif m.pronto and not spar:
				_spara(g, m, turno)
			else:
				g.postura = "prone"
		504:
			if m.pronto and not spar:
				_spara(g, m, turno)
			elif not m.pronto:
				_prepara(g, m, turno)
			else:
				g.postura = "prone"

func _prepara(g: Dictionary, m: Dictionary, turno: int) -> void:
	g.postura = "crouching"
	m.pronto = true
	m.preparato = turno
	p._log("tedesco", "Il %s prepara un colpo di mortaio." % p.nome(g))

func _spara(g: Dictionary, m: Dictionary, turno: int) -> void:
	g.postura = "crouching"
	m.pronto = false
	m.sparato = turno
	var pct: int = p.percentuale()
	if pct == 5:
		p._log("dado", "Il colpo di mortaio fa cilecca (05).")
		return
	var bersaglio := _bersaglio_mortaio(g, m)
	var arrivo := ""
	if bool(bersaglio.b):
		var r: int = p.d10()
		arrivo = str(bersaglio.h) if r <= 3 else E.vicino(str(bersaglio.h), [0, 1, 2, 3, 4, 5][r - 4])
		p._log("dado", "Mortaio sul segnalino: %d (diagramma B) → %s." % [r, arrivo if arrivo != "" else "fuori mappa"])
	else:
		var r100: int = p.d10() * 10 + p.d10()
		arrivo = MO.dispersione(str(bersaglio.h), r100)
		p._log("dado", "Mortaio su %s: %02d (diagramma A) → %s." % [str(bersaglio.h), r100, arrivo if arrivo != "" else "fuori mappa"])
	m.marcatore = arrivo
	if arrivo == "":
		return
	p._fx("esplosione", {"a": arrivo})
	_impatto(arrivo)

func _bersaglio_mortaio(g: Dictionary, m: Dictionary) -> Dictionary:
	var marc: String = str(m.get("marcatore", ""))
	var lontano := func(h: String) -> bool: return E.distanza(h, str(m.hex)) > 7
	var visti_mezzi: Array = mezzi_attivi().filter(func(v): return lontano.call(v.hex) and _vede_hex(g, v.hex))
	var visti_us: Array = p.americani_attivi_in_mappa().filter(func(a): return p.vede_unita(g, a))
	if marc != "" and _vede_hex(g, marc):
		for v in mezzi_attivi():
			if v.hex == marc:
				return {"h": marc, "b": true}
		var vicini: Array = mezzi_attivi().filter(func(v): return E.distanza(v.hex, marc) <= 2)
		if not vicini.is_empty():
			vicini.sort_custom(func(a, b): return E.distanza(a.hex, "S10") < E.distanza(b.hex, "S10"))
			return {"h": vicini[0].hex, "b": true}
		if not visti_mezzi.is_empty():
			visti_mezzi.sort_custom(func(a, b): return E.distanza(a.hex, "S10") < E.distanza(b.hex, "S10"))
			return {"h": visti_mezzi[0].hex, "b": false}
		for a in visti_us:
			if a.hex == marc:
				return {"h": marc, "b": true}
		var vicini_us: Array = visti_us.filter(func(a): return E.distanza(a.hex, marc) <= 2)
		if not vicini_us.is_empty():
			return {"h": _hex_piu_americani(vicini_us), "b": true}
		var lontani: Array = visti_us.filter(func(a): return lontano.call(a.hex))
		if not lontani.is_empty():
			lontani.sort_custom(func(a, b): return E.distanza(a.hex, "S10") < E.distanza(b.hex, "S10"))
			return {"h": lontani[0].hex, "b": false}
	if not visti_mezzi.is_empty():
		visti_mezzi.sort_custom(func(a, b): return E.distanza(a.hex, "S10") < E.distanza(b.hex, "S10"))
		return {"h": visti_mezzi[0].hex, "b": false}
	var us_lontani: Array = visti_us.filter(func(a): return lontano.call(a.hex))
	if not us_lontani.is_empty():
		return {"h": _hex_piu_americani(us_lontani), "b": false}
	var r: int = p.d10()
	p._log("dado", "Il mortaio non ha bersagli: dado %d → %s." % [r, MORTAIO_CASO[r]])
	return {"h": MORTAIO_CASO[r], "b": false}

func _vede_hex(g: Dictionary, h: String) -> bool:
	return p.terreno.vede(g.hex, h, g.postura, "standing")

func _hex_piu_americani(lista: Array) -> String:
	var conti := {}
	for a in lista:
		conti[a.hex] = int(conti.get(a.hex, 0)) + 1
	var migliore := ""
	for h in conti:
		if migliore == "" or int(conti[h]) > int(conti[migliore]) or (int(conti[h]) == int(conti[migliore]) and E.distanza(h, "S10") < E.distanza(migliore, "S10")):
			migliore = h
	return migliore

func _impatto(h: String) -> void:
	for v in p.veicoli.in_esagono(h):
		if not p.veicoli.attivo(v):
			continue
		var r: int = p.d10()
		var l := T.lettera_danno(T.GRANATA_FUORI, r)
		p._log("dado", "Mortaio sul mezzo %s: %d → %s." % [str(v.nome).to_lower(), r, p._nome_danno(l)])
		var occ: Array = p.veicoli.occupanti(v)
		if l in ["I", "K"]:
			p.veicoli.disabilita(v, "colpo di mortaio")
			for x in occ:
				if p.attivo(x):
					p._danno_esplosione(x, T.ARMI.carbine.danni)
		else:
			for x in occ:
				if p.attivo(x):
					p._danno_esplosione(x, T.ARMI.pistol.danni)
	var edificio: bool = p.terreno.edificio(h)
	var t: String = p.terreno.tipo(h)
	var tab: String = T.GRANATA_FUORI if edificio or not (t in ["clear", "road", "cover", "crater"]) else T.GRANATA_DENTRO
	for x in p.unita_in(h, "us") + p.unita_in(h, "de"):
		if p.attivo(x) and str(x.get("veicolo", "")) == "":
			p._danno_esplosione(x, tab)

# ------------------------------------------------------------------ operazioni
func op(o: Dictionary, ctx: Dictionary) -> bool:
	if not attiva():
		return false
	match str(o.op):
		"ss_blocco":
			blocco(str(ctx.get("hex", "")) if str(o.hex) == "@" else str(o.hex), bool(o.get("trappola", false)))
		"ss_girovagare":
			_st().letture118 = int(_st().get("letture118", 0)) + 1
			var n := int(_st().letture118)
			if n >= 3:
				p._pv(-1, "a zonzo con il pranzo (lettura %d del 118)" % n)
		"ss_pc_esatto":
			var chi: Dictionary = {}
			for a in p.unita_in(str(ctx.get("hex", "")), "us"):
				if p.attivo(a) and (chi.is_empty() or int(a.PC) > int(chi.PC)):
					chi = a
			if chi.is_empty():
				return true
			var r: int = p.d10()
			var pcv := int(chi.PC)
			p._log("dado", "Controllo di percezione di %s (PC %d): %d." % [p.nome(chi), pcv, r])
			if r <= pcv:
				p.leggi(str(o.esatto) if r == pcv else str(o.ok), ctx)
			else:
				p.leggi(str(o.ko), ctx)
		"ss_riattiva":
			_riattiva(o)
		"ss_dopo_685":
			var tornati: Array = [16, 17, 48, 49, 50].filter(func(n): return p.attivo(p.u("g%d" % n)) and p.in_mappa(p.u("g%d" % n)))
			if not bool(p.s.avvistamenti[6]):
				if tornati.is_empty():
					p.leggi("790", ctx)
				else:
					_st().leggi_790 = true
					p._log("info", "All’inizio del prossimo Round si legge il 790 al posto del controllo Evento.")
		"ss_fine_20":
			_st().fine20 = {"mezzi": o.mezzi, "soldati": o.soldati}
			p.missione.uscita_esagoni = o.soldati + o.mezzi
			p.missione.uscita_breve = "%s (mezzi) e %s (soldati)" % [", ".join(o.mezzi), ", ".join(o.soldati)]
			p._log("info", "Si esce: i mezzi da %s, i soldati da %s. Servono 6 PV." % [", ".join(o.mezzi), ", ".join(o.soldati)])
		"ss_piano":
			var g: Dictionary = p.u("g%d" % int(o.g))
			if not g.is_empty():
				g.piano = 1
		"ss_scendi_piano":
			var g2: Dictionary = p.u(str(ctx.get("g", "")))
			if not g2.is_empty():
				g2.piano = 0
				p._log("tedesco", "Il %s scende al piano terra." % p.nome(g2))
		"ss_333":
			var g3: Dictionary = p.u(str(ctx.get("g", "")))
			if not g3.is_empty():
				g3.reazione = ""
				if p.ia.bersagli(g3).is_empty():
					g3.postura = "crouching"
				else:
					var col: Dictionary = p.missione.tedeschi[str(int(g3.num))].colonne
					var gr: Array = p.missione.tedeschi[str(int(g3.num))].gruppi
					var num := int(p.s.round.get("numero_azione", 0))
					for i in gr.size():
						if num >= int(gr[i][0]) and num <= int(gr[i][1]):
							p.ia.esegui(int(col["D"][i]))
		"ss_431":
			var g4: Dictionary = p.u(str(ctx.get("g", "")))
			if g4.is_empty():
				return true
			if not p.ia.bersagli(g4).is_empty():
				p.ia.esegui(352)
			elif passati_tutti(str(o.varco)) or not vede_un_mezzo(g4):
				_togli(g4, int(o.bonus), "tedesco uscito dalla mappa")
			else:
				g4.postura = "prone"
		"ss_rimuovi_bonus":
			rimuovi_bonus(o.g)
		"ss_mortaio":
			attiva_mortaio(str(o.hex), str(o.get("adv", "")))
		"ss_galleria":
			_st().nota245 = true
		"ss_galleria_358":
			_st().g358 = true
			_controlla_galleria()
		"ss_794":
			_st().g794 = true
		"ss_nota_795":
			_st().g795 = true
		"ss_camion_esplode":
			_camion_esplode()
		"ss_trappola_ritardata":
			if _st().get("t991", false) or not _st().get("trappola_inesplosa", false):
				p._log("info", "Nessuna trappola rimasta inesplosa: nessun evento.")
			else:
				_trappola_991()
		"ss_caduta":
			_caduta()
		"ss_gomma_convoglio":
			_gomma()
		"ss_incidente":
			var v: Dictionary = p.veicoli.v(str(ctx.get("veicolo_id", ""))) if ctx.has("veicolo_id") else {}
			if v.is_empty():
				for x in ctx.get("ids", []):
					v = p.veicoli.di(p.u(str(x)))
					if not v.is_empty():
						break
			if not v.is_empty():
				p.veicoli.controllo_incidente(v, "curva tagliata")
		"ss_ponte_rotto":
			for id in ctx.get("ids", []):
				var x: Dictionary = p.u(str(id))
				var v2: Dictionary = p.veicoli.di(x)
				var da: String = str(x.get("hex_prec", ""))
				if da == "":
					continue
				if not v2.is_empty():
					if p.veicoli.e_autista(x):
						p.veicoli.sposta(v2, da)
						if p.fase_round():
							p.veicoli.controllo_incidente(v2, "ponte distrutto")
				else:
					x.hex = da
					if p.fase_round() and not p.controllo_pc(x, 0, "sul ponte distrutto"):
						x.postura = "prone"
				p._log("info", "Il ponte in %s è distrutto: si torna in %s." % [str(ctx.get("hex", "")), da])
		_:
			return false
	return true

func test(t: Dictionary, ctx: Dictionary):
	if not attiva():
		return null
	if t.has("ss_nessun_avvistamento"):
		return _nessun_avvistamento() == bool(t.ss_nessun_avvistamento)
	if t.has("ss_dispari"):
		return (int(p.s.get("round", {}).get("numero_azione", p.d10())) % 2 == 1) == bool(t.ss_dispari)
	if t.has("ss_us_entro"):
		var g: Dictionary = p.u(str(ctx.get("g", "")))
		if g.is_empty():
			return false
		for a in p.americani_attivi_in_mappa():
			if E.distanza(a.hex, g.hex) <= int(t.ss_us_entro):
				return true
		return false
	if t.has("ss_us_sud_strada"):
		var sud := 0
		var nord := 0
		for a in p.americani_attivi_in_mappa():
			if p.terreno.tipo(a.hex) == "road" or E.riga(a.hex) >= 16:
				sud += 1
			else:
				nord += 1
		return sud > nord
	if t.has("ss_g_attivi_in"):
		for n in t.ss_g_attivi_in[0]:
			var g2: Dictionary = p.u("g%d" % int(n))
			if not g2.is_empty() and p.attivo(g2) and g2.hex == str(t.ss_g_attivi_in[1]):
				return true
		return false
	if t.has("ss_al_piano"):
		var g3: Dictionary = p.u(str(ctx.get("g", "")))
		return not g3.is_empty() and int(g3.get("piano", 0)) > 0
	if t.has("ss_al_piano_us"):
		for id in ctx.get("ids", []):
			if int(p.u(str(id)).get("piano", 0)) > 0:
				return true
		return false
	if t.has("ss_camion_fuori_uso"):
		return not camion().filter(func(v): return v.stato == "distrutto" or (not p.veicoli.attivo(v) and v.stato != "uscito")).is_empty()
	if t.has("ss_vittima_mina_attiva"):
		for id in ctx.get("ids", []):
			if p.attivo(p.u(str(id))):
				return true
		return false
	return null

func inizio_round() -> void:
	if attiva() and _st().get("leggi_790", false):
		_st().leggi_790 = false
		if not bool(p.s.avvistamenti[6]):
			p.leggi("790", {})

func _riattiva(o: Dictionary) -> void:
	var r: int = p.d10()
	var tab: Dictionary = o.dispari if r % 2 == 1 else o.pari
	p._log("dado", "Dado %d (%s)." % [r, "dispari" if r % 2 == 1 else "pari"])
	var coppie: Array = []
	for k in tab:
		var g: Dictionary = p.u("g%s" % k)
		if not g.is_empty() and g.stato == "rimosso":
			coppie.append([int(k), str(tab[k])])
	if coppie.is_empty():
		p._log("info", "Nessuno di questi tedeschi era stato tolto dalla mappa.")
		return
	p._op({"op": "activate", "g": coppie, "stance": "crouching", "adv": null, "two": [], "us_two": false, "aware": false,
		"reaction": "", "rounds": true}, {})
	for c in coppie:
		var g2: Dictionary = p.u("g%d" % int(c[0]))
		if g2.is_empty():
			continue
		var dati: Dictionary = p.missione.tedeschi[str(int(c[0]))]
		for a in g2.armi:
			a.scarica = false
		var iniziali := int(dati.get("granate", 0))
		if int(g2.munizioni.get("granata", 0)) < iniziali:
			var d: int = p.d10()
			var piu: int = 0 if d <= 4 else (1 if d <= 7 else 2)
			g2.munizioni.granata = mini(iniziali, int(g2.munizioni.get("granata", 0)) + piu)
		var reaz: String = str(o.get("reazione", {}).get(str(int(c[0])), ""))
		if reaz != "":
			g2.reazione = reaz

func _camion_esplode() -> void:
	var lista: Array = camion().filter(func(v): return not p.veicoli.attivo(v) and str(v.hex) != "" and v.stato != "uscito" and not v.get("esploso", false))
	if lista.is_empty():
		return
	var v: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	v.esploso = true
	var h: String = v.hex
	p._log("danno", "La benzina prende fuoco: il %s esplode in %s!" % [v.nome.to_lower(), h])
	p._fx("esplosione", {"a": h, "grande": true})
	v.carichi = 0
	for x in p.veicoli.occupanti(v):
		if p.attivo(x):
			x.postura = "standing"
			p._danno_esplosione(x, T.CARICA_DENTRO)
	for w in p.veicoli.in_esagono(h):
		if w == v:
			continue
		var r: int = p.d10()
		if T.lettera_danno(T.CARICA_FUORI, r) in ["I", "K"]:
			p.veicoli.disabilita(w, "esplosione del camion")
		for x in p.veicoli.occupanti(w):
			if p.attivo(x):
				x.postura = "prone"
				p._danno_esplosione(x, T.CARICA_FUORI)
	for x in p.unita_in(h, "us") + p.unita_in(h, "de"):
		if p.attivo(x) and str(x.get("veicolo", "")) == "":
			p._danno_esplosione(x, T.CARICA_FUORI)

func _trappola_991() -> void:
	_st().t991 = true
	var h: String = str(_st().trappola_blocco)
	p._log("info", "La trappola del blocco in %s non era del tutto disinnescata ed esplode!" % h)
	p._fx("esplosione", {"a": h})
	for x in p.unita_in(h, "us") + p.unita_in(h, "de"):
		if p.attivo(x):
			p._danno_esplosione(x, T.GRANATA_DENTRO)

func _caduta() -> void:
	if _st().get("c993", false):
		return
	var lista: Array = p.americani_attivi_in_mappa().filter(func(a): return a.postura != "prone" and str(a.get("veicolo", "")) == "" \
		and not (p.terreno.tipo(a.hex) in ["road", "clear"]))
	if lista.is_empty():
		p._log("info", "Nessuno può cadere: nessun evento.")
		return
	_st().c993 = true
	var a: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	p._log("info", "%s scivola e cade." % p.nome(a))
	a.postura = "prone"
	if not p.controllo_pc(a, 0, "nella caduta"):
		p._danno_esplosione(a, T.ARMI.pistol.danni)

func _gomma() -> void:
	if _st().get("g999", false):
		return
	var lista: Array = mezzi_attivi()
	if lista.is_empty():
		return
	_st().g999 = true
	var v: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	v.gomme = false
	p._log("info", "%s fora una gomma: d’ora in poi va solo piano." % v.nome)
	p.veicoli.controllo_incidente(v, "gomma forata")
